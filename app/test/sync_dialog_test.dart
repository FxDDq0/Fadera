// Finestra di sincronizzazione: un errore non deve bloccarla (fase 3, tappa 1.1).
// Nessun pacchetto in rete: il controller non è collegato a niente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/ui/dialogs/sync_dialog.dart';

void main() {
  testWidgets('Mixer → PC senza collegamento: errore visibile e finestra di nuovo utilizzabile', (t) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SyncDialog(ctl: ctl))));
    await t.tap(find.text('Mixer → PC (consigliato)'));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    expect(find.textContaining('Errore'), findsOneWidget);
    // non è rimasta in "in corso": i pulsanti di scelta sono tornati, niente solo "Interrompi"
    expect(find.text('Interrompi'), findsNothing);
    expect(find.text('Più tardi'), findsOneWidget);
    expect(ctl.synced, isFalse);
  });
}
