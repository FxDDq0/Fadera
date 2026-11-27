// Cattura globale degli errori (fase 3, tappa 2.1): ogni errore non gestito finisce nel registro.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/error_handling.dart';

void main() {
  test('errori del framework e asincroni scritti nel registro', () {
    final ctl = AppController(prefs: Prefs()..persistent = false);
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    final oldBuilder = ErrorWidget.builder;
    addTearDown(() {
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
      ErrorWidget.builder = oldBuilder;
    });
    installErrorHandlers(ctl, presentToConsole: false);
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('guasto nel disegno'), library: 'test'));
    expect(PlatformDispatcher.instance.onError!(StateError('guasto in un timer'), StackTrace.current), isTrue);
    final errors = ctl.logs.where((e) => e.level == 'E').map((e) => e.message).join('\n');
    expect(errors, contains('guasto nel disegno'));
    expect(errors, contains('guasto in un timer'));
  });

  testWidgets('riquadro neutro al posto della schermata di errore', (t) async {
    final w = releaseErrorWidget(FlutterErrorDetails(exception: StateError('x')));
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 100, child: w))));
    expect(find.byKey(const ValueKey('error-box')), findsOneWidget);
  });
}
