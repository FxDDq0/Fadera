// Verifica dello schema contro le righe di nodo REALI di una X32P FW 4.15
// (sync Mixer → PC della prova hardware T01b, 2026-11-21).
import 'dart:io';

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';

void main() {
  final lines = File('test/fixtures/x32p_fw415_sync_nodes.txt')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();

  test('la fixture contiene tutti i 2127 nodi di sync nell\'ordine della tabella', () {
    final paths = lines.map((l) => l.split(' ').first).toList();
    expect(paths.take(2127).toList(), kSyncNodes);
  });

  test('ogni riga reale viene letta senza avvisi', () {
    final s = MixerState(initDefaults: false);
    for (final l in lines) {
      expect(s.applyNodeLine(l, ChangeOrigin.sync), isTrue, reason: l);
    }
    expect(s.warnings, isEmpty);
  });

  test('ogni riga reale si riscrive identica (formato dei valori)', () {
    final s = MixerState(initDefaults: false);
    final mismatches = <String>[];
    for (final l in lines) {
      s.applyNodeLine(l, ChangeOrigin.sync);
      final path = l.split(' ').first;
      final out = s.nodeLine(path);
      if (out != l) mismatches.add('reale:  "$l"\nnostro: "$out"');
    }
    expect(mismatches, isEmpty, reason: mismatches.take(40).join('\n'));
  });

  test('i default generati sono leggibili dallo schema', () {
    final s = MixerState();
    expect(s.warnings, isEmpty);
    expect(s.getIdx('/ch/01/mix/fader'), 0);
    expect(s.getString('/bus/03/config/name'), 'MixBus 3');
  });
}
