/// Simulatore X32: implementa i comportamenti documentati e verificati su hardware
/// per provare l'applicazione senza mixer. Ascolta esclusivamente su 127.0.0.1.
///
/// Comportamenti dove l'hardware non dà ancora una risposta (righe `/ ,s` della
/// sync PC → Mixer, solo inviato dal PC, dataset) seguono una scelta del simulatore,
/// documentata qui e in docs/SIMULATORE.md: non vanno presi come prova di compatibilità.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:x32_core/x32_core.dart';

const kSimulatorName = 'X32-SIMULATOR';

class _Client {
  _Client(this.address, this.port, UdpTransport socket) {
    queue = SendQueue(sink: (d) => socket.trySend(d, address, port), maxOrdered: 200000);
  }

  /// Coda verso questo client: i blob delle sottoscrizioni sono fusi (resta l'ultimo),
  /// tutto il resto è inviato nell'ordine.
  late final SendQueue queue;
  final InternetAddress address;
  final int port;
  DateTime xremoteUntil = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, _Sub> subs = {};
  String get key => '${address.address}:$port';
}

class _Sub {
  _Sub(this.alias, this.factor, this.until);
  final String alias;
  final int factor;
  DateTime until;
  int tick = 0;
}

class Scene {
  Scene(this.name, this.notes, this.values);
  String name;
  String notes;

  /// Valori esatti (come in un mixer reale, che non passa dal testo).
  final Map<String, Object?> values;
}

