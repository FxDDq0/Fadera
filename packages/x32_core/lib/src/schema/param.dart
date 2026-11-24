/// Parametri X32: tipi, quantizzazione e conversioni (doc 15 par. 3, doc 09, Appendice D).
///
/// Ogni parametro ha un indice intero `idx` in `[min, steps]`. È l'unica
/// rappresentazione dello stato: il valore fisico, il float OSC e il testo
/// delle righe di nodo si ricavano tutti dall'indice.
library;

import 'dart:math' as math;

import '../osc/osc.dart';

enum ParamKind {
  /// `0xc1`: intero (anche bitmask `%…b`). Sul filo `,i`.
  int_,

  /// `0xc2`: enumerazione con etichette. Sul filo `,i`.
  enumeration,

  /// `0xc3`: lineare. Sul filo `,f idx/N`.
  linf,

  /// `0xc4`: logaritmico. Sul filo `,f idx/N`.
  logf,

  /// `0xc6`/`0xc7`: livello in dB con curva a 4 segmenti. Sul filo `,f idx/N`.
  level,

  /// `0xc5`: stringa. Sul filo `,s`.
  string,

  /// Campo di una riga di nodo di cui il nome o il tipo non sono documentati:
  /// si conserva il testo così com'è, non si espone come parametro.
  opaque,
}

/// Confidenza dell'informazione (convenzione dei documenti di analisi).
enum Confidence {
  /// Verificato sull'hardware (HARDWARE_VALIDATION).
  hardware,

  /// A: verificato nel binario.
  binary,

  /// B: dedotto con alta confidenza.
  deduced,

  /// C/D: parziale o da verificare.
  unverified,
}

class ParamSpec {
  const ParamSpec._({
    required this.name,
    required this.kind,
    this.min = 0,
    this.max = 0,
    int steps = 0,
    this.minIdx = 0,
    this.labels,
    this.format = '',
    this.unit = '',
    this.confidence = Confidence.binary,
  }) : _steps = steps;

  const ParamSpec.linf(String name, double min, double max, int steps, String format,
      {String unit = '', Confidence confidence = Confidence.binary})
      : this._(name: name, kind: ParamKind.linf, min: min, max: max, steps: steps, format: format, unit: unit, confidence: confidence);

  const ParamSpec.logf(String name, double min, double max, int steps, String format,
      {String unit = '', Confidence confidence = Confidence.binary})
      : this._(name: name, kind: ParamKind.logf, min: min, max: max, steps: steps, format: format, unit: unit, confidence: confidence);

  const ParamSpec.level(String name, int steps, {Confidence confidence = Confidence.binary})
      : this._(name: name, kind: ParamKind.level, min: -144, max: 10, steps: steps, unit: 'dB', confidence: confidence);

  const ParamSpec.enumeration(String name, List<String> labels, {Confidence confidence = Confidence.binary})
      : this._(name: name, kind: ParamKind.enumeration, labels: labels, confidence: confidence);

  const ParamSpec.integer(String name, int minIdx, int maxIdx, {String format = '%d', Confidence confidence = Confidence.binary})
      : this._(name: name, kind: ParamKind.int_, minIdx: minIdx, steps: maxIdx, format: format, confidence: confidence);

  const ParamSpec.string(String name, int maxLength, {Confidence confidence = Confidence.binary})
      : this._(name: name, kind: ParamKind.string, steps: maxLength, confidence: confidence);

  const ParamSpec.opaque(String name) : this._(name: name, kind: ParamKind.opaque, confidence: Confidence.unverified);

  final String name;
  final ParamKind kind;
  final double min;
  final double max;

  final int _steps;

  /// N: numero di passi (l'indice va da [minIdx] a N). Per le stringhe è la lunghezza massima.
  int get steps => labels != null ? labels!.length - 1 : _steps;
  final int minIdx;
  final List<String>? labels;
  final String format;
  final String unit;
  final Confidence confidence;

  bool get isNumeric => kind != ParamKind.string && kind != ParamKind.opaque;
  bool get isFloatOnWire => kind == ParamKind.linf || kind == ParamKind.logf || kind == ParamKind.level;

  int clampIdx(int idx) => idx < minIdx ? minIdx : (idx > steps ? steps : idx);

  // ---------------------------------------------------------------- filo OSC

  /// Valore da inviare per un indice (doc 15 par. 3.2; verificato in T03c: k/N esatto).
  OscArg toOsc(int idx) {
    final i = clampIdx(idx);
    return isFloatOnWire ? OscFloat(steps == 0 ? 0 : i / steps) : OscInt(i);
  }

