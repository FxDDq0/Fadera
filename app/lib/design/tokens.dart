import 'package:flutter/material.dart';

/// Sistema grafico di Fadera: un solo punto in cui sono definiti colori, palette delle strip,
/// tipografia, spaziature, raggi, ombre e dimensioni dei controlli.
///
/// I widget non devono usare colori o misure scritti a mano: usano [AppColors], [Sp], [Rd],
/// [Sz], [Tx] e [Shadows]. Cambiare tema (palette delle strip, accento) significa cambiare
/// [MxTheme.current] e ricostruire l'interfaccia.

/// Tema completo dell'interfaccia.
class MxTheme {
  const MxTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.strip,
    this.accent = const Color(0xFF4C9BFF),
    this.selection = const Color(0xFF4C9BFF),
    this.headerMix = 0.42,
  });

  final String id;
  final String name;
  final String description;

  /// Colori delle strip nell'ordine dell'enum `config/color` del mixer: OFF RD GN YE BL MG CY WH.
  final List<Color> strip;

  /// Colore dei controlli interattivi (manopole, schede attive, valori modificabili).
  final Color accent;

  /// Colore dell'elemento selezionato (strip, banda EQ, slot FX). Diverso da MUTE, SOLO ed errori.
  final Color selection;

  /// Quanto le intestazioni delle strip sono scurite rispetto al colore pieno (0 = pieno, 1 = nero).
  final double headerMix;

  MxTheme withStrip(List<Color> s) =>
      MxTheme(id: id, name: name, description: description, strip: s, accent: accent, selection: selection, headerMix: headerMix);

  // ---------------------------------------------------------------- temi pronti

  static const studio = MxTheme(
    id: 'studio',
    name: 'Studio',
    description: /*l10n*/ 'Colori da console: pieni ma poco saturi, per lunghe sessioni.',
    strip: [
      Color(0xFF5A6170), Color(0xFFB5524C), Color(0xFF4E9468), Color(0xFFC4A24A),
      Color(0xFF4B76B8), Color(0xFF9763A0), Color(0xFF3F95A3), Color(0xFFC3C8D0),
    ],
    headerMix: 0.48,
  );

  static const live = MxTheme(
    id: 'live',
    name: 'Live',
    description: /*l10n*/ 'Più luminosi, riconoscibili a colpo d\'occhio sul palco, senza toni fluorescenti.',
    strip: [
      Color(0xFF656D7D), Color(0xFFD0524B), Color(0xFF45A86E), Color(0xFFD8B23E),
      Color(0xFF4A86D6), Color(0xFFAE65B8), Color(0xFF34A8B8), Color(0xFFD9DDE3),
    ],
    headerMix: 0.4,
  );

  static const minimal = MxTheme(
    id: 'minimal',
    name: 'Minimal',
    description: /*l10n*/ 'Palette molto discreta: il colore resta solo un accenno.',
    strip: [
      Color(0xFF4E5564), Color(0xFF8C6466), Color(0xFF66806F), Color(0xFF8F8466),
      Color(0xFF657A99), Color(0xFF85708A), Color(0xFF63848A), Color(0xFF9AA0AC),
    ],
    headerMix: 0.62,
  );

  static const presets = [studio, live, minimal];

  /// Tema "Personalizzato": parte da Live e usa la palette salvata dall'utente.
  static MxTheme custom(List<int> palette) => MxTheme(
        id: 'custom',
        name: 'Personalizzato',
        description: /*l10n*/ 'Ogni colore scelto da te.',
        strip: palette.length == 8 ? [for (final c in palette) Color(c)] : live.strip,
        headerMix: 0.42,
      );

  static MxTheme byId(String id, List<int> customPalette) => switch (id) {
        'studio' => studio,
        'minimal' => minimal,
        'custom' => custom(customPalette),
        'live' => live,
        _ => studio,
      };

  /// Tema attivo. Impostato all'avvio dalle preferenze e quando l'utente cambia tema.
  static MxTheme current = studio;

  /// Colori locali scelti per singole strip (percorso base → colore). Solo sul PC.
  static Map<String, int> overrides = const {};
}

/// Colori dell'interfaccia. Le superfici sono fisse (tema scuro); palette delle strip,
/// accento e selezione vengono dal tema attivo.
abstract final class AppColors {
  // superfici, dal fondo verso l'alto
  static const bg = Color(0xFF0D1016);
  static const surface = Color(0xFF151921);
  static const surface2 = Color(0xFF1B2029);
  static const surface3 = Color(0xFF242A35);
  static const well = Color(0xFF090B10); // incavi: binari, meter, grafici
  static const border = Color(0xFF272E3A);
  static const borderStrong = Color(0xFF39414F);

