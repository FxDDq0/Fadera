import 'dart:io';

import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../controller/scene_file.dart';
import '../../brand.g.dart';
import '../../controller/prefs.dart';
import '../../theme.dart';
import '../../design/components.dart';
import '../channel_strip.dart';
import '../widgets/controls.dart';
import '../../l10n/l10n.dart';

// ===================================================================== DCA

/// DCA: fader, mute e nomi dei gruppi; assegnazioni (bitmask `grp/dca` di ogni strip)
/// divise per sezione, con riepilogo dei membri di ogni gruppo.
class DcaPage extends StatefulWidget {
  const DcaPage({super.key, required this.ctl, required this.clock});
  final AppController ctl;
  final MeterClock clock;
  @override
  State<DcaPage> createState() => _DcaPageState();
}

class _DcaPageState extends State<DcaPage> {
  int _dca = 1;
  bool _onlyAssigned = false;

  static final _sections = <(String, List<StripRef>)>[
    (tr('Canali 1–16'), [for (var i = 1; i <= 16; i++) StripRef(StripKind.ch, i)]),
    (tr('Canali 17–32'), [for (var i = 17; i <= 32; i++) StripRef(StripKind.ch, i)]),
    (tr('Aux in'), [for (var i = 1; i <= 8; i++) StripRef(StripKind.auxin, i)]),
    (tr('Ritorni FX'), [for (var i = 1; i <= 8; i++) StripRef(StripKind.fxrtn, i)]),
    ('Bus', [for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i)]),
    (tr('Matrix e Main'), [for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i), const StripRef(StripKind.mainSt, 1), const StripRef(StripKind.mainM, 1)]),
  ];

  static Iterable<StripRef> get _all => _sections.expand((s) => s.$2);

  bool _member(StripRef s, int dca) => ((widget.ctl.idx('${s.base}/grp/dca') ?? 0) >> (dca - 1)) & 1 == 1;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return Padding(
      padding: const EdgeInsets.all(Sp.s),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // strip dei DCA: tocco = gruppo da modificare a destra
        for (var d = 1; d <= 8; d++)
          GestureDetector(
            onTap: () => setState(() => _dca = d),
            child: ChannelStrip(ctl: ctl, strip: StripRef(StripKind.dca, d), clock: widget.clock, selected: d == _dca, width: 80),
          ),
        const SizedBox(width: Sp.s),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([for (final s in _all) ctl.hub.listen('${s.base}/grp/dca'), ctl.hub.listen('/dca/$_dca/config/name')]),
            builder: (context, _) {
              final members = [for (final s in _all) if (_member(s, _dca)) s];
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                MxPageHeader(
                  title: tr('DCA {p0} · {p1}', {'p0': _dca, 'p1': ctl.stripName(StripRef(StripKind.dca, _dca))}),
                  subtitle: tr('{p0} {p1}. Tocca una strip per assegnarla o toglierla (parametro grp/dca della strip).', {'p0': members.length, 'p1': members.length == 1 ? tr('strip assegnata') : tr('strip assegnate')}),
                  actions: [
                    MxSegmented<bool>(options: [(false, tr('Tutte')), (true, tr('Solo assegnate'))], value: _onlyAssigned, onChanged: (v) => setState(() => _onlyAssigned = v)),
                  ],
                ),
                _Overview(ctl: ctl, selected: _dca, count: (d) => _all.where((s) => _member(s, d)).length, onSelect: (d) => setState(() => _dca = d)),
                const SizedBox(height: Sp.s),
                Expanded(
                  child: ListView(children: [
                    for (final (title, strips) in _sections)
                      if (!_onlyAssigned || strips.any((s) => _member(s, _dca)))
                        Padding(
                          padding: const EdgeInsets.only(bottom: Sp.s),
                          child: MxPanel(
                            title: title,
                            trailing: Text('${strips.where((s) => _member(s, _dca)).length}/${strips.length}', style: Tx.caption),
                            child: Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
                              for (final s in strips)
                                if (!_onlyAssigned || _member(s, _dca)) _AssignChip(ctl: ctl, strip: s, dca: _dca, on: _member(s, _dca)),
                            ]),
                          ),
                        ),
                    Text(
                      tr('Mute group: l\'assegnazione delle strip si fa dal pannello Canale (MG1–MG6). '
                      'L\'attivazione dei gruppi (/config/mute) non ha ancora indirizzi verificati e per ora non è comandabile da qui.'),
                      style: Tx.caption,
                    ),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

/// Riepilogo degli 8 DCA: numero di membri, gruppo scelto evidenziato.
class _Overview extends StatelessWidget {
  const _Overview({required this.ctl, required this.selected, required this.count, required this.onSelect});
  final AppController ctl;
  final int selected;
  final int Function(int dca) count;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var d = 1; d <= 8; d++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: d < 8 ? Sp.xs : 0),
            child: Material(
              color: d == selected ? AppColors.surface3 : AppColors.surface,
              borderRadius: Rd.brM,
              child: InkWell(
                borderRadius: Rd.brM,
                onTap: () => onSelect(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: 6),
                  decoration: BoxDecoration(borderRadius: Rd.brM, border: Border.all(color: d == selected ? AppColors.selection : AppColors.border, width: d == selected ? 2 : 1)),
                  child: Row(children: [
                    Expanded(child: Text(ctl.stripName(StripRef(StripKind.dca, d)), maxLines: 1, overflow: TextOverflow.ellipsis, style: Tx.strong.copyWith(fontSize: 12))),
                    Text('${count(d)}', style: Tx.value.copyWith(color: count(d) > 0 ? AppColors.text : AppColors.textFaint)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Strip assegnabile: striscia nel colore della strip, nome, stato.
class _AssignChip extends StatelessWidget {
  const _AssignChip({required this.ctl, required this.strip, required this.dca, required this.on});
  final AppController ctl;
  final StripRef strip;
  final int dca;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stripColorFor(strip.base, ctl.idx('${strip.base}/config/color'));
    return Material(
      color: on ? AppColors.selection.withValues(alpha: 0.18) : AppColors.surface2,
      borderRadius: Rd.brS,
      child: InkWell(
        borderRadius: Rd.brS,
        onTap: () {
          final mask = ctl.idx('${strip.base}/grp/dca') ?? 0;
          ctl.setIdx('${strip.base}/grp/dca', mask ^ (1 << (dca - 1)));
        },
        child: Container(
          width: MxDensity.s(104),
          height: MxDensity.s(32),
          decoration: BoxDecoration(borderRadius: Rd.brS, border: Border.all(color: on ? AppColors.selection : AppColors.border)),
          child: Row(children: [
            Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(Rd.s)))),
            const SizedBox(width: 6),
            Expanded(child: Text(ctl.stripName(strip), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? AppColors.text : AppColors.textDim))),
            Icon(on ? Icons.check_circle : Icons.add_circle_outline, size: 15, color: on ? AppColors.selection : AppColors.textFaint),
            const SizedBox(width: 6),
          ]),
        ),
      ),
    );
  }
}

// ================================================================= ROUTING

/// Routing: ingressi dei canali (matrice), uscite digitali, uscite analogiche e patch delle uscite,
/// in quattro schede. Bloccato finché l'utente non sblocca (protezione durante lo spettacolo).
class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  bool _unlocked = false;
  int get _tab => widget.ctl.routingTab;
  set _tab(int v) => widget.ctl.routingTab = v;

  /// Sorgenti degli ingressi raggruppate (indici in kRoutingIn).
  static List<(String, int, int)> get _inGroups => [
    (tr('Ingressi locali'), 0, 4),
    (tr('AES50 A'), 4, 6),
    (tr('AES50 B'), 10, 6),
    ('Card', 16, 4),
    (tr('User In'), 20, 4),
  ];

  void _set(String path, int idx) {
    if (!_unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Routing bloccato: premi "Sblocca" per modificarlo.'))));
      return;
    }
    widget.ctl.setIdx(path, idx);
  }

  /// Nome leggibile di un blocco di sorgenti (es. "A9-16" → "AES50 A 9–16").
  static String _blockName(String code) {
    String range(String s) => s.replaceAll('-', '–');
    for (final (p, n) in [('AN', tr('Locali')), ('CARD', 'Card'), ('UIN', tr('User In')), ('UOUT', tr('User Out')), ('OUT', tr('Uscite')), ('P16', 'P16'), ('A', tr('AES50 A')), ('B', tr('AES50 B'))]) {
      if (code.startsWith(p) && code.length > p.length && RegExp(r'^\d').hasMatch(code.substring(p.length))) return '$n ${range(code.substring(p.length))}';
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MxPageHeader(
          title: tr('Routing'),
          subtitle: _unlocked
              ? tr('Sbloccato: ogni modifica agisce subito sul mixer. Cambiare il routing durante uno spettacolo può interrompere l\'audio.')
              : tr('Bloccato: puoi consultare il routing senza rischio di modifiche. Premi "Sblocca" per cambiarlo.'),
          leading: Icon(_unlocked ? Icons.lock_open : Icons.lock_outline, color: _unlocked ? AppColors.warn : AppColors.textDim),
          actions: [
            MxSegmented<int>(
              options: [(4, tr('Panoramica')), (0, tr('Ingressi')), (1, tr('Uscite digitali')), (2, tr('Uscite analogiche')), (3, tr('Patch uscite')), (5, tr('User routing'))],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            PillButton(
              label: _unlocked ? tr('Blocca') : tr('Sblocca'),
              icon: _unlocked ? Icons.lock : Icons.lock_open,
              active: _unlocked,
              activeColor: AppColors.warn,
              onTap: () => setState(() => _unlocked = !_unlocked),
              height: Sz.controlL,
              width: 104,
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: switch (_tab) {
              0 => _inputs(ctl),
              1 => _digitalOutputs(ctl),
              2 => _analogOutputs(ctl),
              3 => _patch(ctl),
              4 => _RoutingOverview(ctl: ctl, blockName: _blockName),
              _ => _UserRouting(ctl: ctl),
            },
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- ingressi

  Widget _inputs(AppController ctl) {
    return MxPanel(
      title: tr('Ingressi dei canali'),
      subtitle: tr('Ogni riga è un blocco di 8 canali; la sorgente attiva è evidenziata. Parametri /config/routing/IN.'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // intestazione dei gruppi di sorgenti
          Row(children: [
            const SizedBox(width: 92),
            for (final (name, _, count) in _inGroups)
              Container(
                width: count * 49.0 + Sp.m,
                padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Text(name.toUpperCase(), style: Tx.section),
              ),
            SizedBox(width: 150, child: Text(tr('SORGENTE ATTIVA'), style: Tx.section)),
          ]),
          for (final block in ['1-8', '9-16', '17-24', '25-32'])
            ValueListenableBuilder<Object?>(
              valueListenable: ctl.hub.listen('/config/routing/IN/$block'),
              builder: (context, v, _) => Padding(
                padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Row(children: [
                  SizedBox(width: 92, child: Text(tr('Canali {p0}', {'p0': block.replaceAll('-', '–')}), style: Tx.strong)),
                  for (final (_, start, count) in _inGroups) ...[
                    for (var k = start; k < start + count; k++)
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Tooltip(
                          message: _blockName(kRoutingIn[k]),
                          child: _Locked(
                            unlocked: true,
                            child: PillButton(
                              label: kRoutingIn[k].replaceAll(RegExp(r'^(AN|A|B|CARD|UIN)'), ''),
                              active: v == k,
                              activeColor: AppColors.selection,
                              width: 46,
                              height: 28,
                              onTap: () => _set('/config/routing/IN/$block', k),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: Sp.m),
                  ],
                  SizedBox(
                    width: 150,
                    child: Text(v is int && v < kRoutingIn.length ? '← ${_blockName(kRoutingIn[v])}' : '—', style: Tx.body.copyWith(color: AppColors.selection, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: Sp.s),
          Row(children: [
            SizedBox(width: 92, child: Text(tr('Aux in'), style: Tx.strong)),
            _Locked(unlocked: _unlocked, child: ParamDropdown(ctl: ctl, path: '/config/routing/IN/AUX', width: 140)),
          ]),
        ]),
      ),
    );
  }

  // --------------------------------------------------------- uscite digitali

  Widget _digitalOutputs(AppController ctl) {
    final blocks = [('AES50A', tr('AES50 A'), 6), ('AES50B', tr('AES50 B'), 6), ('CARD', 'Card', 4)];
    const ranges = ['1-8', '9-16', '17-24', '25-32', '33-40', '41-48'];
    return MxPanel(
      title: tr('Uscite digitali'),
      subtitle: tr('Cosa esce su ogni blocco di 8 porte (destinazioni nelle righe, sorgenti nei menu). Parametri /config/routing/<blocco>.'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(width: 92, child: Text(tr('BLOCCO'), style: Tx.section)),
            for (final r in ranges) SizedBox(width: 128, child: Text(tr('PORTE {p0}', {'p0': r.replaceAll('-', '–')}), style: Tx.section)),
          ]),
          const SizedBox(height: Sp.xs),
          for (final (code, name, n) in blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: Row(children: [
                SizedBox(width: 92, child: Text(name, style: Tx.strong)),
                for (var i = 0; i < ranges.length; i++)
                  SizedBox(
                    width: 128,
                    child: i < n ? Align(alignment: Alignment.centerLeft, child: _Locked(unlocked: _unlocked, child: ParamDropdown(ctl: ctl, path: '/config/routing/$code/${ranges[i]}', width: 120, labels: _readable(ctl, '/config/routing/$code/${ranges[i]}')))) : null,
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  /// Etichette leggibili per i menu dei blocchi (stessi valori, nomi estesi).
  static List<String>? _readable(AppController ctl, String path) => ctl.state.specOf(path)?.labels?.map(_blockName).toList();

  // -------------------------------------------------------- uscite analogiche

  Widget _analogOutputs(AppController ctl) {
    return MxPanel(
      title: tr('Uscite analogiche e registrazione'),
      subtitle: tr('Sorgente dei blocchi di 4 uscite XLR (/config/routing/OUT) e commutatore Rec/Play.'),
      child: Wrap(spacing: Sp.l, runSpacing: Sp.m, children: [
        for (final f in ['1-4', '5-8', '9-12', '13-16']) MxLabeled(tr('Uscite {p0}', {'p0': f.replaceAll('-', '–')}), _Locked(unlocked: _unlocked, child: ParamDropdown(ctl: ctl, path: '/config/routing/OUT/$f', width: 150, labels: _readable(ctl, '/config/routing/OUT/$f')))),
        MxLabeled(tr('Rec / Play'), _Locked(unlocked: _unlocked, child: ParamDropdown(ctl: ctl, path: '/config/routing/routswitch', width: 110))),
      ]),
    );
  }

  // ------------------------------------------------------------ patch uscite

  Widget _patch(AppController ctl) {
    String two(int i) => i.toString().padLeft(2, '0');
    final groups = <(String, List<(String, String)>)>[
      (tr('Uscite XLR'), [for (var i = 1; i <= 16; i++) (tr('Out {p0}', {'p0': two(i)}), '/outputs/main/${two(i)}')]),
      (tr('Aux out'), [for (var i = 1; i <= 6; i++) (tr('Aux out {p0}', {'p0': i}), '/outputs/aux/0$i')]),
      (tr('P16 (monitor personali)'), [for (var i = 1; i <= 16; i++) ('P16 ${two(i)}', '/outputs/p16/${two(i)}')]),
      (tr('AES/EBU e registrazione'), [for (var i = 1; i <= 2; i++) (tr('AES {p0}', {'p0': i}), '/outputs/aes/0$i'), for (var i = 1; i <= 2; i++) (tr('Rec {p0}', {'p0': i}), '/outputs/rec/0$i')]),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (title, rows) in groups)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: MxPanel(
            title: title,
            subtitle: tr('Uscita · sorgente · punto di prelievo'),
            child: Wrap(spacing: Sp.s, runSpacing: Sp.xs, children: [
              for (final (label, base) in rows)
                Container(
                  width: 352,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.xs),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    SizedBox(width: 70, child: Text(label, style: Tx.strong.copyWith(fontSize: 12))),
                    const Icon(Icons.arrow_back, size: 13, color: AppColors.textFaint),
                    const SizedBox(width: Sp.xs),
                    _Locked(unlocked: _unlocked, child: ParamDropdown(ctl: ctl, path: '$base/src', width: 140, labels: kOutputSources)),
                    const SizedBox(width: Sp.xs),
                    _Locked(unlocked: _unlocked, child: ParamDropdown(ctl: ctl, path: '$base/pos', width: 90)),
                  ]),
                ),
            ]),
          ),
        ),
    ]);
  }
}

/// Panoramica del routing: tutti i collegamenti attivi in una schermata, sola lettura.
/// Colori per famiglia di sorgente: locali, AES50, card, user, bus, matrix, main, uscite dirette.
class _RoutingOverview extends StatelessWidget {
  const _RoutingOverview({required this.ctl, required this.blockName});
  final AppController ctl;
  final String Function(String) blockName;

  static Color colorFor(String label) {
    final l = label.toUpperCase();
    if (l == 'OFF' || l.isEmpty) return AppColors.textFaint;
    if (l.startsWith('LOCALI') || l.startsWith('AN')) return AppColors.series[2];
    if (l.contains('AES50')) return AppColors.series[3];
    if (l.startsWith('CARD')) return AppColors.series[1];
    if (l.startsWith('USER')) return AppColors.series[5];
    if (l.startsWith('MIXBUS') || l.startsWith('BUS')) return AppColors.strip[6];
    if (l.startsWith('MATRIX')) return AppColors.strip[5];
    if (l.startsWith('MAIN')) return AppColors.text;
    if (l.startsWith('DIROUT')) return AppColors.series[4];
    return AppColors.textDim;
  }

  String _enumLabel(String path) {
    final spec = ctl.state.specOf(path);
    final i = ctl.idx(path);
    if (spec?.labels == null || i == null) return '—';
    final raw = spec!.labels![(i - spec.minIdx).clamp(0, spec.labels!.length - 1)];
    return blockName(raw);
  }

  String _src(String base) {
    final i = ctl.idx('$base/src');
    return i == null || i < 0 || i >= kOutputSources.length ? '—' : kOutputSources[i];
  }

  Widget _chip(String dest, String src, {double width = 150}) {
    final c = colorFor(src);
    return Container(
      width: width,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: Sp.s),
      decoration: BoxDecoration(
        color: c == AppColors.textFaint ? AppColors.surface2 : c.withValues(alpha: 0.12),
        borderRadius: Rd.brS,
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Row(children: [
        SizedBox(width: 52, child: Text(dest, style: Tx.label.copyWith(fontSize: 10.5))),
        Expanded(child: Text(src, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c == AppColors.textFaint ? AppColors.textFaint : AppColors.text))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    String two(int i) => i.toString().padLeft(2, '0');
    final listen = <Listenable>[
      for (final b in ['1-8', '9-16', '17-24', '25-32', 'AUX']) ctl.hub.listen('/config/routing/IN/$b'),
      for (final blk in ['AES50A', 'AES50B']) for (final r in ['1-8', '9-16', '17-24', '25-32', '33-40', '41-48']) ctl.hub.listen('/config/routing/$blk/$r'),
      for (final r in ['1-8', '9-16', '17-24', '25-32']) ctl.hub.listen('/config/routing/CARD/$r'),
      for (final r in ['1-4', '5-8', '9-12', '13-16']) ctl.hub.listen('/config/routing/OUT/$r'),
      for (var i = 1; i <= 16; i++) ctl.hub.listen('/outputs/main/${two(i)}/src'),
      for (var i = 1; i <= 6; i++) ctl.hub.listen('/outputs/aux/0$i/src'),
      for (var i = 1; i <= 16; i++) ctl.hub.listen('/outputs/p16/${two(i)}/src'),
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listen),
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: Sp.m, runSpacing: Sp.xs, children: [
          for (final (n, c) in [(tr('Locali'), 'LOCALI'), ('AES50', 'AES50'), ('Card', 'CARD'), ('User', 'USER'), ('Bus', 'MIXBUS'), ('Matrix', 'MATRIX'), ('Main', 'MAIN'), (tr('Uscite dirette'), 'DIROUT'), (tr('Spento'), 'OFF')])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colorFor(c), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text(n, style: Tx.caption),
            ]),
        ]),
        const SizedBox(height: Sp.s),
        MxPanel(
          title: tr('Ingressi dei canali'),
          subtitle: tr('Blocco di canali ← sorgente'),
          child: Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
            for (final b in ['1-8', '9-16', '17-24', '25-32']) _chip('Ch ${b.replaceAll('-', '–')}', _enumLabel('/config/routing/IN/$b'), width: 220),
            _chip(tr('Aux in'), _enumLabel('/config/routing/IN/AUX'), width: 220),
          ]),
        ),
        const SizedBox(height: Sp.s),
        MxPanel(
          title: tr('Uscite digitali'),
          subtitle: tr('Porte ← sorgente'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (blk, name, n) in [('AES50A', tr('AES50 A'), 6), ('AES50B', tr('AES50 B'), 6), ('CARD', 'Card', 4)])
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Row(children: [
                  SizedBox(width: 70, child: Text(name, style: Tx.strong.copyWith(fontSize: 12))),
                  Expanded(
                    child: Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
                      for (final r in ['1-8', '9-16', '17-24', '25-32', '33-40', '41-48'].take(n)) _chip(r.replaceAll('-', '–'), _enumLabel('/config/routing/$blk/$r'), width: 170),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: Sp.s),
        MxPanel(
          title: tr('Uscite XLR, aux e P16'),
          subtitle: 'Uscita ← sorgente (/outputs/…/src). Blocchi analogici: ${[for (final r in ['1-4', '5-8', '9-12', '13-16']) '${r.replaceAll('-', '–')} ← ${_enumLabel('/config/routing/OUT/$r')}'].join(' · ')}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [for (var i = 1; i <= 16; i++) _chip(tr('Out {p0}', {'p0': two(i)}), _src('/outputs/main/${two(i)}'))]),
            const SizedBox(height: Sp.s),
            Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [for (var i = 1; i <= 6; i++) _chip(tr('Aux {p0}', {'p0': i}), _src('/outputs/aux/0$i'))]),
            const SizedBox(height: Sp.s),
            Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [for (var i = 1; i <= 16; i++) _chip('P16 ${two(i)}', _src('/outputs/p16/${two(i)}'))]),
          ]),
        ),
      ]),
    );
  }
}

/// User routing (`/config/userrout/in` e `/out`): sola lettura. I nomi delle sorgenti vengono da
/// [EXT] (protocollo OSC non ufficiale) e non sono ancora verificati: per questo non si modifica.
class _UserRouting extends StatelessWidget {
  const _UserRouting({required this.ctl});
  final AppController ctl;

  /// Nome della sorgente di una porta user secondo [EXT]; `out` comprende anche uscite e monitor.
  static String label(int v, {required bool out}) {
    if (v <= 0) return 'OFF';
    if (v <= 32) return tr('Locale {p0}', {'p0': v});
    if (v <= 80) return tr('AES50 A {p0}', {'p0': v - 32});
    if (v <= 128) return tr('AES50 B {p0}', {'p0': v - 80});
    if (v <= 160) return tr('Card {p0}', {'p0': v - 128});
    if (v <= 166) return tr('Aux in {p0}', {'p0': v - 160});
    if (v == 167) return tr('TB interno');
    if (v == 168) return tr('TB esterno');
    if (!out) return 'n. $v';
    if (v <= 184) return tr('Uscita {p0}', {'p0': v - 168});
    if (v <= 200) return 'P16 ${v - 184}';
    if (v <= 206) return tr('Aux {p0}', {'p0': v - 200});
    if (v == 207) return tr('Monitor L');
    if (v == 208) return tr('Monitor R');
    return 'n. $v';
  }

  @override
  Widget build(BuildContext context) {
    String two(int i) => i.toString().padLeft(2, '0');
    Widget grid(String title, String sub, String node, int count, bool out) => MxPanel(
          title: title,
          subtitle: sub,
          child: Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
            for (var i = 1; i <= count; i++)
              ValueListenableBuilder<Object?>(
                valueListenable: ctl.hub.listen('$node/${two(i)}'),
                builder: (context, v, _) {
                  final n = v as int? ?? 0;
                  final l = label(n, out: out);
                  return Tooltip(
                    message: tr('Valore {p0}', {'p0': n}),
                    child: Container(
                      width: 130,
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: Sp.s),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brS, border: Border.all(color: n == 0 ? AppColors.border : AppColors.series[5].withValues(alpha: 0.6))),
                      child: Row(children: [
                        SizedBox(width: 30, child: Text(two(i), style: Tx.value.copyWith(fontSize: 11, color: AppColors.textDim))),
                        Expanded(child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: n == 0 ? AppColors.textFaint : AppColors.text))),
                      ]),
                    ),
                  );
                },
              ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(Sp.s),
        decoration: BoxDecoration(color: AppColors.warn.withValues(alpha: 0.08), borderRadius: Rd.brM, border: Border.all(color: AppColors.warn.withValues(alpha: 0.4))),
        child: Text(tr('Sola lettura. I nomi delle sorgenti user vengono dal protocollo OSC non ufficiale e non sono ancora verificati sul mixer: '
            'per questo da Fadera non si modificano.'), style: TextStyle(fontSize: 12, color: AppColors.warn)),
      ),
      const SizedBox(height: Sp.s),
      grid(tr('User In 1–32'), tr('Sorgenti dei blocchi "User In" selezionabili negli ingressi dei canali'), '/config/userrout/in', 32, false),
      const SizedBox(height: Sp.s),
      grid(tr('User Out 1–48'), tr('Sorgenti dei blocchi "User Out" selezionabili nelle uscite digitali'), '/config/userrout/out', 48, true),
    ]);
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.unlocked, required this.child});
  final bool unlocked;
  final Widget child;
  @override
  Widget build(BuildContext context) => IgnorePointer(ignoring: !unlocked, child: Opacity(opacity: unlocked ? 1 : 0.55, child: child));
}

// =================================================================== SCENE

/// Scene, snippet e cue sul mixer (`/save`, `/load`, `/copy`, `/delete`, `/rename`, `/add`) e file locali.
class ScenesPage extends StatefulWidget {
  const ScenesPage({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<ScenesPage> createState() => _ScenesPageState();
}

class _ScenesPageState extends State<ScenesPage> {
  Future<bool> _confirm(String title, String text, {String ok = /*l10n*/ 'Conferma', bool danger = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: SizedBox(width: 420, child: Text(text)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla'))),
              FilledButton(style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.mute) : null, onPressed: () => Navigator.pop(c, true), child: Text(tr(ok))),
            ],
          ),
        ) ??
        false;
  }

  Future<(String, String)?> _askName(String title, {String name = '', String notes = ''}) {
    final n = TextEditingController(text: name), d = TextEditingController(text: notes);
    return showDialog<(String, String)>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: n, maxLength: 32, autofocus: true, decoration: InputDecoration(labelText: tr('Nome'))),
            const SizedBox(height: Sp.s),
            TextField(controller: d, maxLength: 64, decoration: InputDecoration(labelText: tr('Note'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla'))),
          FilledButton(onPressed: () => Navigator.pop(c, (n.text, d.text)), child: const Text('OK')),
        ],
      ),
    );
  }

  String _type = 'scene';
  String _filter = '';

  static final _labels = {'scene': (tr('Scene'), tr('la scena'), 100), 'snippet': ('Snippet', tr('lo snippet'), 100), 'cue': ('Cue', tr('il cue'), 500)};

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final c = ctl.client;
    final online = ctl.isOnline && c != null;
    final (title, noun, slots) = _labels[_type]!;
    final names = ctl.datasetNames[_type]!;
    final items = names.entries.where((e) => _filter.isEmpty || e.value.toLowerCase().contains(_filter.toLowerCase()) || '${e.key}'.contains(_filter)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    int firstFree() => List.generate(slots, (i) => i).firstWhere((i) => !names.containsKey(i), orElse: () => -1);
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MxPageHeader(
              title: tr('Scene, snippet e cue'),
              subtitle: online
                  ? tr('Memorie salvate nel mixer. Il richiamo cambia i parametri: viene sempre chiesta conferma e prima si salva un backup locale. '
'Le risposte del mixer a questi comandi non sono ancora verificate su hardware.')
                  : tr('Connettiti a un mixer per gestire le memorie della console. I file sul PC restano disponibili.'),
              actions: [
                MxSegmented<String>(options: [for (final t in _labels.keys) (t, _labels[t]!.$1)], value: _type, onChanged: (v) => setState(() => _type = v)),
              ],
            ),
            Expanded(
              child: MxPanel(
              expand: true,
              padding: const EdgeInsets.all(Sp.s),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // barra degli strumenti: ricerca a sinistra, operazioni generali a destra
                Row(children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(hintText: tr('Cerca in {p0}', {'p0': title}), hintStyle: Tx.caption.copyWith(fontSize: 13), prefixIcon: const Icon(Icons.search, size: 18)),
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                  const Spacer(),
                  MxButton(label: tr('Aggiorna elenco'), icon: Icons.refresh, kind: MxButtonKind.ghost, onTap: online ? () => c.requestShowDump() : null),
                  const SizedBox(width: Sp.s),
                  MxButton(
                    label: _type == 'cue' ? tr('Nuovo cue') : tr('Salva nuovo'),
                    icon: _type == 'cue' ? Icons.add : Icons.save_outlined,
                    kind: MxButtonKind.primary,
                    onTap: !online
                        ? null
                        : () async {
                            final free = firstFree();
                            if (free < 0) return;
                            if (_type == 'cue') {
                              c.cueAdd(free);
                              return;
                            }
                            final r = await _askName(tr('Salva lo stato corrente in posizione {p0}', {'p0': free}));
                            if (r != null) c.datasetSave(_type, free, r.$1, r.$2);
                          },
                  ),
                ]),
                const SizedBox(height: Sp.s),
                // intestazione della tabella
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: 6),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(children: [
                    SizedBox(width: 56, child: Text('N°', style: Tx.section)),
                    Expanded(child: Text(tr('NOME'), style: Tx.section)),
                    SizedBox(width: 250, child: Text(tr('OPERAZIONI'), style: Tx.section, textAlign: TextAlign.right)),
                  ]),
                ),
                Expanded(
                  child: items.isEmpty
                      ? MxEmpty(
                          icon: Icons.photo_library_outlined,
                          text: names.isEmpty ? tr('Nessun elemento noto.\nDopo la connessione usa "Aggiorna elenco".') : tr('Nessun risultato per "{p0}".', {'p0': _filter}),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final e = items[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.xs),
                              decoration: BoxDecoration(
                                color: i.isOdd ? AppColors.surface2.withValues(alpha: 0.5) : Colors.transparent,
                                border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                              ),
                              child: Row(children: [
                                SizedBox(width: 56, child: Text(e.key.toString().padLeft(3, '0'), style: Tx.value.copyWith(color: AppColors.selection))),
                                Expanded(child: Text(e.value.isEmpty ? tr('(senza nome)') : e.value, style: e.value.isEmpty ? Tx.caption : Tx.body)),
                                // operazione principale separata dalle secondarie
                                MxButton(
                                  label: tr('Richiama'),
                                  icon: Icons.play_arrow_rounded,
                                  height: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () async {
                                          if (await _confirm(tr('Richiamare "{p0}"?', {'p0': e.value}), tr('Il mixer applicherà {p0} {p1}: i parametri attuali verranno modificati. Prima viene salvato un backup locale.', {'p0': noun, 'p1': e.key}),
                                              ok: tr('Richiama'))) {
                                            ctl.backupLocalState('prima_di_richiamo_${_type}_${e.key}');
                                            c.datasetLoad(_type, e.key);
                                          }
                                        },
                                ),
                                const SizedBox(width: Sp.m),
                                MxIconButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: tr('Rinomina'),
                                  size: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () async {
                                          final r = await _askName(tr('Rinomina {p0}', {'p0': e.key}), name: e.value);
                                          if (r != null) c.datasetRename(_type, e.key, r.$1, r.$2);
                                        },
                                ),
                                const SizedBox(width: Sp.xs),
                                MxIconButton(
                                  icon: Icons.copy,
                                  tooltip: tr('Copia nella prima posizione libera'),
                                  size: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () {
                                          final free = firstFree();
                                          if (free >= 0) c.datasetCopy(_type, e.key, free);
                                        },
                                ),
                                const SizedBox(width: Sp.xs),
                                MxIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: tr('Elimina'),
                                  color: AppColors.mute,
                                  size: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () async {
                                          if (await _confirm(tr('Eliminare "{p0}"?', {'p0': e.value}), tr('La posizione {p0} verrà cancellata dal mixer. L\'operazione non si può annullare.', {'p0': e.key}),
                                              ok: tr('Elimina'), danger: true)) {
                                            c.datasetDelete(_type, e.key);
                                          }
                                        },
                                ),
                              ]),
                            );
                          },
                        ),
                ),
              ]),
            ),
            ),
          ]),
        ),
        const SizedBox(width: Sp.m),
        SizedBox(width: 360, child: _LocalFiles(ctl: ctl, confirm: _confirm)),
      ]),
    );
  }
}

