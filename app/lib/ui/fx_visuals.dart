import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../controller/app_controller.dart';
import '../design/components.dart';
import '../theme.dart';
import '../l10n/l10n.dart';

/// Editor grafici degli effetti. Ogni grafico compare solo se il tipo possiede davvero i
/// parametri che rappresenta (Appendice C) e si modifica trascinando i punti: il trascinamento
/// imposta il parametro documentato con la sua quantizzazione. I disegni illustrano il
/// significato dei parametri, non riproducono il DSP del mixer.
class FxVisual extends StatelessWidget {
  const FxVisual({super.key, required this.ctl, required this.slot, required this.type, this.color});
  final AppController ctl;
  final int slot;
  final FxTypeDef type;
  final Color? color;

  /// Titoli dei grafici disponibili per un tipo (usato anche dai test).
  static List<String> graphsFor(AppController ctl, int slot, FxTypeDef type) => [for (final g in _graphs(_Fx(ctl, slot, type), AppColors.accent)) g.$1];

  static List<(String, String, _Graph)> _graphs(_Fx fx, Color c) => [
        if (fx.has('Decay') && (fx.has('PreDelay') || fx.has('RevDelay'))) (tr('Inviluppo'), tr('Trascina i punti: pre-delay e decadimento'), _EnvelopeGraph(fx, c)),
        if (fx.has('Time') && (fx.has('FactorL') || fx.has('FactorA'))) (tr('Ripetizioni'), tr('Trascina il punto T: tempo del delay'), _DelayGraph(fx, c)),
        if (fx.has('Speed') && (fx.has('WidthL') || fx.has('Width') || fx.has('Depth'))) (tr('Modulazione'), tr('Orizzontale: velocità · verticale: profondità'), _LfoGraph(fx, c)),
        if (fx.first(['LoCut', 'LC']) != null && fx.first(['HiCut', 'HC']) != null) (tr('Banda passante'), tr('Trascina i due filtri'), _FilterGraph(fx, c)),
        if (_FreqMapGraph.pairs(fx).isNotEmpty) (tr('Mappa delle frequenze'), tr('Orizzontale: frequenza · verticale: guadagno'), _FreqMapGraph(fx, c)),
        if (_LevelsGraph.params(fx).length >= 2) (tr('Livelli'), tr('Trascina le barre in verticale'), _LevelsGraph(fx, c)),
      ];

