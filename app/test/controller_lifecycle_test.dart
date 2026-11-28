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

  test('disconnessione durante una connessione in corso: alla fine nessun collegamento e nessun client', () async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    // l'esito si raccoglie subito, come fa l'interfaccia che attende la connessione
    final pending = ctl.connect('127.0.0.1', port: sim.port).then<Object?>((_) => null, onError: (Object e) => e);
    await ctl.disconnect();
    final error = await pending;
    expect(error, isA<ConnectException>());
    expect(ctl.client, isNull);
    expect(ctl.isOnline, isFalse);
    ctl.dispose();
  });

  test('dispose durante una connessione in corso: il client creato viene rilasciato', () async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    final pending = ctl.connect('127.0.0.1', port: sim.port).then((_) {}, onError: (_) {});
    ctl.dispose();
    await pending;
    expect(ctl.client, isNull);
  });

  test('tipo di effetto cambiato dal mixer: i parametri vengono riletti (tappa 2.6)', () async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await ctl.connect('127.0.0.1', port: sim.port);
    await ctl.syncFromMixer((_, _) {}, () => false);
    final t = ctl.state.getIdx('/fx/1/type') ?? 0;
    // i valori mostrati dall'interfaccia (un notificatore per parametro) prima del cambio
    final par = ctl.state.node('/fx/1/par')!;
    final shown = {for (var i = 0; i < par.fields.length; i++) par.leafPath(i): ctl.hub.listen(par.leafPath(i))};
    // sul mixer il nuovo effetto ha valori diversi dai predefiniti
    sim.surfaceSet('/fx/1/type', t == 0 ? 1 : 0); // cambio "dalla superficie"
    final simPar = sim.state.node('/fx/1/par')!;
    for (var i = 0; i < simPar.fields.length; i++) {
      if (simPar.fields[i].kind != ParamKind.opaque && simPar.fields[i].kind != ParamKind.string) sim.state.setIdx(simPar.leafPath(i), 1, origin: ChangeOrigin.remote);
    }
    // attesa della risposta del simulatore senza tempi fissi
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (ctl.state.nodeLine('/fx/1/par') != sim.state.nodeLine('/fx/1/par') && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200)); // aggiornamento dell'interfaccia (150 ms)
    expect(ctl.state.getIdx('/fx/1/type'), sim.state.getIdx('/fx/1/type'));
    // valori reali riletti dal mixer, non quelli predefiniti ricostruiti sul PC
    expect(ctl.state.nodeLine('/fx/1/par'), sim.state.nodeLine('/fx/1/par'));
    // e l'interfaccia mostra i valori nuovi
    for (final e in shown.entries) {
      if (ctl.state.specOf(e.key) != null) expect(e.value.value, ctl.state.getIdx(e.key), reason: e.key);
    }
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
