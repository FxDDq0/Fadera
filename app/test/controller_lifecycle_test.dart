// Ciclo di vita del collegamento nel controller (fase 3, tappa 2.2), con il simulatore su 127.0.0.1.
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_sim/x32_sim.dart';

void main() {
  late X32Simulator sim;
  setUp(() async => sim = await X32Simulator.start(port: 0));
  tearDown(() async => sim.close());

  test('la disconnessione rilascia il client', () async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await ctl.connect('127.0.0.1', port: sim.port);
    final c = ctl.client!;
    await ctl.disconnect();
    expect(c.disposed, isTrue);
    expect(ctl.client, isNull);
    ctl.dispose();
  });

  test('due connessioni sovrapposte: resta un solo client, gli altri rilasciati', () async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    final seen = <X32Client>[];
    void track() {
      final c = ctl.client;
      if (c != null && !seen.contains(c)) seen.add(c);
    }

    ctl.addListener(track);
    await Future.wait([ctl.connect('127.0.0.1', port: sim.port), ctl.connect('127.0.0.1', port: sim.port)]);
    track();
    expect(ctl.isOnline, isTrue);
    final live = ctl.client!;
    for (final c in seen) {
      if (!identical(c, live)) expect(c.disposed, isTrue);
    }
    ctl.removeListener(track);
    await ctl.disconnect();
    ctl.dispose();
  });

  test('dispose del controller mentre è connesso: nessun errore, nessuna notifica dopo', () async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await ctl.connect('127.0.0.1', port: sim.port);
    final c = ctl.client!;
    ctl.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.disposed, isTrue);
  });
}