  @override
  Widget build(BuildContext context) {
    final fx = _Fx(ctl, slot, type);
    final graphs = _graphs(fx, color ?? AppColors.accent);
    if (graphs.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([for (final p in type.params) ctl.hub.listen(fx.path(p))]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.s),
        child: LayoutBuilder(builder: (context, cons) {
          // fino a due grafici per riga
          final perRow = cons.maxWidth > 900 && graphs.length > 1 ? 2 : 1;
          final w = (cons.maxWidth - (perRow - 1) * Sp.s) / perRow;
          return Wrap(spacing: Sp.s, runSpacing: Sp.s, children: [
            for (final (title, hint, g) in graphs)
              SizedBox(
                width: graphs.length == 1 ? cons.maxWidth : w,
                child: MxPanel(
                  title: title,
                  trailing: Text(hint, style: Tx.caption),
                  padding: const EdgeInsets.fromLTRB(Sp.m, Sp.s, Sp.m, Sp.m),
                  child: SizedBox(height: 170, child: _GraphView(graph: g)),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

/// Accesso ai parametri dello slot per nome.
class _Fx {
  _Fx(this.ctl, this.slot, this.type);
  final AppController ctl;
  final int slot;
  final FxTypeDef type;

  FxParamDef? p(String name) {
    for (final p in type.params) {
      if (p.name == name) return p;
    }
    return null;
  }

  bool has(String name) => p(name) != null;
  FxParamDef? first(List<String> names) {
    for (final n in names) {
      final x = p(n);
      if (x != null) return x;
    }
    return null;
  }

  String path(FxParamDef p) => '/fx/$slot/par/${p.index.toString().padLeft(2, '0')}';
  double? val(FxParamDef? p) => p == null ? null : ctl.state.getPhysical(path(p));
  String? label(FxParamDef? p) {
    if (p == null || p.labels == null) return null;
    final i = ctl.idx(path(p));
    return i == null ? null : p.labels![i.clamp(0, p.labels!.length - 1)];
  }

  String text(FxParamDef p) {
    final s = ctl.state.specOf(path(p));
    final i = ctl.idx(path(p));
    return s == null || i == null ? '—' : s.display(i);
  }

  /// Imposta il valore fisico più vicino consentito dalla quantizzazione del parametro.
  void set(FxParamDef? p, double physical) {
    if (p == null || p.labels != null) return;
    final s = ctl.state.specOf(path(p));
    if (s == null) return;
    final v = physical.clamp(math.min(p.min, p.max), math.max(p.min, p.max)).toDouble();
    final idx = s.idxFromPhysical(v);
    if (idx != ctl.idx(path(p))) ctl.setIdx(path(p), idx);
  }
}

// ============================================================ INFRASTRUTTURA

/// Punto trascinabile di un grafico.
class _Handle {
  _Handle(this.pos, this.label, this.onDrag, {this.color});
  final Offset pos;
  final String label;
  final void Function(Offset local) onDrag;
  final Color? color;
}

abstract class _Graph {
  /// Disegna il grafico e restituisce i punti trascinabili.
  List<_Handle> paint(Canvas canvas, Size size);
}

class _GraphView extends StatefulWidget {
  const _GraphView({required this.graph});
  final _Graph graph;
  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> {
  int? _drag;
  List<_Handle> _last = const [];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        onPanStart: (d) {
          // punto più vicino (entro 40 px)
          var best = -1;
          var bd = 40.0 * 40.0;
          for (var i = 0; i < _last.length; i++) {
            final dd = (_last[i].pos - d.localPosition).distanceSquared;
            if (dd < bd) {
              bd = dd;
              best = i;
            }
          }
          setState(() => _drag = best < 0 ? null : best);
        },
        onPanUpdate: (d) {
          final i = _drag;
          if (i != null && i < _last.length) {
            _last[i].onDrag(Offset(d.localPosition.dx.clamp(0, size.width).toDouble(), d.localPosition.dy.clamp(0, size.height).toDouble()));
          }
        },
        onPanEnd: (_) => setState(() => _drag = null),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: CustomPaint(size: size, painter: _GraphPainter(widget.graph, (h) => _last = h, _drag)),
        ),
      );
    });
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.graph, this.report, this.drag);
  final _Graph graph;
  final void Function(List<_Handle>) report;
  final int? drag;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Rd.m));
    canvas.drawRRect(frame, Paint()..color = AppColors.well);
    canvas.save();
    canvas.clipRRect(frame);
    final hs = graph.paint(canvas, size);
    canvas.restore();
    report(hs);
    for (var i = 0; i < hs.length; i++) {
      final h = hs[i];
      final c = h.color ?? AppColors.text;
      final active = i == drag;
      if (active) canvas.drawCircle(h.pos, 14, Paint()..color = c.withValues(alpha: 0.25));
      canvas.drawCircle(h.pos, active ? 8 : 6.5, Paint()..color = c);
      canvas.drawCircle(h.pos, active ? 8 : 6.5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white);
      // etichetta dentro il riquadro anche vicino ai bordi
      final right = h.pos.dx > size.width - 140;
      _text(canvas, h.label, Offset(right ? h.pos.dx - 10 : h.pos.dx + 10, (h.pos.dy - 18).clamp(2, size.height - 14)),
          color: AppColors.text, size: 10, bold: true, right: right);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter o) => true;
}

void _text(Canvas c, String t, Offset o, {Color color = AppColors.textFaint, double size = 9.5, bool bold = false, bool right = false}) {
  final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)), textDirection: TextDirection.ltr)..layout();
  tp.paint(c, right ? o - Offset(tp.width, 0) : o);
}

final _grid = Paint()..color = AppColors.border.withValues(alpha: 0.7);

