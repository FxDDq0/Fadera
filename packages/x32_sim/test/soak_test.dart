// Test di carico e di durata (client + simulatore su 127.0.0.1).
// Durata predefinita 60 s; per una prova lunga: SOAK_SECONDS=1800 dart test test/soak_test.dart
@Tags(['soak'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_sim/x32_sim.dart';

void main() {
  test('carico continuo: tutti i meter, modifiche da entrambi i lati, nessuna perdita di coerenza', () async {
    final seconds = int.tryParse(Platform.environment['SOAK_SECONDS'] ?? '') ?? 60;
    final sim = await X32Simulator.start(port: 0);
    final t = await UdpTransport.bind(policy: TransportPolicy.loopbackOnly);
    final c = X32Client(transport: t);
    final errors = <String>[];
    final lostAt = <DateTime>[];
    c.log.listen((l) {
      if (l.level == 'E') errors.add(l.message);
    });
    c.linkChanges.listen((s) {
      if (s == LinkState.lost) lostAt.add(DateTime.now());
    });
    // Pause del processo (es. sospensione di Windows): il ciclo di prova stesso resta fermo.
    final pauses = <(DateTime, Duration)>[];
    var lastTick = DateTime.now();
    await c.connect(InternetAddress.loopbackIPv4, port: sim.port);
    final r = await c.syncFromMixer();
    expect(r.ok, isTrue);
    // tutti i 17 banchi meter a 50 ms
    for (var b = 0; b <= 16; b++) {
      c.subscribeMeters(b);
    }
    var frames = 0;
    final mSub = c.meters.listen((_) => frames++);
    final rnd = math.Random(1);
    final rss0 = ProcessInfo.currentRss;
    final sw = Stopwatch()..start();
    var localSends = 0, surface = 0;
    final faderPaths = [for (var i = 1; i <= 32; i++) '/ch/${i.toString().padLeft(2, '0')}/mix/fader'];
    while (sw.elapsed.inSeconds < seconds) {
      // l'utente muove 4 fader (un evento ogni ~8 ms, come X32-Edit)
      for (var k = 0; k < 4; k++) {
        c.state.setIdx(faderPaths[rnd.nextInt(16)], rnd.nextInt(1024));
        localSends++;
      }
      // qualcuno muove i fader 17–32 sul mixer
      sim.surfaceSet(faderPaths[16 + rnd.nextInt(16)], rnd.nextInt(1024));
      surface++;
      await Future<void>.delayed(const Duration(milliseconds: 8));
      final now = DateTime.now();
      final gap = now.difference(lastTick);
      if (gap > const Duration(seconds: 3)) pauses.add((lastTick, gap));
      lastTick = now;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await mSub.cancel();
    final rss1 = ProcessInfo.currentRss;
    // coerenza finale: lo stato del client coincide con quello del simulatore
    final diffs = [for (final p in faderPaths) if (c.state.getIdx(p) != sim.state.getIdx(p)) p];
    stdout.writeln('soak ${seconds}s: $localSends modifiche locali, $surface dalla superficie, $frames blob meter, '
        'RSS ${(rss0 / 1048576).toStringAsFixed(1)} → ${(rss1 / 1048576).toStringAsFixed(1)} MiB, '
        'inviati ${c.sentCount}, ricevuti ${c.receivedCount}, scartati ${c.droppedCount}, coda: wouldBlock ${c.queue.wouldBlockCount}, fusi ${c.queue.coalesced}, profondità max ${c.queue.maxDepth}, errori ${c.queue.sendErrors}, scartati in coda ${c.queue.dropped}, '
        'pause del processo ${pauses.map((p) => '${p.$1.toIso8601String().substring(11, 19)}+${p.$2.inSeconds}s').toList()}, '
        'perdite segnalate ${lostAt.length}');
    expect(diffs, isEmpty, reason: 'fader non allineati: $diffs');
    expect(c.link, LinkState.connected);
    // Una perdita è accettabile solo se coincide con una pausa dell'intero processo
    // (il client ha giustamente smesso di ricevere): deve essere seguita dalla ripresa.
    final unexplained = [
      for (final l in lostAt)
        if (!pauses.any((p) => l.isAfter(p.$1) && l.isBefore(p.$1.add(p.$2).add(const Duration(seconds: 2))))) l,
    ];
    expect(unexplained, isEmpty, reason: 'perdite di connessione senza pausa del processo');
    expect(errors.where((e) => !e.contains('connessione persa')), isEmpty);
    expect(c.droppedCount, 0);
    // ≥ 10 blob/s per banco sul tempo attivo (le pause del processo non contano)
    final paused = pauses.fold<int>(0, (a, p) => a + p.$2.inSeconds);
    expect(frames, greaterThan((seconds - paused).clamp(1, seconds) * 17 * 10));
    expect(rss1 - rss0, lessThan(150 * 1048576)); // nessuna crescita anomala della memoria
    await c.dispose();
    await sim.close();
  }, timeout: const Timeout(Duration(hours: 2)));

  test('prestazioni del motore: decodifica e aggiornamento dello stato', () {
    final st = MixerState();
    final sw = Stopwatch()..start();
    for (var i = 0; i < 200000; i++) {
      st.applyOsc(OscMessage('/ch/${(i % 32 + 1).toString().padLeft(2, '0')}/mix/fader', [OscFloat((i % 1024) / 1023)]));
    }
    final perMsgUs = sw.elapsedMicroseconds / 200000;
    final blob = encodeMeterBlob(0, List.filled(70, 0.5));
    sw.reset();
    for (var i = 0; i < 100000; i++) {
      decodeMeterBlob(0, blob);
    }
    final perBlobUs = sw.elapsedMicroseconds / 100000;
    stdout.writeln('stato: ${perMsgUs.toStringAsFixed(2)} µs/messaggio; meter: ${perBlobUs.toStringAsFixed(2)} µs/blob');
    // 17 banchi × 20 Hz = 340 blob/s: anche a 100 µs/blob resterebbe il 97 % di un core libero
    expect(perMsgUs, lessThan(50));
    expect(perBlobUs, lessThan(100));
  });
}
