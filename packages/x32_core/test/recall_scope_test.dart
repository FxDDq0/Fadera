import 'dart:io';

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';

void main() {
  test('categorie delle righe (tabella doc 06 par. 3.5)', () {
    expect(RecallScope.categoryOf('/ch/01/preamp +0.0 OFF OFF 24  20'), ScopeCategory.preamp);
    expect(RecallScope.categoryOf('/headamp/000 +16.5 OFF'), ScopeCategory.preamp);
    expect(RecallScope.categoryOf('/ch/01/mix ON   -oo ON +0 ON   -oo'), ScopeCategory.inputs);
    expect(RecallScope.categoryOf('/fxrtn/01/mix ON   0.0 ON -100 OFF   -oo'), ScopeCategory.inputs);
    expect(RecallScope.categoryOf('/bus/01/mix ON   -oo OFF +0 OFF   -oo'), ScopeCategory.buses);
    expect(RecallScope.categoryOf('/main/st/mix ON  -6.0 +0'), ScopeCategory.matrixMain);
    expect(RecallScope.categoryOf('/dca/1 ON   0.0'), ScopeCategory.dca);
    expect(RecallScope.categoryOf('/fx/1 VRM'), ScopeCategory.effects);
    expect(RecallScope.categoryOf('/outputs/main/01 4 POST OFF'), ScopeCategory.outputs);
    expect(RecallScope.categoryOf('/config/routing/IN AN1-8 AN9-16 A1-8 CARD1-8 AUX1-4'), ScopeCategory.routing);
    expect(RecallScope.categoryOf('/config/talk ON EXT'), ScopeCategory.talkback);
    expect(RecallScope.categoryOf('/config/chlink OFF OFF'), ScopeCategory.config);
    expect(RecallScope.categoryOf('/-prefs/card USB'), isNull);
    expect(RecallScope.categoryOf('#4.0# "scena"'), isNull);
  });

  test('filtro: categorie escluse e strip protette', () {
    final lines = File('test/fixtures/x32p_fw415_sync_nodes.txt').readAsLinesSync();
    final all = RecallScope().filter(lines);
    expect(all.where((l) => l.startsWith('/-')), isEmpty);
    final noRouting = RecallScope(enabled: ScopeCategory.values.toSet()..remove(ScopeCategory.routing)).filter(lines);
    expect(noRouting.where((l) => l.startsWith('/config/routing')), isEmpty);
    expect(noRouting.length, lessThan(all.length));
    final safe = RecallScope(safeStrips: {'/ch/05', '/dca/2'}).filter(lines);
    expect(safe.where((l) => l.startsWith('/ch/05/') || l.startsWith('/dca/2 ') || l.startsWith('/dca/2/')), isEmpty);
    expect(safe.where((l) => l.startsWith('/ch/15/')), isNotEmpty);
  });
}
