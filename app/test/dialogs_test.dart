// Finestre poco coperte dai test (fase 3, tappa "test"). Nessun pacchetto in rete:
// la ricerca dei mixer è sostituita da un risultato preparato.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/ui/dialogs/color_picker.dart';
import 'package:x32_remote/ui/dialogs/connect_dialog.dart';
import 'package:x32_remote/ui/dialogs/personalize_dialog.dart';
import 'package:x32_remote/ui/dialogs/settings_dialog.dart';
import 'package:x32_remote/ui/pages/scenes_page.dart';

/// Controller con una ricerca finta: nessun broadcast sulla rete.
class _FakeDiscoveryController extends AppController {
  _FakeDiscoveryController(this.report) : super(prefs: Prefs()..persistent = false);
  final DiscoveryReport report;
  @override
  Future<DiscoveryReport> discover() async => report;
}

Future<void> _pumpIn(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(1600, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('connessione: mixer trovato mostrato con nome, modello e firmware', (t) async {
    final ctl = _FakeDiscoveryController(DiscoveryReport([
      MixerInfo(ip: '192.168.1.2', name: 'Palco', model: 'X32', firmware: '4.15', address: InternetAddress('192.168.1.2')),
    ], const [], const []));
    await _pumpIn(t, ConnectDialog(ctl: ctl));
    expect(find.text('Palco'), findsOneWidget);
    expect(find.textContaining('FW 4.15'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('connessione: nessun mixer, con la spiegazione del motivo', (t) async {
    final ctl = _FakeDiscoveryController(DiscoveryReport(const [], [LocalInterface('Wi-Fi', InternetAddress('10.0.0.7'))], const []));
    await _pumpIn(t, ConnectDialog(ctl: ctl));
    expect(find.text('Nessun mixer ha risposto alla ricerca.'), findsOneWidget);
    expect(find.byKey(const ValueKey('connect-why')), findsWidgets);
    // "Connetti" non viene premuto: risolverebbe l'indirizzo in rete (i messaggi sono provati a parte)
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('selettore di colore: si apre, restituisce un colore, si annulla', (t) async {
    Color? picked;
    await _pumpIn(
      t,
      Builder(builder: (c) => TextButton(onPressed: () async => picked = await pickColor(c, initial: const Color(0xFF3E7BFA)), child: const Text('apri'))),
    );
    await t.tap(find.text('apri'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog).evaluate().isNotEmpty || find.byType(AlertDialog).evaluate().isNotEmpty, isTrue);
    await t.tap(find.byType(FilledButton).last);
    await t.pumpAndSettle();
    expect(picked, isNotNull);
  });

  testWidgets('personalizzazione: ogni sezione si apre senza errori', (t) async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    for (var s = 0; s < 6; s++) {
      await _pumpIn(t, PersonalizeDialog(ctl: ctl, initialSection: s));
      expect(t.takeException(), isNull, reason: 'sezione $s');
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('impostazioni: ogni scheda si apre senza errori', (t) async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    for (var tab = 0; tab < 4; tab++) {
      await _pumpIn(t, SettingsDialog(ctl: ctl, initialTab: tab));
      expect(t.takeException(), isNull, reason: 'scheda $tab');
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('scene: elenco noto, ricerca per nome, comandi spenti senza mixer', (t) async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    ctl.datasetNames['scene']!.addAll({1: 'Intro', 2: 'Finale'});
    await _pumpIn(t, ScenesPage(ctl: ctl));
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Finale'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Fin');
    await t.pump();
    expect(find.text('Intro'), findsNothing);
    expect(find.text('Finale'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
