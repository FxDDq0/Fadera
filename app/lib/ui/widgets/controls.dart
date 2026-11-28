import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../theme.dart';
import '../../l10n/l10n.dart';

// =============================================================== FADER

/// Fader verticale. La posizione è lineare nell'indice del parametro: per i livelli
/// l'indice segue già la curva dB a 4 segmenti del mixer, quindi la scala grafica
/// coincide con quella della console. Durante il trascinamento i valori in arrivo
/// dal mixer non spostano il fader (nessun salto).
///
/// La scala dB non è disegnata qui: è il widget [FaderScale], in una colonna separata,
/// così meter, scala e fader non si sovrappongono mai.
class Fader extends StatefulWidget {
  const Fader({
    super.key,
    required this.ctl,
    required this.path,
    this.accent,
    this.capGap = 4,
    this.capMax = 42,
  });
  final AppController ctl;
  final String path;
  final Color? accent;

  /// Spazio fra il cursore e i bordi della colonna (più ampio nei banchi di cursori affiancati).
  final double capGap;

  /// Larghezza massima del cursore (più largo nelle strip larghe).
  final double capMax;

  /// Altezza dell'area di presa del cursore. Meter e scala usano lo stesso margine
  /// ([inset]) in alto e in basso, così le posizioni coincidono.
  static double get thumbHeight => MxDensity.s(Sz.faderCap);
  static double get inset => thumbHeight / 2;

  @override
  State<Fader> createState() => _FaderState();
}

class _FaderState extends State<Fader> {
  int? _dragIdx;
  double _dragFrac = 0;
  bool _hover = false;
  final _focus = FocusNode();

  ParamSpec? get _spec => widget.ctl.state.specOf(widget.path);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _set(int idx) {
    final s = _spec;
    if (s == null) return;
    widget.ctl.setIdx(widget.path, s.clampIdx(idx));
  }

