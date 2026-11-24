import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../controller/app_controller.dart';
import '../theme.dart';
import 'eq_graph.dart';
import 'processors.dart';
import 'icons/strip_icons.dart';
import 'dialogs/icon_picker.dart';
import 'widgets/controls.dart';
import '../design/components.dart';
import '../l10n/l10n.dart';

/// Pannello laterale della strip selezionata, a schede (vedi [PanelTab]).
/// I controlli mostrati dipendono dal tipo di strip (doc 19 par. 1).
/// Schede del pannello, nell'ordine delle pagine del canale della X32
/// (HOME/CONFIG → Canale, GATE, DYN, EQ, MIX → Mandate).
abstract final class PanelTab {
  static const channel = 0, gate = 1, comp = 2, eq = 3, sends = 4;
  static final labels = [tr('Canale'), 'Gate', 'Comp', 'EQ', tr('Mandate')];

  /// Schede disponibili per un tipo di strip: quelle senza parametri non compaiono.
  static List<int> available(StripRef s) => [
        channel,
        if (s.hasGate) gate,
        if (s.hasDyn) comp,
        if (s.eqBands > 0) eq,
        if (s.sendCount > 0) sends,
      ];
}

class SidePanel extends StatefulWidget {
  const SidePanel({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  int _band = 1;

  @override
  void initState() {
    super.initState();
    widget.ctl.panelTab.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    widget.ctl.panelTab.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final s = ctl.selected;
    final tabs = PanelTab.available(s);
    // la scheda scelta resta quella dell'utente; se la strip non la possiede si mostra "Canale"
    final tab = tabs.contains(ctl.panelTab.value) ? ctl.panelTab.value : PanelTab.channel;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: Rd.brL),
      child: Column(children: [
        _PanelHeader(ctl: ctl, strip: s),
        Container(
          height: MxDensity.s(36),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            for (final t in tabs)
              Expanded(
                child: InkWell(
                  onTap: () => ctl.panelTab.value = t,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t == tab ? AppColors.accent : Colors.transparent, width: 2))),
                    child: _TabLabel(ctl: ctl, strip: s, tab: t, active: t == tab),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: switch (tab) {
            PanelTab.gate => DynEditor(ctl: ctl, strip: s, gate: true, key: ValueKey('gate${s.base}')),
            PanelTab.comp => DynEditor(ctl: ctl, strip: s, gate: false, key: ValueKey('dyn${s.base}')),
            PanelTab.eq => _EqTab(ctl: ctl, strip: s, band: _band.clamp(1, s.eqBands), onBand: (b) => setState(() => _band = b), key: ValueKey('eq${s.base}')),
            PanelTab.sends => _SendsTab(ctl: ctl, strip: s, key: ValueKey('snd${s.base}')),
            _ => _ChannelTab(ctl: ctl, strip: s, key: ValueKey('ch${s.base}')),
          },
        ),
      ]),
    );
  }
}