/// Asse logaritmico delle frequenze 20 Hz – 20 kHz.
double _xf(double f, double w, {double pad = 10}) => pad + math.log(f.clamp(20, 20000) / 20) / math.log(1000) * (w - 2 * pad);
double _fx(double x, double w, {double pad = 10}) => 20 * math.pow(1000, ((x - pad) / (w - 2 * pad)).clamp(0.0, 1.0)).toDouble();

void _freqGrid(Canvas canvas, Size size) {
  for (final f in [50, 100, 200, 500, 1000, 2000, 5000, 10000]) {
    final x = _xf(f.toDouble(), size.width);
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), _grid);
    _text(canvas, f >= 1000 ? '${f ~/ 1000}k' : '$f', Offset(x + 2, size.height - 13));
  }
}

// ================================================================ GRAFICI

/// Riverberi: pre-delay, attacco, decadimento esponenziale fino a −60 dB.
class _EnvelopeGraph extends _Graph {
  _EnvelopeGraph(this.fx, this.color);
  final _Fx fx;
  final Color color;

  @override
  List<_Handle> paint(Canvas canvas, Size size) {
    final pdP = fx.first(['PreDelay', 'RevDelay'])!;
    final dcP = fx.p('Decay')!;
    final pdMs = fx.val(pdP) ?? 0;
    final decay = fx.val(dcP) ?? 1;
    // scala fissa sul massimo dei parametri: il grafico non "scappa" durante il trascinamento
    final span = pdP.max / 1000 + dcP.max * 1.1;
    const l = 30.0, r = 12.0, t = 12.0;
    final b = size.height - 20;
    final w = size.width - l - r;
    double x(double s) => l + s / span * w;
    double y(double db) => t + (-db / 60).clamp(0.0, 1.0) * (b - t);
    for (final db in [0, -20, -40, -60]) {
      canvas.drawLine(Offset(l, y(db.toDouble())), Offset(size.width - r, y(db.toDouble())), _grid);
      _text(canvas, '$db', Offset(4, y(db.toDouble()) - 6));
    }
    final step = span > 12 ? 4.0 : (span > 6 ? 2.0 : 1.0);
    for (var s = 0.0; s <= span; s += step) {
      _text(canvas, '${s.toStringAsFixed(0)} s', Offset(x(s) + 2, size.height - 14));
    }
    final pd = pdMs / 1000;
    final path = Path()
      ..moveTo(x(0), y(-60))
      ..lineTo(x(pd), y(-60))
      ..lineTo(x(pd), y(0));
    for (var i = 1; i <= 90; i++) {
      final tt = pd + decay * 1.1 * i / 90;
      path.lineTo(x(tt), y(-60 * (tt - pd) / decay));
    }
    path
      ..lineTo(x(pd + decay * 1.1), y(-60))
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawLine(Offset(x(pd), y(0)), Offset(x(pd + decay), y(-60)), Paint()
      ..color = color
      ..strokeWidth = 2);
    return [
      _Handle(Offset(x(pd), y(0)), tr('Pre-delay {p0}', {'p0': fx.text(pdP)}), (p) => fx.set(pdP, (p.dx - l) / w * span * 1000), color: color),
      _Handle(Offset(x(pd + decay), y(-60)), tr('Decay {p0}', {'p0': fx.text(dcP)}), (p) => fx.set(dcP, (p.dx - l) / w * span - pd), color: color),
    ];
  }
}

/// Delay: segnale diretto, tap e ripetizioni che si attenuano con il feedback.
class _DelayGraph extends _Graph {
  _DelayGraph(this.fx, this.color);
  final _Fx fx;
  final Color color;

  static double? _ratio(String? l) {
    if (l == null) return null;
    final parts = l.split('/');
    if (parts.length == 2) {
      final a = double.tryParse(parts[0]), b = double.tryParse(parts[1]);
      return a == null || b == null || b == 0 ? null : a / b;
    }
    return double.tryParse(l);
  }

