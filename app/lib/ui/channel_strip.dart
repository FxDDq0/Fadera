import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../controller/app_controller.dart';
import '../theme.dart';
import 'master_and_quick.dart';
import 'widgets/controls.dart';
import '../design/components.dart';
import 'icons/strip_icons.dart';
import '../l10n/l10n.dart';

/// Colore delle intestazioni (tonalità scurita del colore della strip, secondo il tema).
Color headerColor(Color c) => AppColors.header(c);

/// Strip del mixer. Aree separate, dall'alto:
/// intestazione (numero, icona, nome) · LED di segnale · [meter | scala | fader] · valore · MUTE · SOLO.
/// Meter, scala e fader sono tre colonne distinte: non si sovrappongono mai.
class ChannelStrip extends StatelessWidget {
  const ChannelStrip({super.key, required this.ctl, required this.strip, required this.clock, required this.selected, this.width = 72});
  final AppController ctl;
  final StripRef strip;
  final MeterClock clock;
  final bool selected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = strip;
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen('${s.base}/config/color'),
      builder: (context, colorIdx, _) {
        final color = AppColors.stripColorFor(s.base, colorIdx as int?);
        final inverted = AppColors.stripInverted(colorIdx);
        final narrow = width < 70;
        final wide = width >= 100;
        return GestureDetector(
          onTap: () {
            ctl.select(s);
            if (ctl.assignMode) addQuickControl(context, ctl);
          },
          // clic destro: menu della strip (layer Utente, parametri)
          onSecondaryTapDown: (d) => _stripMenu(context, ctl, s, d.globalPosition),
          // pressione lunga (touch): seleziona e apre i parametri. Niente doppio tocco qui:
          // ritarderebbe MUTE e SOLO.
          onLongPress: () {
            ctl.select(s);
            ctl.panelRequest.value++;
          },
          behavior: HitTestBehavior.translucent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: width,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: Sp.s),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface2 : AppColors.surface,
              borderRadius: Rd.brM,
              border: Border.all(color: selected ? AppColors.selection : AppColors.border, width: selected ? 2 : 1),
              boxShadow: selected ? Shadows.glow(AppColors.selection, 0.22) : null,
            ),
            child: Column(children: [
              // doppio clic sull'intestazione: apre i parametri (finestre strette)
              GestureDetector(
                onDoubleTap: () {
                  ctl.select(s);
                  ctl.panelRequest.value++;
                },
                child: _Header(ctl: ctl, strip: s, color: color, inverted: inverted, selected: selected),
              ),
              _SignalLed(ctl: ctl, strip: s, color: color, clock: clock),
              if (s.hasPanAndAssign || s.hasBalance)
                Padding(padding: const EdgeInsets.fromLTRB(5, 0, 5, Sp.xs), child: PanBar(ctl: ctl, strip: s, compact: narrow)),
              Expanded(child: _FaderArea(ctl: ctl, strip: s, clock: clock, color: color, narrow: narrow, wide: wide)),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, Sp.xs, 5, 0),
                child: _Value(ctl: ctl, strip: s),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, Sp.s, 5, 0),
                child: ParamToggle(ctl: ctl, path: ctl.mutePath(s), label: tr('MUTE'), invert: true, activeColor: AppColors.mute, width: double.infinity, height: 26),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, Sp.xs, 5, 6),
                child: ValueListenableBuilder<int>(
                  valueListenable: ctl.soloTick,
                  builder: (context, _, _) => PillButton(
                    label: tr('SOLO'),
                    active: ctl.soloOf(s),
                    activeColor: AppColors.solo,
                    width: double.infinity,
                    height: 26,
                    enabled: ctl.isOnline,
                    onTap: () => ctl.toggleSolo(s),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Menu del clic destro su una strip: aggiunta/rimozione dal layer Utente e apertura dei parametri.
Future<void> _stripMenu(BuildContext context, AppController ctl, StripRef s, Offset at) async {
  final inLayer = ctl.inUserLayer(s);
  // riferimenti presi prima del menu: dopo la modifica la strip può sparire dal layer
  final messenger = ScaffoldMessenger.maybeOf(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final v = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      PopupMenuItem(
        value: 'user',
        child: Row(children: [
          Icon(inLayer ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: AppColors.selection),
          const SizedBox(width: Sp.s),
          Flexible(child: Text(inLayer ? tr('Togli dal layer Utente') : tr('Aggiungi al layer Utente'))),
        ]),
      ),
      PopupMenuItem(
        value: 'panel',
        child: Row(children: [
          Icon(Icons.tune, size: 18, color: AppColors.textDim),
          SizedBox(width: Sp.s),
          Flexible(child: Text(tr('Apri i parametri'))),
        ]),
      ),
    ],
  );
  if (v == 'user') {
    final added = ctl.toggleUserLayer(s);
    {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(added ? tr('{p0} aggiunta al layer Utente', {'p0': ctl.stripName(s)}) : tr('{p0} tolta dal layer Utente', {'p0': ctl.stripName(s)})),
        ));
    }
  } else if (v == 'panel') {
    ctl.select(s);
    ctl.panelRequest.value++;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ctl, required this.strip, required this.color, required this.inverted, required this.selected});
  final AppController ctl;
  final StripRef strip;
  final Color color;
  final bool inverted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = inverted ? AppColors.surface2 : headerColor(color);
    final fg = inverted ? color : Colors.white;
    // l'intestazione cresce con la "Dimensione testo" di Windows (fino al 150 %)
    final k = (MediaQuery.textScalerOf(context).scale(10) / 10).clamp(1.0, 1.5);
    return Container(
      height: 50 * k,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Rd.m - 1)),
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 3),
      child: ValueListenableBuilder<Object?>(
        valueListenable: ctl.hub.listen('${strip.base}/config/name'),
        builder: (context, name, _) {
          final n = (name as String?)?.isNotEmpty == true ? name! : strip.label;
          // righe ad altezza fissa: con font o scale di sistema più grandi il testo si taglia, il layout non trabocca
          return Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            SizedBox(
              height: 11 * k,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_shortNumber(strip), style: TextStyle(fontSize: 9.5, height: 1.1, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.7), letterSpacing: 0.5)),
                if (ctl.isLinked(strip)) ...[
                  const SizedBox(width: 3),
                  Tooltip(message: tr('In coppia stereo (link)'), child: Icon(Icons.link, size: 10, color: fg.withValues(alpha: 0.85))),
                ],
              ]),
            ),
            // icona del mixer (config/icon) accanto al nome, nella stessa posizione per tutte le strip
            SizedBox(
              height: 26 * k,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ValueListenableBuilder<Object?>(
                  valueListenable: ctl.hub.listen('${strip.base}/config/icon'),
                  builder: (context, icon, _) => StripIconView(icon as int?, size: 17 * k, color: fg.withValues(alpha: 0.92), tooltip: true),
                ),
                const SizedBox(width: 4),
                Flexible(child: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700, color: fg))),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  static String _shortNumber(StripRef s) => switch (s.kind) {
        StripKind.ch => s.number.toString().padLeft(2, '0'),
        StripKind.auxin => tr('AUX {p0}', {'p0': s.number}),
        StripKind.fxrtn => 'FX ${(s.number + 1) ~/ 2}${s.number.isOdd ? 'L' : 'R'}',
        StripKind.bus => tr('BUS {p0}', {'p0': s.number}),
        StripKind.mtx => tr('MTX {p0}', {'p0': s.number}),
        StripKind.dca => tr('DCA {p0}', {'p0': s.number}),
        StripKind.mainSt => 'LR',
        StripKind.mainM => 'M/C',
      };
}

