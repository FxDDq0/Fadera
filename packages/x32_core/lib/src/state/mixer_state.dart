/// Stato centralizzato del mixer: un valore per ogni campo di ogni nodo.
///
/// Regola anti-eco (doc 15 par. 4.3, verificata su hardware): ogni modifica porta
/// la sua [ChangeOrigin]. Solo le modifiche [ChangeOrigin.local] vanno inviate al
/// mixer; quelle remote e di sync aggiornano il modello e la GUI e basta.
library;

import 'dart:async';

import '../fx/fx_types.dart';
import '../generated/fx_tables.g.dart';
import '../generated/sync_nodes.g.dart';
import '../osc/osc.dart';
import '../schema/param.dart';
import '../schema/x32_schema.dart';
import 'defaults.dart';
import 'node_line.dart';

enum ChangeOrigin {
  /// Modifica dell'utente in questa applicazione: va inviata al mixer.
  local,

  /// Messaggio arrivato dal mixer (o da un altro client tramite il mixer).
  remote,

  /// Riga ricevuta durante la sincronizzazione Mixer → PC.
  sync,

  /// Caricamento di un file o ripristino locale (non inviato).
  load,
}

/// Una modifica di un campo.
class ParamChange {
  const ParamChange(this.node, this.fieldIndex, this.origin, {this.previous});
  final NodeValue node;
  final int fieldIndex;
  final ChangeOrigin origin;

  /// Valore precedente (per l'annullamento delle modifiche locali); può mancare.
  final Object? previous;

  ParamSpec get spec => node.fields[fieldIndex];
  String get path => node.leafPath(fieldIndex);
  Object? get value => node.values[fieldIndex];
}

/// Valori di un nodo. I campi numerici contengono l'indice (`int`), le stringhe
/// un `String`, i campi opachi il token così com'è (`NodeToken`).
class NodeValue {
  NodeValue(this.spec) : fields = List.of(spec.fields), values = List.filled(spec.fields.length, null, growable: true);

  final NodeSpec spec;
  List<ParamSpec> fields;
  final List<Object?> values;

  /// Per i nodi opachi: il testo dei valori così come ricevuto.
  String? rawText;

  String get path => spec.path;
  String leafPath(int i) => '$path/${fields[i].name}';

  int? idx(int i) => values[i] is int ? values[i] as int : null;
  String? str(int i) => values[i] is String ? values[i] as String : null;

  /// Testo dei valori, nel formato delle righe di nodo.
  String valuesText() {
    if (spec.opaque) return rawText ?? '';
    final parts = <String>[];
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      final v = values[i];
      if (v == null) {
        parts.add(f.kind == ParamKind.string ? '""' : '0');
      } else if (v is NodeToken) {
        parts.add(v.raw);
      } else if (f.kind == ParamKind.string) {
        parts.add('"${(v as String).replaceAll('"', '')}"');
      } else {
        parts.add(f.formatIdx(v as int));
      }
    }
    return parts.join(' ');
  }

  String toLine() {
    final t = valuesText();
    return t.isEmpty ? path : '$path $t';
  }
}

/// Nodi fuori dalla tabella di sync accettati al massimo (scene, snippet, cue ne usano meno di 400).
const kMaxDynamicNodes = 4096;

/// Lunghezza massima di una riga di nodo accettata.
const kMaxNodeLineLength = 2048;

/// Avvisi di lettura conservati al massimo.
const kMaxWarnings = 500;

class MixerState {
  MixerState({bool initDefaults = true}) {
    for (final p in kSyncNodes) {
      _addNode(p);
    }
    if (initDefaults) resetToDefaults();
  }

  final Map<String, NodeValue> _nodes = {};
  final Map<String, (NodeValue, int)> _leaves = {};
  final _changes = StreamController<ParamChange>.broadcast(sync: true);
  final _warnings = <String>[];

  /// Flusso sincrono delle modifiche.
  Stream<ParamChange> get changes => _changes.stream;

