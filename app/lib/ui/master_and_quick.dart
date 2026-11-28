import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../controller/app_controller.dart';
import '../controller/prefs.dart';
import '../theme.dart';
import 'widgets/controls.dart';
import 'dialogs/color_picker.dart';
import '../design/components.dart';
import '../l10n/l10n.dart';

//// Master sempre visibile sulla destra (Main LR; selezionabile Mono/C).
/// Stessa struttura delle strip: intestazione · [meter L R | scala | fader] · valore · MUTE · SOLO.
class MasterStrip extends StatefulWidget {
  const MasterStrip({super.key, required this.ctl, required this.clock});
  final AppController ctl;
  final MeterClock clock;
  @override
  State<MasterStrip> createState() => _MasterStripState();
}

class _MasterStripState extends State<MasterStrip> {
  StripRef _target = const StripRef(StripKind.mainSt, 1);

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final t = _target;
    final path = '${t.base}/mix/fader';
    final spec = ctl.state.specOf(path);
    final selected = ctl.selected == t;
    return Container(
      width: Sz.masterWidth,
      margin: const EdgeInsets.fromLTRB(Sp.xs, Sp.s, Sp.s, Sp.s),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Rd.brM,
        border: Border.all(color: selected ? AppColors.selection : AppColors.borderStrong, width: selected ? 2 : 1),
      ),
      child: Column(children: [
        // intestazione: MASTER + scelta LR / Mono (tocco), selezione nel pannello (doppio tocco)
        GestureDetector(
          onTap: () => setState(() => _target = t.kind == StripKind.mainSt ? const StripRef(StripKind.mainM, 1) : const StripRef(StripKind.mainSt, 1)),
          onDoubleTap: () => ctl.select(t),
          child: Tooltip(
            message: tr('Tocca per passare da Main LR a Mono/C; doppio tocco per aprirlo nel pannello'),
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.m - 1)),
                border: Border(top: BorderSide(color: AppColors.text, width: 3)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(tr('MASTER'), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: AppColors.textDim)),
                const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(child: Text(t.kind == StripKind.mainSt ? tr('Main LR') : 'Mono/C', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  const Icon(Icons.swap_vert, size: 13, color: AppColors.textFaint),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, Sp.xs, 4, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Posizione del Main nei banchi meter non ancora verificata (T04): meter spenti.
              Padding(
                padding: EdgeInsets.only(top: Fader.inset - 6, bottom: Fader.inset),
                child: Row(children: [
                  LevelMeter(read: () => -127, clock: widget.clock, width: 5, available: false),
                  const SizedBox(width: 2),
                  LevelMeter(read: () => -127, clock: widget.clock, width: 5, available: false),
                ]),
              ),
              SizedBox(width: 26, child: spec == null ? null : FaderScale(spec: spec, large: true)),
              Expanded(child: Fader(ctl: ctl, path: path, accent: AppColors.text)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(5, Sp.xs, 5, 0),
          child: ValueListenableBuilder<Object?>(
            valueListenable: ctl.hub.listen(path),
            builder: (context, v, _) => MxValueBox(spec == null ? '—' : spec.display(v as int? ?? 0), width: double.infinity),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(5, Sp.s, 5, 0),
          child: ParamToggle(ctl: ctl, path: '${t.base}/mix/on', label: tr('MUTE'), invert: true, activeColor: AppColors.mute, width: double.infinity, height: 26),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(5, Sp.xs, 5, 6),
          child: ValueListenableBuilder<int>(
            valueListenable: ctl.soloTick,
            builder: (context, _, _) => PillButton(
              label: tr('SOLO'),
              active: ctl.soloOf(t),
              activeColor: AppColors.solo,
              width: double.infinity,
              height: 26,
              enabled: ctl.isOnline,
              onTap: () => ctl.toggleSolo(t),
            ),
          ),
        ),
      ]),
    );
  }
}

// ========================================================= BARRA RAPIDA

/// Apre l'editor e aggiunge un controllo alla barra rapida (usato anche dalla modalità "Assegna").
Future<void> addQuickControl(BuildContext context, AppController ctl) async {
  final q = await showDialog<QuickControl>(
    context: context,
    builder: (_) => QuickEditor(ctl: ctl),
  );
  if (q != null) {
    ctl.prefs.quick.add(q);
    ctl.prefs.save();
    ctl.refresh();
  }
}

/// Nome leggibile di un parametro (strip + funzione), per la barra rapida e il suo editor.
String describeParam(AppController ctl, String path) {
  final dca = RegExp(r'^/dca/(\d)/(fader|on)$').firstMatch(path);
  if (dca != null) return tr('DCA {p0} · {p1}', {'p0': dca[1], 'p1': dca[2] == 'on' ? 'Mute' : 'Fader'});
  final m = RegExp(r'^/(ch|auxin|fxrtn|bus|mtx)/(\d\d)/(.+)$').firstMatch(path) ?? RegExp(r'^/(main)/(st|m)/(.+)$').firstMatch(path);
  if (m == null) return path;
  final kind = switch (m[1]) {
    'ch' => StripKind.ch,
    'auxin' => StripKind.auxin,
    'fxrtn' => StripKind.fxrtn,
    'bus' => StripKind.bus,
    'mtx' => StripKind.mtx,
    _ => m[2] == 'st' ? StripKind.mainSt : StripKind.mainM,
  };
  final strip = StripRef(kind, m[1] == 'main' ? 1 : int.parse(m[2]!));
  final leaf = m[3]!;
  final send = RegExp(r'^mix/(\d\d)/level$').firstMatch(leaf);
  final what = send != null
      ? tr('Mandata {p0} {p1}', {'p0': strip.kind == StripKind.bus || strip.kind == StripKind.mainSt || strip.kind == StripKind.mainM ? 'Mtx' : 'Bus', 'p1': int.parse(send[1]!)})
      : switch (leaf) {
          'mix/fader' => 'Fader',
          'mix/on' => 'Mute',
          'mix/pan' => 'Pan',
          'dyn/on' => tr('Compressore'),
          'gate/on' => 'Gate',
          'eq/on' => 'EQ',
          'preamp/hpon' => 'HPF',
          'insert/on' => 'Insert',
          'delay/on' => 'Delay',
          _ => leaf,
        };
  return '${ctl.stripName(strip)} · $what';
}

/// Parametri "mute": `mix/on` e `dca/N/on` valgono 0 quando il canale è muto.
bool isMutePath(String path) => path.endsWith('/mix/on') || RegExp(r'^/dca/\d/on$').hasMatch(path);

/// Barra inferiore personalizzabile: qualsiasi parametro numerico del mixer.
/// Numero di caselle e altezza si scelgono in Personalizzazione → Barra rapida.
class QuickBar extends StatelessWidget {
  const QuickBar({super.key, required this.ctl});
  final AppController ctl;