  /// Indice da un argomento ricevuto: `,f` → `trunc((N+0,5)·f)`, `,i` → clamp (doc 15 par. 3.2).
  /// Restituisce `null` se il tipo dell'argomento non è compatibile.
  int? idxFromOsc(OscArg a) {
    switch (a) {
      case OscFloat(:final value):
        if (!isNumeric || value.isNaN) return null;
        return clampIdx(((steps + 0.5) * value).truncate());
      case OscInt(:final value):
        if (!isNumeric) return null;
        return clampIdx(value);
      default:
        return null;
    }
  }

  // ---------------------------------------------------------- valore fisico

  /// Valore fisico (dB, Hz, ms, …) di un indice. Per gli enum e gli interi è l'indice stesso.
  double physical(int idx) {
    final i = clampIdx(idx);
    final f = steps == 0 ? 0.0 : i / steps;
    switch (kind) {
      case ParamKind.linf:
        return min + f * (max - min);
      case ParamKind.logf:
        return min * math.pow(max / min, f);
      case ParamKind.level:
        return levelFloatToDb(f);
      default:
        return i.toDouble();
    }
  }

  /// Indice più vicino a un valore fisico (arrotondamento `+0,5` e troncamento, poi clamp).
  int idxFromPhysical(double x) {
    switch (kind) {
      case ParamKind.linf:
        if (max == min) return minIdx;
        return clampIdx(((x - min) * steps / (max - min) + 0.5).floor());
      case ParamKind.logf:
        if (x <= 0) return minIdx;
        return clampIdx((math.log(x / min) / (math.log(max / min) / steps) + 0.5).floor());
      case ParamKind.level:
        return levelDbToIdx(x, steps);
      default:
        return clampIdx((x + 0.5).floor());
    }
  }

  /// Frazione 0..1 di un indice (posizione grafica lineare nell'indice).
  double fraction(int idx) => steps == 0 ? 0 : (clampIdx(idx) - minIdx) / (steps - minIdx);

  int idxFromFraction(double f) => clampIdx((minIdx + f * (steps - minIdx) + 0.5).floor());

  // ------------------------------------------------------- testo dei nodi

  /// Testo del valore nelle righe di nodo (doc 17 par. 4).
  String formatIdx(int idx) {
    final i = clampIdx(idx);
    switch (kind) {
      case ParamKind.enumeration:
        return labels![i];
      case ParamKind.int_:
        return formatInt(format, i);
      case ParamKind.linf:
      case ParamKind.logf:
        return formatNumber(format, physical(i));
      case ParamKind.level:
        return formatLevel(physical(i));
      case ParamKind.string:
      case ParamKind.opaque:
        throw StateError('formatIdx su un parametro non numerico');
    }
  }

  /// Indice da un testo di riga di nodo. Restituisce `null` se il testo non è valido.
  int? parseText(String token) {
    switch (kind) {
      case ParamKind.enumeration:
        final k = labels!.indexOf(token);
        if (k >= 0) return k;
        final n = int.tryParse(token);
        return n == null ? null : clampIdx(n);
      case ParamKind.int_:
        if (token.startsWith('%')) {
          final v = int.tryParse(token.substring(1), radix: 2);
          return v == null ? null : clampIdx(v);
        }
        final v = int.tryParse(token);
        return v == null ? null : clampIdx(v);
      case ParamKind.linf:
      case ParamKind.logf:
        final x = parseNumberText(token);
        return x == null ? null : idxFromPhysical(x);
      case ParamKind.level:
        if (token == '-oo') return 0;
        final x = double.tryParse(token);
        return x == null ? null : levelDbToIdx(x, steps);
      case ParamKind.string:
      case ParamKind.opaque:
        return null;
    }
  }

  /// Testo leggibile per la GUI (unità comprese).
  String display(int idx) {
    switch (kind) {
      case ParamKind.level:
        final db = physical(idx);
        if (db <= -90) return '-∞';
        final r = (db * 10).round() / 10;
        if (r == 0) return '0.0';
        return '${r > 0 ? '+' : ''}${r.toStringAsFixed(1)}';
      case ParamKind.linf:
      case ParamKind.logf:
        final x = physical(idx);
        if (unit == 'Hz') return x >= 1000 ? '${(x / 1000).toStringAsFixed(x >= 10000 ? 1 : 2)} kHz' : '${x.toStringAsFixed(x < 100 ? 1 : 0)} Hz';
        final s = formatNumber(format, x).trim();
        return unit.isEmpty ? s : '$s $unit';
      default:
        return formatIdx(idx);
    }
  }
}

// --------------------------------------------------------------- curva dB

