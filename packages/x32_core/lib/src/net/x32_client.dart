/// Motore di comunicazione con il mixer: discovery, connessione, keep-alive,
/// sottoscrizioni, sincronizzazione e invio dei parametri.
///
/// Comportamenti verificati sull'hardware (X32P FW 4.15, prove T01b–T03c):
/// * `/status` con type tag vuoto → `/status ,sss` = stato, IP, nome;
/// * `/xinfo` → `,ssss` = IP, nome, modello, firmware;
/// * `/xremote` e `/renew` ogni ~2 s, meter ri-sottoscritti ogni ~10 s con `0 0 1`;
/// * sync stop-and-wait sui 2127 nodi, risposta `node ,s "<path> …\n"`;
/// * il mixer NON rimanda una modifica al client che l'ha inviata;
/// * le modifiche fatte sul mixer arrivano come `/path ,f|,i|,s`.
///
/// Scelte deliberate rispetto a X32-Edit:
/// * non invia `/-stat/keysolo 0` e `/-stat/osc/on 0` alla connessione (effetto non chiarito);
/// * non reinvia mai i valori ricevuti durante la sync (X32-Edit lo fa per 15 parametri: incongruenza T01b).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../generated/sync_nodes.g.dart';
import '../meters/meters.dart';
import '../osc/osc.dart';
import '../state/mixer_state.dart';
import 'send_queue.dart';
import 'transport.dart';

const int kX32Port = 10023;

/// Identità di un mixer (risposta `/xinfo`, ordine dei campi verificato in T01b).
class MixerInfo {
  const MixerInfo({required this.ip, required this.name, required this.model, required this.firmware, required this.address, this.port = kX32Port});
  final String ip;
  final String name;
  final String model;
  final String firmware;
  final InternetAddress address;
  final int port;

  /// Il simulatore risponde solo su loopback e si dichiara nel nome.
  bool get isSimulator => address.isLoopback;

  @override
  String toString() => '$name ($model, FW $firmware) @ $ip';
}

enum LinkState { disconnected, connecting, connected, syncing, lost }

class ConnectException implements Exception {
  ConnectException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SyncResult {
  SyncResult(this.completed, this.total, this.retransmissions, this.elapsed, {this.cancelled = false, this.error});
  final int completed;
  final int total;
  final int retransmissions;
  final Duration elapsed;
  final bool cancelled;
  final String? error;
  bool get ok => completed == total && !cancelled && error == null;
}

class LogEntry {
  LogEntry(this.level, this.message) : time = DateTime.now();
  final DateTime time;
  final String level;
  final String message;
  @override
  String toString() => '${time.toIso8601String()} [$level] $message';
}

/// I 15 percorsi di `hidden/prefs` (doc 15 par. 5.2, verificati in T01b).
const kHiddenPrefsPaths = [
  '/-prefs/clockrate', '/-prefs/clocksource', '/-prefs/scene_advance', '/-prefs/safe_masterlevels', //
  '/-prefs/clockmode', '/-prefs/show_control', '/-prefs/haflags', '/-prefs/hardmute', '/-prefs/dcamute', //
  '/-prefs/invertmutes', '/-prefs/remote/ioenable', '/-prefs/rta/source', '/-prefs/rta/pos', '/-prefs/rta/det', //
  '/-prefs/rta/options'
];

/// I 22 percorsi di `hidden/states` (doc 05 par. 4, verificati in T01b).
const kHiddenStatesPaths = [
  '/-stat/tape/state', '/-usb/path', '/-usb/title', '/-stat/tape/etime', '/-stat/tape/rtime', //
  '/-stat/aes50/state', '/-stat/aes50/A', '/-stat/aes50/B', '/-show/prepos/current', '/-stat/usbmounted', //
  '/-usb/dir/dirpos', '/-usb/dir/maxpos', '/-stat/xcardtype', '/-stat/xcardsync', '/-stat/rtasource', //
  '/-stat/talk/A', '/-stat/talk/B', '/-stat/osc/on', '/-stat/keysolo', '/-stat/urec/state', //
  '/-stat/urec/etime', '/-stat/urec/rtime'
];

class X32Client {
  X32Client({
    required this.transport,
    MixerState? state,
    this.keepAlive = const Duration(milliseconds: 2000),
    this.meterResubscribe = const Duration(milliseconds: 10000),
    this.lostAfter = const Duration(milliseconds: 10000),
    this.replyTimeout = const Duration(milliseconds: 500),
    this.connectAttempts = 4,
    this.syncMaxRetries = 20,
  }) : state = state ?? MixerState() {
    _rx = transport.incoming.listen(_onDatagram, onError: (Object e) => _log('W', 'ricezione: $e'));
    _tx = this.state.changes.listen(_onStateChange);
    queue = SendQueue(sink: _sink, onLog: _log);
    _wr = transport.writable.listen((_) => queue.onWritable());
  }

