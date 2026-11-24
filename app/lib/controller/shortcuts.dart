import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_controller.dart';
import '../l10n/l10n.dart';

/// Azioni da tastiera (personalizzabili, salvate nelle preferenze).
enum ShortcutAction {
  layer1(/*l10n*/ 'Pagina Ch 1–8', LogicalKeyboardKey.digit1),
  layer2(/*l10n*/ 'Pagina Ch 9–16', LogicalKeyboardKey.digit2),
  layer3(/*l10n*/ 'Pagina Ch 17–24', LogicalKeyboardKey.digit3),
  layer4(/*l10n*/ 'Pagina Ch 25–32', LogicalKeyboardKey.digit4),
  layer5(/*l10n*/ 'Layer Aux · FX', LogicalKeyboardKey.digit5),
  layer6(/*l10n*/ 'Layer Bus', LogicalKeyboardKey.digit6),
  layer7(/*l10n*/ 'Layer Matrix · Main', LogicalKeyboardKey.digit7),
  layer8(/*l10n*/ 'Pagina DCA', LogicalKeyboardKey.digit8),
  layer9(/*l10n*/ 'Layer utente', LogicalKeyboardKey.digit9),
  pageMixer(/*l10n*/ 'Pagina Mixer', LogicalKeyboardKey.f5),
  pageDca(/*l10n*/ 'Pagina DCA', LogicalKeyboardKey.f6),
  pageFx(/*l10n*/ 'Pagina Effetti', LogicalKeyboardKey.f7),
  pageRouting(/*l10n*/ 'Pagina Routing', LogicalKeyboardKey.f8),
  pageScenes(/*l10n*/ 'Pagina Scene', LogicalKeyboardKey.f9),
  prevStrip(/*l10n*/ 'Strip precedente', LogicalKeyboardKey.arrowLeft),
  nextStrip(/*l10n*/ 'Strip successiva', LogicalKeyboardKey.arrowRight),
  faderUp(/*l10n*/ 'Fader della strip selezionata su', LogicalKeyboardKey.arrowUp),
  faderDown(/*l10n*/ 'Fader della strip selezionata giù', LogicalKeyboardKey.arrowDown),
  mute(/*l10n*/ 'Mute della strip selezionata', LogicalKeyboardKey.keyM),
  solo(/*l10n*/ 'Solo della strip selezionata', LogicalKeyboardKey.keyS);

  const ShortcutAction(this._label, this.defaultKey);
  final String _label;
  String get label => tr(_label);
  final LogicalKeyboardKey defaultKey;
}

/// Tasto assegnato a un'azione (personalizzato o predefinito).
LogicalKeyboardKey keyFor(AppController ctl, ShortcutAction a) {
  final id = ctl.prefs.shortcuts[a.name];
  return id == null ? a.defaultKey : LogicalKeyboardKey(id);
}

/// Vero se il fuoco è in un campo di testo: in quel caso le scorciatoie non agiscono.
bool _typing() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  if (ctx.widget is EditableText) return true;
  return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Gestore delle scorciatoie a livello di finestra. Restituisce `handled` solo per i tasti assegnati.
KeyEventResult handleShortcut(AppController ctl, KeyEvent e) {
  if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
  if (_typing()) return KeyEventResult.ignored;
  final hw = HardwareKeyboard.instance;
  if (hw.isControlPressed && e.logicalKey == LogicalKeyboardKey.keyZ) {
    ctl.undo();
    return KeyEventResult.handled;
  }
  if (hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) return KeyEventResult.ignored;
  ShortcutAction? action;
  for (final a in ShortcutAction.values) {
    if (keyFor(ctl, a) == e.logicalKey) {
      action = a;
      break;
    }
  }
  if (action == null) return KeyEventResult.ignored;
  final repeatable = action == ShortcutAction.faderUp || action == ShortcutAction.faderDown || action == ShortcutAction.prevStrip || action == ShortcutAction.nextStrip;
  if (e is KeyRepeatEvent && !repeatable) return KeyEventResult.handled;
  final step = hw.isShiftPressed ? 10 : 1;
  switch (action) {
    case ShortcutAction.layer1:
    case ShortcutAction.layer2:
    case ShortcutAction.layer3:
    case ShortcutAction.layer4:
    case ShortcutAction.layer5:
    case ShortcutAction.layer6:
    case ShortcutAction.layer7:
      final k = action.index - ShortcutAction.layer1.index;
      // con 16 fader per pagina: tasto 1 = Ch 1–16, tasto 2 = Ch 17–32; 3 e 4 aprono la pagina che li contiene
      ctl.setLayer(ctl.prefs.stripsPerPage == 16 && k == 1 ? Layer.ch17 : Layer.values[k]);
    case ShortcutAction.layer8:
      ctl.setPage(AppPage.dca); // i DCA hanno la loro pagina (fader e assegnazioni)
    case ShortcutAction.layer9:
      ctl.setLayer(Layer.band);
    case ShortcutAction.pageMixer:
      ctl.setPage(AppPage.mixer);
    case ShortcutAction.pageDca:
      ctl.setPage(AppPage.dca);
    case ShortcutAction.pageFx:
      ctl.setPage(AppPage.effects);
    case ShortcutAction.pageRouting:
      ctl.setPage(AppPage.routing);
    case ShortcutAction.pageScenes:
      ctl.setPage(AppPage.scenes);
    case ShortcutAction.prevStrip:
    case ShortcutAction.nextStrip:
      final strips = ctl.stripsFor(ctl.layer);
      if (strips.isEmpty) break;
      final i = strips.indexOf(ctl.selected);
      final d = action == ShortcutAction.nextStrip ? 1 : -1;
      ctl.select(strips[i < 0 ? 0 : (i + d).clamp(0, strips.length - 1)]);
    case ShortcutAction.faderUp:
    case ShortcutAction.faderDown:
      final p = ctl.faderPath(ctl.selected);
      final cur = ctl.idx(p);
      if (cur != null) ctl.setIdx(p, cur + (action == ShortcutAction.faderUp ? step : -step));
    case ShortcutAction.mute:
      ctl.toggle(ctl.mutePath(ctl.selected));
    case ShortcutAction.solo:
      ctl.toggleSolo(ctl.selected);
  }
  return KeyEventResult.handled;
}
