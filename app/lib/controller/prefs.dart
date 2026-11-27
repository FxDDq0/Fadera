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
    // Prima esecuzione col nuovo nome: si copiano le preferenze dei nomi precedenti
    // (Mixora, poi X32Remote), così l'utente ritrova temi, layout e profili.
    for (final previous in const ['Mixora', 'X32Remote']) {
      final old = File('$base${Platform.pathSeparator}$previous${Platform.pathSeparator}prefs.json');
      if (env['FLUTTER_TEST'] != 'true' && previous != Brand.appDataFolder && old.existsSync()) {
        try {
          old.copySync('${d.path}${Platform.pathSeparator}prefs.json');
        } on Object {
          // preferenze precedenti illeggibili: si riparte dai valori predefiniti
        }
        break;
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

  /// File delle preferenze; nei test si passa un file in una cartella temporanea.
  Prefs({File? file}) : _fileOverride = file;
  final File? _fileOverride;
  File get _file => _fileOverride ?? File('${appDataDir().path}${Platform.pathSeparator}prefs.json');
  Timer? _saveTimer;

  /// Esito della lettura: file illeggibile, impostazioni non valide, copia del file originale.
  bool loadUnreadable = false;
  final List<String> loadBadFields = [];
  String? corruptCopyPath;

  /// Descrizione del problema di lettura per il registro (null se tutto è a posto).
  String? get loadError => loadUnreadable
      ? 'preferenze non leggibili: uso i valori predefiniti${corruptCopyPath != null ? '; copia: $corruptCopyPath' : ''}'
      : loadBadFields.isNotEmpty
          ? 'impostazioni non valide riportate al valore predefinito: ${loadBadFields.join(', ')}${corruptCopyPath != null ? '; copia: $corruptCopyPath' : ''}'
          : null;

  /// Ultimo errore di salvataggio (null dopo un salvataggio riuscito).
  String? saveError;

  /// Chiamata quando un salvataggio fallisce (il controller la scrive nel registro).
  void Function(String message)? onSaveError;

  /// Legge le preferenze. Ogni impostazione è letta da sola: un valore sbagliato torna al
  /// predefinito senza azzerare le altre. Il file guasto viene conservato accanto
  /// (`prefs.json.corrupt-<data>`) prima che un salvataggio lo sovrascriva.
  static Prefs load({File? file}) {
    final p = Prefs(file: file);
    final f = p._file;
    final String text;
    try {
      if (!f.existsSync()) return p;
      // un file di preferenze sano pesa pochi KB: oltre 1 MB non viene nemmeno letto
      if (f.lengthSync() > 1024 * 1024) throw const FileSystemException('file troppo grande');
      text = f.readAsStringSync();
    } on Object {
      p.loadUnreadable = true;
      return p;
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(text) as Map<String, dynamic>;
    } on Object {
      p.loadUnreadable = true;
      p._keepCorrupt(text);
      return p;
    }
    final bad = p.loadBadFields;
    void read(String key, void Function(Object? v) apply) {
      if (!j.containsKey(key)) return;
      try {
        apply(j[key]);
      } on Object {
        bad.add(key);
      }
    }

    read('lastHost', (v) => p.lastHost = v as String);
    read('autoReconnect', (v) => p.autoReconnect = v as bool);
    read('welcomeDone', (v) => p.welcomeDone = v as bool);
    read('language', (v) => p.language = v as String);
    read('selectedFollowsMixer', (v) => p.selectedFollowsMixer = v as bool);
    read('uiScale', (v) => p.uiScale = _clampD((v as num).toDouble(), 0.5, 2.5, 1.0));
    read('quickLayouts', (v) {
      final layouts = {
        for (final e in (v as Map<String, dynamic>).entries)
          e.key: [for (final q in e.value as List) QuickControl.fromJson(q as Map<String, dynamic>)],
      };
      if (layouts.isNotEmpty) p.quickLayouts = layouts;
    });
    read('activeQuickLayout', (v) => p.activeQuickLayout = v as String);
    if (!p.quickLayouts.containsKey(p.activeQuickLayout)) p.activeQuickLayout = p.quickLayouts.keys.first;
    read('bandStrips', (v) => p.bandStrips = [for (final s in v as List) s as String]);
    read('experimentalRecallScope', (v) => p.experimentalRecallScope = v as bool);
    read('scopeExcluded', (v) => p.scopeExcluded = [for (final s in v as List) s as String]);
    read('safeStrips', (v) => p.safeStrips = [for (final s in v as List) s as String]);
    read('shortcuts', (v) => p.shortcuts = {for (final e in (v as Map<String, dynamic>).entries) e.key: (e.value as num).toInt()});
    read('colorTheme', (v) => p.colorTheme = v as String);
    read('customPalette', (v) => p.customPalette = [for (final c in v as List) (c as num).toInt()]);
    read('stripColorOverride', (v) => p.stripColorOverride = {for (final e in (v as Map<String, dynamic>).entries) e.key: (e.value as num).toInt()});
    read('colorProfiles', (v) => p.colorProfiles = {for (final e in (v as Map<String, dynamic>).entries) e.key: e.value as Map<String, dynamic>});
    read('touchMode', (v) => p.touchMode = const ['auto', 'on', 'off'].contains(v) ? v as String : throw FormatException('touchMode: $v'));
    read('stripsPerPage', (v) => p.stripsPerPage = (v as num).toInt() == 16 ? 16 : 8);
    read('quickSlots', (v) {
      final n = (v as num).toInt();
      p.quickSlots = const [8, 10, 12, 16].contains(n) ? n : 12;
    });
    read('quickBarLarge', (v) => p.quickBarLarge = v as bool);
    read('meterPeakHoldMs', (v) {
      final n = (v as num).toInt();
      p.meterPeakHoldMs = n == -1 ? -1 : n.clamp(0, 10000);
    });
    read('meterFall', (v) => p.meterFall = _clampD((v as num).toDouble(), 1, 200, 26));
    read('meterPeakReadout', (v) => p.meterPeakReadout = v as bool);
    if (bad.isNotEmpty) p._keepCorrupt(text);
    return p;
  }

  static double _clampD(double v, double lo, double hi, double fallback) => v.isFinite ? v.clamp(lo, hi) : fallback;

  /// Conserva il contenuto originale accanto al file (prima che un salvataggio lo sostituisca).
  void _keepCorrupt(String text) {
    try {
      final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '');
      final copy = File('${_file.path}.corrupt-$ts');
      copy.writeAsStringSync(text);
      // al massimo tre copie: un file che resta guasto non riempie la cartella a ogni avvio
      final name = '${_file.uri.pathSegments.last}.corrupt-';
      final old = _file.parent.listSync().whereType<File>().where((f) => f.uri.pathSegments.last.startsWith(name)).toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final f in old.skip(3)) {
        f.deleteSync();
      }
      corruptCopyPath = copy.path;
    } on Object {
      corruptCopyPath = null;
    }
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

  /// Scrittura atomica (file temporaneo poi rinomina). Restituisce falso se non è riuscita:
  /// l'errore resta in [saveError] e viene segnalato con [onSaveError], mai come eccezione.
  bool saveNow() {
    _saveTimer?.cancel();
    if (!persistent) return true;
    final tmp = File('${_file.path}.tmp');
    try {
      tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
      tmp.renameSync(_file.path);
      saveError = null;
      return true;
    } on Object catch (e) {
      saveError = 'preferenze non salvate: $e';
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } on Object {
        // il file temporaneo resta: verrà sovrascritto al prossimo salvataggio
      }
      onSaveError?.call(saveError!);
      return false;
    }
  }
}