  /// Coda di invio (coalescenza dei parametri, ordine dei comandi, limiti, ritentativi).
  late final SendQueue queue;
  late final StreamSubscription<void> _wr;

  SendResult _sink(Uint8List data) {
    final h = _host;
    if (h == null) return SendResult.sent; // nessuna destinazione: il messaggio non ha più senso
    return transport.trySend(data, h, _port);
  }

  final Transport transport;
  final MixerState state;
  final Duration keepAlive;
  final Duration meterResubscribe;
  final Duration lostAfter;
  final Duration replyTimeout;
  final int connectAttempts;
  final int syncMaxRetries;

  late final StreamSubscription<UdpPacket> _rx;
  late final StreamSubscription<ParamChange> _tx;

  MixerInfo? _mixer;
  MixerInfo? get mixer => _mixer;
  InternetAddress? _host;
  int _port = kX32Port;

  LinkState _link = LinkState.disconnected;
  LinkState get link => _link;
  final _linkCtl = StreamController<LinkState>.broadcast();
  Stream<LinkState> get linkChanges => _linkCtl.stream;

  final _meterCtl = StreamController<MeterFrame>.broadcast();
  Stream<MeterFrame> get meters => _meterCtl.stream;

  final _logCtl = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get log => _logCtl.stream;

  /// Stati di solo 1..80 (indice = strip globale + 1), da `hidden/solo` e `/-stat/solosw/NN`.
  final List<bool> solo = List.filled(81, false);
  final _soloCtl = StreamController<int>.broadcast();
  Stream<int> get soloChanges => _soloCtl.stream;

  /// Indice di selezione inviato dal mixer (`/-stat/selidx`, 0-based, verificato in T03).
  final _selCtl = StreamController<int>.broadcast();
  Stream<int> get mixerSelection => _selCtl.stream;

  /// Righe `node` arrivate fuori da una richiesta (es. dopo `/showdump`).
  final _nodeCtl = StreamController<String>.broadcast();
  Stream<String> get nodeLines => _nodeCtl.stream;

  final Set<int> _meterBanks = {};
  Set<int> get subscribedMeters => Set.unmodifiable(_meterBanks);

  Timer? _keepAliveTimer;
  Timer? _meterTimer;
  Timer? _watchdog;
  DateTime _lastRx = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get lastReceive => _lastRx;

  Completer<List<String>>? _statusWait;
  String? _pendingNode;
  Completer<void>? _nodeWait;

  bool autoReconnect = true;
  bool _closing = false;

  int get sentCount => queue.sent;
  int receivedCount = 0;

  /// Comandi rifiutati perché il mixer non era raggiungibile.
  int rejectedWhileLost = 0;
  int droppedCount = 0;

  // ------------------------------------------------------------ discovery

  /// Cerca i mixer inviando `"/xinfo\0\0"` (pacchetto grezzo verificato in T01b) agli
  /// indirizzi indicati e raccogliendo le risposte per [window].
  static Future<List<MixerInfo>> discover(Transport t, List<InternetAddress> targets,
      {Duration window = const Duration(milliseconds: 1500), int port = kX32Port}) async {
    final found = <String, MixerInfo>{};
    final sub = t.incoming.listen((d) {
      try {
        for (final m in decodeOsc(d.data)) {
          if (m.address == '/xinfo' && m.args.length == 4 && m.args.every((a) => a is OscString)) {
            final a = m.args.cast<OscString>().map((s) => s.value).toList();
            found.putIfAbsent('${d.address.address}:${d.port}',
                () => MixerInfo(ip: a[0], name: a[1], model: a[2], firmware: a[3], address: d.address, port: d.port));
          }
        }
      } on OscFormatException {
        // pacchetti estranei sulla porta: ignorati
      }
    });
    final raw = encodeOsc(OscMessage('/xinfo', const [], false));
    for (final ip in targets) {
      try {
        t.send(raw, ip, port);
      } on Object {
        // destinazione non ammessa o rete assente: si prosegue con le altre
      }
    }
    await Future<void>.delayed(window);
    await sub.cancel();
    return found.values.toList();
  }

