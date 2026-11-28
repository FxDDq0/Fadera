// Piccoli difetti dell'interfaccia (fase 3, tappa 2.8). Nessuna rete.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/controller/shortcuts.dart';
import 'package:x32_remote/ui/master_and_quick.dart';

void main() {
  test('un tasto assegnato a un\'azione viene tolto alle altre, anche se era il loro predefinito', () {
    final p = Prefs()..persistent = false;
    // "M" è il predefinito di Mute: assegnarlo a Solo deve liberarlo da Mute
    assignShortcut(p, ShortcutAction.solo, LogicalKeyboardKey.keyM);
    expect(shortcutKey(p, ShortcutAction.solo), LogicalKeyboardKey.keyM);
    expect(shortcutKey(p, ShortcutAction.mute), isNull);
    final owners = ShortcutAction.values.where((a) => shortcutKey(p, a) == LogicalKeyboardKey.keyM);
    expect(owners, [ShortcutAction.solo]);
  });

  test('nuovo layout della barra rapida: niente nomi doppi, vuoti o riservati', () {
    final p = Prefs()..persistent = false;
    expect(layoutNameProblem(p, 'Concerto'), isNull);
    expect(layoutNameProblem(p, 'Predefinito'), isNotNull);
    expect(layoutNameProblem(p, '  '), isNotNull);
    expect(layoutNameProblem(p, '+'), isNotNull);
    expect(layoutNameProblem(p, '-'), isNotNull);
  });

  test('trascinamento lento sulla barra rapida: piccoli spostamenti si sommano', () {
    final spec = const ParamSpec.enumeration('x', ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
    final d = QuickDragAccumulator();
    var idx = 0;
    for (var i = 0; i < 100; i++) {
      idx = d.update(spec, idx, 1); // 100 eventi da 1 px
    }
    expect(idx, greaterThan(0));
  });

  test('meter sotto la soglia minima: la barra si svuota', () {
    final b = MeterBallistics(fallDbPerSecond: 200, floorDb: -90);
    b.input(-80);
    b.input(-127);
    for (var i = 0; i < 20; i++) {
      b.tick(16);
    }
    expect(b.level, -127);
  });
}
