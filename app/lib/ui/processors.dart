import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:x32_core/x32_core.dart';

import '../controller/app_controller.dart';
import '../design/components.dart';
import '../theme.dart';
import 'widgets/controls.dart';
import '../l10n/l10n.dart';

/// Editor dei processori del canale (Gate e Compressore), nella stessa famiglia grafica dell'EQ:
/// intestazione con stato ON/OFF, modo ed "Editor grande" · grafico interattivo · griglia ordinata
/// di controlli · impostazioni · filtro della sorgente chiave.
///
/// Le curve sono calcolate con le formule standard dai parametri documentati (soglia, ratio,
/// knee, range, modo): mostrano la caratteristica statica, non il DSP del mixer. La riduzione di
/// guadagno reale arriva dal banco meter 16 (verificato su X32P FW 4.15, prove A5/A5b) ed è
/// mostrata da [GainReductionMeter] per i canali 1–32.

const kRatioValues = [1.1, 1.3, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.0, 10.0, 20.0, 100.0];

/// Caratteristica statica di gate/expander o compressore: uscita in dB per un ingresso in dB.
class DynModel {
  DynModel.gate({required this.thr, required this.range, required this.mode})
      : gate = true,
        ratio = 1,
        knee = 0,
        expander = false,
        makeup = 0;
  DynModel.comp({required this.thr, required this.ratio, required this.knee, required this.expander, required this.makeup})
      : gate = false,
        range = 0,
        mode = 0;

  final bool gate, expander;
  final double thr, ratio, knee, range, makeup;
  final int mode;

  static const modeRatios = [2.0, 3.0, 4.0];

  double out(double x) {
    if (gate) {
      switch (mode) {
        case 4: // DUCK: attenua di "range" quando la chiave supera la soglia (qui: l'ingresso stesso)
          return x >= thr ? x - range : x;
        case 3: // GATE
          return x >= thr ? x : x - range;
        default: // EXP2/3/4
          if (x >= thr) return x;
          return math.max(thr + (x - thr) * modeRatios[mode.clamp(0, 2)], x - range);
      }
    }
    double y;
    if (expander) {
      y = x >= thr ? x : thr + (x - thr) * ratio;
    } else {
      final w = knee * 2; // larghezza del ginocchio in dB (indicativa: la scala del parametro non è documentata)
      if (w > 0 && (x - thr).abs() <= w / 2) {
        final d = x - thr + w / 2;
        y = x + (1 / ratio - 1) * d * d / (2 * w);
      } else {
        y = x <= thr ? x : thr + (x - thr) / ratio;
      }
    }
    return y + makeup;
  }
}

// ================================================================ GRAFICO

/// Curva di trasferimento interattiva: ingresso (orizzontale) → uscita (verticale), −80…0 dB
/// (fino a +24 dB in uscita per il makeup). Punti trascinabili: soglia (orizzontale) e,
/// per il gate, range (verticale).
class DynGraph extends StatefulWidget {
  const DynGraph({super.key, required this.ctl, required this.base, required this.gate});
  final AppController ctl;
  final String base;
  final bool gate;
  @override
  State<DynGraph> createState() => _DynGraphState();
}