  @override
  List<_Handle> paint(Canvas canvas, Size size) {
    final tP = fx.p('Time')!;
    final time = fx.val(tP) ?? 500;
    final maxT = tP.max * 1.2;
    const l = 14.0, r = 14.0, t = 14.0;
    final base = size.height - 20;
    final w = size.width - l - r;
    double x(double ms) => l + ms / maxT * w;
    canvas.drawLine(Offset(l, base), Offset(size.width - r, base), Paint()..color = AppColors.textFaint);
    final step = maxT > 2500 ? 1000.0 : 500.0;
    for (var ms = 0.0; ms <= maxT; ms += step) {
      _text(canvas, '${(ms / 1000).toStringAsFixed(1)} s', Offset(x(ms) + 2, size.height - 14));
    }
    canvas.drawRect(Rect.fromLTWH(x(0) - 2, t, 4, base - t), Paint()..color = AppColors.text);
    _text(canvas, 'diretto', Offset(x(0) + 5, t));
    final taps = <(String, double, double)>[];
    if (fx.has('FactorL')) {
      taps.add(('L', time * (_ratio(fx.label(fx.p('FactorL'))) ?? 1), (fx.val(fx.p('FeedL')) ?? 30) / 100));
      taps.add(('R', time * (_ratio(fx.label(fx.p('FactorR'))) ?? 1), (fx.val(fx.p('FeedR')) ?? 30) / 100));
    } else {
      final fb = (fx.val(fx.p('Feedback')) ?? 30) / 100;
      taps.add(('T', time, fb));
      for (final k in ['A', 'B', 'C']) {
        final f = fx.p('Factor$k');
        if (f != null) taps.add((k, time * (_ratio(fx.label(f)) ?? 1), fb));
      }
    }
    final colors = AppColors.series;
    for (var i = 0; i < taps.length; i++) {
      final (name, ms, fb) = taps[i];
      final c = i == 0 ? color : colors[(i + 2) % colors.length];
      // prima ripetizione e successive (feedback): ampiezza fb^n
      var g = 1.0;
      for (var n = 1; n <= 10 && ms * n < maxT && g > 0.04; n++) {
        final h = (base - t - 10) * g;
        canvas.drawRect(Rect.fromLTWH(x(ms * n) - 1.5 + i * 3, base - h, 3, h), Paint()..color = c.withValues(alpha: n == 1 ? 1 : 0.45));
        g *= fb.clamp(0.0, 0.95);
      }
      _text(canvas, '$name ${ms.toStringAsFixed(0)} ms', Offset(size.width - r, t + 14.0 * i), color: c, right: true);
    }
    return [_Handle(Offset(x(time), t + 10), 'T ${fx.text(tP)}', (p) => fx.set(tP, (p.dx - l) / w * maxT), color: color)];
  }
}

/// Modulazione: forma dell'LFO su due secondi; velocità in orizzontale, profondità in verticale.
class _LfoGraph extends _Graph {
  _LfoGraph(this.fx, this.color);
  final _Fx fx;
  final Color color;

  @override
  List<_Handle> paint(Canvas canvas, Size size) {
    final sP = fx.p('Speed')!;
    final dP = fx.first(['WidthL', 'Width', 'Depth'])!;
    final rP = fx.p('WidthR');
    final speed = fx.val(sP) ?? 1;
    double frac(FxParamDef p) => (((fx.val(p) ?? p.min) - p.min) / (p.max - p.min)).clamp(0.0, 1.0);
    final depth = frac(dP);
    final depthR = rP == null ? null : frac(rP);
    const seconds = 2.0;
    final mid = size.height / 2 - 4;
    final amp = size.height / 2 - 18;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), _grid);
    void wave(double d, double phase, Color c, double stroke) {
      final p = Path();
      for (var i = 0; i <= size.width.toInt(); i += 2) {
        final tt = i / size.width * seconds;
        final yy = mid - math.sin(2 * math.pi * speed * tt + phase) * d * amp;
        i == 0 ? p.moveTo(0, yy) : p.lineTo(i.toDouble(), yy);
      }
      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = c);
    }

    if (depthR != null) wave(depthR, math.pi / 2, AppColors.series[3].withValues(alpha: 0.7), 1.5);
    wave(depth, 0, color, 2.2);
    _text(canvas, '0 s', const Offset(4, 0) + Offset(0, size.height - 14));
    _text(canvas, '2 s', Offset(size.width - 4, size.height - 14), right: true);
    // punto: x proporzionale alla velocità (scala logaritmica del parametro), y = profondità
    final lo = math.max(sP.min, 0.01), hi = sP.max;
    double xs(double v) => 12 + math.log(v.clamp(lo, hi) / lo) / math.log(hi / lo) * (size.width - 24);
    return [
      _Handle(Offset(xs(speed), mid - depth * amp), '${fx.text(sP)} · ${fx.text(dP)}', (p) {
        fx.set(sP, lo * math.pow(hi / lo, ((p.dx - 12) / (size.width - 24)).clamp(0.0, 1.0)));
        fx.set(dP, dP.min + ((mid - p.dy) / amp).clamp(0.0, 1.0) * (dP.max - dP.min));
      }, color: color),
    ];
  }
}