  /// Avvisi di parsing (righe con campi inattesi, valori fuori tabella).
  List<String> get warnings => List.unmodifiable(_warnings);

  /// Avvisi conservati al massimo: i più vecchi lasciano il posto ai nuovi.
  void _warn(String w) {
    _warnings.add(w);
    if (_warnings.length > kMaxWarnings) _warnings.removeRange(0, _warnings.length - kMaxWarnings);
  }

  int _dynamicNodes = 0;
  static final _dynamicPath = RegExp(r'^/[A-Za-z0-9_\-]+(/[A-Za-z0-9_\-]+){0,7}$');

  Iterable<NodeValue> get nodes => _nodes.values;
  NodeValue? node(String path) => _nodes[path];

  void _addNode(String path) {
    final spec = nodeSpecFor(path);
    final n = NodeValue(spec);
    _nodes[path] = n;
    _indexLeaves(n);
  }

  void _indexLeaves(NodeValue n) {
    for (var i = 0; i < n.fields.length; i++) {
      if (n.fields[i].kind != ParamKind.opaque) _leaves[n.leafPath(i)] = (n, i);
    }
  }

  /// Ripristina tutti i nodi ai valori iniziali (nessun invio).
  void resetToDefaults() {
    for (final n in _nodes.values) {
      if (n.spec.dynamicFx != null) continue;
      applyNodeLine('${n.path} ${defaultValuesFor(n.path)}', ChangeOrigin.load, notify: false);
    }
    for (var s = 1; s <= 8; s++) {
      resetFxParams(s, ChangeOrigin.load, notify: false);
    }
  }

  // ------------------------------------------------------------ lettura

  ParamSpec? specOf(String leaf) {
    final e = _leaves[leaf];
    return e == null ? null : e.$1.fields[e.$2];
  }

  bool hasParam(String leaf) => _leaves.containsKey(leaf);

  int? getIdx(String leaf) {
    final e = _leaves[leaf];
    return e?.$1.idx(e.$2);
  }

  String? getString(String leaf) {
    final e = _leaves[leaf];
    return e?.$1.str(e.$2);
  }

  double? getPhysical(String leaf) {
    final e = _leaves[leaf];
    if (e == null) return null;
    final i = e.$1.idx(e.$2);
    return i == null ? null : e.$1.fields[e.$2].physical(i);
  }

  String? fxTypeCode(int slot) {
    final n = _nodes['/fx/$slot'];
    final i = n?.idx(0);
    if (n == null || i == null) return null;
    return n.fields[0].labels![i];
  }

  FxTypeDef? fxType(int slot) {
    final c = fxTypeCode(slot);
    return c == null ? null : kFxTypes[c];
  }

  // ---------------------------------------------------------- scrittura

  /// Modifica un parametro. Con [ChangeOrigin.local] il client lo invierà al mixer.
  /// Restituisce falso se il percorso non esiste o il valore non cambia.
  bool setIdx(String leaf, int idx, {ChangeOrigin origin = ChangeOrigin.local}) {
    final e = _leaves[leaf];
    if (e == null) return false;
    final (n, i) = e;
    final spec = n.fields[i];
    if (!spec.isNumeric) return false;
    final v = spec.clampIdx(idx);
    final old = n.values[i];
    if (old == v) return false;
    n.values[i] = v;
    _afterFieldChange(n, i, origin, previous: old);
    return true;
  }

  bool setString(String leaf, String value, {ChangeOrigin origin = ChangeOrigin.local}) {
    final e = _leaves[leaf];
    if (e == null) return false;
    final (n, i) = e;
    final spec = n.fields[i];
    if (spec.kind != ParamKind.string) return false;
    final v = value.length > spec.steps ? value.substring(0, spec.steps) : value;
    final old = n.values[i];
    if (old == v) return false;
    n.values[i] = v;
    _afterFieldChange(n, i, origin, previous: old);
    return true;
  }