  // testo
  static const text = Color(0xFFE7EAF0);
  static const textDim = Color(0xFF959DAE);
  static const textFaint = Color(0xFF5E6677);

  // stati: ognuno ha un colore proprio
  static const mute = Color(0xFFE5484D);
  static const solo = Color(0xFFF2C230);
  static const ok = Color(0xFF2FB56A);
  static const warn = Color(0xFFF08C2E);
  static const error = Color(0xFFFF5C7A);
  static const sim = Color(0xFF8E7CF0);

  // meter
  static const meterLow = Color(0xFF2FBF71);
  static const meterMid = Color(0xFFE8C547);
  static const meterHigh = Color(0xFFE5484D);

  static Color get accent => MxTheme.current.accent;
  static Color get selection => MxTheme.current.selection;
  static List<Color> get strip => MxTheme.current.strip;

  static Color stripColor(int? idx) => strip[(idx ?? 0) % 8];
  static bool stripInverted(int? idx) => (idx ?? 0) >= 8;

  /// Colore di una strip: colore locale se l'utente l'ha scelto, altrimenti la palette del tema.
  static Color stripColorFor(String base, int? idx) {
    final o = MxTheme.overrides[base];
    return o != null ? Color(o) : stripColor(idx);
  }

  /// Intestazione della strip: tonalità scurita del colore, secondo il tema.
  static Color header(Color c) => Color.lerp(c, const Color(0xFF0F1218), MxTheme.current.headerMix)!;

  /// Testo leggibile sopra un colore pieno.
  static Color onColor(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF0D1016) : Colors.white;

  /// Colori delle bande EQ (1–6) e delle serie nei grafici: distinti tra loro e dagli stati.
  static const series = [
    Color(0xFFFF7A59), Color(0xFFF5B83D), Color(0xFF7BD389), Color(0xFF39C6E0), Color(0xFF7C8CFF), Color(0xFFE07BE0),
  ];
}

/// Densità dell'interfaccia: in modalità touch controlli, cursori e barre crescono del 30 %.
abstract final class MxDensity {
  static bool touch = false;
  static double get k => touch ? 1.3 : 1.0;
  static double s(double v) => v * k;
}

/// Spaziature (multipli di 4).
abstract final class Sp {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

/// Raggi degli angoli.
abstract final class Rd {
  static const s = 4.0;
  static const m = 6.0;
  static const l = 10.0;
  static const brS = BorderRadius.all(Radius.circular(s));
  static const brM = BorderRadius.all(Radius.circular(m));
  static const brL = BorderRadius.all(Radius.circular(l));
}

/// Dimensioni standard dei controlli.
abstract final class Sz {
  static const controlS = 24.0;
  static const controlM = 28.0;
  static const controlL = 32.0;
  static const topBar = 48.0;
  static const quickBar = 64.0;

  /// Strip del mixer: sotto la larghezza minima la fila scorre invece di comprimersi.
  static const stripMin = 60.0;
  static const stripMax = 150.0;
  static const masterWidth = 112.0;

  /// Cursore del fader (altezza totale dell'area di presa).
  static const faderCap = 34.0;
}

/// Stili di testo.
abstract final class Tx {
  static const family = 'Segoe UI';
  static const monoFamily = 'Consolas';

  /// Titolo di sezione: MAIUSCOLO, piccolo, spaziato.
  static const section = TextStyle(fontFamily: family, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AppColors.textDim);

  /// Etichetta di un controllo.
  static const label = TextStyle(fontFamily: family, fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textDim);

  /// Testo secondario, note.
  static const caption = TextStyle(fontFamily: family, fontSize: 11, color: AppColors.textFaint);

  static const body = TextStyle(fontFamily: family, fontSize: 13, color: AppColors.text);
  static const strong = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text);
  static const title = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text);
  static const pageTitle = TextStyle(fontFamily: family, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text);

  /// Valori numerici: carattere a spaziatura fissa con cifre tabellari.
  static const value = TextStyle(fontFamily: monoFamily, fontSize: 12, color: AppColors.text, fontFeatures: [FontFeature.tabularFigures()]);
}

/// Ombre ed effetti luminosi.
abstract final class Shadows {
  static const panel = [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))];
  static const cap = [BoxShadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 2))];
  static List<BoxShadow> glow(Color c, [double a = 0.35]) => [BoxShadow(color: c.withValues(alpha: a), blurRadius: 10)];
}