  /// Indirizzi di broadcast delle interfacce IPv4 locali (/24 se la maschera non è nota) più 255.255.255.255.
  static Future<List<InternetAddress>> broadcastTargets() async {
    final out = <InternetAddress>[InternetAddress('255.255.255.255')];
    for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in ni.addresses) {
        if (a.isLoopback) continue;
        final p = a.address.split('.');
        out.add(InternetAddress('${p[0]}.${p[1]}.${p[2]}.255'));
      }
    }
    return out;
  }

  /// Ricerca su **ogni scheda di rete**: un socket legato all'indirizzo di ciascuna interfaccia IPv4,
  /// così il broadcast esce davvero anche dal Wi-Fi quando è collegata pure l'Ethernet (Windows
  /// manda 255.255.255.255 da una sola scheda). A ogni scheda: 255.255.255.255, il broadcast
  /// della sua rete (/24) e gli indirizzi diretti [hosts] (es. l'ultimo mixer usato: utile se il
  /// router non inoltra i broadcast dal Wi-Fi alla rete cablata).
  static Future<DiscoveryReport> discoverAll({List<InternetAddress> hosts = const [], Duration window = const Duration(milliseconds: 1500)}) async {
    final ifaces = <LocalInterface>[];
    for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in ni.addresses) {
        if (!a.isLoopback && !a.isLinkLocal) ifaces.add(LocalInterface(ni.name, a));
      }
    }
    final found = <String, MixerInfo>{};
    final errors = <String>[];
    Future<void> scan(Transport t, List<InternetAddress> targets) async {
      for (final m in await discover(t, targets, window: window)) {
        found.putIfAbsent('${m.address.address}:${m.port}', () => m);
      }
    }

    final jobs = <Future<void>>[];
    final transports = <Transport>[];
    for (final li in ifaces) {
      try {
        final t = await UdpTransport.bind(address: li.address, broadcast: true);
        transports.add(t);
        final p = li.address.address.split('.');
        jobs.add(scan(t, [InternetAddress('255.255.255.255'), InternetAddress('${p[0]}.${p[1]}.${p[2]}.255'), ...hosts]));
      } on Object catch (e) {
        errors.add('${li.name} ${li.address.address}: $e');
      }
    }
    // simulatore locale (ascolta solo su 127.0.0.1)
    try {
      final lt = await UdpTransport.bind(address: InternetAddress.loopbackIPv4);
      transports.add(lt);
      jobs.add(scan(lt, [InternetAddress.loopbackIPv4]));
    } on Object catch (e) {
      errors.add('loopback: $e');
    }
    if (transports.length == 1) {
      // nessuna scheda di rete utilizzabile: tentativo con un socket generico, come prima
      final t = await UdpTransport.bind(broadcast: true);
      transports.add(t);
      jobs.add(scan(t, [...await broadcastTargets(), ...hosts]));
    }
    await Future.wait(jobs);
    for (final t in transports) {
      await t.close();
    }
    return DiscoveryReport(found.values.toList(), ifaces, errors);
  }

  // ----------------------------------------------------------- connessione

  /// Si connette al mixer. Non simula mai il successo: senza una risposta
  /// `/status` reale entro i tentativi previsti lancia [ConnectException].
  Future<MixerInfo> connect(InternetAddress host, {int port = kX32Port, MixerInfo? known}) async {
    if (_link == LinkState.connected || _link == LinkState.syncing) await disconnect();
    _closing = false;
    _host = host;
    _port = port;
    _setLink(LinkState.connecting);
    List<String>? status;
    for (var i = 0; i < connectAttempts && status == null; i++) {
      _statusWait = Completer<List<String>>();
      _send(OscMessage('/status'));
      try {
        status = await _statusWait!.future.timeout(replyTimeout * 2);
      } on TimeoutException {
        _log('W', 'nessuna risposta a /status da ${host.address} (tentativo ${i + 1}/$connectAttempts)');
      }
    }
    _statusWait = null;
    if (status == null) {
      _setLink(LinkState.disconnected);
      throw ConnectException('Il mixer ${host.address} non risponde.');
    }
    var info = known;
    if (info == null) {
      // Identità: /xinfo diretto (stesso formato della discovery).
      info = await _queryInfo(host, port) ??
          MixerInfo(ip: status.length > 1 ? status[1] : host.address, name: status.length > 2 ? status[2] : '?', model: '?', firmware: '?', address: host, port: port);
    }
    _mixer = info;
    _lastRx = DateTime.now();
    _startSession();
    _setLink(LinkState.connected);
    _log('I', 'connesso a $info');
    return info;
  }

  Completer<MixerInfo?>? _infoWait;

  Future<MixerInfo?> _queryInfo(InternetAddress host, int port) async {
    _infoWait = Completer<MixerInfo?>();
    _send(OscMessage('/xinfo'));
    try {
      return await _infoWait!.future.timeout(replyTimeout * 2);
    } on TimeoutException {
      return null;
    } finally {
      _infoWait = null;
    }
  }

  void _startSession() {
    // Sequenza osservata in T01b (senza keysolo/osc, vedi intestazione).
    _send(OscMessage('/xremote'));
    _send(OscMessage('/formatsubscribe', [
      const OscString('hidden/prefs'),
      for (final p in kHiddenPrefsPaths) OscString(p),
      const OscInt(0), const OscInt(0), const OscInt(10),
    ]));
    _subscribeStates();
    for (final b in _meterBanks) {
      _batchSubscribe(b);
    }
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(keepAlive, (_) => _onKeepAlive());
    _meterTimer?.cancel();
    _meterTimer = Timer.periodic(meterResubscribe, (_) {
      // Con il mixer non raggiungibile niente rinnovi: li rifà _startSession alla ripresa.
      if (_link == LinkState.lost) return;
      for (final b in _meterBanks) {
        _batchSubscribe(b);
      }
    });
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) => _checkWatchdog());
  }

  void _subscribeStates() {
    _send(OscMessage('/formatsubscribe', [
      const OscString('hidden/states'),
      for (final p in kHiddenStatesPaths) OscString(p),
      const OscInt(0), const OscInt(0), const OscInt(4),
    ]));
    _send(OscMessage('/formatsubscribe', [
      const OscString('hidden/solo'), const OscString('/-stat/solosw/**'), const OscInt(1), const OscInt(80), const OscInt(20),
    ]));
  }

  void _onKeepAlive() {
    if (_link == LinkState.lost) {
      // tentativo di ripresa: /status, la risposta riporta in connected (_onStatusWhileLost)
      if (autoReconnect) _send(OscMessage('/status'));
      return;
    }
    if (_link != LinkState.connected && _link != LinkState.syncing) return;
    // keep-alive ripetitivi: in caso di congestione ne resta in coda uno solo per tipo
    queue.enqueueLatest(OscMessage('/xremote'), key: '/xremote');
    for (final a in ['hidden/prefs', 'hidden/states', 'hidden/solo', for (final b in _meterBanks) 'meters/$b']) {
      queue.enqueueLatest(OscMessage('/renew', [OscString(a)]), key: '/renew $a');
    }
  }

  void _checkWatchdog() {
    if (_link != LinkState.connected && _link != LinkState.syncing) return;
    if (DateTime.now().difference(_lastRx) > lostAfter) {
      _log('E', 'nessun dato dal mixer da ${lostAfter.inSeconds} s: connessione persa');
      final n = queue.clear();
      if (n > 0) _log('W', '$n messaggi in coda scartati: non partiranno alla ripresa');
      _setLink(LinkState.lost);
      _nodeWait?.completeError(ConnectException('connessione persa'));
    }
  }

  /// Chiude la sessione: `/unsubscribe` senza argomenti, poi azzera i timer (doc 15 par. 2.4).
  Future<void> disconnect() async {
    _closing = true;
    if (_host != null && (_link == LinkState.connected || _link == LinkState.syncing)) {
      _send(OscMessage('/unsubscribe'));
    }
    _keepAliveTimer?.cancel();
    _meterTimer?.cancel();
    _watchdog?.cancel();
    _keepAliveTimer = _meterTimer = _watchdog = null;
    queue.clear();
    _nodeWait?.completeError(ConnectException('disconnesso'));
    _setLink(LinkState.disconnected);
    _mixer = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _rx.cancel();
    await _tx.cancel();
    await _wr.cancel();
    queue.dispose();
    await transport.close();
    await _linkCtl.close();
    await _meterCtl.close();
    await _logCtl.close();
    await _soloCtl.close();
    await _selCtl.close();
    await _nodeCtl.close();
  }

  // ------------------------------------------------------------- meter

  void subscribeMeters(int bank) {
    if (bank < 0 || bank >= kMeterBankWords.length) throw RangeError.range(bank, 0, kMeterBankWords.length - 1);
    if (_meterBanks.add(bank) && _isOnline) _batchSubscribe(bank);
  }

  void unsubscribeMeters(int bank) {
    if (_meterBanks.remove(bank) && _isOnline) _send(OscMessage('/unsubscribe', [OscString('meters/$bank')]));
  }

  void _batchSubscribe(int bank) {
    // Argomenti osservati in T01b: "0 0 1" per tutti i banchi, "3 0 1" per meters/5.
    final a = bank == 5 ? 3 : 0;
    _send(OscMessage('/batchsubscribe', [OscString('meters/$bank'), OscString('/meters/$bank'), OscInt(a), const OscInt(0), const OscInt(1)]));
  }

  bool get _isOnline => _host != null && (_link == LinkState.connected || _link == LinkState.syncing);

  // ------------------------------------------------------------- invio

  void _onStateChange(ParamChange c) {
    if (c.origin != ChangeOrigin.local) return; // anti-eco: solo le modifiche locali partono
    if (!_isOnline) return;
    final path = c.path;
    if (path.startsWith('/-')) return; // gli stati si inviano solo in modo esplicito
    final m = state.oscFor(path);
    // parametro continuo: in coda resta solo l'ultimo valore (coalescenza)
    if (m != null) queue.enqueueLatest(m);
  }

  /// Invio esplicito di uno stato o di un'azione `/-…` (doc 15 par. 4.2).
  void sendExplicit(String path, OscArg arg) {
    if (!path.startsWith('/-')) throw ArgumentError('solo percorsi /-…');
    if (_isOnline) _send(OscMessage(path, [arg]));
  }

  /// Solo di una strip: `/-stat/solosw/NN ,i 0|1`.
  /// NOTA: la direzione PC → mixer non è ancora verificata su hardware (doc 23).
  void setSolo(int soloIndex, bool on) {
    if (soloIndex < 1 || soloIndex > 80) throw RangeError.range(soloIndex, 1, 80);
    if (!_isOnline) {
      _log('W', 'solo non inviato: mixer non connesso o non raggiungibile');
      rejectedWhileLost++;
      return;
    }
    solo[soloIndex] = on;
    _soloCtl.add(soloIndex);
    sendExplicit('/-stat/solosw/${soloIndex.toString().padLeft(2, '0')}', OscInt(on ? 1 : 0));
  }

  /// Operazioni sui dataset del mixer (doc 15 par. 6.4, comandi verificati nel binario).
  void datasetLoad(String type, int idx) => _send(OscMessage('/load', [OscString(type), OscInt(idx), const OscInt(0), const OscInt(0)]));
  void datasetSave(String type, int idx, String name, String notes) =>
      _send(OscMessage('/save', [OscString(type), OscInt(idx), OscString(name), OscString(notes), const OscInt(0)]));
  void datasetCopy(String type, int src, int dst) => _send(OscMessage('/copy', [OscString(type), OscInt(src), OscInt(dst), const OscInt(0)]));
  void datasetDelete(String type, int idx) => _send(OscMessage('/delete', [OscString(type), OscInt(idx)]));
  void datasetRename(String type, int idx, String name, String notes) =>
      _send(OscMessage('/rename', [OscString(type), OscInt(idx), OscString(name), OscString(notes)]));
  /// Nuovo cue in posizione [pos] (`/add ,sis "cue" pos ""`, doc 15 par. 6.4).
  void cueAdd(int pos) => _send(OscMessage('/add', [const OscString('cue'), OscInt(pos), const OscString('')]));
  void requestShowDump() => _send(OscMessage('/showdump'));

  /// Richiede un singolo nodo (`/node ,s`); la risposta aggiorna lo stato come sync.
  void requestNode(String path) => _send(OscMessage('/node', [OscString(path.startsWith('/') ? path.substring(1) : path)]));

  /// Invia righe di nodo (file di scena/snippet) come `/ ,s` (doc 15 par. 6.3).
  /// Risposta del mixer non verificata su hardware: il chiamante chiede conferma e salva un backup.
  Future<int> sendNodeLines(Iterable<String> lines) async {
    var n = 0;
    for (final l in lines) {
      final t = l.trim();
      if (!t.startsWith('/')) continue;
      if (!_send(OscMessage('/', [OscString(t.substring(1))]))) break;
      if (++n % 32 == 0) await queue.drained(); // contropressione: nessuna coda che cresce
    }
    await queue.drained();
    return n;
  }

  /// Comando ordinato: mai fuso né scartato. Restituisce falso se non è stato accodato.
  bool _send(OscMessage m) {
    if (_host == null) return false;
    if (_link == LinkState.lost && m.address != '/status') {
      // Mixer non raggiungibile: il comando NON viene accodato, così non può partire
      // alla riconnessione in un momento imprevisto (es. un richiamo di scena).
      _log('W', '${m.address} non inviato: mixer non raggiungibile');
      rejectedWhileLost++;
      return false;
    }
    try {
      queue.enqueueOrdered(m);
      return true;
    } on QueueFullException catch (e) {
      _log('E', '${m.address}: $e');
      return false;
    }
  }

  // ---------------------------------------------------------- ricezione

  void _onDatagram(UdpPacket d) {
    if (_host == null || d.address.address != _host!.address) {
      return; // solo il mixer connesso (la discovery usa un trasporto separato)
    }
    List<OscMessage> msgs;
    try {
      msgs = decodeOsc(d.data);
    } on OscFormatException catch (e) {
      droppedCount++;
      _log('W', 'datagramma scartato: ${e.message}');
      return;
    }
    _lastRx = DateTime.now();
    receivedCount++;
    if (_link == LinkState.lost && !_closing) {
      _log('I', 'il mixer risponde di nuovo: ripresa della sessione');
      // Prima lo stato "connesso", poi la sessione: con lo stato ancora "perso" _send scarterebbe
      // /xremote, /formatsubscribe e le iscrizioni ai meter (difetto visto sull'X32P, prova A8 del 2026-11-23).
      _setLink(LinkState.connected);
      _startSession();
    }
    for (final m in msgs) {
      _dispatch(m);
    }
  }

  void _dispatch(OscMessage m) {
    final a = m.address;
    if (a == '/status') {
      if (m.args.length == 3 && m.args.every((x) => x is OscString)) {
        _statusWait?.complete(m.args.cast<OscString>().map((s) => s.value).toList());
        _statusWait = null;
      }
      return;
    }
    if (a == '/xinfo') {
      if (m.args.length == 4 && m.args.every((x) => x is OscString) && _infoWait != null) {
        final v = m.args.cast<OscString>().map((s) => s.value).toList();
        _infoWait!.complete(MixerInfo(ip: v[0], name: v[1], model: v[2], firmware: v[3], address: _host!, port: _port));
      }
      return;
    }
    if (a == 'node' || a == '/node') {
      if (m.args.length != 1 || m.args.single is! OscString) return;
      final line = (m.args.single as OscString).value;
      final path = line.trimLeft().split(RegExp(r'\s')).first;
      state.applyNodeLine(line, ChangeOrigin.sync);
      if (_pendingNode != null && path == _pendingNode) {
        _pendingNode = null;
        _nodeWait?.complete();
      } else {
        _nodeCtl.add(line.trimRight());
      }
      return;
    }
    if (a.startsWith('meters/')) {
      if (m.args.length != 1 || m.args.single is! OscBlob) return;
      final bank = int.tryParse(a.substring(7));
      if (bank == null) return;
      final f = decodeMeterBlob(bank, (m.args.single as OscBlob).bytes);
      if (f == null) {
        droppedCount++;
        return;
      }
      _meterCtl.add(f);
      return;
    }
    if (a == 'hidden/solo') {
      if (m.args.length == 1 && m.args.single is OscBlob) _applySoloBlob((m.args.single as OscBlob).bytes);
      return;
    }
    if (a.startsWith('hidden/') || a.startsWith('usb/')) return;
    if (a.startsWith('/-stat/solosw/')) {
      final n = int.tryParse(a.substring(14));
      if (n != null && n >= 1 && n <= 80 && m.args.length == 1 && m.args.single is OscInt) {
        final on = (m.args.single as OscInt).value != 0;
        if (solo[n] != on) {
          solo[n] = on;
          _soloCtl.add(n);
        }
      }
      return;
    }
    if (a == '/-stat/selidx') {
      if (m.args.length == 1 && m.args.single is OscInt) _selCtl.add((m.args.single as OscInt).value);
      return;
    }
    if (a.startsWith('/-')) return; // altri stati: arrivano tramite le sottoscrizioni
    state.applyOsc(m, origin: ChangeOrigin.remote);
  }

  void _applySoloBlob(Uint8List b) {
    // Blob osservato in T01b: 324 byte = int32 LE con la dimensione + 80 int32 LE.
    if (b.length < 4 + 80 * 4) return;
    final bd = ByteData.sublistView(b);
    for (var i = 0; i < 80; i++) {
      final on = bd.getInt32(4 + i * 4, Endian.little) != 0;
      if (solo[i + 1] != on) {
        solo[i + 1] = on;
        _soloCtl.add(i + 1);
      }
    }
  }

  // ------------------------------------------------------- sincronizzazione

  /// Sync Mixer → PC: richiede i 2127 nodi uno alla volta (stop-and-wait) e li applica
  /// come aggiornamenti di sync (mai reinviati). Ritrasmette ogni [replyTimeout].
  Future<SyncResult> syncFromMixer({void Function(int done, int total)? onProgress, bool Function()? cancelled, bool showDump = true}) async {
    if (!_isOnline) throw StateError('non connesso');
    final sw = Stopwatch()..start();
    _setLink(LinkState.syncing);
    var retrans = 0;
    var done = 0;
    String? error;
    try {
      for (final path in kSyncNodes) {
        if (cancelled?.call() ?? false) {
          return SyncResult(done, kSyncNodes.length, retrans, sw.elapsed, cancelled: true);
        }
        var ok = false;
        for (var attempt = 0; attempt <= syncMaxRetries && !ok; attempt++) {
          _pendingNode = path;
          _nodeWait = Completer<void>();
          if (attempt > 0) retrans++;
          _send(OscMessage('/node', [OscString(path.substring(1))]));
          try {
            await _nodeWait!.future.timeout(replyTimeout);
            ok = true;
          } on TimeoutException {
            // ritrasmissione
          }
          if (_link == LinkState.lost || _link == LinkState.disconnected) {
            throw ConnectException('connessione interrotta durante la sync');
          }
        }
        if (!ok) throw ConnectException('nessuna risposta per $path dopo $syncMaxRetries ritrasmissioni');
        done++;
        onProgress?.call(done, kSyncNodes.length);
      }
      if (showDump) {
        _send(OscMessage('/node', [const OscString('-prefs/card')]));
        requestShowDump();
      }
    } on ConnectException catch (e) {
      error = e.message;
      _log('E', 'sync interrotta: ${e.message}');
    } finally {
      _pendingNode = null;
      _nodeWait = null;
      if (_link == LinkState.syncing) _setLink(LinkState.connected);
    }
    final r = SyncResult(done, kSyncNodes.length, retrans, sw.elapsed, error: error);
    _log(r.ok ? 'I' : 'W', 'sync Mixer → PC: $done/${kSyncNodes.length} nodi, $retrans ritrasmissioni, ${sw.elapsedMilliseconds} ms');
    return r;
  }

  /// Sync PC → Mixer: invia ogni nodo come `/ ,s "<riga senza />"` (doc 15 par. 4.4).
  /// La risposta del mixer a queste righe NON è verificata su hardware: si invia con una
  /// coda ordinata con contropressione ogni [pacingEvery] righe, senza attendere conferme. Il chiamante
  /// deve aver ottenuto la conferma esplicita dell'utente e salvato un backup.
  Future<SyncResult> syncToMixer({void Function(int done, int total)? onProgress, bool Function()? cancelled, int pacingEvery = 32}) async {
    if (!_isOnline) throw StateError('non connesso');
    final sw = Stopwatch()..start();
    _setLink(LinkState.syncing);
    var done = 0;
    try {
      for (final path in kSyncNodes) {
        if (cancelled?.call() ?? false) return SyncResult(done, kSyncNodes.length, 0, sw.elapsed, cancelled: true);
        final n = state.node(path);
        final line = n?.toLine();
        if (line != null && (!n!.spec.opaque || n.rawText != null) && line.length > path.length) {
          if (!_send(OscMessage('/', [OscString(line.substring(1))]))) throw ConnectException('coda dei comandi piena');
        }
        done++;
        if (done % pacingEvery == 0) await queue.drained();
        onProgress?.call(done, kSyncNodes.length);
      }
    } finally {
      if (_link == LinkState.syncing) _setLink(LinkState.connected);
    }
    _log('I', 'sync PC → Mixer: $done righe inviate in ${sw.elapsedMilliseconds} ms (risposta del mixer non verificata)');
    return SyncResult(done, kSyncNodes.length, 0, sw.elapsed);
  }

  // ------------------------------------------------------------- utilità

  void _setLink(LinkState s) {
    if (_link == s) return;
    _link = s;
    if (!_linkCtl.isClosed) _linkCtl.add(s);
  }

  void _log(String level, String msg) {
    if (!_logCtl.isClosed) _logCtl.add(LogEntry(level, msg));
  }
}

