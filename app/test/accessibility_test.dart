// Accessibilità (fase 3, novità 6.4): contrasto del testo secondario e controlli leggibili
// dagli screen reader. Nessuna rete.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_core/x32_core.dart';
import 'package:x32_remote/controller/app_controller.dart';
import 'package:x32_remote/controller/prefs.dart';
import 'package:x32_remote/design/tokens.dart';
import 'package:x32_remote/ui/widgets/controls.dart';

Finder _slider() => find.byWidgetPredicate((w) => w is Semantics && w.properties.slider == true);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (([la, lb]..sort()).last + 0.05) / (([la, lb]..sort()).first + 0.05);
}

void main() {
  test('testo secondario leggibile: contrasto almeno 4,5:1 (WCAG AA) sugli sfondi dei pannelli', () {
    for (final bg in [AppColors.surface, AppColors.surface2, AppColors.surface3]) {
      expect(_contrast(AppColors.textFaint, bg), greaterThanOrEqualTo(4.5), reason: bg.toString());
    }
  });

  testWidgets('fader: per lo screen reader è un cursore con nome e valore, regolabile', (t) async {
    final sem = t.ensureSemantics();
    final ctl = AppController(prefs: Prefs()..persistent = false);
    ctl.state.setString('/ch/05/config/name', 'Kick', origin: ChangeOrigin.remote);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 60, height: 300, child: Fader(ctl: ctl, path: '/ch/05/mix/fader')))));
    final node = t.getSemantics(_slider());
    expect(node.label, contains('Kick'));
    expect(node.value, isNotEmpty);
    final data = node.getSemanticsData();
    expect(data.hasFlag(SemanticsFlag.isSlider), isTrue);
    final before = ctl.state.getIdx('/ch/05/mix/fader')!;
    expect(data.hasAction(SemanticsAction.increase), isTrue, reason: 'azione "aumenta" disponibile');
    t.semantics.performAction(find.semantics.byLabel(RegExp('Kick')), SemanticsAction.increase);
    await t.pump();
    expect(ctl.state.getIdx('/ch/05/mix/fader')!, greaterThan(before));
    sem.dispose();
  });

  testWidgets('manopola: cursore con il proprio nome', (t) async {
    final sem = t.ensureSemantics();
    final ctl = AppController(prefs: Prefs()..persistent = false);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: Knob(ctl: ctl, path: '/ch/01/mix/pan', label: 'PAN')))));
    final node = t.getSemantics(_slider());
    expect(node.label, contains('PAN'));
    expect(node.getSemanticsData().hasFlag(SemanticsFlag.isSlider), isTrue);
    sem.dispose();
  });
}