class X32Simulator {
  X32Simulator._(this._socket, {required this.model, required this.firmware}) {
    _socket.incoming.listen(_onPacket, onError: (Object _) {});
    _socket.writable.listen((_) {
      for (final c in _clients.values) {
        c.queue.onWritable();
      }
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _onTick());
  }

  /// Avvia il simulatore. [port] 0 sceglie una porta libera (test automatici).
  /// [initFile] o [initLines]: righe di nodo iniziali (scena dimostrativa).
  static Future<X32Simulator> start({int port = kX32Port, String model = 'X32', String firmware = '4.15-SIM', String? initFile, List<String>? initLines}) async {
    final s = await UdpTransport.bind(address: InternetAddress.loopbackIPv4, port: port, policy: TransportPolicy.loopbackOnly);
    final sim = X32Simulator._(s, model: model, firmware: firmware);
    for (final l in [if (initFile != null) ...File(initFile).readAsLinesSync(), ...?initLines]) {
      sim.state.applyNodeLine(l, ChangeOrigin.load, notify: false);
    }
    return sim;
  }

  final UdpTransport _socket;
  final String model;
  final String firmware;
  final MixerState state = MixerState();
  final Map<String, _Client> _clients = {};
  final Map<String, Map<int, Scene>> datasets = {'scene': {}, 'snippet': {}, 'cue': {}};
  Map<int, Scene> get scenes => datasets['scene']!;
  final List<bool> solo = List.filled(81, false);
  late final Timer _timer;
  final _rnd = math.Random(7);
  int _ticks = 0;

  int get port => _socket.localPort;

  /// Simulazione di un'interruzione: finché è vero il simulatore non risponde.
  bool paused = false;

  /// Percentuale di pacchetti in ingresso ignorati (test di robustezza).
  double dropRate = 0;

  int received = 0;

  /// Ultimi indirizzi ricevuti (per i test: verificare che il client non rimandi gli echi).
  final List<String> receivedAddresses = [];
  int sent = 0;
  final List<String> log = [];

  Future<void> close() async {
    _timer.cancel();
    await _socket.close();
  }

  // --------------------------------------------------------------- invio

  void _sendTo(_Client c, OscMessage m) {
    if (m.args.length == 1 && m.args.single is OscBlob) {
      c.queue.enqueueLatest(m, key: m.address);
    } else {
      c.queue.enqueueOrdered(m);
    }
    sent++;
  }

  /// Notifica i client con /xremote attivo, escluso il mittente
  /// (comportamento verificato su hardware in T03c).
  void _broadcast(OscMessage m, {_Client? except}) {
    final now = DateTime.now();
    for (final c in _clients.values) {
      if (identical(c, except)) continue;
      if (c.xremoteUntil.isAfter(now)) _sendTo(c, m);
    }
  }

  // ----------------------------------------------------------- ricezione

  void _onPacket(UdpPacket d) {
    if (!d.address.isLoopback) return; // mai traffico esterno
    received++;
    if (paused) return;
    if (dropRate > 0 && _rnd.nextDouble() < dropRate) return;
    final c = _clients.putIfAbsent('${d.address.address}:${d.port}', () => _Client(d.address, d.port, _socket));
    List<OscMessage> msgs;
    try {
      msgs = decodeOsc(d.data);
    } on OscFormatException {
      return;
    }
    for (final m in msgs) {
      if (receivedAddresses.length > 5000) receivedAddresses.removeRange(0, 1000);
      receivedAddresses.add(m.address);
      _handle(c, m);
    }
  }

  void _handle(_Client c, OscMessage m) {
    final a = m.address;
    final now = DateTime.now();
    switch (a) {
      case '/xinfo':
        _sendTo(c, OscMessage('/xinfo', [const OscString('127.0.0.1'), const OscString(kSimulatorName), OscString(model), OscString(firmware)]));
        return;
      case '/status':
        _sendTo(c, OscMessage('/status', [const OscString('active'), const OscString('127.0.0.1'), const OscString(kSimulatorName)]));
        return;
      case '/xremote':
        c.xremoteUntil = now.add(const Duration(seconds: 10));
        return;
      case '/node':
        if (m.args.length == 1 && m.args.single is OscString) {
          final path = '/${(m.args.single as OscString).value}';
          final line = state.nodeLine(path);
          if (line != null) _sendTo(c, OscMessage('node', [OscString('$line\n')]));
        }
        return;
      case '/':
        // Scelta del simulatore (hardware non verificato): applica la riga, nessuna risposta,
        // notifica gli altri client campo per campo.
        if (m.args.length == 1 && m.args.single is OscString) {
          final sub = state.changes.listen((ch) {
            final om = state.oscFor(ch.path);
            if (om != null) _broadcast(om, except: c);
          });
          state.applyNodeLine('/${(m.args.single as OscString).value}', ChangeOrigin.remote);
          sub.cancel();
        }
        return;
      case '/batchsubscribe':
        if (m.args.length == 5 && m.args[0] is OscString && m.args[4] is OscInt) {
          final alias = (m.args[0] as OscString).value;
          c.subs[alias] = _Sub(alias, math.max(1, (m.args[4] as OscInt).value), now.add(const Duration(seconds: 10)));
        }
        return;
      case '/formatsubscribe':
        if (m.args.isNotEmpty && m.args.first is OscString && m.args.last is OscInt) {
          final alias = (m.args.first as OscString).value;
          c.subs[alias] = _Sub(alias, math.max(1, (m.args.last as OscInt).value), now.add(const Duration(seconds: 10)));
        }
        return;
      case '/renew':
        if (m.args.length == 1 && m.args.single is OscString) {
          c.subs[(m.args.single as OscString).value]?.until = now.add(const Duration(seconds: 10));
        }
        return;
      case '/unsubscribe':
        if (m.args.isEmpty) {
          c.subs.clear();
          c.xremoteUntil = DateTime.fromMillisecondsSinceEpoch(0);
        } else if (m.args.single is OscString) {
          c.subs.remove((m.args.single as OscString).value);
        }
        return;
      case '/showdump':
        _sendTo(c, OscMessage('node', [const OscString('/-show/showfile/show "SIMULATOR" 0 0 0 0 0 0 0 0 0 0 "4.15"\n')]));
        for (final type in datasets.keys) {
          for (final idx in datasets[type]!.keys) {
            _sendTo(c, OscMessage('node', [OscString(_datasetLine(type, idx))]));
          }
        }
        return;
      case '/save':
      case '/load':
      case '/copy':
      case '/delete':
      case '/rename':
      case '/add':
        _dataset(a, m);
        return;
    }
    if (a.startsWith('/-stat/solosw/')) {
      final n = int.tryParse(a.substring(14));
      if (n != null && n >= 1 && n <= 80 && m.args.length == 1 && m.args.single is OscInt) {
        solo[n] = (m.args.single as OscInt).value != 0;
        _broadcast(OscMessage(a, [OscInt(solo[n] ? 1 : 0)]), except: c);
        _broadcast(OscMessage('/-stat/solo', [OscInt(solo.any((x) => x) ? 1 : 0)]), except: c);
      }
      return;
    }
    if (a.startsWith('/-')) return;
    if (m.args.isEmpty) {
      final om = state.oscFor(a);
      if (om != null) _sendTo(c, om);
      return;
    }
    if (state.applyOsc(m, origin: ChangeOrigin.remote)) {
      final om = state.oscFor(a);
      if (om != null) _broadcast(om, except: c);
    }
  }


  /// Dataset (scene, snippet, cue) gestiti in memoria. Il formato delle righe
  /// `/-show/showfile/<tipo>/NNN` è quello osservato per le scene in T01b; per snippet e
  /// cue è una scelta del simulatore. Uno snippet qui salva tutti i valori (sul mixer reale
  /// contiene solo una parte dei parametri); richiamare un cue non cambia i parametri.
  void _dataset(String cmd, OscMessage m) {
    if (m.args.isEmpty || m.args[0] is! OscString) return;
    final type = (m.args[0] as OscString).value;
    final store = datasets[type];
    if (store == null) return;
    int? arg(int i) => m.args.length > i && m.args[i] is OscInt ? (m.args[i] as OscInt).value : null;
    String sarg(int i) => m.args.length > i && m.args[i] is OscString ? (m.args[i] as OscString).value : '';
    final idx = arg(1);
    if (idx == null) return;
    switch (cmd) {
      case '/save':
        if (type == 'cue') return; // /save non prevede i cue (doc 15 par. 6.4)
        store[idx] = Scene(sarg(2), sarg(3), state.captureValues());
        _broadcast(OscMessage('node', [OscString(_datasetLine(type, idx))]));
      case '/add':
        if (type != 'cue') return;
        store[idx] = Scene(sarg(2), '', const {});
        _broadcast(OscMessage('node', [OscString(_datasetLine(type, idx))]));
      case '/load':
        final sc = store[idx];
        if (sc == null || type == 'cue') return;
        final sub = state.changes.listen((ch) {
          final om = state.oscFor(ch.path);
          if (om != null) _broadcast(om); // un richiamo aggiorna tutti i client
        });
        state.restoreValues(sc.values, ChangeOrigin.remote);
        sub.cancel();
      case '/copy':
        final src = store[idx];
        final dst = arg(2);
        if (src == null || dst == null) return;
        store[dst] = Scene(src.name, src.notes, Map.of(src.values));
        _broadcast(OscMessage('node', [OscString(_datasetLine(type, dst))]));
      case '/delete':
        if (store.remove(idx) != null) {
          _broadcast(OscMessage('node', [OscString('/-show/showfile/$type/${idx.toString().padLeft(3, '0')} "" "" %000000000 0\n')]));
        }
      case '/rename':
        final sc = store[idx];
        if (sc == null) return;
        sc.name = sarg(2);
        sc.notes = sarg(3);
        _broadcast(OscMessage('node', [OscString(_datasetLine(type, idx))]));
    }
  }

  String _datasetLine(String type, int idx) {
    final sc = datasets[type]![idx]!;
    return '/-show/showfile/$type/${idx.toString().padLeft(3, '0')} "${sc.name}" "${sc.notes}" %111111110 1\n';
  }

  // -------------------------------------------- modifiche "sul mixer"

  /// Simula una modifica fatta sulla superficie del mixer: tutti i client ricevono il valore.
  void surfaceSet(String path, int idx) {
    if (state.setIdx(path, idx, origin: ChangeOrigin.remote)) {
      final om = state.oscFor(path);
      if (om != null) _broadcast(om);
    }
  }

  // ------------------------------------------------- sottoscrizioni

  void _onTick() {
    _ticks++;
    if (paused) return;
    final now = DateTime.now();
    for (final c in _clients.values) {
      c.subs.removeWhere((k, s) => s.until.isBefore(now));
      for (final s in c.subs.values) {
        if (++s.tick < s.factor) continue;
        s.tick = 0;
        final blob = _blobFor(s.alias);
        if (blob != null) _sendTo(c, OscMessage(s.alias, [OscBlob(blob)]));
      }
    }
  }

  Uint8List? _blobFor(String alias) {
    if (alias.startsWith('meters/')) {
      final bank = int.tryParse(alias.substring(7));
      if (bank == null || bank < 0 || bank > 16) return null;
      return encodeMeterBlob(bank, _meterValues(bank));
    }
    if (alias == 'hidden/solo') {
      final bd = ByteData(4 + 80 * 4)..setInt32(0, 4 + 80 * 4, Endian.little);
      for (var i = 0; i < 80; i++) {
        bd.setInt32(4 + i * 4, solo[i + 1] ? 1 : 0, Endian.little);
      }
      return bd.buffer.asUint8List();
    }
    if (alias == 'hidden/states') {
      final bd = ByteData(4 + 50 * 4)..setInt32(0, 4 + 50 * 4, Endian.little);
      return bd.buffer.asUint8List();
    }
    if (alias == 'hidden/prefs') {
      final bd = ByteData(64)..setInt32(0, 64, Endian.little);
      return bd.buffer.asUint8List();
    }
    return null;
  }

  /// Segnali simulati: ogni ingresso ha un livello pseudo-musicale; le uscite
  /// seguono fader e mute. Disposizione del banco 0 come MeterBank0Map [EXT].
  List<double> _meterValues(int bank) {
    final t = _ticks * 0.05;
    double sig(int i) {
      final base = 0.25 + 0.2 * math.sin(t * (0.7 + i * 0.13) + i);
      final transient = (math.sin(t * (3.1 + i * 0.37)) > 0.92) ? 0.4 : 0.0;
      return (base + transient + _rnd.nextDouble() * 0.05).clamp(0.0, 1.0);
    }

    double strip(String base, int i) {
      final on = state.getIdx('$base/mix/on') ?? 1;
      final f = state.getPhysical('$base/mix/fader') ?? -144;
      if (on == 0) return 0;
      return sig(i) * math.pow(10, f.clamp(-144, 10) / 20);
    }

    final n = kMeterBankWords[bank];
    if (bank == 0) {
      return [
        for (var c = 1; c <= 32; c++) sig(c),
        for (var a = 1; a <= 8; a++) sig(40 + a),
        for (var f = 1; f <= 8; f++) sig(50 + f) * 0.6,
        for (var b = 1; b <= 16; b++) strip('/bus/${b.toString().padLeft(2, '0')}', 60 + b),
        for (var x = 1; x <= 6; x++) strip('/mtx/0$x', 80 + x),
      ];
    }
    if (bank == 16) {
      // Riduzione di guadagno simulata con la caratteristica statica, nell'ordine verificato su
      // X32P (MeterBank16Map): gate 0–31, compressore 32–63; il resto senza riduzione.
      final out = List<double>.filled(n * 2, 1.0);
      for (var c = 1; c <= 32; c++) {
        final b = '/ch/${c.toString().padLeft(2, '0')}';
        final lvl = 20 * math.log(math.max(sig(c), 1e-6)) / math.ln10;
        if ((state.getIdx('$b/gate/on') ?? 0) == 1 && lvl < (state.getPhysical('$b/gate/thr') ?? -80)) {
          out[MeterBank16Map.gate(c)] = math.pow(10, -(state.getPhysical('$b/gate/range') ?? 60) / 20).toDouble();
        }
        final thr = state.getPhysical('$b/dyn/thr') ?? 0;
        if ((state.getIdx('$b/dyn/on') ?? 0) == 1 && lvl > thr) {
          final spec = state.specOf('$b/dyn/ratio');
          final ri = state.getIdx('$b/dyn/ratio');
          final ratio = spec?.labels != null && ri != null ? (double.tryParse(spec!.labels![ri]) ?? 3) : 3.0;
          out[MeterBank16Map.comp(c)] = math.pow(10, -(lvl - thr) * (1 - 1 / ratio) / 20).toDouble();
        }
      }
      return out;
    }
    if (bank == 15) return List.filled(n * 2, 0);
    if (meterBankType(bank) == MeterValueType.unknown) return List.filled(n, 0);
    final out = List<double>.generate(n, (i) => sig(i + bank * 7) * 0.8);
    if (bank == 5 || bank == 2) {
      // posizioni del main non verificate: il simulatore mette L/R nelle ultime due
      final m = strip('/main/st', 99);
      if (n >= 2) {
        out[n - 2] = m;
        out[n - 1] = m * 0.97;
      }
    }
    return out;
  }
}