class _DynGraphState extends State<DynGraph> {
  String? _drag;
  static const lo = -80.0;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final b = widget.base;
    final fields = widget.gate ? ['on', 'mode', 'thr', 'range'] : ['on', 'mode', 'thr', 'ratio', 'knee', 'mgain'];
    return ListenableBuilder(
      listenable: Listenable.merge([for (final f in fields) ctl.hub.listen('$b/$f')]),
      builder: (context, _) {
        final on = ctl.idx('$b/on') == 1;
        final thr = ctl.state.getPhysical('$b/thr') ?? 0;
        final m = widget.gate
            ? DynModel.gate(thr: thr, range: ctl.state.getPhysical('$b/range') ?? 60, mode: ctl.idx('$b/mode') ?? 3)
            : DynModel.comp(
                thr: thr,
                ratio: kRatioValues[(ctl.idx('$b/ratio') ?? 5).clamp(0, kRatioValues.length - 1)],
                knee: ctl.state.getPhysical('$b/knee') ?? 0,
                expander: ctl.idx('$b/mode') == 1,
                makeup: ctl.state.getPhysical('$b/mgain') ?? 0,
              );
        return LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final geo = _Geo(size, widget.gate ? 0.0 : 24.0);
          final thrPt = Offset(geo.x(thr), geo.y(m.out(thr)));
          final rangePt = widget.gate ? Offset(geo.x(lo + 8), geo.y(m.out(lo + 8))) : null;
          void setThr(double dx) {
            final spec = ctl.state.specOf('$b/thr');
            if (spec != null) ctl.setIdx('$b/thr', spec.idxFromPhysical(geo.inX(dx)));
          }

          void setRange(double dy) {
            final spec = ctl.state.specOf('$b/range');
            // range = distanza fra la diagonale e il punto trascinato, all'ingresso lo+8
            final out = geo.inY(dy);
            if (spec != null) ctl.setIdx('$b/range', spec.idxFromPhysical(((lo + 8) - out).clamp(3, 60)));
          }

          return GestureDetector(
            onPanStart: (d) {
              final p = d.localPosition;
              if (rangePt != null && (p - rangePt).distance < 26) {
                _drag = 'range';
              } else {
                _drag = 'thr';
              }
              setState(() {});
            },
            onPanUpdate: (d) => _drag == 'range' ? setRange(d.localPosition.dy) : setThr(d.localPosition.dx),
            onPanEnd: (_) => setState(() => _drag = null),
            onTapDown: (d) => setThr(d.localPosition.dx),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: CustomPaint(size: size, painter: _DynPainter(m, on, geo, thrPt, rangePt, _drag, ctl.state.specOf('$b/thr'), ctl.idx('$b/thr'), widget.gate ? ctl.state.specOf('$b/range') : null, widget.gate ? ctl.idx('$b/range') : null)),
            ),
          );
        });
      },
    );
  }
}

class _Geo {
  _Geo(this.size, this.headroom);
  final Size size;
  final double headroom;
  static const l = 30.0, r = 10.0, t = 10.0, b = 22.0;
  static const lo = -80.0;
  double get w => size.width - l - r;
  double get h => size.height - t - b;
  double x(double db) => l + (db - lo) / -lo * w;
  double y(double db) => t + (1 - ((db - lo) / (-lo + headroom)).clamp(0.0, 1.0)) * h;
  double inX(double px) => (lo + (px - l) / w * -lo).clamp(lo, 0);
  double inY(double py) => lo + (1 - (py - t) / h) * (-lo + headroom);
}

