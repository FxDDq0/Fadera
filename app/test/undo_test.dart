// Annulla (Ctrl+Z) e operazioni che sostituiscono lo stato (fase 3, tappa 2.5).
// Dopo un richiamo, un ripristino o una sync, Ctrl+Z non deve rimandare al mixer valori vecchi.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_sim/x32_sim.dart';

void main() {
  test('richiamo di scena: la cronologia di annullamento si svuota', () {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    ctl.setIdx('/ch/01/mix/fader', 500);
    expect(ctl.canUndo, isTrue);
    ctl.clearUndo();
    expect(ctl.canUndo, isFalse);
    ctl.dispose();
  });

  test('ripristino di un backup: cronologia svuotata; file non valido segnalato senza eccezioni', () {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    final backup = ctl.backupLocalState('test_annulla');
    addTearDown(() {
      backup.deleteSync();
      File('${backup.path.substring(0, backup.path.length - 5)}.txt').deleteSync();
    });
    ctl.setIdx('/ch/01/mix/fader', 500);
    expect(ctl.restoreBackup(backup), isNull);
    expect(ctl.canUndo, isFalse);
    final bad = File('${Directory.systemTemp.path}${Platform.pathSeparator}fadera_backup_guasto.json')..writeAsStringSync('{"values": 3}');
    addTearDown(bad.deleteSync);
    expect(ctl.restoreBackup(bad), isNotNull);
    ctl.dispose();
  });

  test('sync Mixer → PC: cronologia svuotata', () async {
    final sim = await X32Simulator.start(port: 0);
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await ctl.connect('127.0.0.1', port: sim.port);
    ctl.setIdx('/ch/01/mix/fader', 500);
    expect(ctl.canUndo, isTrue);
    await ctl.syncFromMixer((_, _) {}, () => false);
    expect(ctl.canUndo, isFalse);
    await ctl.disconnect();
    ctl.dispose();
    await sim.close();
  });
}
