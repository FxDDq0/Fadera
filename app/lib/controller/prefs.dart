import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../brand.g.dart';

/// Cartella dei dati dell'applicazione (preferenze, backup, log).
/// Windows: %APPDATA%\<Brand.appDataFolder>. Altre piattaforme: cartella home o temporanea.
/// Cartella propria dell'app: non condivide nulla con X32-Edit.
Directory appDataDir() {
  final env = Platform.environment;
  // I test automatici usano una cartella temporanea: non toccano i dati reali dell'utente.
  final base = env['FLUTTER_TEST'] == 'true'
      ? '${Directory.systemTemp.path}${Platform.pathSeparator}x32remote_test'
      : (env['APPDATA'] ?? env['HOME'] ?? Directory.systemTemp.path);
  final d = Directory('$base${Platform.pathSeparator}${Brand.appDataFolder}');
  if (!d.existsSync()) {
    d.createSync(recursive: true);
    // Prima esecuzione col nuovo nome: si copiano le preferenze della versione precedente (nome provvisorio).
    final old = File('$base${Platform.pathSeparator}X32Remote${Platform.pathSeparator}prefs.json');
    if (env['FLUTTER_TEST'] != 'true' && old.existsSync()) {
      try {
        old.copySync('${d.path}${Platform.pathSeparator}prefs.json');
      } on Object {
        // preferenze precedenti illeggibili: si riparte dai valori predefiniti
      }
    }
  }
  return d;
}

String appSubDirPath(String name) => appSubDir(name).path;