/// Filtri passa-alto e passa-basso dell'effetto, su asse logaritmico.
class _FilterGraph extends _Graph {
  _FilterGraph(this.fx, this.color);
  final _Fx fx;
  final Color color;

  @override
  List<_Handle> paint(Canvas canvas, Size size) {
    final loP = fx.first(['LoCut', 'LC'])!;
    final hiP = fx.first(['HiCut', 'HC'])!;
    final lo = fx.val(loP) ?? 20, hi = fx.val(hiP) ?? 20000;
    _freqGrid(canvas, size);
    const top = 30.0;
    final bottom = size.height - 18;
    final w = size.width;
    final p = Path()
      ..moveTo(_xf(20, w), bottom)
      ..cubicTo(_xf(lo, w) - 18, bottom, _xf(lo, w) - 6, top, _xf(lo, w) + 6, top)
      ..lineTo(_xf(hi, w) - 6, top)
      ..cubicTo(_xf(hi, w) + 6, top, _xf(hi, w) + 18, bottom, _xf(20000, w), bottom);
    canvas.drawPath(Path.from(p)..close(), Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color);
    return [
      _Handle(Offset(_xf(lo, w), top), '${loP.name} ${fx.text(loP)}', (q) => fx.set(loP, _fx(q.dx, w)), color: color),
      _Handle(Offset(_xf(hi, w), top + 22), '${hiP.name} ${fx.text(hiP)}', (q) => fx.set(hiP, _fx(q.dx, w)), color: color),
    ];
  }
}

/// Coppie frequenza / guadagno documentate (EQ valvolari, enhancer, saturazione, shelving):
/// ogni coppia è un punto (frequenza in orizzontale, guadagno in verticale).
class _FreqMapGraph extends _Graph {
  _FreqMapGraph(this.fx, this.color);
  final _Fx fx;
  final Color color;

  static const _gainWords = ['Gain', 'Boost', 'Cut', 'Atten'];

  static List<(FxParamDef, FxParamDef?)> pairs(_Fx fx) {
    final out = <(FxParamDef, FxParamDef?)>[];
    for (final p in fx.type.params) {
      if (p.unit != 3 || p.labels != null || !p.name.contains('Freq') || p.name.startsWith('Feed')) continue;
      // nei tipi doppi si mostra solo il canale A
      if (fx.type.isDual && p.name.endsWith('B')) continue;
      final stem = p.name.substring(0, p.name.indexOf('Freq'));
      FxParamDef? g;
      for (final q in fx.type.params) {
        if (q.labels != null || identical(q, p)) continue;
        if (q.name.startsWith(stem) && _gainWords.any(q.name.contains) && !q.name.contains('Freq') && q.unit != 3) {
          g = q;
          break;
        }
      }
      out.add((p, g));
    }
    return out;
  }

