// Analisi della fixture reale: perché 2130 righe e non 2127.
import 'dart:io';

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';

void main() {
  test('composizione delle righe reali della X32P', () {
    final lines = File('test/fixtures/x32p_fw415_sync_nodes.txt').readAsLinesSync().where((l) => l.isNotEmpty).toList();
    final paths = [for (final l in lines) l.split(' ').first];
    final inTable = paths.where(kSyncNodes.contains).toList();
    final extra = paths.where((p) => !kSyncNodes.contains(p)).toList();
    final missing = kSyncNodes.where((p) => !paths.contains(p)).toList();
    final dup = paths.length - paths.toSet().length;
    final s = MixerState(initDefaults: false);
    for (final l in lines) {
      s.applyNodeLine(l, ChangeOrigin.sync);
    }
    final opaque = [for (final p in paths) if (s.node(p)!.spec.opaque) p];
    final report = StringBuffer()
      ..writeln('righe: ${lines.length}; percorsi distinti: ${paths.toSet().length}; duplicati: $dup')
      ..writeln('nella tabella dei 2127: ${inTable.length}; mancanti: ${missing.length}')
      ..writeln('righe aggiuntive: $extra')
      ..writeln('nodi opachi (testo conservato, nessun parametro): ${opaque.length}')
      ..writeln(opaque.map((p) => p.replaceAll(RegExp(r'/\d+'), '/N')).toSet().join(', '));
    File('../../docs/analisi_fixture_2130.txt').writeAsStringSync(report.toString());
    expect(lines.length, 2130);
    expect(inTable.length, 2127);
    expect(missing, isEmpty);
    expect(dup, 0);
    expect(extra, ['/-prefs/card', '/-show/showfile/show', '/-show/showfile/scene/001']);
    expect(s.warnings, isEmpty);
  });
}
