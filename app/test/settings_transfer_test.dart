// Esporta e importa le impostazioni (fase 3, novità 6.3). Cartelle temporanee, nessuna rete.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('fadera_transfer_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('esportazione e importazione: stesse impostazioni, indirizzo del mixer escluso', () {
    final a = Prefs()
      ..persistent = false
      ..lastHost = '192.168.1.2'
      ..colorTheme = 'live'
      ..stripsPerPage = 16
      ..quickSlots = 16
      ..bandStrips = ['/ch/01', '/ch/05']
      ..shortcuts = {'mute': 77};
    final f = a.exportSettings(dir);
    expect(f.readAsStringSync(), isNot(contains('192.168.1.2')));

    final b = Prefs()
      ..persistent = false
      ..lastHost = '10.0.0.9';
    expect(b.importSettings(f), isNull);
    expect(b.colorTheme, 'live');
    expect(b.stripsPerPage, 16);
    expect(b.quickSlots, 16);
    expect(b.bandStrips, ['/ch/01', '/ch/05']);
    expect(b.shortcuts, {'mute': 77});
    expect(b.lastHost, '10.0.0.9'); // l'indirizzo del mixer di questo PC resta
  });

  testWidgets('dal controller: importazione applicata subito e segnalata', (t) async {
    final a = Prefs()
      ..persistent = false
      ..colorTheme = 'live'
      ..stripsPerPage = 16;
    final f = a.exportSettings(dir);
    final ctl = AppController(prefs: Prefs()..persistent = false);
    ctl.pendingNotices.clear();
    expect(ctl.importSettings(f), isTrue);
    expect(ctl.prefs.colorTheme, 'live');
    expect(ctl.inputLayers, const [Layer.ch1, Layer.ch17]); // 16 fader per pagina applicati
    expect(ctl.pendingNotices.single, contains('importate'));
    final bad = File('${dir.path}${Platform.pathSeparator}rotto.json')..writeAsStringSync('x');
    expect(ctl.importSettings(bad), isFalse);
    ctl.dispose();
  });

  test('file non valido: errore e nessuna impostazione cambiata', () {
    final bad = File('${dir.path}${Platform.pathSeparator}guasto.json')..writeAsStringSync('{ non valido');
    final b = Prefs()
      ..persistent = false
      ..colorTheme = 'minimal';
    expect(b.importSettings(bad), isNotNull);
    expect(b.colorTheme, 'minimal');
  });
}
