import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:x32_core/x32_core.dart';

import '../design/tokens.dart';
import '../ui/widgets/controls.dart' show MeterSettings;
import 'prefs.dart';
import '../l10n/l10n.dart';

/// Pagine principali.
enum AppPage { mixer, dca, effects, routing, scenes }

/// Layer della vista mixer.
/// Layer del mixer: quattro pagine di ingressi da 8 canali, poi le altre categorie.
enum Layer { ch1, ch9, ch17, ch25, auxFx, bus, mtx, dca, band }

extension LayerLabel on Layer {
  String get label => switch (this) {
        Layer.ch1 => 'Ch 1–8',
        Layer.ch9 => 'Ch 9–16',
        Layer.ch17 => 'Ch 17–24',
        Layer.ch25 => 'Ch 25–32',
        Layer.auxFx => 'Aux · FX',
        Layer.bus => 'Bus',
        Layer.mtx => 'Matrix · Main',
        Layer.dca => 'DCA',
        Layer.band => tr('Utente'),
      };
}

/// Notifiche per singolo parametro: solo i widget interessati si ricostruiscono.
class ParamHub {
  ParamHub(this.state) {
    _sub = state.changes.listen((c) {
      final n = _notifiers[c.path];
      if (n != null) n.value = c.value;
    });
  }

  final MixerState state;
  late final StreamSubscription<ParamChange> _sub;
  final Map<String, ValueNotifier<Object?>> _notifiers = {};

  ValueListenable<Object?> listen(String path) => _notifiers.putIfAbsent(path, () {
        final s = state.specOf(path);
        return ValueNotifier<Object?>(s?.kind == ParamKind.string ? state.getString(path) : state.getIdx(path));
      });

  /// Da chiamare quando i campi cambiano struttura (cambio di tipo FX) o dopo un ripristino.
  void refreshAll() {
    for (final e in _notifiers.entries) {
      final s = state.specOf(e.key);
      e.value.value = s?.kind == ParamKind.string ? state.getString(e.key) : state.getIdx(e.key);
    }
  }

  void dispose() => _sub.cancel();
}

/// Ultimi valori dei meter, letti dal rendering a ogni frame (nessuna notifica per pacchetto).
class MeterHub {
  /// dB per strip (indice globale 0–79) ricavati dal banco 0 secondo [MeterBank0Map] [EXT].
  final Float64List stripDb = Float64List(80)..fillRange(0, 80, -127);
  final Map<int, DateTime> lastFrame = {};

  /// Riduzione di guadagno in dB (≤ 0) di gate e compressore dei canali 1–32, dal banco 16.
  final Float64List gateGrDb = Float64List(32);
  final Float64List compGrDb = Float64List(32);

  void onFrame(MeterFrame f) {
    lastFrame[f.bank] = DateTime.now();
    if (f.bank == MeterBank16Map.bank && f.values.length >= 64) {
      for (var ch = 1; ch <= 32; ch++) {
        gateGrDb[ch - 1] = math.min(0, f.db(MeterBank16Map.gate(ch)));
        compGrDb[ch - 1] = math.min(0, f.db(MeterBank16Map.comp(ch)));
      }
    }
    if (f.bank == 0 && f.values.length == 70) {
      for (var i = 0; i < 70; i++) {
        // banco 0: ch 0–31, aux 32–39, fxrtn 40–47, bus 48–63, mtx 64–69 (stesso ordine dell'indice globale)
        stripDb[i] = f.db(i);
      }
    }
  }

  bool hasData(int bank) {
    final t = lastFrame[bank];
    return t != null && DateTime.now().difference(t).inMilliseconds < 1000;
  }

  /// Vero se è arrivato un banco qualsiasi nell'ultimo secondo (orologio dei meter).
  bool get anyLive {
    final now = DateTime.now();
    for (final t in lastFrame.values) {
      if (now.difference(t).inMilliseconds < 1000) return true;
    }
    return false;
  }

  void clear() {
    stripDb.fillRange(0, 80, -127);
    gateGrDb.fillRange(0, 32, 0);
    compGrDb.fillRange(0, 32, 0);
    lastFrame.clear();
  }
}

