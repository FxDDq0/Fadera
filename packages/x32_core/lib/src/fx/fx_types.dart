/// Tipi di effetto e parametri (Appendice C).
library;

import '../schema/param.dart';

class FxParamDef {
  const FxParamDef({
    required this.index,
    required this.name,
    required this.min,
    required this.max,
    required this.n,
    required this.format,
    required this.unit,
    required this.defaultValue,
    required this.labels,
  });

  /// Posizione 1..64 in `/fx/N/par/KK`.
  final int index;
  final String name;
  final double min;
  final double max;

  /// `n > 0` lineare (N = n−1), `n < 0` logaritmico (N = −n−1), formato vuoto = enum (N = n−1).
  final int n;
  final String format;

  /// Codice unità: 1 ms, 2 s, 3 Hz (verificati), 4 dB, 5 % (dedotti).
  final int unit;
  final double defaultValue;
  final List<String>? labels;

  String get unitLabel => switch (unit) { 1 => 'ms', 2 => 's', 3 => 'Hz', 4 => 'dB', 5 => '%', _ => '' };

  ParamSpec toSpec() {
    final key = index.toString().padLeft(2, '0');
    if (format.isEmpty) return ParamSpec.enumeration(key, labels!);
    final conf = (unit == 4 || unit == 5) ? Confidence.deduced : Confidence.binary;
    if (n < 0) return ParamSpec.logf(key, min, max, -n - 1, format, unit: unitLabel, confidence: conf);
    return ParamSpec.linf(key, min, max, n - 1, format, unit: unitLabel, confidence: conf);
  }

  int get defaultIdx => toSpec().idxFromPhysical(defaultValue);
}

class FxTypeDef {
  const FxTypeDef({
    required this.code,
    required this.internalIndex,
    required this.editorGroup,
    required this.flag,
    required this.params,
  });

  final String code;
  final int internalIndex;
  final int editorGroup;
  final int flag;
  final List<FxParamDef> params;

  /// Effetto "doppio" (flag 0x100: GEQ2, TEQ2, …), occupa due unità.
  bool get isDual => (flag & 0x100) != 0;
}
