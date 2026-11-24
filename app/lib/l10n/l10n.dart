/// Lingue dell'interfaccia.
///
/// Il testo italiano scritto nel codice è la chiave: `tr('Connetti')` restituisce la traduzione nella
/// lingua attiva (da `translations.g.dart`, generato da `app/l10n/<lingua>.json` con
/// `tools/gen_l10n.py`) oppure l'italiano se manca. I valori variabili si passano come segnaposto:
/// `tr('Versione {v}', {'v': kAppVersion})`.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;

import 'translations.g.dart';

/// Lingue disponibili: codice e nome nella lingua stessa.
const kLanguages = <(String, String)>[
  ('it', 'Italiano'),
  ('en', 'English'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('de', 'Deutsch'),
  ('pt', 'Português'),
];

abstract final class L10n {
  /// Lingua attiva (codice di due lettere). Cambia → l'interfaccia si ricostruisce.
  static final ValueNotifier<String> current = ValueNotifier<String>('it');

  static String get lang => current.value;
  static Locale get locale => Locale(lang);
  static List<Locale> get supportedLocales => [for (final (c, _) in kLanguages) Locale(c)];

  /// Lingua del sistema, se supportata; altrimenti inglese.
  static String systemLanguage([String? localeName]) {
    // nei test automatici la lingua è sempre l'italiano (i test controllano i testi originali)
    if (localeName == null && _underTest) return 'it';
    final name = (localeName ?? _platformLocale()).toLowerCase();
    final code = name.length >= 2 ? name.substring(0, 2) : '';
    return kLanguages.any((l) => l.$1 == code) ? code : 'en';
  }

  static bool get _underTest {
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } on Object {
      return false;
    }
  }

  static String _platformLocale() {
    try {
      return Platform.localeName;
    } on Object {
      return 'en';
    }
  }

  /// Applica la preferenza: un codice di lingua oppure 'system'.
  static void apply(String preference) {
    current.value = preference == 'system' || !kLanguages.any((l) => l.$1 == preference) ? systemLanguage() : preference;
  }
}

/// Traduce un testo dell'interfaccia (chiave = testo italiano). [args] sostituisce i segnaposto `{nome}`.
String tr(String it, [Map<String, Object?> args = const {}]) {
  var s = it;
  if (L10n.lang != 'it') {
    final t = kTranslations[L10n.lang]?[it];
    if (t != null && t.isNotEmpty) s = t;
  }
  if (args.isNotEmpty) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  }
  return s;
}
