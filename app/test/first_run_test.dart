// Primo avvio: schermata di benvenuto, simulatore integrato, messaggi di errore comprensibili.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/main.dart';
import 'package:x32_remote/ui/dialogs/connect_dialog.dart';
import 'package:x32_remote/ui/dialogs/welcome_dialog.dart';

void main() {
  testWidgets('primo avvio: benvenuto una sola volta, "Più tardi" non collega nulla', (t) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await t.pumpWidget(MaterialApp(home: WelcomeGate(ctl: ctl, child: HomeScreen(ctl: ctl))));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
    expect(find.textContaining('non affiliato'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('welcome-later')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('welcome')), findsNothing);
    expect(ctl.prefs.welcomeDone, isTrue);
    expect(ctl.isOnline, isFalse);
    // secondo avvio: niente benvenuto
    await t.pumpWidget(MaterialApp(home: WelcomeGate(ctl: ctl, child: const SizedBox())));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('welcome')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('simulatore integrato: avvio, sync in sola lettura, arresto alla disconnessione', (t) async {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await t.runAsync(() async {
      final info = await ctl.connectBuiltinSimulator();
      expect(info.isSimulator, isTrue);
      expect(ctl.usingBuiltinSimulator, isTrue);
      final r = await ctl.syncFromMixer((_, _) {}, () => false);
      expect(r.ok, isTrue);
      expect(ctl.state.getString('/ch/01/config/name'), isNotEmpty);
      await ctl.disconnect();
      expect(ctl.usingBuiltinSimulator, isFalse);
    });
  });

  test('messaggi di errore della connessione comprensibili', () {
    expect(friendlyConnectError('', Exception()), contains('Setup → Network'));
    expect(friendlyConnectError('192.168.1.x', const FormatException('x')), contains('Indirizzo non valido'));
    expect(friendlyConnectError('192.168.1.2', ConnectException('Il mixer 192.168.1.2 non risponde.')), contains('hotspot'));
    expect(friendlyConnectError('mixer.local', const SocketException('lookup failed')), contains('non raggiungibile'));
  });
}
