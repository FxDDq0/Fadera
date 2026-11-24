// Lingue dell'interfaccia: copertura delle traduzioni, segnaposto, cambio di lingua dal vivo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/l10n/l10n.dart';
import 'package:x32_remote/l10n/translations.g.dart';
import 'package:x32_remote/main.dart';
import 'package:x32_remote/ui/dialogs/welcome_dialog.dart';

void main() {
  tearDown(() => L10n.current.value = 'it');

  test('ogni testo dell\'interfaccia è tradotto in tutte le lingue, con gli stessi segnaposto', () {
    final keys = (jsonDecode(File('l10n/keys.json').readAsStringSync()) as List).cast<String>();
    expect(keys.length, greaterThan(600));
    final ph = RegExp(r'\{p\d+\}');
    List<String> phs(String s) => ph.allMatches(s).map((m) => m.group(0)!).toList()..sort();
    for (final (code, _) in kLanguages.where((l) => l.$1 != 'it')) {
      final t = kTranslations[code]!;
      final missing = keys.where((k) => (t[k] ?? '').isEmpty).toList();
      expect(missing, isEmpty, reason: '$code: mancano ${missing.take(5)}');
      for (final k in keys) {
        expect(phs(t[k]!), phs(k), reason: '$code: segnaposto diversi in "$k"');
      }
    }
  });

  test('tr: segnaposto, lingua di sistema, testo sconosciuto', () {
    L10n.current.value = 'en';
    expect(tr('Versione {p0}', {'p0': '1.0'}), 'Version 1.0');
    expect(tr('testo che non esiste'), 'testo che non esiste');
    expect(L10n.systemLanguage('de_DE'), 'de');
    expect(L10n.systemLanguage('ja_JP'), 'en'); // lingua non supportata → inglese
    L10n.current.value = 'it';
    expect(tr('Versione {p0}', {'p0': '1.0'}), 'Versione 1.0');
  });

  testWidgets('cambio di lingua: l\'interfaccia si aggiorna subito e le finestre restano aperte', (t) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await t.pumpWidget(ControllerApp(controller: ctl));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Non connesso'), findsOneWidget);
    // finestra aperta durante il cambio
    showWelcome(t.element(find.byType(HomeScreen)), ctl);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Cerca il mixer'), findsOneWidget);
    for (final (code, word) in [('en', 'Search for the mixer'), ('de', 'Mischpult suchen'), ('fr', 'Rechercher la console'), ('es', 'Buscar el mezclador'), ('pt', 'Procurar o mixer')]) {
      ctl.setLanguage(code);
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text(word), findsOneWidget, reason: code);
      expect(find.byKey(const ValueKey('welcome')), findsOneWidget, reason: 'la finestra resta aperta');
    }
    expect(find.text('Not connected'), findsNothing);
    ctl.setLanguage('en');
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Not connected'), findsOneWidget);
    expect(ctl.prefs.toJson()['language'], 'en');
    expect(t.takeException(), isNull);
    ctl.setLanguage('it');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
