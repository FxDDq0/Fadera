import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../controller/app_controller.dart';
import '../theme.dart';
import '../l10n/l10n.dart';

/// Grafico interattivo dell'EQ parametrico.
///
/// La curva è calcolata con le formule standard dei filtri biquadratici (RBJ):
/// è una rappresentazione indicativa, NON il DSP del mixer. I valori inviati sono
/// solo quelli dei parametri (tipo, frequenza, gain, Q) con la quantizzazione documentata.
class EqGraph extends StatefulWidget {
  const EqGraph({super.key, required this.ctl, required this.strip, required this.selectedBand, required this.onSelectBand});
  final AppController ctl;
  final StripRef strip;
  final int selectedBand;
  final ValueChanged<int> onSelectBand;

  @override
  State<EqGraph> createState() => _EqGraphState();
}

class _EqGraphState extends State<EqGraph> {
  int? _drag;

  String _p(int band, String f) => '${widget.strip.base}/eq/$band/$f';

  static const fMin = 20.0, fMax = 20000.0, gRange = 18.0;

  double _xOf(double f, double w) => math.log(f / fMin) / math.log(fMax / fMin) * w;
  double _fOf(double x, double w) => fMin * math.pow(fMax / fMin, (x / w).clamp(0.0, 1.0));
  double _yOf(double g, double h) => h / 2 - g / gRange * (h / 2);
  double _gOf(double y, double h) => ((h / 2 - y) / (h / 2) * gRange).clamp(-15.0, 15.0);

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final bands = widget.strip.eqBands;
    final listenables = <Listenable>[
      ctl.hub.listen('${widget.strip.base}/eq/on'),
      for (var b = 1; b <= bands; b++)
        for (final f in ['type', 'f', 'g', 'q']) ctl.hub.listen(_p(b, f)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      return ListenableBuilder(
        listenable: Listenable.merge(listenables),
        builder: (context, _) {
          final on = ctl.idx('${widget.strip.base}/eq/on') == 1;
          final data = [
            for (var b = 1; b <= bands; b++)
              _Band(
                type: ctl.state.specOf(_p(b, 'type'))!.labels![ctl.idx(_p(b, 'type')) ?? 0],
                f: ctl.state.getPhysical(_p(b, 'f')) ?? 1000,
                g: ctl.state.getPhysical(_p(b, 'g')) ?? 0,
                q: ctl.state.getPhysical(_p(b, 'q')) ?? 2,
              ),
          ];
          return GestureDetector(
            onPanStart: (d) {
              // banda più vicina al punto toccato
              var best = 1;
              var bestD = double.infinity;
              for (var b = 1; b <= bands; b++) {
                final bd = data[b - 1];
                final dx = _xOf(bd.f, w) - d.localPosition.dx;
                final dy = _yOf(bd.hasGain ? bd.g : 0, h) - d.localPosition.dy;
                final dist = dx * dx + dy * dy;
                if (dist < bestD) {
                  bestD = dist;
                  best = b;
                }
              }
              _drag = best;
              widget.onSelectBand(best);
            },
            onPanUpdate: (d) {
              final b = _drag;
              if (b == null) return;
              final fs = ctl.state.specOf(_p(b, 'f'))!;
              ctl.setIdx(_p(b, 'f'), fs.idxFromPhysical(_fOf(d.localPosition.dx, w)));
              if (data[b - 1].hasGain) {
                final gs = ctl.state.specOf(_p(b, 'g'))!;
                ctl.setIdx(_p(b, 'g'), gs.idxFromPhysical(_gOf(d.localPosition.dy, h)));
              }
            },
            onPanEnd: (_) => _drag = null,
            child: CustomPaint(size: Size(w, h), painter: _EqPainter(data, on, widget.selectedBand, this)),
          );
        },
      );
    });
  }
}

class _Band {
  _Band({required this.type, required this.f, required this.g, required this.q});
  final String type;
  final double f, g, q;
  bool get hasGain => type == 'PEQ' || type == 'VEQ' || type == 'LShv' || type == 'HShv';

  /// Risposta in dB alla frequenza [x] (approssimazione con biquad RBJ a 48 kHz).
  double db(double x) {
    const fs = 48000.0;
    final w0 = 2 * math.pi * f / fs;
    final cw = math.cos(w0), sw = math.sin(w0);
    final a = math.pow(10, g / 40).toDouble();
    final alpha = sw / (2 * q);
    double b0, b1, b2, a0, a1, a2;
    switch (type) {
      case 'LCut':
        b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
      case 'HCut':
        b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
      case 'LShv':
        final s = 2 * math.sqrt(a) * alpha;
        b0 = a * ((a + 1) - (a - 1) * cw + s); b1 = 2 * a * ((a - 1) - (a + 1) * cw); b2 = a * ((a + 1) - (a - 1) * cw - s);
        a0 = (a + 1) + (a - 1) * cw + s; a1 = -2 * ((a - 1) + (a + 1) * cw); a2 = (a + 1) + (a - 1) * cw - s;
      case 'HShv':
        final s = 2 * math.sqrt(a) * alpha;
        b0 = a * ((a + 1) + (a - 1) * cw + s); b1 = -2 * a * ((a - 1) + (a + 1) * cw); b2 = a * ((a + 1) + (a - 1) * cw - s);
        a0 = (a + 1) - (a - 1) * cw + s; a1 = 2 * ((a - 1) - (a + 1) * cw); a2 = (a + 1) - (a - 1) * cw - s;
      case 'PEQ':
      case 'VEQ':
        b0 = 1 + alpha * a; b1 = -2 * cw; b2 = 1 - alpha * a;
        a0 = 1 + alpha / a; a1 = -2 * cw; a2 = 1 - alpha / a;
      default:
        return 0; // tipi crossover (BU/BS/LR): non disegnati
    }
    final wx = 2 * math.pi * x / fs;
    final c1 = math.cos(wx), s1 = math.sin(wx), c2 = math.cos(2 * wx), s2 = math.sin(2 * wx);
    final nr = b0 + b1 * c1 + b2 * c2, ni = -(b1 * s1 + b2 * s2);
    final dr = a0 + a1 * c1 + a2 * c2, di = -(a1 * s1 + a2 * s2);
    final mag = math.sqrt((nr * nr + ni * ni) / (dr * dr + di * di));
    return 20 * math.log(math.max(mag, 1e-9)) / math.ln10;
  }
}

