// L'applicazione completa (controller + interfaccia) collegata al simulatore su 127.0.0.1.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/main.dart';
import 'package:x32_sim/x32_sim.dart';

void main() {
  testWidgets('connessione al simulatore, sync, fader in entrambe le direzioni', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final ctl = AppController(prefs: Prefs());
    late X32Simulator sim;
    await t.runAsync(() async {
      sim = await X32Simulator.start(port: 0);
      sim.state.setString('/ch/01/config/name', 'Kick', origin: ChangeOrigin.remote);
      final info = await ctl.connect('127.0.0.1', port: sim.port);
      expect(info.isSimulator, isTrue);
      final r = await ctl.syncFromMixer((_, _) {}, () => false);
      expect(r.ok, isTrue);
    });
    await t.pumpWidget(ControllerApp(controller: ctl));
    await t.pump(const Duration(milliseconds: 100));

    // la sessione simulata è dichiarata in modo evidente
    expect(find.text('SIMULATORE'), findsOneWidget);
    expect(find.textContaining('SESSIONE SIMULATA'), findsOneWidget);
    expect(find.text('Kick'), findsWidgets);

    // PC → simulatore
    ctl.setIdx('/ch/02/mix/fader', 767);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    expect(sim.state.getIdx('/ch/02/mix/fader'), 767);

    // simulatore ("superficie") → PC
    await t.runAsync(() async {
      sim.surfaceSet('/ch/03/mix/fader', 512);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.state.getIdx('/ch/03/mix/fader'), 512);
    expect(find.text('-10.0'), findsWidgets);

    // meter: il banco 0 arriva e alimenta l'hub
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    expect(ctl.meters.hasData(0), isTrue);

    await t.runAsync(() async {
      await ctl.disconnect();
      await sim.close();
    });
    await t.pump();
    expect(find.text('Non connesso'), findsOneWidget);
  });

  testWidgets('icone: lette con la sync, aggiornate dalla superficie, confermate per rilettura', (t) async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    late X32Simulator sim;
    await t.runAsync(() async {
      sim = await X32Simulator.start(port: 0);
      sim.state.applyNodeLine('/ch/01/config "Kick" 3 RD 1', ChangeOrigin.remote);
      await ctl.connect('127.0.0.1', port: sim.port);
      final r = await ctl.syncFromMixer((_, _) {}, () => false);
      expect(r.ok, isTrue);
    });
    // 1. lettura durante la sync: icona e colore distinti
    expect(ctl.idx('/ch/01/config/icon'), 3);
    expect(ctl.idx('/ch/01/config/color'), 1);
    // 2. modifica fatta "sul mixer" (superficie del simulatore)
    await t.runAsync(() async {
      sim.surfaceSet('/ch/01/config/icon', 41);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(ctl.idx('/ch/01/config/icon'), 41);
    // 3. invio da Mixora e rilettura del nodo: la conferma è la risposta del mixer
    String? readBack;
    await t.runAsync(() async {
      final sub = ctl.client!.nodeLines.listen((l) {
        if (l.startsWith('/ch/01/config ')) readBack = l;
      });
      ctl.setIdx('/ch/01/config/icon', 50);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      ctl.client!.requestNode('/ch/01/config');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
    });
    expect(sim.state.getIdx('/ch/01/config/icon'), 50);
    expect(readBack, contains(' 50 '));
    // 4. dopo una nuova sync l'icona corrisponde ancora a quella del mixer
    await t.runAsync(() async {
      sim.surfaceSet('/ch/01/config/icon', 23);
      await ctl.syncFromMixer((_, _) {}, () => false);
    });
    expect(ctl.idx('/ch/01/config/icon'), 23);
    // 5. disconnessione: l'ultima icona letta resta visibile, il selettore non invia
    await t.runAsync(() async {
      await ctl.disconnect();
      await sim.close();
    });
    expect(ctl.idx('/ch/01/config/icon'), 23);
    expect(ctl.isOnline, isFalse);
  });
}
