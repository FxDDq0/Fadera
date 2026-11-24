import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../controller/app_controller.dart';
import '../../theme.dart';
import '../channel_strip.dart';
import '../master_and_quick.dart';
import '../side_panel.dart';
import '../widgets/controls.dart';
import '../../l10n/l10n.dart';

/// Vista principale: fino a 16 strip, pannello laterale, master a destra.
class MixerPage extends StatefulWidget {
  const MixerPage({super.key, required this.ctl, required this.clock});
  final AppController ctl;
  final MeterClock clock;
  @override
  State<MixerPage> createState() => _MixerPageState();
}

class _MixerPageState extends State<MixerPage> {
  final _scroll = ScrollController();

  /// Sotto questa larghezza il pannello laterale diventa una linguetta che si apre sopra le strip,
  /// così i 16 canali restano visibili.
  static const _compactBelow = 1100.0;
  bool _panelOpen = false;

  @override
  void initState() {
    super.initState();
    widget.ctl.panelRequest.addListener(_openPanel);
  }

  void _openPanel() {
    if (mounted && !_panelOpen) setState(() => _panelOpen = true);
  }

  @override
  void dispose() {
    widget.ctl.panelRequest.removeListener(_openPanel);
    _scroll.dispose();
    super.dispose();
  }

  Widget _strips(AppController ctl) {
    final strips = ctl.stripsFor(ctl.layer);
    if (strips.isEmpty) return _EmptyLayer(ctl: ctl);
    return LayoutBuilder(builder: (context, c) {
      // 8 strip per pagina di ingressi; sotto la larghezza minima la fila scorre invece di comprimere i controlli.
      final w = ((c.maxWidth - 8) / strips.length - 4).clamp(Sz.stripMin * (MxDensity.touch ? 1.2 : 1), MxDensity.s(Sz.stripMax));
      return Scrollbar(
        controller: _scroll,
        thumbVisibility: (w + 4) * strips.length + 8 > c.maxWidth,
        child: ListView.builder(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          // strip centrate quando la fila è più corta dello spazio disponibile
          padding: EdgeInsets.symmetric(horizontal: ((c.maxWidth - (w + 4) * strips.length) / 2).clamp(4.0, double.infinity)),
          itemCount: strips.length,
          itemBuilder: (context, i) => ChannelStrip(
            key: ValueKey('${strips[i].base}#${ctl.faderTarget}'),
            ctl: ctl,
            strip: strips[i],
            clock: widget.clock,
            selected: strips[i] == ctl.selected,
            width: w,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final width = MediaQuery.sizeOf(context).width;
    final panel = Padding(padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.s, Sp.xxs, Sp.s), child: SidePanel(ctl: ctl));
    // pannello fisso se le strip restano larghe almeno quanto il minimo; altrimenti linguetta sovrapposta
    final n = ctl.stripsFor(ctl.layer).length.clamp(1, 32);
    final docked = (width - _panelWidth(context) - Sz.masterWidth - 20) / n - 4 >= Sz.stripMin * (MxDensity.touch ? 1.2 : 1);
    if (docked && width >= _compactBelow) {
      return Row(children: [
        Expanded(child: _strips(ctl)),
        SizedBox(width: _panelWidth(context), child: panel),
        MasterStrip(ctl: ctl, clock: widget.clock),
      ]);
    }
    // finestra stretta: linguetta + pannello sovrapposto
    return Row(children: [
      Expanded(
        child: Stack(children: [
          Positioned.fill(right: 26, child: _strips(ctl)),
          if (_panelOpen) ...[
            // clic fuori dal pannello: si chiude
            Positioned.fill(right: 26, child: GestureDetector(onTap: () => setState(() => _panelOpen = false), child: const ColoredBox(color: Color(0x55000000)))),
            Positioned(
              top: 0,
              bottom: 0,
              right: 26,
              width: MxDensity.s(330),
              child: DecoratedBox(decoration: const BoxDecoration(boxShadow: Shadows.panel), child: panel),
            ),
          ],
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 26,
            child: InkWell(
              onTap: () => setState(() => _panelOpen = !_panelOpen),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: Sp.s),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brM, border: Border.all(color: _panelOpen ? AppColors.selection : AppColors.border)),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_panelOpen ? Icons.expand_more : Icons.expand_less, size: 14, color: AppColors.selection),
                      const SizedBox(width: 4),
                      Text(tr('{p0} · parametri', {'p0': ctl.stripName(ctl.selected)}), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
      MasterStrip(ctl: ctl, clock: widget.clock),
    ]);
  }
}

/// Larghezza del pannello laterale: circa un quinto della finestra, fra 268 e 360 px,
/// per lasciare alle strip lo spazio dei 16 canali.
double _panelWidth(BuildContext context) => (MediaQuery.sizeOf(context).width * 0.24).clamp(320.0, 460.0);

class _EmptyLayer extends StatelessWidget {
  const _EmptyLayer({required this.ctl});
  final AppController ctl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_border_rounded, size: 40, color: AppColors.textFaint),
        const SizedBox(height: 8),
        Text(tr('Il layer utente è vuoto.'), style: TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 4),
        SizedBox(
          width: 460,
          child: Text(
              tr('Qui metti le strip che ti servono insieme durante lo spettacolo, da qualsiasi categoria (per esempio voce solista, chitarra, ritorno del riverbero, un bus monitor). '
              'È l’equivalente dei banchi "User" di X32-Edit: è salvato solo su questo PC e non cambia nulla sul mixer.'),
              textAlign: TextAlign.center,
              style: Tx.caption),
        ),
        const SizedBox(height: 4),
        Text(tr('Strip selezionata: {p0}', {'p0': ctl.stripName(ctl.selected)}), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            ctl.prefs.bandStrips.add(ctl.selected.base);
            ctl.prefs.save();
            ctl.refresh();
          },
          icon: const Icon(Icons.add),
          label: Text(tr('Aggiungi strip selezionata')),
        ),
      ]),
    );
  }
}

/// Ticker dei meter: un aggiornamento per frame, indipendente dalla rete.
class MeterTickerHost extends StatefulWidget {
  const MeterTickerHost({super.key, required this.clock, required this.child});
  final MeterClock clock;
  final Widget child;
  @override
  State<MeterTickerHost> createState() => _MeterTickerHostState();
}

class _MeterTickerHostState extends State<MeterTickerHost> with SingleTickerProviderStateMixin {
  late final Ticker _t = createTicker(widget.clock.tick)..start();
  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