Directory appSubDir(String name) {
  final d = Directory('${appDataDir().path}${Platform.pathSeparator}$name');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

/// Un controllo rapido della barra inferiore.
class QuickControl {
  QuickControl({required this.path, required this.label, this.color = 0xFF3E7BFA, this.wide = false});
  String path;
  String label;
  int color;

  /// Occupa due caselle della barra.
  bool wide;

  Map<String, Object> toJson() => {'path': path, 'label': label, 'color': color, 'wide': wide};
  QuickControl copy() => QuickControl(path: path, label: label, color: color, wide: wide);
  static QuickControl fromJson(Map<String, dynamic> j) => QuickControl(
      path: j['path'] as String, label: j['label'] as String, color: (j['color'] as num?)?.toInt() ?? 0xFF3E7BFA, wide: j['wide'] as bool? ?? false);
}

/// Preferenze locali, salvate in JSON (mai inviate al mixer).
class Prefs {
  String lastHost = '';
  bool autoReconnect = true;

  /// Falso finché l'utente non ha visto la schermata di benvenuto (primo avvio).
  bool welcomeDone = false;

  /// Lingua dell'interfaccia: 'system' (lingua di Windows) oppure un codice (it, en, es, fr, de, pt).
  String language = 'system';
  bool selectedFollowsMixer = false;
  double uiScale = 1.0;

  /// Layout della barra rapida: nome → controlli.
  Map<String, List<QuickControl>> quickLayouts = {'Predefinito': []};
  String activeQuickLayout = 'Predefinito';

  /// Canali della vista "Band" (percorsi base, es. "/ch/01").
  List<String> bandStrips = [];


  /// Scorciatoie personalizzate: nome dell'azione → id del tasto (LogicalKeyboardKey.keyId).
  Map<String, int> shortcuts = {};

  /// Ambito di richiamo per l'invio di file di scena: categorie escluse e strip protette.
  /// Funzione sperimentale (categorie ricostruite, non verificate): disattivata per impostazione predefinita.
  bool experimentalRecallScope = false;
  List<String> scopeExcluded = [];
  List<String> safeStrips = [];

  /// Aspetto: tema dei colori (studio, live, minimal, custom), palette personalizzata
  /// (8 colori nell'ordine del mixer OFF RD GN YE BL MG CY WH), colori locali per strip
  /// (percorso base → ARGB, solo sul PC) e configurazioni di colore salvate.
  String colorTheme = 'studio';
  List<int> customPalette = [];
  Map<String, int> stripColorOverride = {};
  Map<String, Map<String, dynamic>> colorProfiles = {};

  /// Modalità touch: 'auto' (attiva su tablet e telefoni), 'on', 'off'.
  String touchMode = 'auto';

  /// Fader per pagina degli ingressi: 8 (Ch 1–8 … 25–32) o 16 (Ch 1–16, 17–32).
  int stripsPerPage = 8;

  /// Barra rapida: caselle visibili (8, 10, 12, 16) e altezza maggiore.
  int quickSlots = 12;
  bool quickBarLarge = false;

  /// Meter: tenuta del picco in ms (0 = nessuna, −1 = tenuto), discesa in dB/s, valore del picco nelle strip.
  int meterPeakHoldMs = 1500;
  double meterFall = 26;
  bool meterPeakReadout = false;

  /// Profilo completo dell'aspetto (tutto ciò che è solo sul PC), per Personalizzazione → Profili.
  Map<String, dynamic> captureProfile() => {
        'theme': colorTheme,
        'custom': [...customPalette],
        'overrides': {...stripColorOverride},
        'quickLayouts': {for (final e in quickLayouts.entries) e.key: [for (final q in e.value) q.toJson()]},
        'activeQuickLayout': activeQuickLayout,
        'quickSlots': quickSlots,
        'quickBarLarge': quickBarLarge,
        'bandStrips': [...bandStrips],
        'touchMode': touchMode,
        'stripsPerPage': stripsPerPage,
        'meterPeakHoldMs': meterPeakHoldMs,
        'meterFall': meterFall,
        'meterPeakReadout': meterPeakReadout,
      };

  /// Applica un profilo; i campi assenti (profili salvati con versioni precedenti) restano invariati.
  void applyProfile(Map<String, dynamic> v) {
    colorTheme = v['theme'] as String? ?? colorTheme;
    if (v['custom'] is List) customPalette = [for (final c in v['custom'] as List) (c as num).toInt()];
    if (v['overrides'] is Map) stripColorOverride = {for (final o in (v['overrides'] as Map).entries) o.key as String: (o.value as num).toInt()};
    if (v['quickLayouts'] is Map) {
      quickLayouts = {
        for (final e in (v['quickLayouts'] as Map).entries) e.key as String: [for (final q in e.value as List) QuickControl.fromJson(Map<String, dynamic>.from(q as Map))],
      };
      if (quickLayouts.isEmpty) quickLayouts = {'Predefinito': []};
      activeQuickLayout = v['activeQuickLayout'] as String? ?? quickLayouts.keys.first;
      if (!quickLayouts.containsKey(activeQuickLayout)) activeQuickLayout = quickLayouts.keys.first;
    }
    quickSlots = (v['quickSlots'] as num?)?.toInt() ?? quickSlots;
    quickBarLarge = v['quickBarLarge'] as bool? ?? quickBarLarge;
    if (v['bandStrips'] is List) bandStrips = [for (final b in v['bandStrips'] as List) b as String];
    touchMode = v['touchMode'] as String? ?? touchMode;
    stripsPerPage = v['stripsPerPage'] as int? ?? stripsPerPage;
    meterPeakHoldMs = (v['meterPeakHoldMs'] as num?)?.toInt() ?? meterPeakHoldMs;
    meterFall = (v['meterFall'] as num?)?.toDouble() ?? meterFall;
    meterPeakReadout = v['meterPeakReadout'] as bool? ?? meterPeakReadout;
  }

  List<QuickControl> get quick => quickLayouts.putIfAbsent(activeQuickLayout, () => []);

  File get _file => File('${appDataDir().path}${Platform.pathSeparator}prefs.json');
  Timer? _saveTimer;

  static Prefs load() {
    final p = Prefs();
    try {
      final f = p._file;
      if (f.existsSync()) {
        final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        p.lastHost = j['lastHost'] as String? ?? '';
        p.autoReconnect = j['autoReconnect'] as bool? ?? true;
        p.welcomeDone = j['welcomeDone'] as bool? ?? false;
        p.language = j['language'] as String? ?? 'system';
        p.selectedFollowsMixer = j['selectedFollowsMixer'] as bool? ?? false;
        p.uiScale = (j['uiScale'] as num?)?.toDouble() ?? 1.0;
        final ql = j['quickLayouts'] as Map<String, dynamic>?;
        if (ql != null) {
          p.quickLayouts = {
            for (final e in ql.entries) e.key: [for (final q in e.value as List) QuickControl.fromJson(q as Map<String, dynamic>)],
          };
        }
        p.activeQuickLayout = j['activeQuickLayout'] as String? ?? p.quickLayouts.keys.first;
        p.bandStrips = [for (final s in (j['bandStrips'] as List? ?? const [])) s as String];
        p.experimentalRecallScope = j['experimentalRecallScope'] as bool? ?? false;
        p.scopeExcluded = [for (final s in (j['scopeExcluded'] as List? ?? const [])) s as String];
        p.safeStrips = [for (final s in (j['safeStrips'] as List? ?? const [])) s as String];
        p.shortcuts = {for (final e in (j['shortcuts'] as Map<String, dynamic>? ?? const {}).entries) e.key: (e.value as num).toInt()};
        p.colorTheme = j['colorTheme'] as String? ?? 'studio';
        p.customPalette = [for (final c in (j['customPalette'] as List? ?? const [])) (c as num).toInt()];
        p.stripColorOverride = {for (final e in (j['stripColorOverride'] as Map<String, dynamic>? ?? const {}).entries) e.key: (e.value as num).toInt()};
        p.colorProfiles = {for (final e in (j['colorProfiles'] as Map<String, dynamic>? ?? const {}).entries) e.key: e.value as Map<String, dynamic>};
        p.touchMode = j['touchMode'] as String? ?? 'auto';
        p.stripsPerPage = (j['stripsPerPage'] as int? ?? 8) == 16 ? 16 : 8;
        p.quickSlots = (j['quickSlots'] as num?)?.toInt() ?? 12;
        p.quickBarLarge = j['quickBarLarge'] as bool? ?? false;
        p.meterPeakHoldMs = (j['meterPeakHoldMs'] as num?)?.toInt() ?? 1500;
        p.meterFall = (j['meterFall'] as num?)?.toDouble() ?? 26;
        p.meterPeakReadout = j['meterPeakReadout'] as bool? ?? false;
      }
    } on Object {
      // preferenze illeggibili: si riparte dai valori predefiniti (il file resta per l'analisi)
    }
    return p;
  }

  Map<String, Object> toJson() => {
        'lastHost': lastHost,
        'autoReconnect': autoReconnect,
        'welcomeDone': welcomeDone,
        'language': language,
        'selectedFollowsMixer': selectedFollowsMixer,
        'uiScale': uiScale,
        'quickLayouts': {for (final e in quickLayouts.entries) e.key: [for (final q in e.value) q.toJson()]},
        'activeQuickLayout': activeQuickLayout,
        'bandStrips': bandStrips,
        'shortcuts': shortcuts,
        'experimentalRecallScope': experimentalRecallScope,
        'scopeExcluded': scopeExcluded,
        'safeStrips': safeStrips,
        'colorTheme': colorTheme,
        'customPalette': customPalette,
        'stripColorOverride': stripColorOverride,
        'colorProfiles': colorProfiles,
        'touchMode': touchMode,
        'stripsPerPage': stripsPerPage,
        'quickSlots': quickSlots,
        'quickBarLarge': quickBarLarge,
        'meterPeakHoldMs': meterPeakHoldMs,
        'meterFall': meterFall,
        'meterPeakReadout': meterPeakReadout,
      };

  /// Salvataggio ritardato (raggruppa modifiche ravvicinate). Scrittura atomica.
  /// Falso per sessioni dimostrative o di cattura: nessuna scrittura su disco.
  bool persistent = true;

  void save() {
    if (!persistent) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), saveNow);
  }

  void saveNow() {
    if (!persistent) return;
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
    tmp.renameSync(_file.path);
  }
}
