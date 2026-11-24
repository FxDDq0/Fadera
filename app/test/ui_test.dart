// Test dell'interfaccia (senza mixer e senza rete).
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/main.dart';
import 'package:x32_remote/ui/widgets/controls.dart';
import 'package:x32_remote/theme.dart';
import 'package:x32_remote/ui/dialogs/personalize_dialog.dart';
import 'package:x32_remote/ui/pages/fx_page.dart';
import 'package:x32_remote/ui/pages/other_pages.dart';
import 'package:x32_remote/ui/fx_visuals.dart';
import 'package:x32_remote/ui/master_and_quick.dart';
import 'package:x32_remote/ui/processors.dart';
import 'package:x32_remote/ui/side_panel.dart';
import 'package:x32_remote/ui/icons/strip_icons.dart';
import 'package:x32_remote/ui/dialogs/icon_picker.dart';

AppController newCtl() => AppController(prefs: Prefs());

Future<void> pumpApp(WidgetTester t, AppController ctl, {Size size = const Size(1920, 1080)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ControllerApp(controller: ctl));
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('avvio: stato "Non connesso", nessuna connessione simulata', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    expect(find.text('Non connesso'), findsOneWidget);
    expect(find.text('SIMULATORE'), findsNothing);
    expect(ctl.isOnline, isFalse);
  });

  testWidgets('pagine degli ingressi da 8 canali, master sempre visibile', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    expect(find.text('MUTE'), findsNWidgets(9)); // 8 strip + master
    expect(find.text('Ch 01'), findsWidgets);
    expect(find.text('Ch 08'), findsWidgets);
    for (final (l, first) in [(Layer.ch9, 'Ch 09'), (Layer.ch17, 'Ch 17'), (Layer.ch25, 'Ch 25')]) {
      ctl.setLayer(l);
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text(first), findsWidgets);
      expect(find.text('MUTE'), findsNWidgets(9));
    }
    // la strip è larga: fader comodo anche con il mouse
    expect(t.getSize(find.byType(Fader).first).width, greaterThan(60));
  });

  testWidgets('cambio di layer e selezione aggiornano il pannello laterale', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    await t.ensureVisible(find.text('Bus').first);
    await t.tap(find.text('Bus').first);
    await t.pump(const Duration(milliseconds: 300));
    expect(ctl.layer, Layer.bus);
    await t.tap(find.text('MixBus 3').first);
    await t.pump(const Duration(milliseconds: 300));
    expect(ctl.selected, const StripRef(StripKind.bus, 3));
    expect(find.text('BUS 03'), findsOneWidget); // intestazione del pannello
  });

  testWidgets('il fader trascinato modifica il parametro con la curva del mixer', (t) async {
    final ctl = newCtl();
    final sent = <ParamChange>[];
    ctl.state.changes.listen(sent.add);
    await pumpApp(t, ctl);
    final fader = find.byType(Fader).first;
    await t.drag(fader, const Offset(0, -2000)); // fino in cima
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/01/mix/fader'), 1023);
    expect(sent.last.origin, ChangeOrigin.local);
    expect(find.text('+10.0'), findsWidgets);
    await t.drag(fader, const Offset(0, 4000)); // fino in fondo
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/01/mix/fader'), 0);
    expect(find.text('-∞'), findsWidgets);
  });

  testWidgets('doppio tocco sul fader: 0 dB (indice 767)', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    final fader = find.byType(Fader).first;
    await t.tap(fader);
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(fader);
    await t.pump(const Duration(milliseconds: 400));
    expect(ctl.state.getIdx('/ch/01/mix/fader'), 767);
  });

  testWidgets('MUTE inverte mix/on (0 = muto)', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    expect(ctl.state.getIdx('/ch/01/mix/on'), 1);
    await t.tap(find.text('MUTE').first);
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/01/mix/on'), 0);
  });

  testWidgets('un aggiornamento remoto sposta il fader senza essere reinviato', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    ctl.state.applyOsc(OscMessage('/ch/02/mix/fader', [const OscFloat(767 / 1023)]));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('0.0'), findsWidgets);
  });

  testWidgets('finestra piccola (1024×640): nessun errore di layout', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1280, 720));
    expect(t.takeException(), isNull);
    await pumpApp(t, ctl, size: const Size(1024, 640));
    expect(t.takeException(), isNull);
  });

  testWidgets('pagine DCA, Effetti, Routing, Scene: un clic dalla barra superiore', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    for (final (label, page) in [('Effetti', AppPage.effects), ('DCA', AppPage.dca), ('Routing', AppPage.routing), ('Scene', AppPage.scenes)]) {
      final f = find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith(label == 'DCA' ? 'DCA:' : label));
      await t.ensureVisible(f.first);
      await t.pump();
      await t.tap(f.first);
      await t.pump(const Duration(milliseconds: 400));
      expect(ctl.page, page, reason: label);
      expect(t.takeException(), isNull, reason: label);
    }
    // niente più menu "+" né scheda "Band"
    expect(find.byTooltip('Altre pagine'), findsNothing);
    expect(find.text('Band'), findsNothing);
  });

  testWidgets('routing bloccato per impostazione predefinita', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    ctl.routingTab = 0; // scheda Ingressi
    ctl.setPage(AppPage.routing);
    await t.pump(const Duration(milliseconds: 300));
    final before = ctl.state.getIdx('/config/routing/IN/1-8');
    await t.tap(find.text('9-16').first);
    await t.pump(const Duration(milliseconds: 300));
    expect(ctl.state.getIdx('/config/routing/IN/1-8'), before);
  });

  testWidgets('pagina effetti: parametri con nomi dell\'Appendice C', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    await t.ensureVisible(find.text('Effetti').first);
    await t.pump();
    await t.tap(find.text('Effetti').first);
    await t.pump(const Duration(milliseconds: 300));
    // FX1 predefinito: HALL
    expect(find.text('PreDelay'), findsOneWidget);
    expect(find.text('Decay'), findsOneWidget);
  });

  testWidgets('pannello EQ: grafico e controlli di banda', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    await t.tap(find.text('EQ').last);
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('BANDA 1'), findsWidgets); // titolo della banda scelta
    expect(find.text('Frequenza'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('scorciatoie: layer, selezione, mute, fader; inattive mentre si scrive', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    await t.sendKeyEvent(LogicalKeyboardKey.digit6);
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.layer, Layer.bus);
    await t.sendKeyEvent(LogicalKeyboardKey.digit1);
    await t.pump(const Duration(milliseconds: 100));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.selected, const StripRef(StripKind.ch, 2));
    await t.sendKeyEvent(LogicalKeyboardKey.keyM);
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/02/mix/on'), 0);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/02/mix/fader'), 1);
    await t.sendKeyEvent(LogicalKeyboardKey.f7);
    await t.pump(const Duration(milliseconds: 200));
    expect(ctl.page, AppPage.effects);
    await t.sendKeyEvent(LogicalKeyboardKey.f5);
    await t.pump(const Duration(milliseconds: 200));
    // scrivendo il nome nel pannello, "M" non deve mutare
    await t.tap(find.byType(TextField).first);
    await t.pump(const Duration(milliseconds: 100));
    await t.sendKeyEvent(LogicalKeyboardKey.keyM);
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/02/mix/on'), 0);
  });

  testWidgets('pagina Scene: schede Scene, Snippet, Cue', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    ctl.setPage(AppPage.scenes);
    await t.pump(const Duration(milliseconds: 300));
    for (final tab in ['Snippet', 'Cue', 'Scene']) {
      await t.tap(find.text(tab).last);
      await t.pump(const Duration(milliseconds: 200));
      expect(t.takeException(), isNull, reason: tab);
    }
    expect(find.text('Nuovo cue'), findsNothing);
  });

  testWidgets('link stereo letto da /config/chlink', (t) async {
    final ctl = newCtl();
    ctl.state.applyNodeLine('/config/chlink ON OFF OFF OFF OFF OFF OFF OFF OFF OFF OFF OFF OFF OFF OFF OFF', ChangeOrigin.load);
    expect(ctl.isLinked(const StripRef(StripKind.ch, 1)), isTrue);
    expect(ctl.isLinked(const StripRef(StripKind.ch, 2)), isTrue);
    expect(ctl.isLinked(const StripRef(StripKind.ch, 3)), isFalse);
    await pumpApp(t, ctl);
    expect(find.byIcon(Icons.link), findsNWidgets(2));
  });

  testWidgets('editor FX: visualizzazioni dedicate per riverbero, delay, modulazione', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    await t.ensureVisible(find.text('Effetti').last);
    await t.pump();
    await t.tap(find.text('Effetti').last);
    await t.pump(const Duration(milliseconds: 300));
    for (final code in ['HALL', 'DLY', '3TAP', 'CRS', 'FLNG', 'LIM']) {
      ctl.setIdx('/fx/1/type', kFxOrderSlots1to4.indexOf(code));
      ctl.state.resetFxParams(1, ChangeOrigin.load);
      ctl.hub.refreshAll();
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull, reason: code);
    }
  });

  testWidgets("Ctrl+Z annulla l'ultima modifica locale (trascinamento = un passo)", (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    ctl.setIdx('/ch/04/mix/fader', 100);
    ctl.setIdx('/ch/04/mix/fader', 200);
    ctl.setIdx('/ch/04/mix/fader', 300);
    ctl.toggle('/ch/04/mix/on');
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    expect(ctl.state.getIdx('/ch/04/mix/on'), 1);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(ctl.state.getIdx('/ch/04/mix/fader'), 0);
    // gli aggiornamenti remoti non entrano nella cronologia
    ctl.state.applyOsc(OscMessage('/ch/05/mix/fader', [const OscFloat(0.5)]));
    expect(ctl.canUndo, isFalse);
  });

  testWidgets('barra rapida: interruttore, trascinamento, rimozione, cambio di layout', (t) async {
    final prefs = Prefs()..persistent = false;
    prefs.quickLayouts = {
      'A': [QuickControl(path: '/ch/03/mix/on', label: 'Tom · Mute'), QuickControl(path: '/ch/03/mix/fader', label: 'Tom · Fader')],
      'B': [QuickControl(path: '/main/st/mix/on', label: 'Main · Mute')],
    };
    prefs.activeQuickLayout = 'A';
    final ctl = AppController(prefs: prefs);
    await pumpApp(t, ctl);
    expect(find.text('Tom · Mute'), findsOneWidget);
    expect(find.text('Assegna'), findsWidgets); // caselle vuote
    await t.tap(find.text('Tom · Mute'));
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/03/mix/on'), 0);
    await t.drag(find.text('Tom · Fader'), const Offset(200, 0));
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/03/mix/fader'), greaterThan(0));
    // rimozione
    await t.tap(find.descendant(of: find.ancestor(of: find.text('Tom · Mute'), matching: find.byType(Stack)).first, matching: find.byIcon(Icons.close)));
    await t.pump(const Duration(milliseconds: 100));
    expect(prefs.quickLayouts['A']!.length, 1);
    // cambio di layout
    prefs.activeQuickLayout = 'B';
    ctl.refresh();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Main · Mute'), findsOneWidget);
    expect(find.text('Tom · Fader'), findsNothing);
  });

  testWidgets('strip: meter, scala e fader in colonne separate (nessuna sovrapposizione)', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    final meter = t.getRect(find.byType(LevelMeter).first);
    final scale = t.getRect(find.byType(FaderScale).first);
    final fader = t.getRect(find.byType(Fader).first);
    expect(meter.right, lessThanOrEqualTo(scale.left));
    expect(scale.right, lessThanOrEqualTo(fader.left));
    expect(fader.width, greaterThanOrEqualTo(30));
  });

  testWidgets('a 1366×768: 8 strip larghe, pannello fisso e master visibili', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1366, 768));
    expect(find.text('MUTE'), findsNWidgets(9));
    final last = t.getRect(find.byType(Fader).at(7));
    expect(last.right, lessThan(1366 - Sz.masterWidth));
    expect(find.text('Canale'), findsWidgets); // pannello laterale aperto
    expect(t.takeException(), isNull);
  });

  testWidgets('personalizzazione: tema e colore locale cambiano i colori delle strip', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1600, 900));
    await t.tap(find.byTooltip('Personalizzazione: temi colore, colori dei canali, layer utente, barra rapida'));
    await t.pumpAndSettle();
    expect(find.byType(PersonalizeDialog), findsOneWidget);
    await t.tap(find.text('Live'));
    await t.pump();
    expect(MxTheme.current.id, 'live');
    expect(ctl.prefs.colorTheme, 'live');
    // colore locale: solo nell'app, nessun parametro del mixer cambia
    final before = ctl.idx('/ch/01/config/color');
    ctl.prefs.stripColorOverride['/ch/01'] = 0xFF123456;
    ctl.applyAppearance();
    expect(AppColors.stripColorFor('/ch/01', before), const Color(0xFF123456));
    expect(ctl.idx('/ch/01/config/color'), before);
    ctl.prefs.stripColorOverride.clear();
    ctl.prefs.colorTheme = 'studio';
    ctl.applyAppearance();
    await t.pump(const Duration(seconds: 1)); // salvataggio ritardato delle preferenze
  });

  test('effetti: parametri raggruppati per funzione dai nomi documentati', () {
    expect(fxGroupOf('PreDelay', FxFamily.reverb), FxGroup.space);
    expect(fxGroupOf('Decay', FxFamily.reverb), FxGroup.room);
    expect(fxGroupOf('Attack', FxFamily.reverb), FxGroup.room);
    expect(fxGroupOf('Attack', FxFamily.dynamics), FxGroup.dynamics);
    expect(fxGroupOf('FeedL', FxFamily.delay), FxGroup.space);
    expect(fxGroupOf('Feed', FxFamily.modulation), FxGroup.modulation);
    expect(fxGroupOf('LoCut', FxFamily.reverb), FxGroup.tone);
    expect(fxGroupOf('Mix', FxFamily.modulation), FxGroup.output);
    // ogni tipo documentato ha nome descrittivo e famiglia
    for (final code in kFxTypes.keys) {
      expect(kFxCatalog.containsKey(code), isTrue, reason: code);
    }
  });

  test('effetti: editor grafici solo per i parametri che il tipo possiede', () {
    final ctl = newCtl();
    expect(FxVisual.graphsFor(ctl, 1, kFxTypes['HALL']!), containsAll(['Inviluppo', 'Banda passante']));
    expect(FxVisual.graphsFor(ctl, 1, kFxTypes['DLY']!), contains('Ripetizioni'));
    expect(FxVisual.graphsFor(ctl, 1, kFxTypes['CRS']!), contains('Modulazione'));
    expect(FxVisual.graphsFor(ctl, 1, kFxTypes['DRV']!), contains('Mappa delle frequenze'));
    expect(FxVisual.graphsFor(ctl, 1, kFxTypes['HALL']!), isNot(contains('Ripetizioni')));
  });

  testWidgets('barra rapida: i mute mostrano MUTO e i nomi sono leggibili', (t) async {
    final prefs = Prefs()
      ..persistent = false
      ..quickLayouts = {
        'A': [QuickControl(path: '/ch/01/mix/on', label: 'Kick · Mute')],
      }
      ..activeQuickLayout = 'A';
    final ctl = AppController(prefs: prefs);
    await pumpApp(t, ctl);
    expect(find.text('attivo'), findsOneWidget);
    await t.tap(find.text('Kick · Mute'));
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.state.getIdx('/ch/01/mix/on'), 0);
    expect(find.text('MUTO'), findsOneWidget);
    expect(describeParam(ctl, '/ch/05/mix/03/level'), endsWith('· Mandata Bus 3'));
    expect(describeParam(ctl, '/dca/2/on'), 'DCA 2 · Mute');
  });

  testWidgets('modalità touch: controlli più grandi, nessun errore di layout', (t) async {
    final ctl = newCtl();
    ctl.prefs.touchMode = 'on';
    ctl.applyAppearance();
    await pumpApp(t, ctl, size: const Size(1366, 1024));
    expect(MxDensity.touch, isTrue);
    expect(t.getSize(find.text('MUTE').first.evaluate().isEmpty ? find.byType(Fader).first : find.byType(Fader).first).width, greaterThan(30));
    ctl.prefs.touchMode = 'off';
    ctl.applyAppearance();
    expect(MxDensity.touch, isFalse);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('DCA: assegnazione da sezione e riepilogo dei membri', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1600, 900));
    ctl.setPage(AppPage.dca);
    await t.pump(const Duration(milliseconds: 300));
    expect(ctl.idx('/ch/01/grp/dca') ?? 0, 0);
    await t.tap(find.text(ctl.stripName(const StripRef(StripKind.ch, 1))).last);
    await t.pump(const Duration(milliseconds: 100));
    expect((ctl.idx('/ch/01/grp/dca') ?? 0) & 1, 1);
    expect(find.textContaining('1 strip assegnata'), findsOneWidget);
  });

  testWidgets('routing: le quattro schede si aprono, bloccato per impostazione predefinita', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1366, 768));
    ctl.setPage(AppPage.routing);
    await t.pump(const Duration(milliseconds: 300));
    for (final tab in ['Uscite digitali', 'Uscite analogiche', 'Patch uscite', 'Ingressi']) {
      await t.tap(find.text(tab).last);
      await t.pump(const Duration(milliseconds: 200));
      expect(t.takeException(), isNull, reason: tab);
    }
    expect(find.text('Sblocca'), findsOneWidget);
  });

  test('schede del pannello secondo il tipo di strip', () {
    expect(PanelTab.available(const StripRef(StripKind.ch, 1)), [PanelTab.channel, PanelTab.gate, PanelTab.comp, PanelTab.eq, PanelTab.sends]);
    expect(PanelTab.available(const StripRef(StripKind.bus, 1)), isNot(contains(PanelTab.gate)));
    expect(PanelTab.available(const StripRef(StripKind.auxin, 1)), isNot(contains(PanelTab.comp)));
    expect(PanelTab.available(const StripRef(StripKind.dca, 1)), [PanelTab.channel]);
  });

  test('curve statiche di compressore e gate', () {
    final c = DynModel.comp(thr: -20, ratio: 4, knee: 0, expander: false, makeup: 0);
    expect(c.out(-40), -40); // sotto soglia: invariato
    expect(c.out(0), closeTo(-15, 1e-9)); // 20 dB sopra soglia → 5 dB
    final m = DynModel.comp(thr: -20, ratio: 4, knee: 0, expander: false, makeup: 6);
    expect(m.out(-40), -34);
    final g = DynModel.gate(thr: -40, range: 30, mode: 3);
    expect(g.out(-30), -30);
    expect(g.out(-60), -90);
    final e = DynModel.gate(thr: -40, range: 60, mode: 0); // EXP2
    expect(e.out(-50), -60);
  });

  testWidgets('scheda Canale: delay, pan con centro; schede Gate e Comp dedicate', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1600, 900));
    expect(find.text('DELAY DEL CANALE'), findsOneWidget);
    expect(find.text('USCITA VERSO IL MAIN'), findsOneWidget);
    expect(find.text('GATE'), findsNothing); // non più nella scheda Canale
    // pan spostato e riportato al centro
    final spec = ctl.state.specOf('/ch/01/mix/pan')!;
    ctl.setIdx('/ch/01/mix/pan', spec.idxFromPhysical(40));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('R40'), findsWidgets);
    await t.tap(find.text('Centro'));
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.state.getPhysical('/ch/01/mix/pan'), closeTo(0, 1e-9));
    // scheda Comp: trascinando sul grafico cambia la soglia
    await t.tap(find.text('Comp').last);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(DynGraph), findsOneWidget);
    final before = ctl.idx('/ch/01/dyn/thr');
    final r = t.getRect(find.byType(DynGraph));
    await t.tapAt(Offset(r.left + r.width * 0.3, r.center.dy));
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.idx('/ch/01/dyn/thr'), isNot(before));
    await t.tap(find.text('Gate').last);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Range'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  test('icone: 74 identificativi con nome e gruppo, nessuna icona per numeri sconosciuti', () {
    expect(kStripIcons.length, 74);
    for (var i = 0; i < 74; i++) {
      expect(kStripIcons[i].id, i + 1);
      expect(kStripIconGroups, contains(kStripIcons[i].group));
    }
    // valori predefiniti di X32-Edit [A] coerenti con i significati [EXT]
    expect(stripIconInfo(55)!.name, 'Jack TRS'); // aux in
    expect(stripIconInfo(61)!.name, 'Effetti (FX)'); // fx return
    expect(stripIconInfo(71)!.name, 'Mix bus'); // bus
    expect(stripIconInfo(72)!.name, 'Matrix'); // matrix
    expect(stripIconInfo(70)!.name, 'Fader'); // DCA
    expect(stripIconInfo(0), isNull);
    expect(stripIconInfo(80), isNull);
  });

  testWidgets('icone: lette dal mixer, aggiornate dal mixer, sconosciute conservate', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1600, 900));
    // sync: riga config reale con icona 3 (cassa fronte), separata dal colore
    ctl.state.applyNodeLine('/ch/01/config "Kick" 3 RD 1', ChangeOrigin.sync);
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.idx('/ch/01/config/icon'), 3);
    expect(ctl.idx('/ch/01/config/color'), 1);
    expect(find.byWidgetPredicate((w) => w is StripIconView && w.id == 3), findsWidgets);
    // modifica fatta sul mixer (messaggio OSC del campo)
    ctl.state.applyOsc(OscMessage('/ch/01/config/icon', [const OscInt(41)]));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byWidgetPredicate((w) => w is StripIconView && w.id == 41), findsWidgets);
    // identificativo sconosciuto: valore conservato, icona neutra
    ctl.state.applyNodeLine('/ch/02/config "Snare" 80 RD 2', ChangeOrigin.sync);
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.idx('/ch/02/config/icon'), 80);
    expect(find.byWidgetPredicate((w) => w is StripIconView && w.id == 80), findsWidgets);
    expect(ctl.state.snapshot(), contains('/ch/02/config "Snare" 80 RD 2'));
  });

  testWidgets('selettore delle icone: senza connessione non modifica nulla', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1600, 900));
    final before = ctl.idx('/ch/01/config/icon');
    await t.tap(find.byWidgetPredicate((w) => w is StripIconView && w.size == 28).first);
    await t.pumpAndSettle();
    expect(find.byType(IconPickerDialog), findsOneWidget);
    expect(find.textContaining('Non connesso: l'), findsOneWidget);
    await t.tap(find.byTooltip('Voce maschile (n. 41)'));
    await t.pump();
    await t.tap(find.text('Invia al mixer'));
    await t.pump();
    expect(ctl.idx('/ch/01/config/icon'), before); // nessuna modifica locale spacciata per sincronizzata
  });

  test('profili: salvano e ripristinano tutto l\'aspetto locale', () {
    final p = Prefs()..persistent = false;
    p
      ..colorTheme = 'live'
      ..bandStrips = ['/ch/17', '/ch/01']
      ..quickSlots = 8
      ..touchMode = 'on'
      ..quickLayouts = {'Show': [QuickControl(path: '/ch/01/mix/on', label: 'Kick · Mute')]}
      ..activeQuickLayout = 'Show';
    final profile = p.captureProfile();
    final q = Prefs()..persistent = false;
    q.applyProfile(profile);
    expect(q.colorTheme, 'live');
    expect(q.bandStrips, ['/ch/17', '/ch/01']);
    expect(q.quickSlots, 8);
    expect(q.touchMode, 'on');
    expect(q.activeQuickLayout, 'Show');
    expect(q.quick.single.path, '/ch/01/mix/on');
    // profilo vecchio (solo colori): gli altri campi restano invariati
    q.applyProfile({'theme': 'minimal'});
    expect(q.colorTheme, 'minimal');
    expect(q.bandStrips, ['/ch/17', '/ch/01']);
  });

  testWidgets('diagnostica: contatori visibili ed esportazione su file', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1600, 900));
    final f = ctl.exportDiagnostics(appVersion: 'test');
    final text = f.readAsStringSync();
    expect(text, contains('## Connessione'));
    expect(text, contains('## Traffico'));
    expect(text, contains('coda:'));
    expect(text, contains('## Ultima sync'));
    f.deleteSync();
    await t.tap(find.byIcon(Icons.settings));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(Tab, 'Diagnostica'));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Esporta diagnostica'), findsOneWidget);
    expect(find.text('TRAFFICO E CODA DI INVIO'), findsOneWidget);
    expect(t.takeException(), isNull);
    Navigator.of(t.element(find.text('Esporta diagnostica'))).pop();
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('routing: panoramica dei collegamenti e user routing in sola lettura', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl, size: const Size(1600, 900));
    ctl.setPage(AppPage.routing);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('INGRESSI DEI CANALI'), findsWidgets); // panoramica predefinita
    await t.tap(find.text('User routing'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Sola lettura'), findsOneWidget);
    expect(find.descendant(of: find.byType(RoutingPage), matching: find.byType(DropdownButton<int>)), findsNothing); // nessun comando di modifica
    expect(t.takeException(), isNull);
  });

  testWidgets('layer Utente: stellina nel pannello e clic destro sulla strip', (t) async {
    final ctl = newCtl();
    ctl.prefs.bandStrips = [];
    await pumpApp(t, ctl, size: const Size(1600, 900));
    // stellina del canale selezionato (Ch 01)
    expect(ctl.inUserLayer(ctl.selected), isFalse);
    await t.tap(find.byIcon(Icons.star_border_rounded).last);
    await t.pump(const Duration(milliseconds: 100));
    expect(ctl.inUserLayer(ctl.selected), isTrue);
    expect(find.textContaining('aggiunta al layer Utente'), findsOneWidget);
    // clic destro sull'intestazione della strip 3 → menu → aggiungi
    final strip3 = find.text('Ch 03').first;
    await t.tap(strip3, buttons: kSecondaryButton);
    await t.pumpAndSettle();
    await t.tap(find.text('Aggiungi al layer Utente'));
    await t.pumpAndSettle();
    expect(ctl.prefs.bandStrips, contains('/ch/03'));
    // nel layer Utente compaiono le strip scelte; un secondo clic destro le toglie
    ctl.setLayer(Layer.band);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('MUTE'), findsNWidgets(3)); // 2 strip + master
    await t.tap(find.text('Ch 03').first, buttons: kSecondaryButton);
    await t.pumpAndSettle();
    await t.tap(find.text('Togli dal layer Utente'));
    await t.pumpAndSettle();
    expect(ctl.prefs.bandStrips, isNot(contains('/ch/03')));
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('GR: valore reale dal banco 16 (gate pos. 0, compressore pos. 32), spento fuori dai canali', (tester) async {
    final ctl = newCtl();
    Widget host(StripRef s, bool gate) => MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(height: 200, child: GainReductionMeter(ctl: ctl, strip: s, gate: gate)))));
    final ch1 = const StripRef(StripKind.ch, 1);
    // nessun dato: nessun valore inventato
    await tester.pumpWidget(host(ch1, false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('—'), findsOneWidget);
    // compressore di ch 1 a −6 dB, gate di ch 1 chiuso a −60 dB
    final v = List<double>.filled(192, 1.0);
    v[MeterBank16Map.comp(1)] = 0.501187; // −6 dB
    v[MeterBank16Map.gate(1)] = 0.001; // −60 dB
    ctl.meters.onFrame(decodeMeterBlob(16, encodeMeterBlob(16, v))!);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('-6.0'), findsOneWidget);
    await tester.pumpWidget(host(ch1, true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('-60'), findsOneWidget);
    // bus: posizione non verificata → spento
    await tester.pumpWidget(host(const StripRef(StripKind.bus, 1), false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('non disponibile'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pagine: 8 o 16 fader per pagina, la pagina corrente resta visibile', (t) async {
    final ctl = newCtl();
    await pumpApp(t, ctl);
    expect(find.text('Ch 9–16'), findsOneWidget);
    // selettore rapido nella barra in alto
    await t.tap(find.byKey(const ValueKey('per-page-16')));
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.prefs.stripsPerPage, 16);
    expect(find.text('Ch 1–16'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('per-page-8')));
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.prefs.stripsPerPage, 8);
    ctl.setLayer(Layer.ch9);
    expect(ctl.stripsFor(ctl.layer).map((s) => s.number), [9, 10, 11, 12, 13, 14, 15, 16]);
    ctl.setStripsPerPage(16);
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.layer, Layer.ch1);
    expect(ctl.stripsFor(ctl.layer).map((s) => s.number), [for (var i = 1; i <= 16; i++) i]);
    expect(find.text('Ch 1–16'), findsOneWidget);
    expect(find.text('Ch 17–32'), findsOneWidget);
    expect(find.text('Ch 9–16'), findsNothing);
    expect(ctl.prefs.toJson()['stripsPerPage'], 16);
    ctl.setLayer(Layer.ch25);
    expect(ctl.layer, Layer.ch17);
    expect(ctl.stripsFor(ctl.layer).first.number, 17);
    expect(t.takeException(), isNull);
    // 16 strip a 1366×768: nessun errore di layout
    await pumpApp(t, ctl, size: const Size(1366, 768));
    expect(t.takeException(), isNull);
    ctl.setStripsPerPage(8);
    await t.pump(const Duration(milliseconds: 50));
    expect(ctl.stripsFor(ctl.layer).map((s) => s.number), [17, 18, 19, 20, 21, 22, 23, 24]);
    await t.pump(const Duration(seconds: 3));
  });
}