/// Etichetta della scheda con il LED di stato del processore (verde se attivo).
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.ctl, required this.strip, required this.tab, required this.active});
  final AppController ctl;
  final StripRef strip;
  final int tab;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final onPath = switch (tab) {
      PanelTab.gate => '${strip.base}/gate/on',
      PanelTab.comp => '${strip.base}/dyn/on',
      PanelTab.eq => '${strip.base}/eq/on',
      _ => null,
    };
    final text = Text(PanelTab.labels[tab],
        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.text : AppColors.textDim));
    if (onPath == null) return text;
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(onPath),
      builder: (context, v, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: v == 1 ? AppColors.ok : AppColors.surface3)),
        const SizedBox(width: 5),
        Flexible(child: text),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: AppColors.textDim)));
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.ctl, required this.strip});
  final AppController ctl;
  final StripRef strip;

  @override
  Widget build(BuildContext context) {
    final colorPath = '${strip.base}/config/color';
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(colorPath),
      builder: (context, ci, _) {
        final color = AppColors.stripColorFor(strip.base, ci as int?);
        return Container(
          padding: const EdgeInsets.fromLTRB(Sp.m, Sp.m, Sp.m, Sp.s),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.22), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Rd.l)),
            border: Border(top: BorderSide(color: color, width: 3)),
          ),
          child: Row(children: [
            // icona del mixer: clic per il selettore
            InkWell(
              onTap: () => showDialog<void>(context: context, builder: (_) => IconPickerDialog(ctl: ctl, strip: strip)),
              borderRadius: Rd.brM,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.header(color), borderRadius: Rd.brM, border: Border.all(color: color.withValues(alpha: 0.6))),
                child: Center(
                  child: ValueListenableBuilder<Object?>(
                    valueListenable: ctl.hub.listen('${strip.base}/config/icon'),
                    builder: (context, icon, _) => StripIconView(icon as int?, size: 28, color: Colors.white, tooltip: true),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(strip.label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
                ValueListenableBuilder<Object?>(
                  valueListenable: ctl.hub.listen('${strip.base}/config/name'),
                  builder: (context, name, _) => _NameField(ctl: ctl, strip: strip, name: (name as String?) ?? ''),
                ),
                const SizedBox(height: 6),
                // colori del mixer (/config/color): l'elenco completo e i colori locali sono in Personalizzazione
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (var i = 0; i < 8; i++)
                    MxSwatch(color: AppColors.strip[i], size: 16, selected: ci == i && !MxTheme.overrides.containsKey(strip.base), onTap: () => ctl.setIdx(colorPath, i)),
                ]),
              ]),
            ),
            // stellina: aggiunge o toglie la strip dal layer Utente (solo sul PC)
            _UserLayerStar(ctl: ctl, strip: strip),
          ]),
        );
      },
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.ctl, required this.strip, required this.name});
  final AppController ctl;
  final StripRef strip;
  final String name;
  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c = TextEditingController(text: widget.name);
  final _f = FocusNode();

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (!_f.hasFocus && _c.text != widget.name) _c.text = widget.name;
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _f,
      maxLength: 12,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      decoration: InputDecoration(isDense: true, filled: false, contentPadding: EdgeInsets.zero, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, counterText: '', hintText: widget.strip.label),
      onSubmitted: (v) => widget.ctl.setString('${widget.strip.base}/config/name', v.replaceAll(RegExp(r'[^\x20-\x7E]'), '').replaceAll('"', '')),
    );
  }
}

// ================================================================ CANALE

class _Section extends StatefulWidget {
  // ignore: unused_element_parameter
  const _Section({required this.title, required this.children, this.onPath, this.ctl, this.advanced = const [], this.collapsed = false});
  final String title;
  final List<Widget> children;
  final String? onPath;
  final AppController? ctl;

  /// Parametri secondari, mostrati con "Altri parametri".
  final List<Widget> advanced;

  /// Sezione chiusa per impostazione predefinita (solo titolo).
  final bool collapsed;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _open = !widget.collapsed;
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.s),
      padding: const EdgeInsets.fromLTRB(Sp.m, Sp.s, Sp.m, Sp.m),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: w.collapsed ? () => setState(() => _open = !_open) : null,
          child: Row(children: [
            Text(w.title.toUpperCase(), style: Tx.section),
            if (w.collapsed) Icon(_open ? Icons.expand_less : Icons.expand_more, size: 16, color: AppColors.textFaint),
            const Spacer(),
            if (w.onPath != null && w.ctl != null) _OnBadge(ctl: w.ctl!, path: w.onPath!),
          ]),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          Wrap(spacing: Sp.s, runSpacing: Sp.m, crossAxisAlignment: WrapCrossAlignment.end, children: w.children),
          if (w.advanced.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _advanced = !_advanced),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_advanced ? Icons.expand_less : Icons.expand_more, size: 15, color: AppColors.textFaint),
                  Text(_advanced ? tr('Meno parametri') : tr('Altri parametri'), style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
                ]),
              ),
            ),
            if (_advanced) Wrap(spacing: Sp.s, runSpacing: Sp.m, crossAxisAlignment: WrapCrossAlignment.end, children: w.advanced),
          ],
        ],
      ]),
    );
  }
}