  void _afterFieldChange(NodeValue n, int i, ChangeOrigin origin, {bool notify = true, Object? previous}) {
    if (n.path.startsWith('/fx/') && n.fields[i].name == 'type') {
      _rebuildFxPar(int.parse(n.path.substring(4)));
    }
    if (notify) _changes.add(ParamChange(n, i, origin, previous: previous));
  }

  void _rebuildFxPar(int slot) {
    final par = _nodes['/fx/$slot/par'];
    final code = fxTypeCode(slot);
    if (par == null || code == null) return;
    _leaves.removeWhere((k, v) => identical(v.$1, par));
    final old = List<Object?>.of(par.values);
    final oldFields = par.fields;
    par.fields = fxParFields(code);
    par.values
      ..clear()
      ..addAll(List.filled(64, null));
    for (var i = 0; i < 64 && i < old.length; i++) {
      // conserva l'indice solo se il campo resta dello stesso tipo
      if (i < oldFields.length && oldFields[i].kind == par.fields[i].kind && old[i] is int) {
        par.values[i] = par.fields[i].clampIdx(old[i] as int);
      } else if (par.fields[i].kind == ParamKind.opaque) {
        par.values[i] = const NodeToken('0');
      }
    }
    _indexLeaves(par);
  }

  /// Applica i default dell'effetto corrente allo slot (Appendice C, colonna Default).
  void resetFxParams(int slot, ChangeOrigin origin, {bool notify = true}) {
    _rebuildFxPar(slot);
    final par = _nodes['/fx/$slot/par'];
    final t = fxType(slot);
    if (par == null || t == null) return;
    for (var i = 0; i < 64; i++) {
      par.values[i] = par.fields[i].kind == ParamKind.opaque ? const NodeToken('0') : 0;
    }
    for (final p in t.params) {
      par.values[p.index - 1] = p.defaultIdx;
      if (notify) _changes.add(ParamChange(par, p.index - 1, origin));
    }
  }

  // ------------------------------------------------------------ OSC in

  /// Applica un messaggio di parametro ricevuto (`/path ,i|,f|,s` con un solo argomento).
  /// I messaggi con argomenti in numero o tipo inattesi vengono scartati (doc 15 par. 7).
  bool applyOsc(OscMessage m, {ChangeOrigin origin = ChangeOrigin.remote}) {
    if (m.args.length != 1) return false;
    final e = _leaves[m.address];
    if (e == null) return false;
    final (n, i) = e;
    final spec = n.fields[i];
    final a = m.args.single;
    if (spec.kind == ParamKind.string) {
      if (a is! OscString) return false;
      return setString(m.address, a.value, origin: origin);
    }
    final idx = spec.idxFromOsc(a);
    if (idx == null) return false;
    return setIdx(m.address, idx, origin: origin);
  }

  /// Messaggio OSC per inviare un parametro (un messaggio, un argomento).
  OscMessage? oscFor(String leaf) {
    final e = _leaves[leaf];
    if (e == null) return null;
    final (n, i) = e;
    final spec = n.fields[i];
    final v = n.values[i];
    if (spec.kind == ParamKind.string) return OscMessage(leaf, [OscString((v as String?) ?? '')]);
    if (v is! int) return null;
    return OscMessage(leaf, [spec.toOsc(v)]);
  }

  // ----------------------------------------------------- righe di nodo