/// LED di segnale: acceso quando il meter supera −50 dBFS; spento quando la posizione nel
/// banco meter non è disponibile. Con "valore del picco" attivo mostra il picco in dBFS.
class _SignalLed extends StatefulWidget {
  const _SignalLed({required this.ctl, required this.strip, required this.color, required this.clock});
  final AppController ctl;
  final StripRef strip;
  final Color color;
  final MeterClock clock;
  @override
  State<_SignalLed> createState() => _SignalLedState();
}

class _SignalLedState extends State<_SignalLed> {
  MeterBallistics _b = MeterSettings.ballistics();

  @override
  Widget build(BuildContext context) {
    final gi = widget.strip.globalIndex;
    return SizedBox(
      height: 16,
      child: Center(
        child: ListenableBuilder(
          listenable: widget.clock,
          builder: (context, _) {
            final db = gi < 70 ? widget.ctl.meters.stripDb[gi] : -127.0;
            if (MeterSettings.peakReadout && gi < 70) {
              _b
                ..input(db)
                ..tick(widget.clock.dtMs);
              final p = _b.peak;
              return GestureDetector(
                onTap: () => _b = MeterSettings.ballistics(),
                child: Text(p <= -90 ? '−∞' : p.toStringAsFixed(1),
                    style: Tx.value.copyWith(fontSize: 10, color: _b.clip ? AppColors.meterHigh : (p > -6 ? AppColors.meterMid : AppColors.textDim))),
              );
            }
            final on = gi < 70 && db > -50;
            return Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: on ? AppColors.meterLow : AppColors.surface3,
                shape: BoxShape.circle,
                boxShadow: on ? Shadows.glow(AppColors.meterLow, 0.7) : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Meter, scala e fader in tre colonne separate.
class _FaderArea extends StatelessWidget {
  const _FaderArea({required this.ctl, required this.strip, required this.clock, required this.color, required this.narrow, this.wide = false});
  final bool wide;
  final AppController ctl;
  final StripRef strip;
  final MeterClock clock;
  final Color color;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final gi = strip.globalIndex;
    final meterAvailable = gi < 70; // banco 0: ch, aux, fxrtn, bus, mtx (mappa [EXT], da verificare in T04)
    final path = ctl.faderPath(strip);
    final spec = ctl.state.specOf(path);
    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 4 : 6, Sp.xs, narrow ? 2 : 4, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // meter: stessa altezza utile del fader (margine = metà cursore)
        Padding(
          padding: EdgeInsets.only(top: Fader.inset - 6, bottom: Fader.inset),
          child: LevelMeter(read: () => ctl.meters.stripDb[gi], clock: clock, width: narrow ? 5 : (wide ? 9 : 6), available: meterAvailable),
        ),
        SizedBox(width: narrow ? 17 : (wide ? 28 : 22), child: spec == null ? null : FaderScale(spec: spec, dense: narrow, large: wide)),
        Expanded(child: Fader(ctl: ctl, path: path, accent: color, capMax: wide ? 54 : 42)),
      ]),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.ctl, required this.strip});
  final AppController ctl;
  final StripRef strip;

  @override
  Widget build(BuildContext context) {
    final path = ctl.faderPath(strip);
    final spec = ctl.state.specOf(path);
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(path),
      builder: (context, v, _) => MxValueBox(spec == null || v == null ? '—' : spec.display(v as int), width: double.infinity),
    );
  }
}