/// Badge ON/OFF in alto a destra delle sezioni (verde pieno quando attivo, come nel riferimento).
/// Badge ON/OFF in alto a destra delle sezioni.
class _OnBadge extends StatelessWidget {
  const _OnBadge({required this.ctl, required this.path});
  final AppController ctl;
  final String path;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Object?>(
        valueListenable: ctl.hub.listen(path),
        builder: (context, v, _) => MxStateBadge(on: v == 1, onTap: () => ctl.toggle(path)),
      );
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Tx.label),
        const SizedBox(height: Sp.xs),
        child,
      ]);
}

/// Headamp collegato a un canale tramite il routing (doc 19 par. 2.2):
/// `((source−1) & 7) + 8 · indice(/config/routing/IN/<blocco>)` per sorgenti 1–32 e blocchi AN/A/B.
int? headampFor(AppController ctl, StripRef s) {
  if (s.kind != StripKind.ch) return null;
  final src = ctl.idx('${s.base}/config/source');
  if (src == null || src < 1 || src > 32) return null;
  final block = ['1-8', '9-16', '17-24', '25-32'][(src - 1) >> 3];
  final e = ctl.idx('/config/routing/IN/$block');
  if (e == null || e > 15) return null; // CARD e UIN non hanno preamplificatore
  return ((src - 1) & 7) + 8 * e;
}

/// Scheda Canale: tutto ciò che riguarda il canale e il suo ingresso (pagine HOME e CONFIG
/// della X32) e l'uscita verso il main (pagina MAIN). Ogni sezione compare solo se la strip
/// possiede quei parametri.
class _ChannelTab extends StatelessWidget {
  const _ChannelTab({super.key, required this.ctl, required this.strip});
  final AppController ctl;
  final StripRef strip;

  @override
  Widget build(BuildContext context) {
    final b = strip.base;
    return ListenableBuilder(
      listenable: Listenable.merge([
        if (strip.hasSource) ctl.hub.listen('$b/config/source'),
        for (final k in ['1-8', '9-16', '17-24', '25-32']) ctl.hub.listen('/config/routing/IN/$k'),
      ]),
      builder: (context, _) {
        final ha = headampFor(ctl, strip);
        final haPath = ha == null ? null : '/headamp/${ha.toString().padLeft(3, '0')}';
        final linked = ctl.isLinked(strip);
        return ListView(padding: const EdgeInsets.all(Sp.s), children: [
          // ------------------------------------------------------------ ingresso
          if (strip.hasSource || strip.hasTrim || strip.hasInvert)
            _Section(title: tr('Ingresso'), children: [
              if (haPath != null) ...[
                Knob(ctl: ctl, path: '$haPath/gain', label: tr('Gain'), defaultIdx: 24, size: 42, compact: true),
                Padding(padding: const EdgeInsets.only(bottom: 18), child: ParamToggle(ctl: ctl, path: '$haPath/phantom', label: '48V', activeColor: AppColors.mute, width: 44, height: 26)),
              ] else if (strip.kind == StripKind.ch)
                SizedBox(width: 130, child: Text(tr('Nessun preamplificatore: la sorgente non è un ingresso analogico o AES50.'), style: Tx.caption)),
              if (strip.hasTrim) Knob(ctl: ctl, path: '$b/preamp/trim', label: tr('Trim'), defaultIdx: 72, bipolar: true, size: 42, compact: true),
              if (strip.hasInvert)
                Padding(padding: const EdgeInsets.only(bottom: 18), child: Tooltip(message: tr('Inversione di fase'), child: ParamToggle(ctl: ctl, path: '$b/preamp/invert', label: 'Ø', width: 36, height: 26))),
              if (strip.hasSource) _Labeled(tr('Sorgente'), ParamDropdown(ctl: ctl, path: '$b/config/source', width: 76)),
            ]),
          // ----------------------------------------------------- filtro passa-alto
          if (strip.hasHpf)
            _Section(title: tr('Filtro passa-alto'), onPath: '$b/preamp/hpon', ctl: ctl, children: [
              Knob(ctl: ctl, path: '$b/preamp/hpf', label: tr('Frequenza'), defaultIdx: 0, size: 42, compact: true),
              _Labeled(tr('Pendenza'), ParamDropdown(ctl: ctl, path: '$b/preamp/hpslope', width: 70)),
            ]),
          // ---------------------------------------------------------------- delay
          if (strip.hasDelay)
            _Section(title: tr('Delay del canale'), onPath: '$b/delay/on', ctl: ctl, children: [
              Knob(ctl: ctl, path: '$b/delay/time', label: tr('Tempo'), defaultIdx: 0, size: 42),
              SizedBox(width: 150, child: Text(tr('Ritardo d\'ingresso per allineare microfoni e sorgenti (ms).'), style: Tx.caption)),
            ]),
          // ------------------------------------------------------- uscita al main
          if (strip.hasPanAndAssign || strip.hasBalance)
            _Section(title: strip.hasBalance ? tr('Bilanciamento') : tr('Uscita verso il main'), children: [
              _PanControl(ctl: ctl, strip: strip, balance: strip.hasBalance || linked),
              if (strip.hasPanAndAssign) ...[
                _Labeled(tr('Main LR'), ParamToggle(ctl: ctl, path: '$b/mix/st', label: 'LR', width: 52)),
                _Labeled('Mono/C', ParamToggle(ctl: ctl, path: '$b/mix/mono', label: 'M/C', width: 52)),
                Knob(ctl: ctl, path: '$b/mix/mlevel', label: tr('Livello M/C'), size: 42),
              ],
            ]),
          // --------------------------------------------------------------- insert
          if (strip.hasInsert)
            _Section(title: tr('Insert'), onPath: '$b/insert/on', ctl: ctl, children: [
              _Labeled(tr('Posizione'), ParamDropdown(ctl: ctl, path: '$b/insert/pos', width: 76)),
              _Labeled(tr('Effetto'), ParamDropdown(ctl: ctl, path: '$b/insert/sel', width: 90)),
            ]),
          // -------------------------------------------------------------- automix
          if (strip.hasAutomix)
            _Section(title: tr('Automix'), children: [
              _Labeled(tr('Gruppo'), ParamDropdown(ctl: ctl, path: '$b/automix/group', width: 70)),
              Knob(ctl: ctl, path: '$b/automix/weight', label: tr('Peso'), defaultIdx: 24, bipolar: true, size: 42),
            ]),
          // --------------------------------------------------------------- gruppi
          if (strip.hasGroups)
            _Section(title: tr('DCA e mute group'), children: [
              _BitButtons(ctl: ctl, path: '$b/grp/dca', count: 8, prefix: 'DCA'),
              _BitButtons(ctl: ctl, path: '$b/grp/mute', count: 6, prefix: 'MG'),
            ]),
        ]);
      },
    );
  }
}