/// Elimina i registri `x32remote_AAAA-MM-GG.log` più vecchi di [keep]. Restituisce quanti ne ha tolti.
int pruneLogs(Directory d, {required DateTime now, Duration keep = const Duration(days: 30)}) {
  var removed = 0;
  final re = RegExp(r'^x32remote_(\d{4}-\d{2}-\d{2})\.log$');
  try {
    for (final f in d.listSync().whereType<File>()) {
      final m = re.firstMatch(f.uri.pathSegments.last);
      final day = m == null ? null : DateTime.tryParse(m.group(1)!);
      if (day != null && now.difference(day) > keep) {
        f.deleteSync();
        removed++;
      }
    }
  } on FileSystemException {
    // pulizia facoltativa: un file bloccato resta lì
  }
  return removed;
}

class AppController extends ChangeNotifier {
  AppController({Prefs? prefs}) : prefs = prefs ?? Prefs.load() {
    hub = ParamHub(state);
    _undoSub = state.changes.listen((c) {
      _recordUndo(c);
      _watchFxType(c);
    });
    _openLog();
    applyAppearance();
    L10n.apply(this.prefs.language);
    this.prefs.onSaveError = (m) {
      log('E', m);
      notify(tr('Le impostazioni non sono state salvate: {p0}', {'p0': this.prefs.saveError ?? m}));
    };
    final problem = this.prefs.loadError;
    if (problem != null) {
      log('W', problem);
      final copy = this.prefs.corruptCopyPath;
      notify(this.prefs.loadUnreadable
          ? tr('Il file delle impostazioni era illeggibile: sono stati usati i valori predefiniti.')
          : tr('Alcune impostazioni non erano valide e sono tornate al valore predefinito: {p0}.', {'p0': this.prefs.loadBadFields.join(', ')}));
      if (copy != null) log('I', 'copia del file originale delle impostazioni: $copy');
    }
  }

  static final _fxTypePath = RegExp(r'^/fx/([1-8])/type$');
  Timer? _fxRefresh;

  /// Tipo di effetto cambiato dal mixer o da un altro client: i parametri del nuovo effetto
  /// vengono riletti dal mixer (stessa richiesta `/node` del cambio locale) e l'interfaccia aggiornata.
  void _watchFxType(ParamChange c) {
    if (c.origin != ChangeOrigin.remote) return;
    final m = _fxTypePath.firstMatch(c.path);
    if (m == null) return;
    _client?.requestNode('/fx/${m.group(1)}/par');
    _fxRefresh?.cancel();
    _fxRefresh = Timer(const Duration(milliseconds: 150), () {
      if (!_disposed) hub.refreshAll();
    });
  }

  /// Avvisi per l'utente, mostrati in basso dalla schermata principale (in ordine di arrivo).
  final List<String> pendingNotices = [];
  final ValueNotifier<int> noticeTick = ValueNotifier(0);

  void notify(String message) {
    pendingNotices.add(message);
    noticeTick.value++;
  }

  /// Cambia la lingua dell'interfaccia ('system' = lingua di Windows) e la salva.
  void setLanguage(String code) {
    prefs.language = code;
    prefs.save();
    L10n.apply(code);
    notifyListeners();
  }

  /// Applica il tema dei colori e i colori locali delle strip salvati nelle preferenze.
  void applyAppearance() {
    MxTheme.current = MxTheme.byId(prefs.colorTheme, prefs.customPalette);
    MxTheme.overrides = prefs.stripColorOverride;
    MxDensity.touch = prefs.touchMode == 'on' || (prefs.touchMode == 'auto' && (Platform.isAndroid || Platform.isIOS));
    MeterSettings.peakHoldMs = prefs.meterPeakHoldMs;
    MeterSettings.fallDbPerSecond = prefs.meterFall;
    MeterSettings.peakReadout = prefs.meterPeakReadout;
    MeterSettings.version++;
  }

  /// Richiesta di aprire il pannello laterale (finestre strette, pressione lunga su una strip).
  final panelRequest = ValueNotifier<int>(0);

  // ------------------------------------------------------------ annulla

  /// Modifiche locali annullabili (Ctrl+Z). I trascinamenti sullo stesso parametro
  /// entro 1 s diventano un solo passo. Non comprende scene, sync né file.
  final List<(String, Object?, DateTime)> _undo = [];
  late final StreamSubscription<ParamChange> _undoSub;
  bool _undoing = false;
  bool get canUndo => _undo.isNotEmpty;

  /// Svuota la cronologia: dopo sync, richiami, ripristini e caricamenti i valori "precedenti"
  /// non valgono più e Ctrl+Z li rimanderebbe al mixer.
  void clearUndo() {
    if (_undo.isEmpty) return;
    _undo.clear();
    notifyListeners();
  }