  /// Applica una riga di nodo (`node ,s` del mixer, file di scena, simulatore).
  /// Restituisce falso se il nodo non esiste.
  bool applyNodeLine(String line, ChangeOrigin origin, {bool notify = true}) {
    final split = splitNodeLine(line);
    if (split == null) return false;
    final (path, tokens) = split;
    var n = _nodes[path];
    if (n == null) {
      // Nodi fuori dalla tabella di sync (es. /-show/showfile/scene/NNN): conservati come opachi,
      // entro limiti di sicurezza (percorso plausibile, riga corta, numero massimo di nodi).
      if (!_dynamicPath.hasMatch(path) || line.length > kMaxNodeLineLength) {
        _warn('riga di nodo rifiutata: ${path.length > 64 ? '${path.substring(0, 64)}…' : path}');
        return false;
      }
      if (_dynamicNodes >= kMaxDynamicNodes) {
        if (_dynamicNodes == kMaxDynamicNodes) _warn('raggiunto il limite di $kMaxDynamicNodes nodi fuori tabella: gli altri sono ignorati');
        _dynamicNodes = kMaxDynamicNodes + 1;
        return false;
      }
      _dynamicNodes++;
      _addNode(path);
      n = _nodes[path]!;
    } else if (line.length > kMaxNodeLineLength) {
      _warn('$path: riga troppo lunga (${line.length} caratteri), ignorata');
      return false;
    }
    if (n.spec.opaque) {
      final text = tokens.map((t) => t.raw).join(' ');
      // conserva la spaziatura originale dopo il percorso
      final idx = line.indexOf(path) + path.length;
      final tail = line.substring(idx).replaceFirst(RegExp(r'^ '), '').trimRight();
      // nodo opaco: il testo è conservato così com'è (riga applicata, nessun evento per campo)
      n.rawText = tail.isEmpty ? text : tail;
      return true;
    }
    if (n.spec.dynamicFx != null && n.fields.isEmpty) _rebuildFxPar(n.spec.dynamicFx!);
    if (tokens.length != n.fields.length) {
      _warn('$path: ${tokens.length} valori invece di ${n.fields.length}');
    }
    final count = tokens.length < n.fields.length ? tokens.length : n.fields.length;
    for (var i = 0; i < count; i++) {
      final f = n.fields[i];
      final t = tokens[i];
      Object? v;
      switch (f.kind) {
        case ParamKind.string:
          v = t.text.length > f.steps ? t.text.substring(0, f.steps) : t.text;
        case ParamKind.opaque:
          v = t;
        default:
          v = f.parseText(t.text);
          if (v == null) {
            _warn('$path/${f.name}: valore non valido "${t.text}"');
            continue;
          }
      }
      if (n.values[i] != v || v is NodeToken) {
        n.values[i] = v;
        if (f.kind != ParamKind.opaque) _afterFieldChange(n, i, origin, notify: notify);
      }
    }
    return true;
  }

  /// Riga di nodo da inviare (sync PC → Mixer, file di scena).
  String? nodeLine(String path) => _nodes[path]?.toLine();

  /// Istantanea testuale completa (backup prima delle operazioni distruttive).
  String snapshot() => kSyncNodes.map((p) => _nodes[p]!.toLine()).join('\n');

  /// Copia esatta di tutti i valori (indici, stringhe, testo dei nodi opachi):
  /// a differenza di [snapshot] non perde risoluzione (le righe hanno 0,1 dB).
  Map<String, Object?> captureValues() {
    final out = <String, Object?>{};
    for (final n in _nodes.values) {
      if (n.spec.opaque) {
        out[n.path] = n.rawText;
        continue;
      }
      for (var i = 0; i < n.fields.length; i++) {
        final v = n.values[i];
        out[n.leafPath(i)] = v is NodeToken ? v.raw : v;
      }
    }
    return out;
  }

  /// Ripristina i valori catturati con [captureValues]. Le modifiche vengono
  /// notificate con [origin] (per esempio `load` per non inviarle).
  void restoreValues(Map<String, Object?> values, ChangeOrigin origin) {
    // prima i tipi FX, perché ricostruiscono i campi di /fx/N/par
    for (var s = 1; s <= 8; s++) {
      final v = values['/fx/$s/type'];
      if (v is int) setIdx('/fx/$s/type', v, origin: origin);
    }
    values.forEach((k, v) {
      final n = _nodes[k];
      if (n != null && n.spec.opaque) {
        n.rawText = v as String?;
        return;
      }
      if (v is int) {
        setIdx(k, v, origin: origin);
      } else if (v is String && _leaves[k]?.$1.fields[_leaves[k]!.$2].kind == ParamKind.string) {
        setString(k, v, origin: origin);
      }
    });
  }

  void clearWarnings() => _warnings.clear();

  Future<void> dispose() => _changes.close();
}