class _DynPainter extends CustomPainter {
  _DynPainter(this.m, this.on, this.g, this.thrPt, this.rangePt, this.drag, this.thrSpec, this.thrIdx, this.rangeSpec, this.rangeIdx);
  final DynModel m;
  final bool on;
  final _Geo g;
  final Offset thrPt;
  final Offset? rangePt;
  final String? drag;
  final ParamSpec? thrSpec, rangeSpec;
  final int? thrIdx, rangeIdx;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Rd.m)), Paint()..color = AppColors.well);
    final grid = Paint()..color = AppColors.border.withValues(alpha: 0.6);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String s, Offset o, {Color c = AppColors.textFaint, bool right = false}) {
      tp.text = TextSpan(text: s, style: TextStyle(fontSize: 9, color: c));
      tp.layout();
      tp.paint(canvas, right ? o - Offset(tp.width, 0) : o);
    }

    for (var db = -80; db <= 0; db += 20) {
      canvas.drawLine(Offset(g.x(db.toDouble()), _Geo.t), Offset(g.x(db.toDouble()), size.height - _Geo.b), grid);
      label('$db', Offset(g.x(db.toDouble()) - 6, size.height - 15));
    }
    for (var db = -80; db <= g.headroom; db += 20) {
      canvas.drawLine(Offset(_Geo.l, g.y(db.toDouble())), Offset(size.width - _Geo.r, g.y(db.toDouble())), grid);
      label(db > 0 ? '+$db' : '$db', Offset(_Geo.l - 4, g.y(db.toDouble()) - 6), right: true);
    }
    label(tr('ingresso dB'), Offset(size.width - _Geo.r - 2, size.height - 15), right: true);
    // diagonale 1:1 (nessun intervento)
    canvas.drawLine(Offset(g.x(-80), g.y(-80)), Offset(g.x(0), g.y(0)), Paint()
      ..color = AppColors.textFaint.withValues(alpha: 0.6)
      ..strokeWidth = 1);
    // soglia
    final col = on ? AppColors.accent : AppColors.textFaint;
    final tx = g.x(m.thr);
    canvas.drawLine(Offset(tx, _Geo.t), Offset(tx, size.height - _Geo.b), Paint()
      ..color = col.withValues(alpha: 0.55)
      ..strokeWidth = 1.2);
    // zona di intervento
    final zone = m.gate
        ? (m.mode == 4 ? Rect.fromLTRB(tx, _Geo.t, size.width - _Geo.r, size.height - _Geo.b) : Rect.fromLTRB(_Geo.l, _Geo.t, tx, size.height - _Geo.b))
        : Rect.fromLTRB(m.expander ? _Geo.l : tx, _Geo.t, m.expander ? tx : size.width - _Geo.r, size.height - _Geo.b);
    canvas.drawRect(zone, Paint()..color = col.withValues(alpha: 0.06));
    // curva
    final p = Path();
    for (var i = 0; i <= 160; i++) {
      final xin = -80 + i * 0.5;
      final yy = g.y(m.out(xin));
      i == 0 ? p.moveTo(g.x(xin), yy) : p.lineTo(g.x(xin), yy);
    }
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = col);
    // punti trascinabili
    void handle(Offset o, String name, String text) {
      final active = drag == name;
      if (active) canvas.drawCircle(o, 13, Paint()..color = col.withValues(alpha: 0.25));
      canvas.drawCircle(o, active ? 8 : 6.5, Paint()..color = col);
      canvas.drawCircle(o, active ? 8 : 6.5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white);
      final right = o.dx > size.width - 120;
      tp.text = TextSpan(text: text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text));
      tp.layout();
      tp.paint(canvas, Offset(right ? o.dx - tp.width - 10 : o.dx + 10, (o.dy - 18).clamp(2, size.height - 30)));
    }

    handle(thrPt, 'thr', tr('Soglia {p0}', {'p0': thrSpec == null || thrIdx == null ? '' : thrSpec!.display(thrIdx!)}));
    if (rangePt != null) handle(rangePt!, 'range', tr('Range {p0}', {'p0': rangeSpec == null || rangeIdx == null ? '' : rangeSpec!.display(rangeIdx!)}));
    if (!on) label(tr('processore disattivato'), const Offset(_Geo.l + 6, _Geo.t + 4), c: AppColors.textDim);
  }

  @override
  bool shouldRepaint(_DynPainter o) => true;
}

/// Tempi del processore (attacco, hold, rilascio) come inviluppo su asse logaritmico.
class EnvelopeStrip extends StatelessWidget {
  const EnvelopeStrip({super.key, required this.ctl, required this.base});
  final AppController ctl;
  final String base;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([for (final f in ['attack', 'hold', 'release']) ctl.hub.listen('$base/$f')]),
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _EnvPainter(
          ctl.state.getPhysical('$base/attack') ?? 10,
          ctl.state.getPhysical('$base/hold') ?? 10,
          ctl.state.getPhysical('$base/release') ?? 100,
        ),
      ),
    );
  }
}

