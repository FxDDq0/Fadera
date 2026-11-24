/// Coda di invio verso il mixer.
///
/// Requisiti (uso dal vivo):
/// * **mai un valore vecchio dopo uno più recente** per lo stesso parametro;
/// * **coalescenza**: durante un trascinamento rapido, se il sistema non riesce a inviare
///   subito, resta in coda solo l'ultimo valore di ogni parametro;
/// * **ordine** rispettato per i comandi che richiedono una sequenza (scene, sync, solo,
///   sottoscrizioni): non vengono mai fusi né scartati;
/// * **coda limitata**: i parametri sono al massimo uno per percorso; i comandi hanno un
///   tetto ([maxOrdered]) oltre il quale l'accodamento fallisce con un errore esplicito;
/// * **errori di invio** gestiti: ritentativo breve, poi scarto con segnalazione.
///
/// Barriere: un parametro può essere fuso solo con una voce accodata *dopo* l'ultimo
/// comando ordinato. Esempio: fader A=1, richiamo scena, fader A=2 → si inviano A=1,
/// la scena, A=2 (non A=2 prima della scena, che lo cancellerebbe).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../osc/osc.dart';

/// Esito di un tentativo di invio al trasporto.
enum SendResult {
  /// Datagramma consegnato al sistema operativo.
  sent,

  /// Il sistema non può accettarlo ora (buffer pieno): riprovare quando torna scrivibile.
  wouldBlock,

  /// Errore del socket (rete assente, indirizzo non raggiungibile…).
  error,
}

class QueueFullException implements Exception {
  QueueFullException(this.limit);
  final int limit;
  @override
  String toString() => 'Coda dei comandi piena ($limit): comando non accodato';
}

class _Entry {
  _Entry(this.message, this.key, this.generation);
  OscMessage message;
  final String? key; // null = comando ordinato
  final int generation;
  int errors = 0;
  DateTime? retryAt;
}

class SendQueue {
  SendQueue({required this.sink, this.maxOrdered = 4096, this.maxErrorRetries = 20, this.retryDelay = const Duration(milliseconds: 50), this.onLog});

  /// Invia un datagramma già codificato.
  final SendResult Function(Uint8List data) sink;
  final int maxOrdered;
  final int maxErrorRetries;
  final Duration retryDelay;
  final void Function(String level, String message)? onLog;

  final _queue = Queue<_Entry>();
  final Map<String, _Entry> _byKey = {};
  int _generation = 0;
  int _ordered = 0;
  Timer? _retryTimer;
  Timer? _blockedTimer;
  Completer<void>? _drained;

  /// Vero dopo un `wouldBlock`: niente nuovi tentativi finché il socket non torna
  /// scrivibile ([onWritable]) o scade il controllo di sicurezza ([blockedRecheck]).
  bool _blocked = false;
  final Duration blockedRecheck = const Duration(milliseconds: 20);

  // statistiche
  int sent = 0;
  int coalesced = 0;
  int wouldBlockCount = 0;
  int sendErrors = 0;
  int dropped = 0;
  int maxDepth = 0;

  int get length => _queue.length;
  int get orderedLength => _ordered;
  bool get isEmpty => _queue.isEmpty;

  /// Accoda un parametro continuo o uno stato ripetitivo: fuso con l'eventuale voce
  /// ancora in attesa con la stessa [key] (di norma il percorso OSC).
  void enqueueLatest(OscMessage m, {String? key}) {
    final k = key ?? m.address;
    final e = _byKey[k];
    if (e != null && e.generation == _generation) {
      e.message = m;
      coalesced++;
      return;
    }
    final n = _Entry(m, k, _generation);
    _byKey[k] = n;
    _queue.add(n);
    _afterAdd();
  }

  /// Accoda un comando che va inviato esattamente, nell'ordine. Lancia [QueueFullException]
  /// se la coda dei comandi ha raggiunto [maxOrdered].
  void enqueueOrdered(OscMessage m) {
    if (_ordered >= maxOrdered) throw QueueFullException(maxOrdered);
    _generation++;
    _queue.add(_Entry(m, null, _generation));
    _ordered++;
    _generation++; // anche i parametri accodati dopo il comando restano dopo
    _afterAdd();
  }

  void _afterAdd() {
    if (_queue.length > maxDepth) maxDepth = _queue.length;
    flush();
  }

  /// Il trasporto segnala che il socket è di nuovo scrivibile.
  void onWritable() {
    _blocked = false;
    _blockedTimer?.cancel();
    flush();
  }

  /// Svuota la coda finché il trasporto accetta.
  void flush() {
    if (_blocked) return;
    while (_queue.isNotEmpty) {
      final e = _queue.first;
      final now = DateTime.now();
      if (e.retryAt != null && now.isBefore(e.retryAt!)) {
        _scheduleRetry(e.retryAt!.difference(now));
        return;
      }
      Uint8List data;
      try {
        data = encodeOsc(e.message);
      } on OscFormatException catch (x) {
        _drop(e, 'messaggio non codificabile ${e.message.address}: ${x.message}');
        continue;
      }
      final r = sink(data);
      switch (r) {
        case SendResult.sent:
          sent++;
          _remove(e);
        case SendResult.wouldBlock:
          wouldBlockCount++;
          _blocked = true;
          _blockedTimer?.cancel();
          _blockedTimer = Timer(blockedRecheck, onWritable); // sicurezza se l'evento non arriva
          return;
        case SendResult.error:
          sendErrors++;
          e.errors++;
          if (e.errors > maxErrorRetries) {
            _drop(e, 'invio di ${e.message.address} fallito ${e.errors} volte: scartato');
            continue;
          }
          e.retryAt = now.add(retryDelay);
          _scheduleRetry(retryDelay);
          return;
      }
    }
    _drained?.complete();
    _drained = null;
  }

  void _scheduleRetry(Duration d) {
    _retryTimer?.cancel();
    _retryTimer = Timer(d, flush);
  }

  void _remove(_Entry e) {
    _queue.removeFirst();
    if (e.key == null) {
      _ordered--;
    } else if (identical(_byKey[e.key], e)) {
      _byKey.remove(e.key);
    }
  }

  void _drop(_Entry e, String why) {
    dropped++;
    _remove(e);
    onLog?.call(e.key == null ? 'E' : 'W', why);
  }

  /// Completa quando la coda è vuota (contropressione per sync e invio di file).
  Future<void> drained() {
    if (_queue.isEmpty) return Future.value();
    return (_drained ??= Completer<void>()).future;
  }

  /// Svuota la coda senza inviare (disconnessione o perdita del mixer): evita che comandi
  /// vecchi partano minuti dopo, alla ripresa.
  int clear() {
    final n = _queue.length;
    _blocked = false;
    _blockedTimer?.cancel();
    _queue.clear();
    _byKey.clear();
    _ordered = 0;
    _retryTimer?.cancel();
    _drained?.complete();
    _drained = null;
    return n;
  }

  void dispose() {
    _retryTimer?.cancel();
    _blockedTimer?.cancel();
    clear();
  }
}