/// Pan (o bilanciamento): manopola bipolare con tacca centrale, valore L/C/R e pulsante Centro.
class _PanControl extends StatelessWidget {
  const _PanControl({required this.ctl, required this.strip, required this.balance});
  final AppController ctl;
  final StripRef strip;
  final bool balance;

  @override
  Widget build(BuildContext context) {
    final path = '${strip.base}/mix/pan';
    final spec = ctl.state.specOf(path);
    if (spec == null) return const SizedBox.shrink();
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(path),
      builder: (context, _, _) {
        final v = ctl.state.getPhysical(path) ?? 0;
        return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Tooltip(
            message: tr('Stesso parametro della barra {p0} sulla strip ({p1}/mix/pan): i due controlli si muovono insieme.', {'p0': balance ? 'BAL' : 'PAN', 'p1': strip.base}),
            child: Knob(ctl: ctl, path: path, label: balance ? tr('Bilanciamento') : 'Pan', defaultIdx: spec.idxFromPhysical(0), bipolar: true, size: 46, valueText: panText),
          ),
          const SizedBox(width: Sp.xs),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PillButton(label: tr('Centro'), active: v.round() == 0, activeColor: AppColors.surface3, width: 52, height: 22, onTap: () => ctl.setIdx(path, spec.idxFromPhysical(0))),
            ]),
          ),
        ]);
      },
    );
  }
}