  @override
  List<_Handle> paint(Canvas canvas, Size size) {
    _freqGrid(canvas, size);
    final w = size.width;
    final mid = size.height / 2 - 6;
    final amp = size.height / 2 - 22;
    canvas.drawLine(Offset(0, mid), Offset(w, mid), Paint()..color = AppColors.textFaint);
    final hs = <_Handle>[];
    final ps = pairs(fx);
    for (var i = 0; i < ps.length; i++) {
      final (fP, gP) = ps[i];
      final c = AppColors.series[i % AppColors.series.length];
      final f = fx.val(fP) ?? 1000;
      // guadagno normalizzato nel range del parametro (−1…+1 se bipolare, 0…1 altrimenti)
      double gv = 0;
      if (gP != null) {
        final v = fx.val(gP) ?? 0;
        gv = gP.min < 0 ? v / math.max(gP.max.abs(), gP.min.abs()) : (v - gP.min) / (gP.max - gP.min);
      }
      final y = mid - gv.clamp(-1.0, 1.0) * amp;
      final x = _xf(f, w);
      canvas.drawLine(Offset(x, mid), Offset(x, y), Paint()
        ..color = c
        ..strokeWidth = 2);
      // campana indicativa attorno al punto
      final bell = Path();
      for (var k = -40; k <= 40; k++) {
        final xx = x + k * 2.0;
        final yy = mid + (y - mid) * math.exp(-(k * k) / 300.0);
        k == -40 ? bell.moveTo(xx, yy) : bell.lineTo(xx, yy);
      }
      canvas.drawPath(bell, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = c.withValues(alpha: 0.6));
      final name = fP.name.substring(0, fP.name.indexOf('Freq'));
      hs.add(_Handle(Offset(x, y), gP == null ? '${fP.name} ${fx.text(fP)}' : '${name.isEmpty ? '' : '$name '}${fx.text(fP)} · ${fx.text(gP)}', (q) {
        fx.set(fP, _fx(q.dx, w));
        if (gP != null) {
          final n = ((mid - q.dy) / amp).clamp(-1.0, 1.0);
          fx.set(gP, gP.min < 0 ? n * math.max(gP.max.abs(), gP.min.abs()) : gP.min + n.clamp(0.0, 1.0) * (gP.max - gP.min));
        }
      }, color: c));
    }
    return hs;
  }
}

/// Livelli in dB delle dinamiche e della saturazione (ingresso, uscita, soglie): barre verticali.
class _LevelsGraph extends _Graph {
  _LevelsGraph(this.fx, this.color);
  final _Fx fx;
  final Color color;

  static List<FxParamDef> params(_Fx fx) => [
        for (final p in fx.type.params)
          if (p.unit == 4 &&
              p.labels == null &&
              !(fx.type.isDual && p.name.endsWith('B')) &&
              !RegExp(r'^\d').hasMatch(p.name) &&
              !p.name.startsWith('Lvl') &&
              _FreqMapGraph.pairs(fx).every((pair) => !identical(pair.$2, p)))
            p,
      ].take(8).toList();

  @override
  List<_Handle> paint(Canvas canvas, Size size) {
    final ps = params(fx);
    const top = 14.0;
    final bottom = size.height - 20;
    final colW = size.width / ps.length;
    final hs = <_Handle>[];
    for (var i = 0; i < ps.length; i++) {
      final p = ps[i];
      final v = fx.val(p) ?? 0;
      final f = ((v - p.min) / (p.max - p.min)).clamp(0.0, 1.0);
      final cx = colW * (i + 0.5);
      final y = bottom - f * (bottom - top);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - 7, top, cx + 7, bottom), const Radius.circular(3)), Paint()..color = AppColors.surface2);
      if (p.min < 0 && p.max > 0) {
        final zy = bottom - (-p.min / (p.max - p.min)) * (bottom - top);
        canvas.drawLine(Offset(cx - 11, zy), Offset(cx + 11, zy), Paint()..color = AppColors.textDim);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - 7, y, cx + 7, bottom), const Radius.circular(3)), Paint()..color = color.withValues(alpha: 0.75));
      final tp = TextPainter(text: TextSpan(text: p.name, style: const TextStyle(fontSize: 9.5, color: AppColors.textDim)), textDirection: TextDirection.ltr)..layout(maxWidth: colW - 4);
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - 15));
      hs.add(_Handle(Offset(cx, y), fx.text(p), (q) => fx.set(p, p.min + ((bottom - q.dy) / (bottom - top)).clamp(0.0, 1.0) * (p.max - p.min)), color: color));
    }
    return hs;
  }
}