  /// Da chiamare dopo un richiamo di scena, snippet o cue partito verso il mixer.
  void afterRecall() => clearUndo();

  void _recordUndo(ParamChange c) {
    if (c.origin != ChangeOrigin.local || _undoing || c.previous == null) return;
    final now = DateTime.now();
    if (_undo.isNotEmpty && _undo.last.$1 == c.path && now.difference(_undo.last.$3).inMilliseconds < 1000) {
      _undo[_undo.length - 1] = (c.path, _undo.last.$2, now);
      return;
    }
    _undo.add((c.path, c.previous, now));
    if (_undo.length > 200) _undo.removeAt(0);
  }

  /// Annulla l'ultima modifica locale: il valore precedente viene inviato al mixer.
  String? undo() {
    if (_undo.isEmpty) return null;
    final (path, old, _) = _undo.removeLast();
    _undoing = true;
    try {
      if (old is int) {
        state.setIdx(path, old);
      } else if (old is String) {
        state.setString(path, old);
      }
    } finally {
      _undoing = false;
    }
    return path;
  }

  final Prefs prefs;

  /// Slot FX aperto nella pagina Effetti (resta scelto cambiando pagina).
  int fxSlot = 1;

  /// Scheda aperta nella pagina Routing.
  int routingTab = 4;
  final MixerState state = MixerState();
  late final ParamHub hub;
  final MeterHub meters = MeterHub();

  X32Client? _client;
  X32Client? get client => _client;
  StreamSubscription<LinkState>? _linkSub;
  StreamSubscription<MeterFrame>? _meterSub;
  StreamSubscription<LogEntry>? _logSub;
  StreamSubscription<int>? _soloSub;
  StreamSubscription<int>? _selSub;
  StreamSubscription<String>? _nodeSub;

  LinkState get link => _client?.link ?? LinkState.disconnected;
  MixerInfo? get mixer => _client?.mixer;
  bool get isOnline => link == LinkState.connected || link == LinkState.syncing;
  bool get isSimulator => mixer?.isSimulator ?? false;

  /// Lo stato locale è allineato al mixer solo dopo una sync completata in questa sessione.
  bool synced = false;

  AppPage page = AppPage.mixer;

  /// Scheda del pannello laterale (0 Canale, 1 EQ, 2 Mandate).
  final ValueNotifier<int> panelTab = ValueNotifier(0);
  Layer layer = Layer.ch1;
  StripRef selected = const StripRef(StripKind.ch, 1);

  /// 0 = i fader controllano il mix principale; 1–16 = mandate al bus N.
  int faderTarget = 0;

  /// Modalità di assegnazione della barra rapida.
  bool assignMode = false;

  final List<LogEntry> logs = [];

  // ------------------------------------------------------- diagnostica

  /// Cambi di stato del collegamento (ora, stato), ultimi 200.
  final List<(DateTime, LinkState)> linkEvents = [];

  /// Perdite del mixer in questa sessione.
  int lostCount = 0;

  /// Ultima sync Mixer → PC.
  SyncResult? lastSync;
  DateTime? lastSyncTime;