/// Curva a 4 segmenti (doc 15 par. 3.3, verificata su 15 conversioni in T01b).
double levelFloatToDb(double f) {
  if (f <= 0) return -144;
  if (f >= 0.5) return 40 * f - 30;
  if (f >= 0.25) return 80 * f - 50;
  if (f >= 0.0625) return 160 * f - 70;
  return 480 * f - 90;
}

int levelDbToIdx(double x, int n) {
  int r(double v) => (v + 0.5).floor().clamp(0, n);
  if (x <= -90) return 0;
  if (x >= -10) return r(n * (x + 30) / 40);
  if (x >= -30) return r(n * (x + 50) / 80);
  if (x >= -60) return r(n * (x + 70) / 160);
  return r(n * (x + 90) / 480);
}

/// Formato dei livelli nelle righe di nodo (doc 17 par. 4).
String formatLevel(double db) {
  if (db.abs() < 0.1) return '  0.0';
  if (db > -90) return _cFormat(db, width: 5, precision: 1, plus: true);
  return '  -oo';
}

// ----------------------------------------------------------- printf ridotto

final _fmtRe = RegExp(r'^%([+ ]?)(k?)(\d*)(?:\.(\d+))?(k?)([fd])$');

/// Formato `%d` e bitmask `%%%0Nb` dei parametri interi.
String formatInt(String format, int v) {
  final m = RegExp(r'^%%%0(\d+)b$').firstMatch(format);
  if (m != null) return '%${v.toRadixString(2).padLeft(int.parse(m.group(1)!), '0')}';
  return v.toString();
}

/// `sprintf` dei valori fisici con l'estensione `k` delle frequenze
/// (`%k1f`, `%.0kf`, `%.1kf`: oltre 1000 il punto decimale diventa `k`).
String formatNumber(String format, double x) {
  final m = _fmtRe.firstMatch(format);
  if (m == null) return x.toString();
  final plus = m.group(1) == '+';
  final k = m.group(2)!.isNotEmpty || m.group(5)!.isNotEmpty;
  var width = m.group(3)!.isEmpty ? 0 : int.parse(m.group(3)!);
  var precision = m.group(4) == null ? -1 : int.parse(m.group(4)!);
  if (k && m.group(2)!.isNotEmpty && precision < 0) {
    // "%k1f": la cifra dopo k è la precisione.
    precision = width;
    width = 0;
  }
  if (precision < 0) precision = 0;
  if (k && double.parse(x.toStringAsFixed(precision)).abs() >= 1000) {
    // Oltre 1000 Hz: una cifra decimale in più, troncata (riga reale "1k97" per 1977,2 Hz).
    final d = precision + 1;
    final scale = math.pow(10, d);
    final v = ((x / 1000) * scale + 1e-9).floor() / scale;
    return v.toStringAsFixed(d).replaceFirst('.', 'k');
  }
  if (width > 0 && m.group(4) != null && precision == 0 && !plus) {
    // "%4.0f": il mixer riserva il primo carattere al segno (come "% 3.0f").
    // Righe reali di release: " 258", " 35", "  5".
    final s = x.toStringAsFixed(0).padLeft(width - 1);
    return s.startsWith(' ') ? s : ' $s';
  }
  if (width > 0 && m.group(4) != null) {
    // Con larghezza e precisione il mixer riduce i decimali per restare nella larghezza,
    // troncando (righe reali di hold con "%4.2f": "50.2" per 50,24, "28.2" per 28,25, "10.0" per 10,02).
    for (var p = precision; p >= 0; p--) {
      final s = _cFormat(x, width: 0, precision: p, plus: plus);
      if (s.length <= width || p == 0) {
        if (p == precision) return s.padLeft(width);
        final scale = math.pow(10, p);
        final t = ((x.abs() * scale) + 1e-6).floor() / scale * x.sign;
        return _cFormat(t, width: width, precision: p, plus: plus);
      }
    }
  }
  return _cFormat(x, width: width, precision: precision, plus: plus);
}

String _cFormat(double x, {required int width, required int precision, bool plus = false}) {
  var s = x.toStringAsFixed(precision);
  if (s.startsWith('-') && double.parse(s) == 0) s = s.substring(1);
  if (plus && !s.startsWith('-')) s = '+$s';
  return s.padLeft(width);
}

/// Numero dal testo dei nodi (`124.7`, `1k97`, `10k4`, `+0.0`, `70%`).
double? parseNumberText(String t) {
  var s = t.trim();
  if (s.endsWith('%')) s = s.substring(0, s.length - 1);
  final ki = s.indexOf('k');
  if (ki >= 0) {
    final a = s.substring(0, ki);
    final b = s.substring(ki + 1);
    final v = double.tryParse('${a.isEmpty ? '0' : a}.${b.isEmpty ? '0' : b}');
    return v == null ? null : v * 1000;
  }
  return double.tryParse(s);
}
