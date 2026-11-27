// Test di integrazione: client reale ↔ simulatore su UDP 127.0.0.1.
// Il trasporto del client è in modalità loopbackOnly: nessun pacchetto può
// raggiungere un mixer fisico.
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_sim/x32_sim.dart';

final lo = InternetAddress.loopbackIPv4;

Future<X32Client> newClient({Duration lostAfter = const Duration(seconds: 10)}) async {
  final t = await UdpTransport.bind(policy: TransportPolicy.loopbackOnly);
  return X32Client(transport: t, lostAfter: lostAfter, keepAlive: const Duration(milliseconds: 300));
}

Future<void> waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condizione non raggiunta');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late X32Simulator sim;
  setUp(() async => sim = await X32Simulator.start(port: 0));
  tearDown(() async => sim.close());

  test('discovery: /xinfo grezzo, risposta con 4 stringhe e flag simulatore', () async {
    final t = await UdpTransport.bind(policy: TransportPolicy.loopbackOnly, broadcast: true);
    final found = await X32Client.discover(t, [lo], port: sim.port, window: const Duration(milliseconds: 300));
    await t.close();
    expect(found, hasLength(1));
    expect(found.single.name, kSimulatorName);
    expect(found.single.isSimulator, isTrue);
  });

  test('connessione, identità e sottoscrizioni', () async {
    final c = await newClient();
    final info = await c.connect(lo, port: sim.port);
    expect(info.name, kSimulatorName);
    expect(info.model, 'X32');
    expect(c.link, LinkState.connected);
    await c.dispose();
  });

  test('nessuna connessione finta: porta senza mixer → errore', () async {
    final t = await UdpTransport.bind(policy: TransportPolicy.loopbackOnly);
    final c = X32Client(transport: t, replyTimeout: const Duration(milliseconds: 100), connectAttempts: 2);
    await expectLater(c.connect(lo, port: 9), throwsA(isA<ConnectException>()));
    expect(c.link, LinkState.disconnected);
    await c.dispose();
  });

  test('il trasporto di test rifiuta destinazioni non di loopback', () async {
    final t = await UdpTransport.bind(policy: TransportPolicy.loopbackOnly);
    expect(() => t.send(encodeOsc(OscMessage('/xinfo')), InternetAddress('192.168.1.2'), 10023), throwsA(isA<TransportPolicyViolation>()));
    await t.close();
  });

  test('sync Mixer → PC: 2127 nodi, stato identico al simulatore', () async {
    sim.state.setString('/ch/07/config/name', 'Basso', origin: ChangeOrigin.remote);
    sim.state.setIdx('/ch/07/mix/fader', 700, origin: ChangeOrigin.remote);
    sim.state.setIdx('/fx/2/type', kFxOrderSlots1to4.indexOf('DLY'), origin: ChangeOrigin.remote);
    sim.state.resetFxParams(2, ChangeOrigin.remote);
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    final sentBefore = c.sentCount;
    final r = await c.syncFromMixer();
    expect(r.ok, isTrue, reason: r.error);
    expect(r.completed, 2127);
    expect(c.state.getString('/ch/07/config/name'), 'Basso');
    // Le righe di testo hanno risoluzione 0,1 dB: l'indice del fader può differire di 1 (limite del protocollo).
    expect(c.state.getIdx('/ch/07/mix/fader'), inInclusiveRange(699, 701));
    expect(c.state.fxTypeCode(2), 'DLY');
    for (final p in kSyncNodes) {
      expect(c.state.nodeLine(p), sim.state.nodeLine(p), reason: p);
    }
    // anti-eco: durante la sync il client invia solo richieste /node (+ keep-alive)
    expect(c.sentCount - sentBefore, lessThan(2127 + 200));
    await c.dispose();
  });

  test('sync con il 20 % di pacchetti persi: ritrasmissione a 500 ms', () async {
    sim.dropRate = 0.2;
    final t = await UdpTransport.bind(policy: TransportPolicy.loopbackOnly);
    final c = X32Client(transport: t, replyTimeout: const Duration(milliseconds: 30), connectAttempts: 20);
    await c.connect(lo, port: sim.port);
    final r = await c.syncFromMixer(showDump: false);
    expect(r.ok, isTrue);
    expect(r.retransmissions, greaterThan(0));
    await c.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('PC → mixer: un messaggio per modifica, k/N esatto', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    c.state.setIdx('/ch/03/mix/fader', 767);
    c.state.setIdx('/ch/03/eq/2/g', 90);
    c.state.setString('/ch/03/config/name', 'Voce');
    await waitFor(() => sim.state.getString('/ch/03/config/name') == 'Voce');
    expect(sim.state.getIdx('/ch/03/mix/fader'), 767);
    expect(sim.state.getIdx('/ch/03/eq/2/g'), 90);
    await c.dispose();
  });

  test('mixer → PC: le modifiche dalla superficie arrivano e non vengono reinviate', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final before = sim.received;
    final sentBefore = c.sentCount;
    final got = <int>[];
    c.state.changes.listen((ch) {
      if (ch.path == '/ch/10/mix/fader') got.add(ch.value! as int);
    });
    // ritmo reale del mixer durante un movimento: un messaggio ogni ~20 ms (T03)
    for (var i = 1; i <= 50; i++) {
      sim.surfaceSet('/ch/10/mix/fader', i * 10);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await waitFor(() => c.state.getIdx('/ch/10/mix/fader') == 500);
    expect(got, [for (var i = 1; i <= 50; i++) i * 10]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // nessun messaggio /ch/10/... dal client: solo keep-alive
    expect(sim.receivedAddresses.where((a) => a.startsWith('/ch/10')), isEmpty);
    expect(sentBefore, greaterThan(0));
    expect(before, greaterThan(0));
    await c.dispose();
  });

  test('due client: la modifica di A arriva a B, non torna ad A', () async {
    final a = await newClient();
    final b = await newClient();
    await a.connect(lo, port: sim.port);
    await b.connect(lo, port: sim.port);
    var echoesToA = 0;
    a.state.changes.listen((ch) {
      if (ch.origin == ChangeOrigin.remote && ch.path == '/ch/12/mix/pan') echoesToA++;
    });
    a.state.setIdx('/ch/12/mix/pan', 20);
    await waitFor(() => b.state.getIdx('/ch/12/mix/pan') == 20);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(echoesToA, 0);
    await a.dispose();
    await b.dispose();
  });

  test('meter: banco 0 a 50 ms, count validato', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    final frames = <MeterFrame>[];
    final sub = c.meters.listen(frames.add);
    c.subscribeMeters(0);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await sub.cancel();
    expect(frames.length, inInclusiveRange(3, 20)); // ~12 attesi; margine per macchine lente (CI)
    expect(frames.first.values.length, 70);
    c.unsubscribeMeters(0);
    await c.dispose();
  });

  test('solo: invio dal client e stato dal blob hidden/solo', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    c.setSolo(31, true);
    await waitFor(() => sim.solo[31]);
    sim.solo[5] = true;
    await waitFor(() => c.solo[5], timeout: const Duration(seconds: 6));
    await c.dispose();
  });

  test('scene: save, rename, load (richiamo aggiorna lo stato)', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    c.state.setIdx('/ch/01/mix/fader', 600);
    await waitFor(() => sim.state.getIdx('/ch/01/mix/fader') == 600);
    c.datasetSave('scene', 3, 'Prova', 'note');
    await waitFor(() => sim.scenes.containsKey(3));
    c.datasetRename('scene', 3, 'Concerto', '');
    await waitFor(() => sim.scenes[3]!.name == 'Concerto');
    c.state.setIdx('/ch/01/mix/fader', 100);
    await waitFor(() => sim.state.getIdx('/ch/01/mix/fader') == 100);
    c.datasetLoad('scene', 3);
    await waitFor(() => c.state.getIdx('/ch/01/mix/fader') == 600);
    await c.dispose();
  });

  test('perdita di connessione rilevata e ripresa automatica', () async {
    final c = await newClient(lostAfter: const Duration(milliseconds: 800));
    await c.connect(lo, port: sim.port);
    c.subscribeMeters(0);
    sim.paused = true;
    await waitFor(() => c.link == LinkState.lost, timeout: const Duration(seconds: 4));
    final rejectedBefore = c.rejectedWhileLost;
    sim.paused = false;
    await waitFor(() => c.link == LinkState.connected, timeout: const Duration(seconds: 4));
    // Alla ripresa /xremote, /formatsubscribe e le iscrizioni ai meter devono partire davvero
    // (difetto visto sull'X32P nella prova A8: venivano scartati come "mixer non raggiungibile").
    expect(c.rejectedWhileLost, rejectedBefore);
    final frames = <MeterFrame>[];
    final sub = c.meters.listen(frames.add);
    await waitFor(() => frames.isNotEmpty, timeout: const Duration(seconds: 2));
    await sub.cancel();
    await c.dispose();
  });

  test('sync PC → Mixer: il simulatore riceve tutte le righe', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    c.state.applyNodeLine('/ch/20/config "Tastiera" 5 BL 20', ChangeOrigin.load);
    c.state.applyNodeLine('/ch/20/mix ON  -3.0 ON -20 OFF   -oo', ChangeOrigin.load);
    final r = await c.syncToMixer();
    expect(r.completed, 2127);
    await waitFor(() => sim.state.getString('/ch/20/config/name') == 'Tastiera');
    expect(sim.state.nodeLine('/ch/20/mix'), c.state.nodeLine('/ch/20/mix'));
    await c.dispose();
  });

  test('pacchetti dall\'IP del mixer ma da un\'altra porta: ignorati', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    final before = c.state.getIdx('/ch/05/mix/fader');
    final spoof = await RawDatagramSocket.bind(lo, 0);
    spoof.send(encodeOsc(OscMessage('node', [const OscString('/ch/05/mix ON  +10.0 ON +0 OFF   -oo')])), lo, c.transport.localPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c.state.getIdx('/ch/05/mix/fader'), before);
    spoof.close();
    await c.dispose();
  });

  test('sync PC → Mixer interrotta dalla perdita del collegamento: esito con errore, nessuna eccezione', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    var dropped = false;
    final r = await c.syncToMixer(cancelled: () {
      // a metà invio il collegamento cade (come un cavo staccato)
      if (!dropped && c.queue.length == 0) {
        dropped = true;
        unawaited(c.disconnect());
      }
      return false;
    });
    expect(r.ok, isFalse);
    expect(r.cancelled, isFalse);
    expect(r.error, isNotNull);
    expect(r.completed, lessThan(r.total));
    await c.dispose();
  });

  test('sync senza collegamento: esito con errore invece di un\'eccezione', () async {
    final c = await newClient();
    final to = await c.syncToMixer();
    final from = await c.syncFromMixer();
    expect(to.ok || from.ok, isFalse);
    expect(to.error, isNotNull);
    expect(from.error, isNotNull);
    await c.dispose();
  });

  test('snippet e cue: save, add, copy, delete; elenco tramite righe /-show/showfile', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    final lines = <String>[];
    c.nodeLines.listen(lines.add);
    c.datasetSave('snippet', 2, 'Batteria', '');
    c.cueAdd(5);
    await waitFor(() => sim.datasets['snippet']!.containsKey(2) && sim.datasets['cue']!.containsKey(5));
    c.datasetCopy('snippet', 2, 3);
    await waitFor(() => sim.datasets['snippet']!.containsKey(3));
    c.datasetDelete('cue', 5);
    await waitFor(() => !sim.datasets['cue']!.containsKey(5));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(lines.any((l) => l.startsWith('/-show/showfile/snippet/002 "Batteria"')), isTrue);
    expect(lines.any((l) => l.startsWith('/-show/showfile/cue/005')), isTrue);
    await c.dispose();
  });

  test("trascinamenti rapidissimi su 16 fader con comandi intercalati: il simulatore riceve sempre l'ultimo valore", () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    for (var b = 0; b <= 16; b++) {
      c.subscribeMeters(b); // carico in ricezione durante i trascinamenti
    }
    var seed = 7;
    int rnd() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final expected = <String, int>{};
    for (var round = 0; round < 40; round++) {
      // raffica senza pause: migliaia di valori in pochi millisecondi
      for (var i = 0; i < 1000; i++) {
        final p = '/ch/${(1 + rnd() % 16).toString().padLeft(2, '0')}/mix/fader';
        final v = rnd() % 1024;
        c.state.setIdx(p, v);
        expected[p] = c.state.getIdx(p)!;
      }
      c.setSolo(1 + rnd() % 32, round.isEven); // comando ordinato in mezzo
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await c.queue.drained();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final diffs = [for (final e in expected.entries) if (sim.state.getIdx(e.key) != e.value) '${e.key}: sim ${sim.state.getIdx(e.key)} atteso ${e.value}'];
    expect(diffs, isEmpty);
    expect(c.queue.dropped, 0);
    expect(c.queue.sendErrors, 0);
    printOnFailure('inviati ${c.queue.sent}, fusi ${c.queue.coalesced}, wouldBlock ${c.queue.wouldBlockCount}, profondità max ${c.queue.maxDepth}');
    await c.dispose();
  });

  test('disconnessione durante trascinamenti rapidi: nessun comando vecchio dopo la riconnessione', () async {
    final c = await newClient(lostAfter: const Duration(milliseconds: 800));
    await c.connect(lo, port: sim.port);
    sim.scenes[3] = Scene('S3', '', sim.state.captureValues());
    var v = 0;
    Future<void> drag(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        for (var ch = 1; ch <= 8; ch++) {
          c.state.setIdx('/ch/0$ch/mix/fader', v = (v + 37) % 1024);
        }
        await Future<void>.delayed(const Duration(milliseconds: 4));
      }
    }

    await drag(const Duration(milliseconds: 500));
    sim.paused = true; // il mixer smette di rispondere (cavo staccato)
    await drag(const Duration(milliseconds: 600));
    await waitFor(() => c.link == LinkState.lost, timeout: const Duration(seconds: 5));
    await drag(const Duration(milliseconds: 300)); // modifiche durante la perdita
    c.datasetLoad('scene', 3); // comandi durante la perdita: devono essere rifiutati
    c.setSolo(5, true);
    expect(c.rejectedWhileLost, greaterThanOrEqualTo(2));
    expect(c.queue.orderedLength, 0);
    final mark = sim.receivedAddresses.length;
    sim.paused = false;
    await waitFor(() => c.link == LinkState.connected, timeout: const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final after = sim.receivedAddresses.sublist(mark);
    expect(after.where((a) => a == '/load' || a.startsWith('/-stat/solosw')), isEmpty, reason: 'comandi della perdita eseguiti dopo la ripresa');
    expect(sim.solo[5], isFalse);
    // dopo la ripresa le nuove modifiche arrivano e l'ultimo valore vince
    await drag(const Duration(milliseconds: 400));
    await c.queue.drained();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (var ch = 1; ch <= 8; ch++) {
      expect(sim.state.getIdx('/ch/0$ch/mix/fader'), c.state.getIdx('/ch/0$ch/mix/fader'), reason: 'ch $ch');
    }
    await c.dispose();
  });

  test('ordine: aggiornamenti continui e richiamo di scena', () async {
    final c = await newClient();
    await c.connect(lo, port: sim.port);
    sim.state.setIdx('/ch/01/mix/fader', 100, origin: ChangeOrigin.remote);
    sim.scenes[4] = Scene('S4', '', sim.state.captureValues()); // nella scena il fader vale 100
    // a) movimenti, scena, altri movimenti: vince l'ultimo movimento
    for (var i = 0; i <= 500; i += 5) {
      c.state.setIdx('/ch/01/mix/fader', i);
    }
    c.datasetLoad('scene', 4);
    for (var i = 600; i <= 800; i += 5) {
      c.state.setIdx('/ch/01/mix/fader', i);
    }
    await c.queue.drained();
    await waitFor(() => sim.state.getIdx('/ch/01/mix/fader') == 800);
    final seq = sim.receivedAddresses.where((a) => a == '/load' || a == '/ch/01/mix/fader').toList();
    final loadAt = seq.indexOf('/load');
    expect(loadAt, greaterThan(0));
    expect(seq.sublist(loadAt + 1), everyElement('/ch/01/mix/fader'));
    // b) movimenti e poi scena: vince la scena, e il client riceve il valore della scena
    for (var i = 0; i <= 500; i += 5) {
      c.state.setIdx('/ch/01/mix/fader', i);
    }
    c.datasetLoad('scene', 4);
    await c.queue.drained();
    await waitFor(() => sim.state.getIdx('/ch/01/mix/fader') == 100);
    await waitFor(() => c.state.getIdx('/ch/01/mix/fader') == 100);
    await c.dispose();
  });

  test('ricerca su ogni scheda: il simulatore locale compare; spiegazione quando non risponde nessuno', () async {
    final r = await X32Client.discoverAll(window: const Duration(milliseconds: 600));
    // il simulatore di questo test ascolta su una porta casuale: la ricerca standard (10023) non lo trova,
    // ma le schede del PC risultano elencate per la diagnosi
    expect(r.interfaces.every((i) => !i.address.isLoopback), isTrue);
    final empty = DiscoveryReport(const [], [LocalInterface('Wi-Fi', InternetAddress('10.194.230.74'))], const []);
    final altraRete = empty.explain('192.168.1.2');
    expect(altraRete.any((s) => s.contains('192.168.1.x') && s.contains('altra rete')), isTrue);
    final stessaRete = DiscoveryReport(const [], [LocalInterface('Wi-Fi', InternetAddress('192.168.1.58'))], const []).explain('192.168.1.2');
    expect(stessaRete.any((s) => s.contains('isolamento')), isTrue);
    expect(DiscoveryReport(const [], const [], const []).explain('').single, contains('nessuna rete'));
  });

  test('ricerca: risposta dal simulatore sulla porta 10023 tramite 127.0.0.1', () async {
    X32Simulator? s;
    try {
      s = await X32Simulator.start(port: kX32Port);
    } on SocketException {
      markTestSkipped('porta 10023 occupata');
      return;
    }
    final r = await X32Client.discoverAll(window: const Duration(milliseconds: 600));
    expect(r.mixers.any((m) => m.isSimulator), isTrue);
    await s.close();
  });
}