  int get _zeroDbIdx => _spec?.kind == ParamKind.level
      ? levelDbToIdx(0, _spec!.steps)
      : (_spec?.steps ?? 0) ~/ 2;

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final cur = widget.ctl.idx(widget.path) ?? 0;
    final big = HardwareKeyboard.instance.isShiftPressed ? 1 : 10;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _set(cur + 1);
      case LogicalKeyboardKey.arrowDown:
        _set(cur - 1);
      case LogicalKeyboardKey.pageUp:
        _set(cur + big * 4);
      case LogicalKeyboardKey.pageDown:
        _set(cur - big * 4);
      case LogicalKeyboardKey.home:
        _set(_zeroDbIdx);
      case LogicalKeyboardKey.end:
        _set(0);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    if (spec == null) return const SizedBox();
    final accent = widget.accent ?? AppColors.accent;
    return ValueListenableBuilder<Object?>(
      valueListenable: widget.ctl.hub.listen(widget.path),
      builder: (context, v, _) {
        final idx = _dragIdx ?? (v as int? ?? 0);
        final frac = spec.fraction(idx);
        // screen reader: cursore con il nome della strip e il valore; su/giù di circa l'1 %
        final step = math.max(1, spec.steps ~/ 100);
        return Semantics(
          container: true,
          slider: true,
          label: _semanticLabel(),
          value: spec.display(idx),
          increasedValue: spec.display(spec.clampIdx(idx + step)),
          decreasedValue: spec.display(spec.clampIdx(idx - step)),
          onIncrease: () => _set(idx + step),
          onDecrease: () => _set(idx - step),
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _onKey,
            onFocusChange: (_) => setState(() {}),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: LayoutBuilder(
                builder: (context, c) {
                  final travel = math.max(1.0, c.maxHeight - Fader.thumbHeight);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => _set(_zeroDbIdx),
                    onVerticalDragStart: (d) {
                      _focus.requestFocus();
                      setState(() {
                        _dragFrac = frac;
                        _dragIdx = idx;
                      });
                    },
                    onVerticalDragUpdate: (d) {
                      final fine =
                          HardwareKeyboard.instance.isShiftPressed ||
                          HardwareKeyboard.instance.isControlPressed;
                      _dragFrac =
                          (_dragFrac - d.delta.dy / travel * (fine ? 0.1 : 1))
                              .clamp(0.0, 1.0);
                      final ni = spec.idxFromFraction(_dragFrac);
                      if (ni != _dragIdx) {
                        setState(() => _dragIdx = ni);
                        _set(ni);
                      }
                    },
                    onVerticalDragEnd: (_) => setState(() => _dragIdx = null),
                    onVerticalDragCancel: () => setState(() => _dragIdx = null),
                    onTapDown: (d) => _focus.requestFocus(),
                    child: CustomPaint(
                      painter: _FaderPainter(
                        frac: frac,
                        zeroFrac: spec.kind == ParamKind.level
                            ? spec.fraction(levelDbToIdx(0, spec.steps))
                            : null,
                        accent: accent,
                        focused: _focus.hasFocus,
                        active: _dragIdx != null || _hover,
                        capGap: widget.capGap,
                        capMax: widget.capMax,
                      ),
                      size: Size(c.maxWidth, c.maxHeight),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// "Fader Kick" (nome della strip dal mixer) oppure il percorso se non è una strip.
  String _semanticLabel() {
    final p = widget.path;
    final parts = p.split('/');
    final base = parts.length >= 3 ? '/${parts[1]}/${parts[2]}' : p;
    final s = AppController.parseStrip(base);
    return tr('Fader {p0}', {'p0': s == null ? p : widget.ctl.stripName(s)});
  }
}

class _FaderPainter extends CustomPainter {
  _FaderPainter({
    required this.frac,
    required this.zeroFrac,
    required this.accent,
    required this.focused,
    required this.active,
    this.capGap = 4,
    this.capMax = 42,
  });
  final double capGap;
  final double capMax;
  final double frac;
  final double? zeroFrac;
  final Color accent;
  final bool focused;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = Fader.inset;
    final travel = size.height - Fader.thumbHeight;
    double yOf(double f) => top + (1 - f) * travel;

    // binario incavato
    const tw = 6.0;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - tw / 2, top - 2, tw, travel + 4),
      const Radius.circular(3),
    );
    canvas.drawRRect(track, Paint()..color = AppColors.well);
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.border,
    );
    // riempimento nel colore della strip, dal fondo al cursore
    final y = yOf(frac);
    final filled = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - 1.5, y, cx + 1.5, top + travel),
      const Radius.circular(2),
    );
    canvas.drawRRect(filled, Paint()..color = accent.withValues(alpha: 0.75));
    // tacca dello 0 dB ai lati del binario
    if (zeroFrac != null) {
      final zy = yOf(zeroFrac!);
      final p = Paint()
        ..color = AppColors.textDim
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(cx - tw / 2 - 5, zy),
        Offset(cx - tw / 2 - 1, zy),
        p,
      );
      canvas.drawLine(
        Offset(cx + tw / 2 + 1, zy),
        Offset(cx + tw / 2 + 5, zy),
        p,
      );
    }
    // cursore: corpo chiaro, linea centrale nel colore della strip, righe di presa
    final cw = math.min(MxDensity.s(capMax), size.width - capGap);
    final ch = Fader.thumbHeight * 0.74;
    final thumb = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y), width: cw, height: ch),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      thumb.shift(const Offset(0, 2)),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawRRect(
      thumb,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? const [Color(0xFFF4F6FA), Color(0xFFC3C9D3)]
              : const [Color(0xFFE2E6EC), Color(0xFFAEB5C1)],
        ).createShader(thumb.outerRect),
    );
    final grip = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1;
    for (final dy in [-7.0, -4.0, 4.0, 7.0]) {
      canvas.drawLine(
        Offset(thumb.left + 5, y + dy),
        Offset(thumb.right - 5, y + dy),
        grip,
      );
    }
    canvas.drawLine(
      Offset(thumb.left + 3, y),
      Offset(thumb.right - 3, y),
      Paint()
        ..color = accent
        ..strokeWidth = 2.4,
    );
    if (focused) {
      canvas.drawRRect(
        thumb.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.selection,
      );
    }
  }

  @override
  bool shouldRepaint(_FaderPainter o) =>
      o.frac != frac ||
      o.accent != accent ||
      o.focused != focused ||
      o.active != active ||
      o.zeroFrac != zeroFrac;
}