  /// Esporta un file di diagnostica (testo) nella cartella dei dati e ne restituisce il percorso.
  /// Contiene stato, contatori, coda di invio, ultima sync, avvisi di lettura ed eventi del registro.
  /// Non contiene lo stato completo del mixer (scene, nomi), tranne quanto già nel registro.
  File exportDiagnostics({String appVersion = ''}) {
    final c = _client;
    final q = c?.queue;
    final b = StringBuffer()
      ..writeln('# Diagnostica Fadera')
      ..writeln('creato: ${DateTime.now().toIso8601String()}')
      ..writeln('versione: $appVersion')
      ..writeln('sistema: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln()
      ..writeln('## Connessione')
      ..writeln('stato: ${link.name}${synced ? ', sincronizzato' : ', non sincronizzato'}')
      ..writeln('mixer: ${mixer == null ? '—' : '${mixer!.name} · ${mixer!.model} · firmware ${mixer!.firmware} · ${mixer!.ip}:${mixer!.port}${mixer!.isSimulator ? ' (SIMULATORE)' : ''}'}')
      ..writeln('perdite del mixer: $lostCount')
      ..writeln()
      ..writeln('## Traffico')
      ..writeln('inviati: ${c?.sentCount ?? 0} · ricevuti: ${c?.receivedCount ?? 0} · pacchetti non validi/scartati: ${c?.droppedCount ?? 0} · comandi rifiutati durante la perdita: ${c?.rejectedWhileLost ?? 0}')
      ..writeln('coda: in attesa ${q?.length ?? 0} (comandi ordinati ${q?.orderedLength ?? 0}) · accorpati ${q?.coalesced ?? 0} · rete occupata ${q?.wouldBlockCount ?? 0} · errori di invio ${q?.sendErrors ?? 0} · scartati ${q?.dropped ?? 0} · profondità massima ${q?.maxDepth ?? 0}')
      ..writeln()
      ..writeln('## Ultima sync Mixer → PC')
      ..writeln(lastSync == null
          ? 'nessuna'
          : '${lastSyncTime!.toIso8601String()}: ${lastSync!.completed}/${lastSync!.total} nodi, ritrasmissioni ${lastSync!.retransmissions}, ${lastSync!.elapsed.inMilliseconds} ms${lastSync!.cancelled ? ', annullata' : ''}${lastSync!.error == null ? '' : ', errore: ${lastSync!.error}'}')
      ..writeln()
      ..writeln('## Avvisi di lettura (${state.warnings.length})');
    for (final w in state.warnings.take(200)) {
      b.writeln(w);
    }
    b
      ..writeln()
      ..writeln('## Eventi del collegamento');
    for (final (t, s) in linkEvents) {
      b.writeln('${t.toIso8601String()} ${s.name}');
    }
    b
      ..writeln()
      ..writeln('## Registro (ultimi ${logs.length})');
    for (final e in logs) {
      b.writeln(e.toString());
    }
    final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '');
    final f = File('${appSubDir('diagnostica').path}${Platform.pathSeparator}diagnostica_$ts.txt');
    f.writeAsStringSync(b.toString());
    _addLog(LogEntry('I', 'diagnostica esportata: ${f.path}'));
    return f;
  }
  IOSink? _logFile;

  /// Scene, snippet e cue noti al mixer (righe `/-show/showfile/<tipo>/NNN`).
  final Map<String, Map<int, String>> datasetNames = {'scene': {}, 'snippet': {}, 'cue': {}};
  Map<int, String> get sceneNames => datasetNames['scene']!;

  final ValueNotifier<int> soloTick = ValueNotifier(0);

  // ------------------------------------------------------------- strip

