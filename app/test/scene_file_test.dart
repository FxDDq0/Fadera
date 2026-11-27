// Invio di file di scena: solo righe sicure e riconosciute (fase 3, tappa 1.4). Nessuna rete.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/scene_file.dart';

void main() {
  final state = MixerState();

  test('solo i nodi della tabella di sync vengono inviati; comandi e percorsi sconosciuti scartati', () {
    final plan = planSceneSend([
      '# commento',
      '',
      '/ch/01/mix ON  -3.0 ON +0 OFF   -oo',
      '/ch/02/config "Voce" 1 RD 2',
      '/-action/goscene 5',
      '/-prefs/remote/ioenable 4095',
      '/-stat/solosw/01 ON',
      '/qualcosa/di/strano 1',
      'testo senza barra',
    ], state);
    expect(plan.sendable, ['/ch/01/mix ON  -3.0 ON +0 OFF   -oo', '/ch/02/config "Voce" 1 RD 2']);
    expect(plan.rejected, hasLength(4));
    expect(plan.phantomLines, 0);
  });

  test('righe dell\'alimentazione phantom contate a parte', () {
    final plan = planSceneSend(['/headamp/000 +10.0 ON', '/headamp/001 +0.0 OFF', '/ch/03/mix OFF -oo ON +0 OFF -oo'], state);
    expect(plan.sendable, hasLength(3));
    expect(plan.phantomLines, 2);
  });

  test('file troppo grande rifiutato prima della lettura', () {
    final dir = Directory.systemTemp.createTempSync('fadera_scn_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final big = File('${dir.path}${Platform.pathSeparator}grande.scn')..writeAsBytesSync(List.filled(kMaxSceneFileBytes + 1, 0x41));
    expect(() => readSceneFile(big), throwsA(isA<SceneFileException>()));
    final ok = File('${dir.path}${Platform.pathSeparator}ok.scn')..writeAsStringSync('/ch/01/mix ON -3.0 ON +0 OFF -oo\n');
    expect(readSceneFile(ok), hasLength(1));
  });
}