/// Pulsanti per un parametro bitmask (assegnazione DCA e mute group).
class _BitButtons extends StatelessWidget {
  const _BitButtons({required this.ctl, required this.path, required this.count, required this.prefix});
  final AppController ctl;
  final String path;
  final int count;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(path),
      builder: (context, v, _) {
        final mask = v as int? ?? 0;
        return Wrap(spacing: 4, runSpacing: 4, children: [
          for (var i = 0; i < count; i++)
            PillButton(
              label: '$prefix${i + 1}',
              active: (mask >> i) & 1 == 1,
              width: 54,
              height: 26,
              activeColor: prefix == 'DCA' ? AppColors.accent : AppColors.mute,
              onTap: () => ctl.setIdx(path, mask ^ (1 << i)),
            ),
        ]);
      },
    );
  }
}

// ==================================================================== EQ

/// Scheda EQ del pannello: grafico, scelta della banda, controlli della banda.
/// "Editor grande" apre lo stesso editor a tutta finestra.
class _EqTab extends StatelessWidget {
  const _EqTab({super.key, required this.ctl, required this.strip, required this.band, required this.onBand});
  final AppController ctl;
  final StripRef strip;
  final int band;
  final ValueChanged<int> onBand;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(Sp.s), children: [
      ProcessorHeader(
        ctl: ctl,
        onPath: '${strip.base}/eq/on',
        title: tr('Equalizzatore · {p0} bande', {'p0': strip.eqBands}),
        onBig: () => showDialog<void>(context: context, builder: (_) => EqEditorDialog(ctl: ctl, strip: strip, band: band)),
      ),
      const SizedBox(height: Sp.s),
      SizedBox(height: 200, child: EqGraph(ctl: ctl, strip: strip, selectedBand: band, onSelectBand: onBand)),
      const SizedBox(height: Sp.s),
      EqBandControls(ctl: ctl, strip: strip, band: band, onBand: onBand, compact: true),
    ]);
  }
}

/// Scelta della banda (pulsanti nel colore della banda) e controlli tipo, frequenza, gain, Q.
class EqBandControls extends StatelessWidget {
  const EqBandControls({super.key, required this.ctl, required this.strip, required this.band, required this.onBand, this.compact = false});
  final AppController ctl;
  final StripRef strip;
  final int band;
  final ValueChanged<int> onBand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = '${strip.base}/eq/$band';
    final color = AppColors.series[(band - 1) % AppColors.series.length];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var i = 1; i <= strip.eqBands; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: PillButton(label: compact ? '$i' : tr('Banda {p0}', {'p0': i}), active: i == band, activeColor: AppColors.series[(i - 1) % AppColors.series.length], onTap: () => onBand(i), height: 26),
            ),
          ),
      ]),
      const SizedBox(height: Sp.s),
      Container(
        padding: const EdgeInsets.all(Sp.m),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brM, border: Border(left: BorderSide(color: color, width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr('BANDA {p0}', {'p0': band}), style: Tx.section.copyWith(color: color)),
            const Spacer(),
            ParamDropdown(ctl: ctl, path: '$p/type', width: 96),
          ]),
          const SizedBox(height: Sp.s),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Knob(ctl: ctl, path: '$p/f', label: tr('Frequenza'), color: color, size: compact ? 40 : 52),
            Knob(ctl: ctl, path: '$p/g', label: tr('Gain'), defaultIdx: 60, bipolar: true, color: color, size: compact ? 40 : 52),
            Knob(ctl: ctl, path: '$p/q', label: 'Q', color: color, size: compact ? 40 : 52),
          ]),
        ]),
      ),
      const SizedBox(height: Sp.xs),
      Text(tr('Curva indicativa (filtri standard), non il DSP del mixer. Il mixer non ha un interruttore per singola banda: si usa EQ ON per tutto l\'EQ.'),
          style: Tx.caption),
    ]);
  }
}

/// Editor EQ a tutta finestra: grafico grande e controlli della banda.
class EqEditorDialog extends StatefulWidget {
  const EqEditorDialog({super.key, required this.ctl, required this.strip, required this.band});
  final AppController ctl;
  final StripRef strip;
  final int band;
  @override
  State<EqEditorDialog> createState() => _EqEditorDialogState();
}

