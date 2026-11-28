// Avvisi visibili e modifiche non inviate (fase 3, novità 6.2), con il simulatore su 127.0.0.1.
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_sim/x32_sim.dart';

Future<void> _waitFor(bool Function() ok, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) throw StateError('condizione non raggiunta');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  test('mixer perso: avviso, modifiche contate come non inviate, avviso alla ripresa con il numero', () async {
    final sim = await X32Simulator.start(port: 0);
    final ctl = AppController(prefs: Prefs()..persistent = false, linkLostAfter: const Duration(milliseconds: 800));
    await ctl.connect('127.0.0.1', port: sim.port);
    ctl.pendingNotices.clear();

    sim.paused = true; // come un cavo staccato
    await _waitFor(() => ctl.link == LinkState.lost);
    expect(ctl.pendingNotices.join('\n'), contains('non risponde'));
    ctl.setIdx('/ch/01/mix/fader', 300);
    ctl.setIdx('/ch/02/mix/fader', 400);
    expect(ctl.unsentEdits.value, 2);

    sim.paused = false;
    await _waitFor(() => ctl.link == LinkState.connected);
    expect(ctl.pendingNotices.last, contains('2'));
    // il conteggio resta finché l'utente non lo prende in carico (o rifà la sync)
    expect(ctl.unsentEdits.value, 2);
    ctl.acknowledgeUnsent();
    expect(ctl.unsentEdits.value, 0);

    await ctl.disconnect();
    ctl.dispose();
    await sim.close();
  });

  test('nuova connessione dopo una perdita: nessun falso "risponde di nuovo", conteggio azzerato', () async {
    final sim = await X32Simulator.start(port: 0);
    final ctl = AppController(prefs: Prefs()..persistent = false, linkLostAfter: const Duration(milliseconds: 800));
    await ctl.connect('127.0.0.1', port: sim.port);
    sim.paused = true;
    await _waitFor(() => ctl.link == LinkState.lost);
    ctl.setIdx('/ch/01/mix/fader', 300);
    expect(ctl.unsentEdits.value, 1);
    await ctl.disconnect();
    sim.paused = false;
    ctl.pendingNotices.clear();
    await ctl.connect('127.0.0.1', port: sim.port);
    expect(ctl.unsentEdits.value, 0);
    expect(ctl.pendingNotices.where((n) => n.contains('di nuovo')), isEmpty);
    await ctl.disconnect();
    ctl.dispose();
    await sim.close();
  });

  test('modifiche senza mixer collegato: lavoro locale, nessun conteggio', () {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    ctl.setIdx('/ch/01/mix/fader', 300);
    expect(ctl.unsentEdits.value, 0);
    ctl.dispose();
  });
}
