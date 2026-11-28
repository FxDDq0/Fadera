/// Ambito di richiamo per l'invio di file di scena dal PC (doc 06 par. 3.5).
///
/// X32-Edit, prima di inviare un file di scena, scarta le righe in base al prefisso e
/// a maschere di bit. Qui la stessa logica è
/// esposta come categorie leggibili; la corrispondenza bit → nome è dedotta (classe B).
/// Agisce solo sulle righe inviate dal PC, non sulle impostazioni safe del mixer.
library;

// Espressioni regolari compilate una volta sola (prima ricreate a ogni chiamata, migliaia all'avvio).
final _re1 = RegExp(r'\s');
final _re2 = RegExp(r'^/(ch|auxin)/\d\d/preamp');
final _re3 = RegExp(r'^/(ch|auxin|fxrtn)/');

enum ScopeCategory {
  inputs('Canali, aux in, FX return (mix, EQ, dinamiche…)'),
  preamp('Preamplificatori (preamp, headamp)'),
  buses('Bus'),
  matrixMain('Matrici e main'),
  dca('DCA'),
  effects('Effetti'),
  outputs('Patch delle uscite'),
  routing('Routing (/config/routing)'),
  talkback('Talkback'),
  config('Altre configurazioni (/config)');

  const ScopeCategory(this.label);
  final String label;
}

class RecallScope {
  RecallScope({Set<ScopeCategory>? enabled, Set<String>? safeStrips})
      : enabled = enabled ?? ScopeCategory.values.toSet(),
        safeStrips = safeStrips ?? <String>{};

  /// Categorie incluse nel richiamo.
  final Set<ScopeCategory> enabled;

  /// Strip protette (percorsi base, es. "/ch/05"): le loro righe non vengono inviate.
  final Set<String> safeStrips;

  /// Categoria di una riga di nodo, oppure `null` per le righe sempre scartate
  /// (stati `/-…`, righe non valide).
  static ScopeCategory? categoryOf(String line) {
    final t = line.trimLeft();
    if (!t.startsWith('/') || t.startsWith('/-')) return null;
    final path = t.split(_re1).first;
    if (_re2.hasMatch(path) || path.startsWith('/headamp')) return ScopeCategory.preamp;
    if (_re3.hasMatch(path)) return ScopeCategory.inputs;
    if (path.startsWith('/bus/')) return ScopeCategory.buses;
    if (path.startsWith('/mtx/') || path.startsWith('/main/')) return ScopeCategory.matrixMain;
    if (path.startsWith('/dca/')) return ScopeCategory.dca;
    if (path.startsWith('/fx/')) return ScopeCategory.effects;
    if (path.startsWith('/outputs/')) return ScopeCategory.outputs;
    if (path.startsWith('/config/routing') || path.startsWith('/config/userrout')) return ScopeCategory.routing;
    if (path.startsWith('/config/talk')) return ScopeCategory.talkback;
    if (path.startsWith('/config/')) return ScopeCategory.config;
    return ScopeCategory.config;
  }

  static final _stripRe = RegExp(r'^(/(?:ch|auxin|fxrtn|bus|mtx)/\d\d|/main/(?:st|m)|/dca/\d)');

  bool accepts(String line) {
    final c = categoryOf(line);
    if (c == null || !enabled.contains(c)) return false;
    final path = line.trimLeft().split(_re1).first;
    final m = _stripRe.firstMatch(path);
    if (m != null && safeStrips.contains(m.group(1))) return false;
    return true;
  }

  /// Righe da inviare (l'intestazione `#…` e le righe vuote vengono sempre escluse).
  List<String> filter(Iterable<String> lines) => [for (final l in lines) if (accepts(l)) l.trim()];
}