  @override
  Widget build(BuildContext context) {
    final items = ctl.prefs.quick;
    final slotsVisible = ctl.prefs.quickSlots;
    final large = ctl.prefs.quickBarLarge;
    return Container(
      height: MxDensity.s(large ? 92 : Sz.quickBar + 8),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.fromLTRB(Sp.s, Sp.s - 1, Sp.s, Sp.s - 1),
      child: Row(children: [
        _LayoutMenu(ctl: ctl),
        const SizedBox(width: Sp.s),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            // caselle visibili scelte dall'utente; con più controlli la barra scorre in orizzontale
            final slotW = c.maxWidth / slotsVisible;
            final used = items.fold<int>(0, (n, q) => n + (q.wide ? 2 : 1));
            // niente caselle vuote: dopo i controlli assegnati c'è un solo pulsante "+"
            final empty = used >= 64 ? 0 : 1;
            return ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: items.length + empty,
              onReorderItem: (a, b) {
                if (a >= items.length || b > items.length) return;
                final q = items.removeAt(a);
                items.insert(b.clamp(0, items.length), q);
                ctl.prefs.save();
                ctl.refresh();
              },
              itemBuilder: (context, i) {
                if (i >= items.length) {
                  return SizedBox(key: ValueKey('add$i'), width: items.isEmpty ? 220 : 72, child: _AddTile(onTap: () => addQuickControl(context, ctl), label: items.isEmpty ? tr('Aggiungi un controllo rapido') : tr('Aggiungi')));
                }
                final q = items[i];
                return ReorderableDragStartListener(
                  key: ValueKey('${q.path}#$i'),
                  index: i,
                  child: SizedBox(
                    width: slotW * (q.wide ? 2 : 1),
                    child: _QuickTile(
                      ctl: ctl,
                      q: q,
                      large: large,
                      onEdit: () => _edit(context, q),
                      onRemove: () {
                        items.removeAt(i);
                        ctl.prefs.save();
                        ctl.refresh();
                      },
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, QuickControl q) async {
    final r = await showDialog<QuickControl>(context: context, builder: (_) => QuickEditor(ctl: ctl, initial: q));
    if (r != null) {
      q
        ..path = r.path
        ..label = r.label
        ..color = r.color
        ..wide = r.wide;
      ctl.prefs.save();
      ctl.refresh();
    }
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, this.label = /*l10n*/ 'Assegna'});
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Tooltip(
          message: tr('Aggiungi un controllo alla barra rapida (anche: pulsante "Assegna" in alto, poi tocca una strip)'),
          child: Material(
            color: Colors.transparent,
            borderRadius: Rd.brM,
            child: InkWell(
              borderRadius: Rd.brM,
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add, size: 16, color: AppColors.textDim),
                    if (label.length > 8) ...[const SizedBox(width: 4), Flexible(child: Text(tr(label), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textDim)))],
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Motivo per cui un nome di layout non va bene (null se va bene).
String? layoutNameProblem(Prefs p, String name) {
  final n = name.trim();
  if (n.isEmpty) return tr('Scrivi un nome.');
  if (n == '+' || n == '-') return tr('Nome riservato: scegline un altro.');
  if (p.quickLayouts.containsKey(n)) return tr('Esiste già un layout con questo nome.');
  return null;
}

/// Somma i piccoli spostamenti del trascinamento: con pochi passi (enumerazioni) un pixel
/// alla volta non bastava mai a cambiare valore.
class QuickDragAccumulator {
  double _rest = 0;
  void reset() => _rest = 0;
  int update(ParamSpec spec, int idx, double dx) {
    final wanted = (spec.fraction(idx) + _rest + dx / 300).clamp(0.0, 1.0);
    final next = spec.idxFromFraction(wanted);
    _rest = wanted - spec.fraction(next);
    return next;
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.ctl, required this.q, required this.onEdit, required this.onRemove, this.large = false});
  final AppController ctl;
  final QuickControl q;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool large;

  /// Un accumulatore per controllo, che sopravvive alle ricostruzioni durante il trascinamento.
  static final _drags = Expando<QuickDragAccumulator>();
  QuickDragAccumulator get _drag => _drags[q] ??= QuickDragAccumulator();

  @override
  Widget build(BuildContext context) {
    final spec = ctl.state.specOf(q.path);
    final color = Color(q.color);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: Rd.brM,
        // bordo uniforme (obbligatorio con gli angoli arrotondati); la striscia colorata è disegnata sopra
        border: Border.all(color: AppColors.border),
      ),
      child: spec == null
          ? Center(child: Text(tr('Parametro non disponibile\n{p0}', {'p0': q.path}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.error)))
          : ValueListenableBuilder<Object?>(
              valueListenable: ctl.hub.listen(q.path),
              builder: (context, v, _) {
                final idx = v as int? ?? 0;
                final isSwitch = spec.kind == ParamKind.enumeration && spec.steps == 1;
                final mute = isMutePath(q.path);
                // stato "acceso" dell'interruttore: per i mute vale quando il canale è muto
                final on = mute ? idx == 0 : idx == 1;
                final lamp = mute ? AppColors.mute : color;
                final value = isSwitch ? (mute ? (on ? tr('MUTO') : tr('attivo')) : (on ? 'ON' : 'OFF')) : spec.display(idx);
                return GestureDetector(
                  onSecondaryTap: onEdit,
                  onLongPress: onEdit,
                  onTap: isSwitch ? () => ctl.toggle(q.path) : null,
                  onHorizontalDragStart: isSwitch ? null : (_) => _drag.reset(),
                  onHorizontalDragUpdate: isSwitch ? null : (d) => ctl.setIdx(q.path, _drag.update(spec, ctl.state.getIdx(q.path) ?? idx, d.delta.dx)),
                  child: Stack(children: [
                    if (!isSwitch)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: spec.fraction(idx),
                          child: Container(color: color.withValues(alpha: 0.28)),
                        ),
                      ),
                    if (isSwitch && on) Positioned.fill(child: Container(color: lamp.withValues(alpha: 0.2))),
                    Positioned(top: 0, left: 0, right: 0, height: 3, child: ColoredBox(color: color)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Sp.s, Sp.s, Sp.xs, Sp.s - 2),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Expanded(child: Text(q.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                          InkWell(onTap: onRemove, child: const Icon(Icons.close, size: 13, color: AppColors.textFaint)),
                        ]),
                        Row(children: [
                          if (isSwitch) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: on ? lamp : AppColors.surface3, shape: BoxShape.circle, boxShadow: on ? Shadows.glow(lamp, 0.6) : null),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(value, style: Tx.value.copyWith(fontSize: large ? 15 : 12, fontWeight: isSwitch && on ? FontWeight.w700 : FontWeight.w400, color: isSwitch && on ? lamp : AppColors.text)),
                        ]),
                      ]),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

class _LayoutMenu extends StatelessWidget {
  const _LayoutMenu({required this.ctl});
  final AppController ctl;

  @override
  Widget build(BuildContext context) {
    final p = ctl.prefs;
    return PopupMenuButton<String>(
      tooltip: tr('Layout della barra rapida'),
      color: AppColors.surface2,
      onSelected: (v) async {
        if (v == '+') {
          final name = await _askName(context);
          if (name != null) {
            final problem = layoutNameProblem(p, name);
            if (problem != null) {
              ctl.notify(problem);
            } else {
              p.quickLayouts[name.trim()] = [];
              p.activeQuickLayout = name.trim();
            }
          }
        } else if (v == '-') {
          if (p.quickLayouts.length > 1) {
            p.quickLayouts.remove(p.activeQuickLayout);
            p.activeQuickLayout = p.quickLayouts.keys.first;
          }
        } else {
          p.activeQuickLayout = v;
        }
        p.save();
        ctl.refresh();
      },
      itemBuilder: (_) => [
        for (final k in p.quickLayouts.keys) CheckedPopupMenuItem(value: k, checked: k == p.activeQuickLayout, child: Text(k)),
        const PopupMenuDivider(),
        PopupMenuItem(value: '+', child: Text(tr('Nuovo layout…'))),
        PopupMenuItem(value: '-', child: Text(tr('Elimina layout corrente'))),
      ],
      child: Container(
        width: MxDensity.s(40),
        height: double.infinity,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
        child: Tooltip(
          message: tr('Layout: {p0}', {'p0': p.activeQuickLayout}),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.dashboard_customize, size: 16, color: AppColors.accent),
            const SizedBox(height: 2),
            Text(p.activeQuickLayout, maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(fontSize: 8.5, color: AppColors.textDim)),
          ]),
        ),
      ),
    );
  }

  Future<String?> _askName(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Nome del layout')),
        content: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(d, v)),
        actions: [TextButton(onPressed: () => Navigator.pop(d, c.text), child: Text(tr('Crea')))],
      ),
    );
  }
}

/// Editor di un controllo rapido: parametro scelto per categoria o con la ricerca, nome,
/// colore (pronti o personalizzato), larghezza, anteprima.
class QuickEditor extends StatefulWidget {
  const QuickEditor({super.key, required this.ctl, this.initial});
  final AppController ctl;
  final QuickControl? initial;
  @override
  State<QuickEditor> createState() => _QuickEditorState();
}

class _QuickEditorState extends State<QuickEditor> {
  late final _path = TextEditingController(text: widget.initial?.path ?? '');
  late final _label = TextEditingController(text: widget.initial?.label ?? '');
  late int _color = widget.initial?.color ?? AppColors.strip[4].toARGB32();
  late bool _wide = widget.initial?.wide ?? false;
  int _cat = 0;
  String _filter = '';
  bool _labelEdited = false;

  static final _cats = [tr('Canale selezionato'), 'DCA', tr('Ritorni FX'), 'Bus', tr('Main e matrici'), tr('Cerca')];

  List<String> _paths() {
    final ctl = widget.ctl;
    final s = ctl.selected;
    String two(int i) => i.toString().padLeft(2, '0');
    return switch (_cat) {
      0 => [
          ctl.mutePath(s),
          ctl.faderPath(s),
          if (s.hasPanAndAssign) '${s.base}/mix/pan',
          if (s.hasHpf) '${s.base}/preamp/hpon',
          if (s.hasGate) '${s.base}/gate/on',
          if (s.hasDyn) '${s.base}/dyn/on',
          if (s.eqBands > 0) '${s.base}/eq/on',
          for (var i = 1; i <= s.sendCount; i++) '${s.base}/mix/${two(i)}/level',
        ],
      1 => [for (var d = 1; d <= 8; d++) ...['/dca/$d/fader', '/dca/$d/on']],
      2 => [for (var f = 1; f <= 8; f++) ...['/fxrtn/${two(f)}/mix/fader', '/fxrtn/${two(f)}/mix/on']],
      3 => [for (var b = 1; b <= 16; b++) ...['/bus/${two(b)}/mix/fader', '/bus/${two(b)}/mix/on']],
      4 => [
          '/main/st/mix/fader',
          '/main/st/mix/on',
          '/main/m/mix/fader',
          '/main/m/mix/on',
          for (var m = 1; m <= 6; m++) ...['/mtx/${two(m)}/mix/fader', '/mtx/${two(m)}/mix/on'],
        ],
      _ => _filter.length < 2
          ? const []
          : [
              for (final n in ctl.state.nodes)
                for (var i = 0; i < n.fields.length; i++)
                  if (n.fields[i].isNumeric && n.leafPath(i).contains(_filter)) n.leafPath(i),
            ].take(80).toList(),
    };
  }

  void _pick(String p) => setState(() {
        _path.text = p;
        if (!_labelEdited || _label.text.isEmpty) _label.text = describeParam(widget.ctl, p);
      });

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final valid = ctl.state.specOf(_path.text)?.isNumeric ?? false;
    final preview = QuickControl(path: _path.text, label: _label.text.isEmpty ? tr('Anteprima') : _label.text, color: _color, wide: _wide);
    return AlertDialog(
      title: Text(widget.initial == null ? tr('Nuovo controllo rapido') : tr('Modifica controllo rapido')),
      content: SizedBox(
        width: 720,
        height: 460,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // categorie
          SizedBox(
            width: 170,
            child: ListView(children: [
              for (var i = 0; i < _cats.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: i == _cat ? AppColors.surface3 : Colors.transparent,
                    borderRadius: Rd.brM,
                    child: InkWell(
                      borderRadius: Rd.brM,
                      onTap: () => setState(() => _cat = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.s),
                        child: Text(i == 0 ? '${_cats[i]}\n${ctl.stripName(ctl.selected)}' : _cats[i],
                            style: TextStyle(fontSize: 12.5, fontWeight: i == _cat ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const VerticalDivider(width: Sp.l),
          // parametri
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_cat == _cats.length - 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.s),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(hintText: tr('Cerca un percorso OSC (es. /ch/05/dyn)'), prefixIcon: Icon(Icons.search, size: 18)),
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ),
              Expanded(
                child: ListView(children: [
                  for (final p in _paths())
                    ListTile(
                      dense: true,
                      selected: p == _path.text,
                      selectedTileColor: AppColors.surface3,
                      shape: const RoundedRectangleBorder(borderRadius: Rd.brM),
                      title: Text(describeParam(ctl, p), style: const TextStyle(fontSize: 12.5)),
                      subtitle: Text(p, style: Tx.value.copyWith(fontSize: 10.5, color: AppColors.textFaint)),
                      onTap: () => _pick(p),
                    ),
                ]),
              ),
            ]),
          ),
          const VerticalDivider(width: Sp.l),
          // aspetto e anteprima
          SizedBox(
            width: 200,
            child: ListView(children: [
              Text(tr('NOME'), style: Tx.section),
              const SizedBox(height: Sp.xs),
              TextField(controller: _label, onChanged: (_) => setState(() => _labelEdited = true)),
              const SizedBox(height: Sp.m),
              Text(tr('COLORE'), style: Tx.section),
              const SizedBox(height: Sp.xs),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in [...AppColors.strip.skip(1), AppColors.strip[0]])
                  MxSwatch(color: c, size: 20, selected: c.toARGB32() == _color, onTap: () => setState(() => _color = c.toARGB32())),
                InkWell(
                  onTap: () async {
                    final c = await pickColor(context, initial: Color(_color), title: tr('Colore del controllo'), previewName: _label.text);
                    if (c != null) setState(() => _color = c.toARGB32());
                  },
                  child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.colorize, size: 16, color: AppColors.textDim)),
                ),
              ]),
              const SizedBox(height: Sp.m),
              Text(tr('LARGHEZZA'), style: Tx.section),
              const SizedBox(height: Sp.xs),
              MxSegmented<bool>(options: [(false, tr('1 casella')), (true, tr('2 caselle'))], value: _wide, onChanged: (v) => setState(() => _wide = v), expand: true),
              const SizedBox(height: Sp.m),
              Text(tr('ANTEPRIMA'), style: Tx.section),
              const SizedBox(height: Sp.xs),
              SizedBox(
                height: 60,
                child: valid
                    ? _QuickTile(ctl: ctl, q: preview, onEdit: () {}, onRemove: () {})
                    : Center(child: Text(tr('Scegli un parametro'), style: Tx.caption)),
              ),
              const SizedBox(height: Sp.xs),
              Text(valid ? _path.text : '', style: Tx.value.copyWith(fontSize: 10.5, color: AppColors.textFaint)),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annulla'))),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, QuickControl(path: _path.text, label: _label.text.isEmpty ? describeParam(ctl, _path.text) : _label.text, color: _color, wide: _wide)) : null,
          child: Text(tr('Salva')),
        ),
      ],
    );
  }
}
