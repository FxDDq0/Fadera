// Preferenze: un file guasto non deve far perdere le impostazioni (fase 3, tappa 1.2).
// Ogni test usa una propria cartella temporanea, mai i dati reali dell'utente.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/main.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('fadera_prefs_');
    file = File('${dir.path}${Platform.pathSeparator}prefs.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  List<File> corruptCopies() => dir.listSync().whereType<File>().where((f) => f.path.contains('prefs.json.corrupt-')).toList();

  test('JSON illeggibile: valori predefiniti, file originale conservato, errore dichiarato', () {
    file.writeAsStringSync('{ questo non è json');
    final p = Prefs.load(file: file);
    expect(p.loadError, isNotNull);
    expect(p.lastHost, '');
    final copies = corruptCopies();
    expect(copies, hasLength(1));
    expect(copies.single.readAsStringSync(), '{ questo non è json');
  });

  test('un campo sbagliato non azzera gli altri', () {
    file.writeAsStringSync('{"lastHost": "192.168.1.2", "quickSlots": "dodici", "colorTheme": "live", "quickLayouts": {}}');
    final p = Prefs.load(file: file);
    expect(p.lastHost, '192.168.1.2');
    expect(p.colorTheme, 'live');
    expect(p.quickSlots, 12);
    expect(p.quickLayouts, isNotEmpty);
    expect(p.quickLayouts.containsKey(p.activeQuickLayout), isTrue);
    expect(p.loadError, isNotNull);
    expect(corruptCopies(), hasLength(1));
  });

  test('valori fuori intervallo riportati a valori sensati', () {
    file.writeAsStringSync('{"uiScale": 1e9, "quickSlots": 13, "meterFall": -5, "meterPeakHoldMs": 99999999}');
    final p = Prefs.load(file: file);
    expect(p.uiScale, inInclusiveRange(0.5, 2.5));
    expect(const [8, 10, 12, 16], contains(p.quickSlots));
    expect(p.meterFall, greaterThan(0));
    expect(p.meterPeakHoldMs, lessThanOrEqualTo(10000));
  });

  test('valore non ammesso per la modalità touch riportato al predefinito', () {
    file.writeAsStringSync('{"touchMode": "forse"}');
    expect(Prefs.load(file: file).touchMode, 'auto');
  });

  test('al massimo tre copie dei file guasti', () {
    for (var i = 0; i < 5; i++) {
      File('${file.path}.corrupt-2026-01-0${i + 1}T000000').writeAsStringSync('x');
    }
    file.writeAsStringSync('{ guasto');
    Prefs.load(file: file);
    expect(corruptCopies().length, 3);
  });

  test('file valido: nessun errore e nessuna copia', () {
    final a = Prefs(file: file)..lastHost = '10.0.0.5';
    expect(a.saveNow(), isTrue);
    final b = Prefs.load(file: file);
    expect(b.lastHost, '10.0.0.5');
    expect(b.loadError, isNull);
    expect(corruptCopies(), isEmpty);
  });

  testWidgets('file guasto: l\'utente vede un avviso nella finestra principale', (t) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    file.writeAsStringSync('{"lastHost": 5}');
    final p = Prefs.load(file: file)..persistent = false;
    final ctl = AppController(prefs: p);
    expect(ctl.pendingNotices, hasLength(1));
    await t.pumpWidget(MaterialApp(home: HomeScreen(ctl: ctl)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('notice')), findsOneWidget);
    expect(find.textContaining('lastHost'), findsOneWidget);
    expect(ctl.pendingNotices, isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 9));
  });

  test('salvataggio impossibile: nessuna eccezione, errore dichiarato, niente file temporanei', () {
    Directory(file.path).createSync(); // al posto del file c'è una cartella: la scrittura fallisce
    final p = Prefs(file: file)..lastHost = '10.0.0.5';
    expect(p.saveNow(), isFalse);
    expect(p.saveError, isNotNull);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });
}