class _EnvPainter extends CustomPainter {
  _EnvPainter(this.a, this.h, this.r);
  final double a, h, r;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Rd.m)), Paint()..color = AppColors.well);
    // tre segmenti in proporzione logaritmica: ogni tempo resta visibile anche se piccolo
    double len(double ms) => math.log(1 + ms.clamp(0, 5000));
    final total = len(a) + len(h) + len(r);
    final w = size.width - 20;
    final xa = 10 + len(a) / total * w, xh = xa + len(h) / total * w, xr = xh + len(r) / total * w;
    final top = 14.0, bot = size.height - 16;
    final p = Path()
      ..moveTo(10, bot)
      ..lineTo(xa, top)
      ..lineTo(xh, top)
      ..quadraticBezierTo(xh + (xr - xh) * 0.25, bot - 2, xr, bot);
    canvas.drawPath(Path.from(p)..close(), Paint()..color = AppColors.accent.withValues(alpha: 0.14));
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.accent);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final (x0, x1, t) in [(10.0, xa, tr('Attacco')), (xa, xh, 'Hold'), (xh, xr, tr('Rilascio'))]) {
      tp.text = TextSpan(text: t, style: const TextStyle(fontSize: 9, color: AppColors.textFaint));
      tp.layout();
      if (x1 - x0 > tp.width + 2) tp.paint(canvas, Offset((x0 + x1) / 2 - tp.width / 2, size.height - 13));
    }
  }

  @override
  bool shouldRepaint(_EnvPainter o) => o.a != a || o.h != h || o.r != r;
}

/// Indicatore della riduzione di guadagno reale, dal banco meter 16 (verificato su X32P FW 4.15
/// per il canale 1, prove A5/A5b; gli altri canali con lo stesso ordine [EXT]).
/// Solo per i canali 1–32: per bus, matrici e main la posizione nel banco non è verificata e
/// l'indicatore resta spento e lo dice. Scala 0…−30 dB, valore numerico in basso.
class GainReductionMeter extends StatefulWidget {
  const GainReductionMeter({super.key, required this.ctl, required this.strip, required this.gate});
  final AppController ctl;
  final StripRef strip;
  final bool gate;

  static const double rangeDb = 30;

  @override
  State<GainReductionMeter> createState() => _GainReductionMeterState();
}

class _GainReductionMeterState extends State<GainReductionMeter> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  double _shown = 0; // dB ≤ 0, con rilascio visivo
  int _lastMs = 0;

  bool get _available => widget.strip.kind == StripKind.ch;

  @override
  void initState() {
    super.initState();
    if (_available) _ticker.start();
  }

  void _onTick(Duration t) {
    final ms = t.inMilliseconds;
    final dt = (ms - _lastMs).clamp(0, 100);
    _lastMs = ms;
    final hub = widget.ctl.meters;
    final live = hub.hasData(MeterBank16Map.bank);
    final i = widget.strip.number - 1;
    final target = live ? (widget.gate ? hub.gateGrDb[i] : hub.compGrDb[i]) : 0.0;
    // attacco istantaneo, rilascio visivo di 40 dB/s (il valore vero arriva a 20 Hz)
    final next = target < _shown ? target : math.min(0.0, math.min(target, _shown + 40 * dt / 1000));
    if ((next - _shown).abs() > 0.05 || (next == 0 && _shown != 0)) setState(() => _shown = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = _available && widget.ctl.meters.hasData(MeterBank16Map.bank);
    final msg = !_available
        ? tr('Riduzione di guadagno: disponibile solo per i canali 1–32. Per questa strip la posizione nel banco meter 16 non è verificata sul mixer.')
        : tr('Riduzione di guadagno {p0} letta dal mixer (banco meter 16, verificato su X32P FW 4.15). '
'{p1}', {'p0': widget.gate ? tr('del gate') : tr('del compressore'), 'p1': live ? '' : tr('Nessun dato dal mixer in questo momento.')});
    final frac = (-_shown / GainReductionMeter.rangeDb).clamp(0.0, 1.0);
    return Tooltip(
      message: msg,
      child: Container(
        width: 30,
        decoration: BoxDecoration(color: AppColors.well, borderRadius: Rd.brS, border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          Text('GR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: live ? AppColors.text : AppColors.textFaint)),
          const SizedBox(height: 3),
          Expanded(
            child: !_available
                ? Center(child: RotatedBox(quarterTurns: 3, child: Text(tr('non disponibile'), style: TextStyle(fontSize: 9, color: AppColors.textFaint))))
                : LayoutBuilder(builder: (context, c) {
                    return Stack(alignment: Alignment.topCenter, children: [
                      Container(width: 10, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(2))),
                      Container(
                        key: const ValueKey('gr-bar'),
                        width: 10,
                        height: c.maxHeight * frac,
                        decoration: BoxDecoration(color: live ? AppColors.warn : AppColors.textFaint, borderRadius: BorderRadius.circular(2)),
                      ),
                    ]);
                  }),
          ),
          const SizedBox(height: 3),
          Text(!_available || !live ? '—' : (_shown > -0.1 ? '0' : _shown.toStringAsFixed(_shown > -10 ? 1 : 0)),
              key: const ValueKey('gr-value'),
              style: TextStyle(fontSize: 9, fontFeatures: const [FontFeature.tabularFigures()], color: live ? AppColors.text : AppColors.textFaint)),
        ]),
      ),
    );
  }
}

