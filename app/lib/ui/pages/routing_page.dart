import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../theme.dart';
import '../../design/components.dart';
import '../widgets/controls.dart';
import '../../l10n/l10n.dart';

// ===================================================================== ROUTING

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