/// Scala dB del fader, in una colonna propria accanto al binario. Le tacche usano la
/// stessa curva del fader (indice → posizione), quindi sono allineate al cursore.
class FaderScale extends StatelessWidget {
  const FaderScale({
    super.key,
    required this.spec,
    this.dense = false,
    this.large = false,
  });
  final ParamSpec spec;

  /// Etichette più grandi (strip larghe, master).
  final bool large;

  /// Etichette ridotte (strip strette).
  final bool dense;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ScalePainter(spec, dense, large),
    size: Size.infinite,
  );
}

class _ScalePainter extends CustomPainter {
  _ScalePainter(this.spec, this.dense, [this.large = false]);
  final ParamSpec spec;
  final bool dense;
  final bool large;

  static const _full = [10, 5, 0, -5, -10, -20, -30, -40, -50, -60];
  static const _short = [10, 0, -10, -20, -30, -40, -60];

  @override
  void paint(Canvas canvas, Size size) {
    if (spec.kind != ParamKind.level) return;
    final top = Fader.inset;
    final travel = size.height - Fader.thumbHeight;
    final tp = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
    final marks = dense || travel < 260 ? _short : _full;
    for (final db in marks) {
      final f = spec.fraction(levelDbToIdx(db.toDouble(), spec.steps));
      final y = top + (1 - f) * travel;
      final zero = db == 0;
      canvas.drawLine(
        Offset(size.width - 3, y),
        Offset(size.width, y),
        Paint()..color = zero ? AppColors.textDim : AppColors.textFaint,
      );
      tp.text = TextSpan(
        text: db > 0 ? '+$db' : '$db',
        style: TextStyle(
          fontSize: dense ? 7.5 : (large ? 9.5 : 8.5),
          height: 1,
          fontFamily: Tx.family,
          fontWeight: zero ? FontWeight.w700 : FontWeight.w400,
          color: zero ? AppColors.textDim : AppColors.textFaint,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(math.max(0, size.width - 4 - tp.width), y - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_ScalePainter o) =>
      o.spec != spec || o.dense != dense || o.large != large;
}

// =============================================================== METER

/// Orologio di rendering dei meter: un tick per frame (vsync), separato dalla rete.
/// Con [isLive] si ferma quando non arrivano dati dei meter da più di [idleAfter]
/// (il tempo serve alle barre per scendere a zero) e riparte al primo dato.
class MeterClock extends ChangeNotifier {
  MeterClock({this.isLive, this.idleAfter = const Duration(seconds: 4)});
  final bool Function()? isLive;
  final Duration idleAfter;
  int lastMs = 0;
  int dtMs = 16;
  int _lastLiveMs = 0;
  bool _idle = false;

  /// Vero quando l'orologio è fermo (nessun ridisegno dei meter).
  bool get idle => _idle;

  void tick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    dtMs = (ms - lastMs).clamp(0, 100);
    lastMs = ms;
    final live = isLive?.call() ?? true;
    if (live) {
      _lastLiveMs = ms;
      _idle = false;
    } else if (ms - _lastLiveMs > idleAfter.inMilliseconds) {
      _idle = true;
      return;
    }
    notifyListeners();
  }
}

/// Meter verticale a segmenti con picco e indicatore di clip in alto.
/// Scala propria in dBFS (−60…0), indipendente dalla scala del fader.
class LevelMeter extends StatefulWidget {
  const LevelMeter({
    super.key,
    required this.read,
    required this.clock,
    this.width = 6,
    this.available = true,
  });
  final double Function() read;
  final MeterClock clock;
  final double width;

  /// Falso quando la posizione del valore nel banco non è nota: il meter resta spento.
  final bool available;

  @override
  State<LevelMeter> createState() => _LevelMeterState();
}

/// Impostazioni dei meter (Personalizzazione → Interfaccia), comuni a tutti i meter.
abstract final class MeterSettings {
  /// Tenuta del picco: 0 = nessun indicatore di picco, negativo = tenuto finché non si tocca il meter.
  static int peakHoldMs = 1500;

  /// Velocità di discesa della barra (dB al secondo).
  static double fallDbPerSecond = 26;

  /// Valore numerico del picco al posto del LED di segnale nelle strip.
  static bool peakReadout = false;

  /// Cambia a ogni modifica: i meter ricreano la propria dinamica.
  static int version = 0;

  static MeterBallistics ballistics() => MeterBallistics(
    fallDbPerSecond: fallDbPerSecond,
    peakHoldMs: peakHoldMs < 0 ? 1 << 30 : math.max(peakHoldMs, 1),
  );
}

class _LevelMeterState extends State<LevelMeter> {
  MeterBallistics _b = MeterSettings.ballistics();
  int _ver = MeterSettings.version;

  MeterBallistics get b {
    if (_ver != MeterSettings.version) {
      _b = MeterSettings.ballistics();
      _ver = MeterSettings.version;
    }
    return _b;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.available
          ? tr(
              'Meter in dBFS (−60…0), tacche a 0, −6, −12, −18, −30, −40. In alto il clip: resta acceso finché non tocchi il meter. La scala accanto è quella del fader.',
            )
          : tr('Meter spento: posizione nel banco meter non verificata.'),
      waitDuration: const Duration(milliseconds: 900),
      child: GestureDetector(
        // tocco: azzera clip e picco tenuto
        onTap: widget.available ? () => _b = MeterSettings.ballistics() : null,
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(widget.width, double.infinity),
            painter: _MeterPainter(this, widget.clock),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.s, MeterClock clock) : super(repaint: clock);
  final _LevelMeterState s;

  // gradiente e pennelli riusati tra un frame e l'altro (prima creati a ogni disegno di ogni meter)
  static Rect? _shaderRect;
  static Shader? _shader;
  static final _wellPaint = Paint()..color = AppColors.well;
  static final _gapPaint = Paint()
    ..color = AppColors.well.withValues(alpha: 0.85);
  static final _tickPaint = Paint()
    ..color = AppColors.textFaint.withValues(alpha: 0.6);

  static Shader _shaderFor(Rect body) {
    if (_shader == null || _shaderRect != body) {
      _shaderRect = body;
      _shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: const [
          AppColors.meterLow,
          AppColors.meterLow,
          AppColors.meterMid,
          AppColors.meterHigh,
        ],
        stops: [0, frac(-12), frac(-4), 1],
      ).createShader(body);
    }
    return _shader!;
  }

  static double frac(double db) {
    const lo = -60.0, hi = 0.0;
    return ((db - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  static const _clipH = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(
      0,
      _clipH + 2,
      size.width,
      math.max(0, size.height - _clipH - 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      _wellPaint,
    );
    final clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, _clipH),
      const Radius.circular(1),
    );
    if (!s.widget.available) {
      canvas.drawRRect(clip, _wellPaint);
      return;
    }
    final b = s.b
      ..input(s.widget.read())
      ..tick(s.widget.clock.dtMs);
    final f = frac(b.level);
    if (f > 0) {
      final rect = Rect.fromLTRB(
        body.left + 1,
        body.top + body.height * (1 - f),
        body.right - 1,
        body.bottom,
      );
      canvas.drawRect(rect, Paint()..shader = _shaderFor(body));
      // segmenti: righe scure ogni 3 px, in un unico tracciato (un solo comando di disegno)
      final gaps = Path();
      for (var y = body.bottom - 3; y > rect.top; y -= 3) {
        gaps.addRect(Rect.fromLTWH(body.left, y, body.width, 1));
      }
      canvas.drawPath(gaps, _gapPaint);
    }
    // tacche dBFS sul bordo destro
    for (final db in const [0, -6, -12, -18, -30, -40]) {
      final y = body.top + body.height * (1 - frac(db.toDouble()));
      final major = db == 0 || db == -18;
      canvas.drawRect(
        Rect.fromLTWH(body.right - (major ? 3 : 2), y, major ? 3 : 2, 1),
        _tickPaint,
      );
    }
    final pf = frac(b.peak);
    if (MeterSettings.peakHoldMs != 0 && pf > 0.01) {
      final y = body.top + body.height * (1 - pf);
      canvas.drawRect(
        Rect.fromLTWH(body.left + 1, y, body.width - 2, 1.5),
        Paint()
          ..color = b.peak > -6
              ? AppColors.meterHigh
              : AppColors.text.withValues(alpha: 0.85),
      );
    }
    // indicatore di clip (picco sopra −0,5 dBFS)
    // clip tenuto: resta acceso finché l'utente non tocca il meter
    canvas.drawRRect(
      clip,
      Paint()..color = b.clip ? AppColors.meterHigh : AppColors.surface3,
    );
  }

  @override
  bool shouldRepaint(_MeterPainter old) => true;
}

// ================================================================ KNOB

/// Manopola rotativa: trascinamento verticale (Maiusc = fine), doppio clic = valore predefinito.
/// Nessuna modifica con la rotella del mouse (scelta dell'utente).
class Knob extends StatefulWidget {
  const Knob({
    super.key,
    required this.ctl,
    required this.path,
    required this.label,
    this.defaultIdx,
    this.size = 44,
    this.color,
    this.bipolar = false,
    this.compact = false,
    this.valueText,
  });
  final AppController ctl;
  final String path;
  final String label;
  final int? defaultIdx;
  final double size;
  final Color? color;
  final bool bipolar;

  /// Testi più piccoli e senza unità separata da spazio (pannelli stretti).
  final bool compact;

  /// Testo del valore al posto del formato del parametro (es. pan in L/C/R).
  final String Function(double physical)? valueText;

  @override
  State<Knob> createState() => _KnobState();
}

class _KnobState extends State<Knob> {
  double _acc = 0;
  bool _active = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Tastiera (dopo un clic sulla manopola): frecce = un passo, Pag su/giù = 10 passi,
  /// Inizio = valore predefinito.
  KeyEventResult _onKey(FocusNode n, KeyEvent e, ParamSpec spec, int idx) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    int? to;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowRight:
        to = idx + 1;
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowLeft:
        to = idx - 1;
      case LogicalKeyboardKey.pageUp:
        to = idx + 10;
      case LogicalKeyboardKey.pageDown:
        to = idx - 10;
      case LogicalKeyboardKey.home:
        to = widget.defaultIdx;
      default:
        return KeyEventResult.ignored;
    }
    if (to != null) widget.ctl.setIdx(widget.path, spec.clampIdx(to));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.ctl.state.specOf(widget.path);
    if (spec == null) return const SizedBox();
    final color = widget.color ?? AppColors.accent;
    final size = MxDensity.s(widget.size);
    return ValueListenableBuilder<Object?>(
      valueListenable: widget.ctl.hub.listen(widget.path),
      builder: (context, v, _) {
        final idx = v as int? ?? 0;
        final text = widget.valueText != null
            ? widget.valueText!(spec.physical(idx))
            : (widget.compact
                  ? spec.display(idx).replaceAll(' ', '')
                  : spec.display(idx));
        return SizedBox(
          width: widget.compact ? size + 12 : math.max(size + 16, 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tx.label,
              ),
              const SizedBox(height: Sp.xs),
              Semantics(
                container: true,
                slider: true,
                label: widget.label,
                value: text,
                increasedValue: spec.display(spec.clampIdx(idx + math.max(1, spec.steps ~/ 100))),
                decreasedValue: spec.display(spec.clampIdx(idx - math.max(1, spec.steps ~/ 100))),
                onIncrease: () => widget.ctl.setIdx(
                  widget.path,
                  spec.clampIdx(idx + math.max(1, spec.steps ~/ 100)),
                ),
                onDecrease: () => widget.ctl.setIdx(
                  widget.path,
                  spec.clampIdx(idx - math.max(1, spec.steps ~/ 100)),
                ),
                child: Focus(
                  focusNode: _focus,
                  onKeyEvent: (n, e) => _onKey(n, e, spec, idx),
                  onFocusChange: (_) => setState(() {}),
                  child: GestureDetector(
                    onTapDown: (_) => _focus.requestFocus(),
                    onDoubleTap: widget.defaultIdx == null
                        ? null
                        : () => widget.ctl.setIdx(
                            widget.path,
                            widget.defaultIdx!,
                          ),
                    onVerticalDragStart: (_) => setState(() {
                      _focus.requestFocus();
                      _acc = spec.fraction(idx);
                      _active = true;
                    }),
                    onVerticalDragEnd: (_) => setState(() => _active = false),
                    onVerticalDragCancel: () => setState(() => _active = false),
                    onVerticalDragUpdate: (d) {
                      final fine = HardwareKeyboard.instance.isShiftPressed;
                      _acc = (_acc - d.delta.dy / (fine ? 1500 : 180)).clamp(
                        0.0,
                        1.0,
                      );
                      widget.ctl.setIdx(
                        widget.path,
                        spec.idxFromFraction(_acc),
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: _KnobPainter(
                          spec.fraction(idx),
                          color,
                          widget.bipolar,
                          _active || _focus.hasFocus,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Sp.xs),
              // clic sul valore: inserimento numerico
              Tooltip(
                message: tr(
                  'Clic per digitare il valore · frecce: un passo · Pag su/giù: 10 passi',
                ),
                waitDuration: const Duration(milliseconds: 900),
                child: InkWell(
                  borderRadius: Rd.brS,
                  onTap: () =>
                      editValue(context, widget.ctl, widget.path, widget.label),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Tx.value.copyWith(
                        fontSize: widget.compact ? 10.5 : 11.5,
                        color: _active || _focus.hasFocus
                            ? AppColors.text
                            : AppColors.textDim,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter(this.f, this.color, this.bipolar, this.active);
  final double f;
  final Color color;
  final bool bipolar;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    const start = math.pi * 0.75, sweep = math.pi * 1.5;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surface3;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      sweep,
      false,
      ring,
    );
    if (bipolar) {
      // tacca del centro
      final top = c + const Offset(0, -1) * (r + 3);
      canvas.drawLine(
        top,
        c + const Offset(0, -1) * (r - 3),
        Paint()
          ..color = AppColors.textDim
          ..strokeWidth = 1.5,
      );
    }
    final from = bipolar ? start + sweep / 2 : start;
    final to = start + sweep * f;
    if ((to - from).abs() > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        math.min(from, to),
        (to - from).abs(),
        false,
        ring..color = color,
      );
    }
    // corpo della manopola
    final body = r - 5;
    canvas.drawCircle(
      c + const Offset(0, 1.5),
      body,
      Paint()..color = const Color(0x80000000),
    );
    canvas.drawCircle(
      c,
      body,
      Paint()
        ..shader = RadialGradient(
          colors: active
              ? const [Color(0xFF3A4251), Color(0xFF262C37)]
              : const [Color(0xFF323946), Color(0xFF20252F)],
          center: const Alignment(-0.3, -0.4),
        ).createShader(Rect.fromCircle(center: c, radius: body)),
    );
    canvas.drawCircle(
      c,
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.borderStrong,
    );
    final a = start + sweep * f;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      c + dir * (body * 0.35),
      c + dir * (body - 2),
      Paint()
        ..color = AppColors.text
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter o) =>
      o.f != f || o.color != color || o.active != active;
}

// ============================================================= PULSANTI

/// Pulsante a due stati legato a un parametro enum OFF/ON.
class ParamToggle extends StatelessWidget {
  const ParamToggle({
    super.key,
    required this.ctl,
    required this.path,
    required this.label,
    this.activeColor = AppColors.ok,
    this.invert = false,
    this.width,
    this.height = Sz.controlM,
  });
  final AppController ctl;
  final String path;
  final String label;
  final Color activeColor;

  /// Per il mute: il parametro `mix/on` vale 0 quando il canale è muto.
  final bool invert;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(path),
      builder: (context, v, _) {
        final on = invert ? (v == 0) : (v != null && v != 0);
        return PillButton(
          label: label,
          active: on,
          activeColor: activeColor,
          onTap: () => ctl.toggle(path),
          width: width,
          height: height,
        );
      },
    );
  }
}

/// Pulsante a due stati: spento = superficie scura con testo attenuato; acceso = colore pieno dello stato.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
    this.width,
    this.height = Sz.controlM,
    this.icon,
    this.enabled = true,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;
  final double? width;
  final double height;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ac = activeColor ?? AppColors.accent;
    final fg = !enabled
        ? AppColors.textFaint
        : (active ? AppColors.onColor(ac) : AppColors.textDim);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: active ? ac : AppColors.surface2,
        borderRadius: Rd.brS,
        child: InkWell(
          borderRadius: Rd.brS,
          onTap: enabled ? onTap : null,
          child: Container(
            width: width,
            height: MxDensity.s(height),
            padding: EdgeInsets.symmetric(
              horizontal: width != null && width! < 60 ? 2 : Sp.s,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: Rd.brS,
              border: Border.all(color: active ? ac : AppColors.border),
              boxShadow: active ? Shadows.glow(ac, 0.25) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: fg),
                  if (label.isNotEmpty) const SizedBox(width: 4),
                ],
                if (label.isNotEmpty)
                  // il testo si riduce invece di essere troncato (strip strette)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selettore per un parametro enum (menu a tendina compatto).
class ParamDropdown extends StatelessWidget {
  const ParamDropdown({
    super.key,
    required this.ctl,
    required this.path,
    this.width = 110,
    this.labels,
  });
  final AppController ctl;
  final String path;
  final double width;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final spec = ctl.state.specOf(path);
    if (spec == null) return const SizedBox();
    final names =
        labels ??
        spec.labels ??
        [for (var i = spec.minIdx; i <= spec.steps; i++) '$i'];
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(path),
      builder: (context, v, _) {
        final idx = (v as int? ?? 0) - spec.minIdx;
        return Container(
          width: width,
          height: MxDensity.s(Sz.controlM),
          padding: const EdgeInsets.symmetric(horizontal: Sp.s),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: Rd.brS,
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              isDense: true,
              value: idx.clamp(0, names.length - 1),
              dropdownColor: AppColors.surface2,
              icon: const Icon(
                Icons.expand_more,
                size: 16,
                color: AppColors.textDim,
              ),
              style: const TextStyle(fontSize: 12, color: AppColors.text),
              items: [
                for (var i = 0; i < names.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(names[i], overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (i) =>
                  i == null ? null : ctl.setIdx(path, i + spec.minIdx),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================= PAN

/// Testo del pan: C al centro, L/R con la distanza dal centro (−100…+100 del mixer).
String panText(double v) {
  final r = v.round();
  if (r == 0) return 'C';
  return r < 0 ? 'L${-r}' : 'R$r';
}

/// Pan (o bilanciamento del Main LR) sulla strip: barra orizzontale con tacca centrale,
/// riempimento dal centro, valore. Trascina in orizzontale (Maiusc = fine), doppio clic = centro.
class PanBar extends StatefulWidget {
  const PanBar({
    super.key,
    required this.ctl,
    required this.strip,
    this.compact = false,
  });
  final AppController ctl;
  final StripRef strip;
  final bool compact;
  @override
  State<PanBar> createState() => _PanBarState();
}

class _PanBarState extends State<PanBar> {
  double _acc = 0;

  @override
  Widget build(BuildContext context) {
    final path = '${widget.strip.base}/mix/pan';
    final spec = widget.ctl.state.specOf(path);
    if (spec == null) return const SizedBox.shrink();
    final balance =
        widget.strip.hasBalance || widget.ctl.isLinked(widget.strip);
    return ValueListenableBuilder<Object?>(
      valueListenable: widget.ctl.hub.listen(path),
      builder: (context, v, _) {
        final idx = v as int? ?? spec.idxFromPhysical(0);
        final f = spec.fraction(idx);
        final phys = widget.ctl.state.getPhysical(path) ?? 0;
        return Tooltip(
          message: tr(
            '{p0}: {p1}. Trascina in orizzontale (Maiusc = fine), doppio clic = centro.',
            {'p0': balance ? tr('Bilanciamento') : 'Pan', 'p1': panText(phys)},
          ),
          waitDuration: const Duration(milliseconds: 700),
          child: GestureDetector(
            onDoubleTap: () => widget.ctl.setIdx(path, spec.idxFromPhysical(0)),
            onHorizontalDragStart: (_) => _acc = f,
            onHorizontalDragUpdate: (d) {
              final fine = HardwareKeyboard.instance.isShiftPressed;
              _acc = (_acc + d.delta.dx / (fine ? 600 : 120)).clamp(0.0, 1.0);
              final ni = spec.idxFromFraction(_acc);
              if (ni != idx) widget.ctl.setIdx(path, ni);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: SizedBox(
                height: MxDensity.s(18),
                // etichetta e valore solo se c'è spazio (strip strette, ad esempio 16 per pagina)
                child: LayoutBuilder(
                  builder: (context, c) {
                    final compact = widget.compact || c.maxWidth < 96;
                    return Row(
                      children: [
                        if (!compact) ...[
                          Text(
                            balance ? 'BAL' : 'PAN',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.textFaint,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: CustomPaint(
                            painter: _PanPainter(f),
                            size: Size.infinite,
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 26,
                            child: Text(
                              panText(phys),
                              textAlign: TextAlign.right,
                              style: Tx.value.copyWith(
                                fontSize: 10.5,
                                color: phys.round() == 0
                                    ? AppColors.textDim
                                    : AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PanPainter extends CustomPainter {
  _PanPainter(this.f);
  final double f;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - 3, size.width, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(track, Paint()..color = AppColors.well);
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.border,
    );
    final cx = size.width / 2;
    final x = f * size.width;
    canvas.drawRect(
      Rect.fromLTRB(math.min(cx, x), cy - 2, math.max(cx, x), cy + 2),
      Paint()..color = AppColors.accent.withValues(alpha: 0.8),
    );
    // tacca del centro
    canvas.drawRect(
      Rect.fromLTWH(cx - 0.75, cy - 6, 1.5, 12),
      Paint()..color = AppColors.textDim,
    );
    // indicatore della posizione
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x.clamp(3, size.width - 3), cy),
          width: 5,
          height: 12,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.text,
    );
  }

  @override
  bool shouldRepaint(_PanPainter o) => o.f != f;
}

/// Inserimento numerico di un valore (clic sul valore di una manopola): il valore fisico
/// digitato viene convertito con la stessa quantizzazione del parametro.
Future<void> editValue(
  BuildContext context,
  AppController ctl,
  String path,
  String label,
) async {
  final spec = ctl.state.specOf(path);
  if (spec == null || spec.kind == ParamKind.enumeration) return;
  final cur = ctl.state.getPhysical(path);
  final c = TextEditingController(
    text: cur == null
        ? ''
        : (cur.abs() >= 100 ? cur.toStringAsFixed(0) : cur.toStringAsFixed(2)),
  );
  final r = await showDialog<double>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(label),
      content: SizedBox(
        width: 260,
        child: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            suffixText: spec.unit,
            helperText: tr('Valore attuale: {p0}', {
              'p0': spec.display(ctl.idx(path) ?? 0),
            }),
          ),
          onSubmitted: (v) =>
              Navigator.pop(d, double.tryParse(v.replaceAll(',', '.'))),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: Text(tr('Annulla')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(d, double.tryParse(c.text.replaceAll(',', '.'))),
          child: Text(tr('Imposta')),
        ),
      ],
    ),
  );
  if (r != null) ctl.setIdx(path, spec.idxFromPhysical(r));
}