  List<StripRef> stripsFor(Layer l) => switch (l) {
        Layer.ch1 || Layer.ch9 || Layer.ch17 || Layer.ch25 => [
            for (var i = inputFirst(l); i < inputFirst(l) + prefs.stripsPerPage; i++) StripRef(StripKind.ch, i),
          ],
        Layer.auxFx => [
            for (var i = 1; i <= 8; i++) StripRef(StripKind.auxin, i),
            for (var i = 1; i <= 8; i++) StripRef(StripKind.fxrtn, i),
          ],
        Layer.bus => [for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i)],
        Layer.mtx => [for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i), const StripRef(StripKind.mainSt, 1), const StripRef(StripKind.mainM, 1)],
        Layer.dca => [for (var i = 1; i <= 8; i++) StripRef(StripKind.dca, i)],
        Layer.band => [for (final p in prefs.bandStrips) ?parseStrip(p)],
      };

  /// Pagine degli ingressi visibili: quattro da 8 fader o due da 16.
  List<Layer> get inputLayers => prefs.stripsPerPage == 16 ? const [Layer.ch1, Layer.ch17] : const [Layer.ch1, Layer.ch9, Layer.ch17, Layer.ch25];

  /// Primo canale della pagina [l] con l'impostazione attuale (con 16 fader Ch 9 → 1, Ch 25 → 17).
  int inputFirst(Layer l) {
    final base = switch (l) { Layer.ch9 => 9, Layer.ch17 => 17, Layer.ch25 => 25, _ => 1 };
    return prefs.stripsPerPage == 16 ? (base <= 16 ? 1 : 17) : base;
  }

  /// Etichetta della pagina, che dipende da 8 o 16 fader per pagina.
  String layerLabel(Layer l) => inputLayers.contains(l) || l == Layer.ch9 || l == Layer.ch25
      ? 'Ch ${inputFirst(l)}–${inputFirst(l) + prefs.stripsPerPage - 1}'
      : l.label;

  /// Cambia il numero di fader per pagina (8 o 16) mantenendo visibile il canale corrente.
  void setStripsPerPage(int n) {
    prefs.stripsPerPage = n == 16 ? 16 : 8;
    prefs.save();
    layer = _normalizeLayer(layer);
    notifyListeners();
  }

  Layer _normalizeLayer(Layer l) {
    if (prefs.stripsPerPage != 16) return l;
    return switch (l) { Layer.ch9 => Layer.ch1, Layer.ch25 => Layer.ch17, _ => l };
  }

  /// La strip è nel layer Utente (salvato solo sul PC)?
  bool inUserLayer(StripRef s) => prefs.bandStrips.contains(s.base);

  /// Aggiunge o toglie una strip dal layer Utente; restituisce vero se ora è presente.
  bool toggleUserLayer(StripRef s) {
    final added = !inUserLayer(s);
    added ? prefs.bandStrips.add(s.base) : prefs.bandStrips.remove(s.base);
    prefs.save();
    notifyListeners();
    return added;
  }

  static StripRef? parseStrip(String base) {
    final m = RegExp(r'^/(ch|auxin|fxrtn|bus|mtx)/(\d\d)$').firstMatch(base);
    if (m != null) return StripRef(StripKind.values.byName(m.group(1)!), int.parse(m.group(2)!));
    if (base == '/main/st') return const StripRef(StripKind.mainSt, 1);
    if (base == '/main/m') return const StripRef(StripKind.mainM, 1);
    final d = RegExp(r'^/dca/(\d)$').firstMatch(base);
    if (d != null) return StripRef(StripKind.dca, int.parse(d.group(1)!));
    return null;
  }

  /// Percorso del fader controllato da una strip, secondo [faderTarget].
  String faderPath(StripRef s) {
    if (faderTarget > 0 && s.sendCount >= faderTarget) return '${s.base}/mix/${faderTarget.toString().padLeft(2, '0')}/level';
    if (s.kind == StripKind.dca) return '${s.base}/fader';
    return '${s.base}/mix/fader';
  }

  /// Strip collegata in coppia stereo secondo `/config/chlink|auxlink|fxlink|buslink|mtxlink`.
  /// I nodi sono opachi: l'ordine dei campi (una coppia per campo) è verificato sulle righe
  /// reali; il valore si aggiorna con la sync, non con le modifiche in tempo reale.
  bool isLinked(StripRef s) {
    final node = switch (s.kind) {
      StripKind.ch => '/config/chlink',
      StripKind.auxin => '/config/auxlink',
      StripKind.fxrtn => '/config/fxlink',
      StripKind.bus => '/config/buslink',
      StripKind.mtx => '/config/mtxlink',
      _ => null,
    };
    if (node == null) return false;
    final t = state.node(node)?.rawText?.trim().split(RegExp(r'\s+'));
    final pair = (s.number - 1) ~/ 2;
    return t != null && pair < t.length && t[pair] == 'ON';
  }

  String mutePath(StripRef s) => s.kind == StripKind.dca ? '${s.base}/on' : '${s.base}/mix/on';

  String stripName(StripRef s) {
    final n = state.getString('${s.base}/config/name');
    return (n == null || n.isEmpty) ? s.label : n;
  }

  /// Tutte le strip del mixer, nell'ordine della superficie.
  static final List<StripRef> allStrips = [
    for (var i = 1; i <= 32; i++) StripRef(StripKind.ch, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.auxin, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.fxrtn, i),
    for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i),
    for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i),
    const StripRef(StripKind.mainSt, 1),
    const StripRef(StripKind.mainM, 1),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.dca, i),
  ];

  static final _spaces = RegExp(r'\s+');
  static final _leadingZeros = RegExp(r' 0+(\d)');

  /// Ricerca rapida (Ctrl+F): per nome della strip, per sigla ("Ch 05", "bus 3", "dca 2")
  /// o solo per numero (canali). Prima le corrispondenze esatte, poi quelle iniziali, poi le altre.
  List<StripRef> searchStrips(String query, {int limit = 12}) {
    final q = query.trim().toLowerCase().replaceAll(_spaces, ' ');
    if (q.isEmpty) return const [];
    final n = int.tryParse(q);
    final ranked = <(int, StripRef)>[];
    for (final s in allStrips) {
      final name = stripName(s).toLowerCase();
      final label = s.label.toLowerCase();
      // sigla senza zeri iniziali e senza spazio: "ch 5", "ch5", "bus 3", "bus3"
      final short = label.replaceAllMapped(_leadingZeros, (m) => ' ${m.group(1)}');
      int? rank;
      if (n != null && s.kind == StripKind.ch && s.number == n) {
        rank = 0;
      } else if (q == short || q == short.replaceAll(' ', '') || q == label) {
        rank = 0;
      } else if (name.startsWith(q)) {
        rank = 1;
      } else if (name.contains(q)) {
        rank = 2;
      } else if (short.startsWith(q) || label.startsWith(q)) {
        rank = 3;
      }
      if (rank != null) ranked.add((rank, s));
    }
    ranked.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final r in ranked.take(limit)) r.$2];
  }

  /// Apre la pagina del mixer che contiene [s] e la seleziona.
  void goToStrip(StripRef s) {
    final l = switch (s.kind) {
      StripKind.ch => const [Layer.ch1, Layer.ch9, Layer.ch17, Layer.ch25][(s.number - 1) ~/ 8],
      StripKind.auxin || StripKind.fxrtn => Layer.auxFx,
      StripKind.bus => Layer.bus,
      StripKind.mtx || StripKind.mainSt || StripKind.mainM => Layer.mtx,
      StripKind.dca => Layer.dca,
    };
    layer = _normalizeLayer(l);
    page = AppPage.mixer;
    selected = s;
    notifyListeners();
  }

  /// Richiesta di aprire la ricerca rapida (scorciatoia Ctrl+F o pulsante della barra).
  final searchRequest = ValueNotifier<int>(0);

  void select(StripRef s) {
    if (s == selected) return;
    selected = s;
    notifyListeners();
  }

  void setLayer(Layer l) {
    layer = _normalizeLayer(l);
    page = AppPage.mixer;
    notifyListeners();
  }

  void setPage(AppPage p) {
    page = p;
    notifyListeners();
  }

  /// Notifica ai widget un cambiamento di preferenze o di stato dell'interfaccia.
  void refresh() => notifyListeners();

  void setFaderTarget(int t) {
    faderTarget = t;
    notifyListeners();
  }

  // ------------------------------------------------------- parametri

  /// Modifica locale: aggiorna lo stato e, se connessi, la invia (anti-eco nel motore).
  void setIdx(String path, int idx) => state.setIdx(path, idx);
  void setString(String path, String v) => state.setString(path, v);
  int? idx(String path) => state.getIdx(path);

  void toggle(String path) {
    final v = state.getIdx(path) ?? 0;
    state.setIdx(path, v == 0 ? 1 : 0);
  }

  bool soloOf(StripRef s) => _client?.solo[s.soloIndex] ?? false;

  void toggleSolo(StripRef s) {
    final c = _client;
    if (c == null || !isOnline) return;
    c.setSolo(s.soloIndex, !c.solo[s.soloIndex]);
    soloTick.value++;
  }

  // ----------------------------------------------------- connessione

  /// Ricerca su ogni scheda di rete, più una richiesta diretta all'ultimo mixer usato.
  Future<DiscoveryReport> discover() async {
    final last = InternetAddress.tryParse(prefs.lastHost.split(':').first);
    return X32Client.discoverAll(hosts: [if (last != null && last.type == InternetAddressType.IPv4) last]);
  }

  /// Si connette; il risultato è vero solo con una risposta reale del mixer.
  Future<MixerInfo> connect(String host, {int port = kX32Port}) async {
    // connessioni serializzate: un doppio clic o una riconnessione non lasciano client orfani
    // l'epoca si legge subito: una disconnessione chiesta da qui in poi annulla questa connessione
    final epoch = _epoch;
    final previous = _connecting;
    final mine = Completer<void>();
    _connecting = mine.future;
    try {
      await previous;
      return await _connectNow(host, port, epoch);
    } finally {
      mine.complete();
    }
  }

  Future<void>? _connecting;

  /// Cambia a ogni disconnessione richiesta dall'utente e a dispose: una connessione partita
  /// prima la riconosce e si annulla, invece di collegarsi comunque.
  int _epoch = 0;

  void _checkEpoch(int epoch, [X32Client? created]) {
    if (epoch != _epoch || _disposed) {
      created?.dispose();
      throw ConnectException('connessione annullata');
    }
  }

  Future<MixerInfo> _connectNow(String host, int port, int epoch) async {
    _checkEpoch(epoch);
    clearUndo();
    await _disconnectNow();
    _checkEpoch(epoch);
    final addr = (await InternetAddress.lookup(host)).firstWhere((a) => a.type == InternetAddressType.IPv4);
    _checkEpoch(epoch);
    final t = await UdpTransport.bind();
    if (epoch != _epoch || _disposed) {
      await t.close();
      throw ConnectException('connessione annullata');
    }
    final c = X32Client(transport: t, state: state)..autoReconnect = prefs.autoReconnect;
    _client = c;
    _linkSub = c.linkChanges.listen((s) {
      linkEvents.add((DateTime.now(), s));
      if (linkEvents.length > 200) linkEvents.removeAt(0);
      if (s == LinkState.lost) lostCount++;
      if (s == LinkState.lost) {
        meters.clear();
        // Durante la perdita le modifiche fatte sul mixer non arrivano e quelle locali non partono:
        // alla ripresa lo stato va considerato non allineato finché non si rifà la sync.
        synced = false;
      }
      notifyListeners();
    });
    _meterSub = c.meters.listen(meters.onFrame);
    _logSub = c.log.listen(_addLog);
    _soloSub = c.soloChanges.listen((_) => soloTick.value++);
    _selSub = c.mixerSelection.listen(_onMixerSelection);
    _nodeSub = c.nodeLines.listen(_onNodeLine);
    try {
      final info = await c.connect(addr, port: port);
      _checkEpoch(epoch);
      if (!identical(_client, c)) throw ConnectException('connessione annullata');
      prefs.lastHost = host;
      prefs.save();
      c.subscribeMeters(0);
      c.subscribeMeters(MeterBank16Map.bank); // riduzione di guadagno di gate e compressore
      synced = false;
      notifyListeners();
      return info;
    } on Object {
      if (identical(_client, c)) {
        await _disconnectNow();
      } else {
        await c.dispose();
      }
      rethrow;
    }
  }

  /// Disconnessione richiesta dall'esterno: annulla anche una connessione ancora in corso.
  Future<void> disconnect() async {
    _epoch++;
    await _disconnectNow();
  }

  Future<void> _disconnectNow() async {
    final c = _client;
    _client = null;
    for (final s in [_linkSub, _meterSub, _logSub, _soloSub, _selSub, _nodeSub]) {
      await s?.cancel();
    }
    // dispose chiude anche il trasporto e gli stream del client (prima restavano aperti a ogni riconnessione)
    await c?.dispose();
    meters.clear();
    synced = false;
    notifyListeners();
  }

  void _onMixerSelection(int idx) {
    if (!prefs.selectedFollowsMixer) return;
    // indice 0-based delle 80 strip (verificato in T03: 30 = ch 31, 48 = bus 1)
    final s = switch (idx) {
      < 32 => StripRef(StripKind.ch, idx + 1),
      < 40 => StripRef(StripKind.auxin, idx - 31),
      < 48 => StripRef(StripKind.fxrtn, idx - 39),
      < 64 => StripRef(StripKind.bus, idx - 47),
      < 70 => StripRef(StripKind.mtx, idx - 63),
      70 => const StripRef(StripKind.mainSt, 1),
      71 => const StripRef(StripKind.mainM, 1),
      _ => StripRef(StripKind.dca, idx - 71),
    };
    select(s);
  }

  static final _showfileLine = RegExp(r'^/-show/showfile/(scene|snippet|cue)/(\d{3})\s+"([^"]*)"');

  void _onNodeLine(String line) {
    // Formato verificato per le scene (T01b); per snippet e cue si legge solo il primo campo tra virgolette.
    final m = _showfileLine.firstMatch(line);
    if (m == null) return;
    final names = datasetNames[m.group(1)]!;
    final i = int.parse(m.group(2)!);
    final name = m.group(3)!;
    // nome vuoto con indicatori azzerati: posizione libera
    if (name.isEmpty && line.contains('%000000000')) {
      names.remove(i);
    } else {
      names[i] = name;
    }
    // l'elenco arriva a raffiche (fino a 700 righe dopo una sync): una sola notifica ogni 50 ms
    _namesTimer ??= Timer(const Duration(milliseconds: 50), () {
      _namesTimer = null;
      notifyListeners();
    });
  }

  Timer? _namesTimer;

  // ------------------------------------------------------------ sync

  Future<SyncResult> syncFromMixer(void Function(int, int) progress, bool Function() cancelled) async {
    final c = _client;
    if (c == null) return SyncResult(0, kSyncNodes.length, 0, Duration.zero, error: tr('mixer non connesso'));
    final r = await c.syncFromMixer(onProgress: progress, cancelled: cancelled);
    _undo.clear();
    lastSync = r;
    lastSyncTime = DateTime.now();
    synced = r.ok;
    hub.refreshAll();
    notifyListeners();
    return r;
  }

  /// Backup completo dello stato locale prima di un'operazione distruttiva.
  /// Salva sia i valori esatti (JSON) sia le righe di nodo (testo leggibile).
  File backupLocalState(String reason) {
    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '_');
    final dir = appSubDir('backup');
    final f = File('${dir.path}${Platform.pathSeparator}${ts}_$reason.json');
    f.writeAsStringSync(jsonEncode({
      'created': DateTime.now().toIso8601String(),
      'reason': reason,
      'mixer': mixer?.toString(),
      'values': state.captureValues(),
    }));
    File('${f.path.substring(0, f.path.length - 5)}.txt').writeAsStringSync(state.snapshot());
    _addLog(LogEntry('I', 'backup salvato: ${f.path}'));
    return f;
  }

  Future<SyncResult> syncToMixer(void Function(int, int) progress, bool Function() cancelled) async {
    final c = _client;
    if (c == null) return SyncResult(0, kSyncNodes.length, 0, Duration.zero, error: tr('mixer non connesso'));
    final r = await c.syncToMixer(onProgress: progress, cancelled: cancelled);
    // dopo un invio parziale lo stato del mixer non coincide più con quello del PC
    synced = r.ok;
    notifyListeners();
    return r;
  }

  /// Ripristina un backup nello stato locale (senza inviare nulla).
  /// Restituisce null se riuscito, altrimenti il motivo (il file viene controllato prima di toccare lo stato).
  String? restoreBackup(File f) {
    final Map<String, Object?> values;
    try {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      values = (j['values'] as Map<String, dynamic>).cast<String, Object?>();
    } on Object catch (e) {
      log('E', 'backup ${f.path} non valido: $e');
      return tr('file di backup non valido');
    }
    state.restoreValues(values, ChangeOrigin.load);
    _undo.clear();
    hub.refreshAll();
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------------- log

  void _openLog() {
    try {
      final d = appSubDir('logs');
      pruneLogs(d, now: DateTime.now());
      final day = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${d.path}${Platform.pathSeparator}x32remote_$day.log');
      _logBytes = file.existsSync() ? file.lengthSync() : 0;
      _logFile = file.openWrite(mode: FileMode.append);
    } on Object {
      _logFile = null;
    }
  }

  /// Il file del giorno non supera questa dimensione: oltre si scrive un'ultima riga e ci si ferma.
  static const maxLogFileBytes = 5 * 1024 * 1024;
  int _logBytes = 0;

  void _addLog(LogEntry e) {
    logs.add(e);
    if (logs.length > 2000) logs.removeRange(0, 500);
    final f = _logFile;
    if (f == null) return;
    final line = e.toString();
    _logBytes += utf8.encode(line).length + 2;
    if (_logBytes > maxLogFileBytes) {
      f.writeln('${DateTime.now().toIso8601String()} [W] registro del giorno oltre ${maxLogFileBytes ~/ (1024 * 1024)} MB: scrittura su disco sospesa (resta in Diagnostica)');
      _logFile = null;
      f.close();
      return;
    }
    f.writeln(line);
  }

  void log(String level, String msg) => _addLog(LogEntry(level, msg));

  bool _disposed = false;

  @override
  void notifyListeners() {
    // operazioni asincrone che finiscono dopo dispose non devono più notificare
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    prefs.saveNow();
    _disposed = true;
    final c = _client;
    _client = null;
    for (final s in [_linkSub, _meterSub, _logSub, _soloSub, _selSub, _nodeSub]) {
      s?.cancel();
    }
    _undoSub.cancel();
    _fxRefresh?.cancel();
    _namesTimer?.cancel();
    hub.dispose();
    soloTick.dispose();
    panelTab.dispose();
    panelRequest.dispose();
    noticeTick.dispose();
    searchRequest.dispose();
    _epoch++;
    final log = _logFile;
    _logFile = null;
    () async {
      try {
        await c?.dispose();
      } finally {
        await log?.close();
      }
    }();
    super.dispose();
  }
}