// ================================================================ EDITOR

/// Intestazione comune dei processori: stato ON/OFF, modo, apertura dell'editor grande.
class ProcessorHeader extends StatelessWidget {
  const ProcessorHeader({super.key, required this.ctl, required this.onPath, required this.title, this.modePath, this.onBig, this.onLabel = 'ON'});
  final AppController ctl;
  final String onPath;
  final String title;
  final String? modePath;
  final VoidCallback? onBig;
  final String onLabel;

  @override
  Widget build(BuildContext context) => Row(children: [
        ParamToggle(ctl: ctl, path: onPath, label: onLabel, width: 64),
        const SizedBox(width: Sp.s),
        Expanded(child: Text(title.toUpperCase(), style: Tx.section, overflow: TextOverflow.ellipsis)),
        if (modePath != null) ...[ParamDropdown(ctl: ctl, path: modePath!, width: 84), const SizedBox(width: Sp.s)],
        if (onBig != null) MxIconButton(icon: Icons.open_in_full, tooltip: tr('Editor grande'), size: Sz.controlM, onTap: onBig),
      ]);
}

/// Griglia ordinata di controlli: celle di larghezza fissa, una o più righe.
class ControlGrid extends StatelessWidget {
  const ControlGrid({super.key, required this.children, this.cell = 72});
  final List<Widget> children;
  final double cell;
  @override
  Widget build(BuildContext context) => Wrap(
        runSpacing: Sp.m,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [for (final c in children) SizedBox(width: MxDensity.s(cell), child: Center(child: c))],
      );
}

/// Editor completo di un processore (usato nel pannello e nell'editor grande).
class DynEditor extends StatelessWidget {
  const DynEditor({super.key, required this.ctl, required this.strip, required this.gate, this.large = false});
  final AppController ctl;
  final StripRef strip;
  final bool gate;
  final bool large;

  String get base => '${strip.base}/${gate ? 'gate' : 'dyn'}';