/// File locali in formato righe di nodo (stesso formato delle scene X32, doc 13).
class _LocalFiles extends StatefulWidget {
  const _LocalFiles({required this.ctl, required this.confirm});
  final AppController ctl;
  final Future<bool> Function(String, String, {String ok, bool danger}) confirm;
  @override
  State<_LocalFiles> createState() => _LocalFilesState();
}

class _LocalFilesState extends State<_LocalFiles> {
  Directory get _dir => appSubDir('scene');

  Future<void> _onFileAction(BuildContext context, File f, String action) async {
    final ctl = widget.ctl;
    final List<String> lines;
    try {
      lines = readSceneFile(f);
    } on SceneFileException catch (e) {
      ctl.log('E', 'file di scena ${f.path}: $e');
      ctl.notify(tr('File non usato: {p0}', {'p0': e.message}));
      return;
    }
    if (action == 'load') {
      try {
        ctl.backupLocalState('prima_di_import_locale');
      } on Object catch (e) {
        ctl.notify(tr('Backup non riuscito ({p0}): file non caricato.', {'p0': e}));
        return;
      }
      // anche nel solo caricamento valgono le regole dell'invio: righe di nodi noti, mai `/-…`
      // (altrimenti una sync PC → Mixer successiva le invierebbe)
      var skipped = 0;
      for (final l in lines) {
        if (!l.trim().startsWith('/')) continue;
        if (!isSceneNodeLine(l, ctl.state) || !ctl.state.applyNodeLine(l, ChangeOrigin.load)) skipped++;
      }
      ctl.hub.refreshAll();
      if (skipped > 0) ctl.notify(tr("File caricato nell'app: {p0} righe non riconosciute ignorate.", {'p0': skipped}));
      return;
    }
    if (action != 'send' || !ctl.isOnline || !context.mounted) return;
    var source = lines;
    var partial = false;
    if (ctl.prefs.experimentalRecallScope) {
      // Funzione sperimentale: invio parziale solo con una conferma esplicita in più.
      final scope = await showDialog<RecallScope>(context: context, builder: (_) => RecallScopeDialog(ctl: ctl));
      if (scope == null || !context.mounted) return;
      final all = [for (final l in lines) if (l.trim().startsWith('/')) l.trim()];
      source = scope.filter(lines);
      partial = source.length != all.length;
      if (partial &&
          !await widget.confirm(tr('Invio PARZIALE (funzione sperimentale)'),
              tr('Verranno inviate solo {p0} righe su {p1}. Il mixer riceverà una configurazione parziale, '
'con categorie ricostruite e non verificate su hardware. Continuare solo se sai esattamente cosa resta escluso.', {'p0': source.length, 'p1': all.length}),
              ok: tr('Ho capito, continua'), danger: true)) {
        return;
      }
    }
    final plan = planSceneSend(source, ctl.state);
    if (plan.sendable.isEmpty) {
      ctl.notify(tr('Nel file non ci sono righe inviabili al mixer ({p0} scartate).', {'p0': plan.rejected.length}));
      return;
    }
    final details = [
      if (plan.rejected.isNotEmpty) tr('{p0} righe non verranno inviate (comandi, preferenze o percorsi sconosciuti).', {'p0': plan.rejected.length}),
      if (plan.phantomLines > 0) tr('ATTENZIONE: {p0} righe cambiano guadagno e alimentazione phantom (+48 V) degli ingressi.', {'p0': plan.phantomLines}),
    ];
    if (!context.mounted) return;
    final ok = await widget.confirm(
        tr('Inviare il file al mixer?'),
        tr('{p0} righe{p1} verranno applicate al mixer. '
'Prima viene salvato un backup locale. La risposta del mixer a questo invio non è ancora verificata su hardware.', {'p0': plan.sendable.length, 'p1': partial ? tr(' (invio parziale)') : ''}) +
            (details.isEmpty ? '' : '\n\n${details.join('\n')}'),
        ok: tr('Invia'),
        danger: true);
    // le finestre di conferma lasciano tempo al collegamento di cadere
    final client = ctl.client;
    if (!ok || !context.mounted) return;
    if (client == null || !ctl.isOnline) {
      ctl.notify(tr('File non inviato: il mixer non è più raggiungibile.'));
      return;
    }
    try {
      ctl.backupLocalState('prima_di_invio_file');
    } on Object catch (e) {
      ctl.notify(tr('Backup non riuscito ({p0}): invio annullato, il mixer non è stato modificato.', {'p0': e}));
      return;
    }
    final sent = await client.sendNodeLines(plan.sendable);
    final complete = sent == plan.sendable.length && ctl.isOnline;
    // lo stato locale segue solo ciò che è partito davvero
    for (final l in plan.sendable.take(sent)) {
      ctl.state.applyNodeLine(l, ChangeOrigin.load);
    }
    ctl.hub.refreshAll();
    ctl.log(complete ? 'I' : 'W', 'file ${f.path}: $sent/${plan.sendable.length} righe inviate, ${plan.rejected.length} scartate');
    ctl.notify(complete
        ? tr('File inviato: {p0} righe.', {'p0': sent})
        : tr('Invio incompleto: {p0} di {p1} righe. Il mixer è stato modificato solo in parte; il backup è nella cartella backup.', {'p0': sent, 'p1': plan.sendable.length}));
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final files = _dir.listSync().whereType<File>().where((f) => f.path.endsWith('.scn')).toList()..sort((a, b) => b.path.compareTo(a.path));
    return Container(
      padding: const EdgeInsets.all(Sp.m),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: Rd.brL, border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('FILE SUL PC'), style: Tx.section),
        const SizedBox(height: 2),
        Text(_dir.path, style: Tx.caption),
        const SizedBox(height: Sp.s),
        Text(tr('Stesso formato delle scene X32. "Carica solo nell’app" non tocca il mixer; "Invia al mixer" chiede conferma e salva prima un backup.'), style: Tx.caption),
        const SizedBox(height: Sp.s),
        FilledButton.icon(
          onPressed: () {
            final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '');
            try {
              File('${_dir.path}${Platform.pathSeparator}scena_$ts.scn')
                  .writeAsStringSync('# ${Brand.name}: esportazione dello stato locale, ${DateTime.now()}\n${ctl.state.snapshot()}\n');
            } on FileSystemException catch (e) {
              ctl.log('E', 'esportazione dello stato non riuscita: $e');
              ctl.notify(tr('Esportazione non riuscita: {p0}', {'p0': e.message}));
            }
            setState(() {});
          },
          icon: const Icon(Icons.download, size: 16),
          label: Text(tr('Esporta stato corrente')),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            for (final f in files)
              ListTile(
                dense: true,
                title: Text(f.uri.pathSegments.last, style: const TextStyle(fontSize: 12)),
                trailing: PopupMenuButton<String>(
                  onSelected: (a) => _onFileAction(context, f, a),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'load', child: Text(tr('Carica solo nell\'app'))),
                    PopupMenuItem(value: 'send', enabled: ctl.isOnline, child: Text(tr('Invia al mixer…'))),
                  ],
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Ambito di richiamo per l'invio di un file di scena: categorie e strip protette.
/// Le scelte restano salvate nelle preferenze. Non modifica le impostazioni safe del mixer.
class RecallScopeDialog extends StatefulWidget {
  const RecallScopeDialog({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<RecallScopeDialog> createState() => _RecallScopeDialogState();
}

class _RecallScopeDialogState extends State<RecallScopeDialog> {
  late final Set<String> _excluded = widget.ctl.prefs.scopeExcluded.toSet();
  late final Set<String> _safe = widget.ctl.prefs.safeStrips.toSet();

  static final _strips = <StripRef>[
    for (var i = 1; i <= 32; i++) StripRef(StripKind.ch, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.auxin, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.fxrtn, i),
    for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i),
    for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i),
    const StripRef(StripKind.mainSt, 1),
    const StripRef(StripKind.mainM, 1),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.dca, i),
  ];

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return AlertDialog(
      title: Text(tr('Ambito di richiamo (sperimentale)')),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 280,
            child: ListView(children: [
              Text(tr('Cosa inviare'), style: Theme.of(context).textTheme.titleMedium),
              for (final c in ScopeCategory.values)
                CheckboxListTile(
                  dense: true,
                  value: !_excluded.contains(c.name),
                  title: Text(c.label, style: const TextStyle(fontSize: 12)),
                  onChanged: (v) => setState(() => v == true ? _excluded.remove(c.name) : _excluded.add(c.name)),
                ),
            ]),
          ),
          const VerticalDivider(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Strip protette (non modificate)'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final s in _strips)
                      PillButton(
                        label: ctl.stripName(s),
                        active: _safe.contains(s.base),
                        activeColor: AppColors.warn,
                        width: 72,
                        height: 26,
                        onTap: () => setState(() => _safe.contains(s.base) ? _safe.remove(s.base) : _safe.add(s.base)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annulla'))),
        FilledButton(
          onPressed: () {
            ctl.prefs
              ..scopeExcluded = _excluded.toList()
              ..safeStrips = _safe.toList()
              ..save();
            Navigator.pop(
              context,
              RecallScope(enabled: {for (final c in ScopeCategory.values) if (!_excluded.contains(c.name)) c}, safeStrips: _safe),
            );
          },
          child: Text(tr('Continua')),
        ),
      ],
    );
  }
}