class _EqEditorDialogState extends State<EqEditorDialog> {
  late int _band = widget.band;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final s = widget.strip;
    return Dialog(
      insetPadding: const EdgeInsets.all(Sp.xl),
      child: Padding(
        padding: const EdgeInsets.all(Sp.l),
        child: Column(children: [
          MxPageHeader(
            title: 'EQ · ${ctl.stripName(s)}',
            subtitle: tr('Trascina i punti nel grafico (frequenza e gain) o usa le manopole. Doppio clic su una manopola: valore predefinito.'),
            actions: [
              ParamToggle(ctl: ctl, path: '${s.base}/eq/on', label: 'EQ ON', width: 70, height: Sz.controlL),
              MxIconButton(icon: Icons.close, tooltip: tr('Chiudi'), onTap: () => Navigator.pop(context)),
            ],
          ),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: EqGraph(ctl: ctl, strip: s, selectedBand: _band, onSelectBand: (b) => setState(() => _band = b))),
              const SizedBox(width: Sp.l),
              SizedBox(
                width: 300,
                child: SingleChildScrollView(child: EqBandControls(ctl: ctl, strip: s, band: _band, onBand: (b) => setState(() => _band = b))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// =============================================================== MANDATE

class _SendsTab extends StatelessWidget {
  const _SendsTab({super.key, required this.ctl, required this.strip});
  final AppController ctl;
  final StripRef strip;

  @override
  Widget build(BuildContext context) {
    final b = strip.base;
    final n = strip.sendCount;
    final dest = strip.kind == StripKind.bus || strip.kind == StripKind.mainSt || strip.kind == StripKind.mainM ? 'Matrix' : 'Bus';
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (n == 0) _Empty(tr('Questa strip non ha mandate.')),
      for (var i = 1; i <= n; i++) _SendRow(ctl: ctl, base: '$b/mix/${i.toString().padLeft(2, '0')}', label: '$dest $i', odd: i.isOdd),
    ]);
  }
}

class _SendRow extends StatelessWidget {
  const _SendRow({required this.ctl, required this.base, required this.label, required this.odd});
  final AppController ctl;
  final String base;
  final String label;
  final bool odd;

  @override
  Widget build(BuildContext context) {
    final spec = ctl.state.specOf('$base/level');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        SizedBox(width: 62, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ParamToggle(ctl: ctl, path: '$base/on', label: 'ON', width: 40, height: 24),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<Object?>(
            valueListenable: ctl.hub.listen('$base/level'),
            builder: (context, v, _) => Row(children: [
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(trackHeight: 4, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7), overlayShape: RoundSliderOverlayShape(overlayRadius: 12)),
                  child: Slider(
                    value: spec!.fraction(v as int? ?? 0),
                    activeColor: AppColors.accent,
                    inactiveColor: AppColors.surface3,
                    onChanged: (f) => ctl.setIdx('$base/level', spec.idxFromFraction(f)),
                  ),
                ),
              ),
              SizedBox(width: 46, child: Text(spec.display(v ?? 0), textAlign: TextAlign.right, style: mono.copyWith(fontSize: 11))),
            ]),
          ),
        ),
        if (odd) ...[
          const SizedBox(width: 8),
          ParamDropdown(ctl: ctl, path: '$base/type', width: 74),
        ] else
          const SizedBox(width: 82),
      ]),
    );
  }
}

/// Stellina del layer Utente: piena se la strip è nel layer. Il layer è salvato solo sul PC.
class _UserLayerStar extends StatelessWidget {
  const _UserLayerStar({required this.ctl, required this.strip});
  final AppController ctl;
  final StripRef strip;

  @override
  Widget build(BuildContext context) {
    final on = ctl.inUserLayer(strip);
    return Tooltip(
      message: on ? tr('Nel layer Utente: clic per toglierla') : tr('Aggiungi al layer Utente (le tue strip preferite, salvate solo su questo PC)'),
      child: IconButton(
        icon: Icon(on ? Icons.star_rounded : Icons.star_border_rounded, color: on ? AppColors.selection : AppColors.textDim, size: 26),
        onPressed: () {
          final messenger = ScaffoldMessenger.maybeOf(context);
          final added = ctl.toggleUserLayer(strip);
          messenger
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(added ? tr('{p0} aggiunta al layer Utente', {'p0': ctl.stripName(strip)}) : tr('{p0} tolta dal layer Utente', {'p0': ctl.stripName(strip)})),
            ));
        },
      ),
    );
  }
}