  @override
  Widget build(BuildContext context) {
    final b = base;
    final hasKey = ctl.state.specOf('$b/keysrc') != null;
    final ks = large ? 52.0 : 42.0;
    final graph = SizedBox(
      height: large ? null : 200,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: DynGraph(ctl: ctl, base: b, gate: gate)),
        const SizedBox(width: Sp.xs),
        GainReductionMeter(ctl: ctl, strip: strip, gate: gate),
      ]),
    );
    final controls = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MxPanel(
        title: gate ? tr('Soglia e range') : tr('Soglia e rapporto'),
        color: AppColors.surface2,
        padding: const EdgeInsets.all(Sp.s),
        child: ControlGrid(children: [
          Knob(ctl: ctl, path: '$b/thr', label: tr('Soglia'), defaultIdx: gate ? 0 : 120, size: ks),
          if (gate) Knob(ctl: ctl, path: '$b/range', label: tr('Range'), size: ks),
          if (!gate) ...[
            MxLabeled(tr('Ratio'), ParamDropdown(ctl: ctl, path: '$b/ratio', width: 64)),
            Knob(ctl: ctl, path: '$b/knee', label: tr('Knee'), size: ks),
            Knob(ctl: ctl, path: '$b/mgain', label: tr('Makeup'), defaultIdx: 0, size: ks),
            Knob(ctl: ctl, path: '$b/mix', label: tr('Mix'), defaultIdx: 20, size: ks),
          ],
        ]),
      ),
      const SizedBox(height: Sp.s),
      MxPanel(
        title: tr('Tempi'),
        color: AppColors.surface2,
        padding: const EdgeInsets.all(Sp.s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 54, child: EnvelopeStrip(ctl: ctl, base: b)),
          const SizedBox(height: Sp.s),
          ControlGrid(children: [
            Knob(ctl: ctl, path: '$b/attack', label: tr('Attacco'), size: ks),
            Knob(ctl: ctl, path: '$b/hold', label: tr('Hold'), size: ks),
            Knob(ctl: ctl, path: '$b/release', label: tr('Rilascio'), size: ks),
          ]),
        ]),
      ),
      if (!gate) ...[
        const SizedBox(height: Sp.s),
        MxPanel(
          title: tr('Rilevamento'),
          color: AppColors.surface2,
          padding: const EdgeInsets.all(Sp.s),
          child: Wrap(spacing: Sp.s, runSpacing: Sp.s, children: [
            MxLabeled(tr('Rilevamento'), ParamDropdown(ctl: ctl, path: '$b/det', width: 72)),
            MxLabeled(tr('Inviluppo'), ParamDropdown(ctl: ctl, path: '$b/env', width: 72)),
            MxLabeled(tr('Posizione'), ParamDropdown(ctl: ctl, path: '$b/pos', width: 72)),
            MxLabeled(tr('Auto'), ParamToggle(ctl: ctl, path: '$b/auto', label: tr('AUTO'), width: 60)),
          ]),
        ),
      ],
      const SizedBox(height: Sp.s),
      MxPanel(
        title: tr('Sorgente chiave e filtro'),
        color: AppColors.surface2,
        padding: const EdgeInsets.all(Sp.s),
        child: Wrap(spacing: Sp.s, runSpacing: Sp.s, crossAxisAlignment: WrapCrossAlignment.end, children: [
          if (hasKey) MxLabeled(tr('Sorgente'), ParamDropdown(ctl: ctl, path: '$b/keysrc', width: 64)),
          MxLabeled(tr('Filtro'), ParamToggle(ctl: ctl, path: '$b/filter/on', label: 'ON', width: 48)),
          MxLabeled(tr('Tipo'), ParamDropdown(ctl: ctl, path: '$b/filter/type', width: 72)),
          Knob(ctl: ctl, path: '$b/filter/f', label: tr('Freq.'), size: large ? 44 : 38, compact: true),
        ]),
      ),
    ]);
    final head = ProcessorHeader(
      ctl: ctl,
      onPath: '$b/on',
      title: gate ? 'Gate' : tr('Compressore'),
      modePath: '$b/mode',
      onBig: large ? null : () => showDialog<void>(context: context, builder: (_) => DynEditorDialog(ctl: ctl, strip: strip, gate: gate)),
    );
    final note = Text(tr('Curva calcolata dai parametri (caratteristica statica), non il DSP del mixer. Clic o trascinamento sul grafico: soglia'
        '; sul punto in basso del gate: range.'), style: Tx.caption);
    if (large) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: Sp.s), Expanded(child: graph), const SizedBox(height: Sp.xs), note])),
        const SizedBox(width: Sp.l),
        SizedBox(width: 360, child: SingleChildScrollView(child: controls)),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(Sp.s), children: [head, const SizedBox(height: Sp.s), graph, const SizedBox(height: Sp.xs), note, const SizedBox(height: Sp.s), controls]);
  }
}

/// Editor grande di gate o compressore.
class DynEditorDialog extends StatelessWidget {
  const DynEditorDialog({super.key, required this.ctl, required this.strip, required this.gate});
  final AppController ctl;
  final StripRef strip;
  final bool gate;

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(Sp.xl),
        child: Padding(
          padding: const EdgeInsets.all(Sp.l),
          child: Column(children: [
            MxPageHeader(
              title: '${gate ? 'Gate' : tr('Compressore')} · ${ctl.stripName(strip)}',
              subtitle: tr('Trascina la soglia sul grafico o usa le manopole. Clic sul valore per digitarlo; frecce della tastiera per i passi fini.'),
              actions: [MxIconButton(icon: Icons.close, tooltip: tr('Chiudi'), onTap: () => Navigator.pop(context))],
            ),
            Expanded(child: DynEditor(ctl: ctl, strip: strip, gate: gate, large: true)),
          ]),
        ),
      );
}
