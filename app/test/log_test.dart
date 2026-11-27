// Registro su disco (fase 3, tappa 2.4): niente file infiniti, niente file vecchi accumulati.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';

void main() {
  test('messaggi ripetuti: al massimo uno per intervallo, con il conteggio di quelli saltati', () {
    final r = LogThrottle(const Duration(seconds: 1));
    final t0 = DateTime(2026, 1, 1, 12);
    expect(r.take(t0), 0); // primo: scritto
    expect(r.take(t0.add(const Duration(milliseconds: 100))), isNull);
    expect(r.take(t0.add(const Duration(milliseconds: 200))), isNull);
    expect(r.take(t0.add(const Duration(milliseconds: 1100))), 2); // scritto, con 2 saltati
  });

  test('registri più vecchi di 30 giorni eliminati, gli altri conservati', () {
    final d = Directory.systemTemp.createTempSync('fadera_logs_');
    addTearDown(() => d.deleteSync(recursive: true));
    final now = DateTime(2026, 11, 28);
    File('${d.path}${Platform.pathSeparator}x32remote_2026-10-01.log').writeAsStringSync('vecchio');
    File('${d.path}${Platform.pathSeparator}x32remote_2026-11-20.log').writeAsStringSync('recente');
    File('${d.path}${Platform.pathSeparator}appunti.txt').writeAsStringSync('non è un registro');
    expect(pruneLogs(d, now: now), 1);
    final names = d.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(names, {'x32remote_2026-11-20.log', 'appunti.txt'});
  });
}
