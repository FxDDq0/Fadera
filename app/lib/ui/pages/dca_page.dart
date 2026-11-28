import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
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