class _EqPainter extends CustomPainter {
  _EqPainter(this.bands, this.on, this.selected, this.s);
  final List<_Band> bands;
  final bool on;
  final int selected;
  final _EqGraphState s;

  static List<Color> get bandColors => AppColors.series;

  static String _hz(double f) => f >= 1000 ? '${(f / 1000).toStringAsFixed(f >= 10000 ? 0 : 1).replaceAll('.0', '')}k' : f.toStringAsFixed(0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Rd.m)), Paint()..color = AppColors.well);
    final minor = Paint()..color = AppColors.border.withValues(alpha: 0.45);
    final major = Paint()..color = AppColors.border;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    // griglia delle frequenze: decadi più marcate
    for (final f in [30, 40, 60, 70, 80, 90, 300, 400, 600, 700, 800, 900, 3000, 4000, 6000, 7000, 8000, 9000]) {
      final x = s._xOf(f.toDouble(), w);
      canvas.drawLine(Offset(x, 0), Offset(x, h), minor);
    }
    for (final f in [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]) {
      final x = s._xOf(f.toDouble(), w);
      canvas.drawLine(Offset(x, 0), Offset(x, h), major);
      tp.text = TextSpan(text: _hz(f.toDouble()), style: const TextStyle(fontSize: 9, color: AppColors.textFaint));
      tp.layout();
      if (x + tp.width + 3 < w) tp.paint(canvas, Offset(x + 3, h - tp.height - 3));
    }
    for (final g in [-15, -12, -9, -6, -3, 0, 3, 6, 9, 12, 15]) {
      final y = s._yOf(g.toDouble(), h);
      final labeled = g % 6 == 0;
      canvas.drawLine(Offset(0, y), Offset(w, y), g == 0 ? (Paint()..color = AppColors.textFaint) : (labeled ? major : minor));
      if (labeled) {
        tp.text = TextSpan(text: g > 0 ? '+$g' : '$g', style: const TextStyle(fontSize: 9, color: AppColors.textFaint));
        tp.layout();
        tp.paint(canvas, Offset(w - tp.width - 4, y - tp.height - 1));
      }
    }
    final col = on ? AppColors.text : AppColors.textFaint;
    // curve delle singole bande (sottili), la selezionata più evidente
    for (var i = 0; i < bands.length; i++) {
      final b = bands[i];
      final p = Path();
      for (var x = 0; x <= w.toInt(); x += 3) {
        final y = s._yOf(b.db(s._fOf(x.toDouble(), w)).clamp(-gRangeClamp, gRangeClamp), h);
        x == 0 ? p.moveTo(0, y) : p.lineTo(x.toDouble(), y);
      }
      final c = bandColors[i % bandColors.length];
      final sel = i + 1 == selected;
      if (sel) {
        final fill = Path.from(p)
          ..lineTo(w, h / 2)
          ..lineTo(0, h / 2)
          ..close();
        canvas.drawPath(fill, Paint()..color = c.withValues(alpha: on ? 0.14 : 0.06));
      }
      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 1.6 : 1
        ..color = c.withValues(alpha: on ? (sel ? 0.9 : 0.45) : 0.25));
    }
    // curva complessiva
    final path = Path();
    for (var i = 0; i <= w.toInt(); i += 2) {
      final f = s._fOf(i.toDouble(), w);
      var g = 0.0;
      for (final b in bands) {
        g += b.db(f);
      }
      final y = s._yOf(g.clamp(-gRangeClamp, gRangeClamp), h);
      i == 0 ? path.moveTo(0, y) : path.lineTo(i.toDouble(), y);
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = col);
    // punti delle bande
    for (var i = 0; i < bands.length; i++) {
      final b = bands[i];
      final c = Offset(s._xOf(b.f, w), s._yOf(b.hasGain ? b.g : 0, h));
      final color = bandColors[i % bandColors.length];
      final sel = i + 1 == selected;
      if (sel) canvas.drawCircle(c, 13, Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawCircle(c, sel ? 9 : 7.5, Paint()..color = color.withValues(alpha: on ? 1 : 0.45));
      canvas.drawCircle(c, sel ? 9 : 7.5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 2 : 1
        ..color = sel ? Colors.white : const Color(0x66000000));
      tp.text = TextSpan(text: '${i + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF0D1016)));
      tp.layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    if (!on) {
      tp.text = TextSpan(text: tr('EQ disattivato'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDim));
      tp.layout();
      tp.paint(canvas, Offset(8, 6));
    }
  }

  static const gRangeClamp = 18.0;

  @override
  bool shouldRepaint(_EqPainter o) => true;
}