/// Una scheda di rete locale con il suo indirizzo IPv4.
class LocalInterface {
  const LocalInterface(this.name, this.address);
  final String name;
  final InternetAddress address;

  /// Rete /24 della scheda (es. 192.168.1), usata solo per la diagnosi.
  String get net24 => address.address.substring(0, address.address.lastIndexOf('.'));
}

/// Esito di [X32Client.discoverAll]: mixer trovati e schede usate, per spiegare un esito vuoto.
class DiscoveryReport {
  DiscoveryReport(this.mixers, this.interfaces, this.errors);
  final List<MixerInfo> mixers;
  final List<LocalInterface> interfaces;
  final List<String> errors;

  /// Spiegazione quando nessun mixer risponde. [lastHost] è l'ultimo indirizzo usato (può essere vuoto).
  List<String> explain(String lastHost) {
    final out = <String>[];
    if (interfaces.isEmpty) {
      out.add('Il PC non ha nessuna rete IPv4 attiva: collega il cavo o il Wi-Fi.');
      return out;
    }
    out.add('Ricerca fatta su: ${interfaces.map((i) => '${i.name} (${i.address.address})').join(', ')}.');
    final ip = InternetAddress.tryParse(lastHost.split(':').first);
    if (ip != null && ip.type == InternetAddressType.IPv4) {
      final net = ip.address.substring(0, ip.address.lastIndexOf('.'));
      if (!interfaces.any((i) => i.net24 == net)) {
        out.add("L'ultimo mixer usato era ${ip.address}, ma nessuna scheda del PC è sulla rete $net.x: "
            "il PC è su un'altra rete (per esempio un hotspot). Collegalo alla stessa rete del mixer.");
      } else {
        out.add("Il PC è sulla stessa rete dell'ultimo mixer (${ip.address}) ma il mixer non risponde: "
            'controlla che sia acceso e collegato. Se il PC è in Wi-Fi e il mixer via cavo, il router può '
            'tenere separati Wi-Fi e rete cablata (isolamento dei client o rete ospiti): disattivalo nel router '
            'o usa la stessa rete del mixer.');
      }
    }
    out.addAll(errors.map((e) => 'Scheda non utilizzabile: $e'));
    return out;
  }
}

