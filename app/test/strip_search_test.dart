// Ricerca rapida dei canali (fase 3, novità 6.1). Nessuna rete.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/main.dart';

void main() {
  AppController ctlWithNames() {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    ctl.state.setString('/ch/05/config/name', 'Kick', origin: ChangeOrigin.remote);
    ctl.state.setString('/ch/21/config/name', 'Voce Lead', origin: ChangeOrigin.remote);
    ctl.state.setString('/bus/03/config/name', 'Monitor Batt', origin: ChangeOrigin.remote);
    return ctl;
  }

  test('per nome (anche parziale, senza maiuscole), per numero e per tipo', () {
    final ctl = ctlWithNames();
    expect(ctl.searchStrips('kick').first, const StripRef(StripKind.ch, 5));
    expect(ctl.searchStrips('voce').first, const StripRef(StripKind.ch, 21));
    expect(ctl.searchStrips('21').first, const StripRef(StripKind.ch, 21));
    expect(ctl.searchStrips('bus 3').first, const StripRef(StripKind.bus, 3));
    expect(ctl.searchStrips('batt').first, const StripRef(StripKind.bus, 3));
    expect(ctl.searchStrips('dca 2').first, const StripRef(StripKind.dca, 2));
    expect(ctl.searchStrips(''), isEmpty);
    expect(ctl.searchStrips('zzzz'), isEmpty);
    ctl.dispose();
  });

  test('scelta di un risultato: pagina giusta e strip selezionata', () {
    final ctl = ctlWithNames();
    ctl.setPage(AppPage.effects);
    ctl.goToStrip(const StripRef(StripKind.ch, 21));
    expect(ctl.page, AppPage.mixer);
    expect(ctl.layer, Layer.ch17);
    expect(ctl.selected, const StripRef(StripKind.ch, 21));
    ctl.goToStrip(const StripRef(StripKind.bus, 3));
    expect(ctl.layer, Layer.bus);
    ctl.dispose();
  });

  testWidgets('Ctrl+F apre la ricerca; Invio va al primo risultato', (t) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final ctl = ctlWithNames();
    await t.pumpWidget(MaterialApp(home: HomeScreen(ctl: ctl)));
    await t.pump(const Duration(milliseconds: 100));
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('strip-search')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('strip-search-field')), 'voce');
    await t.pump();
    expect(find.text('Voce Lead'), findsWidgets);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('strip-search')), findsNothing);
    expect(ctl.selected, const StripRef(StripKind.ch, 21));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
