/// Modalità di cattura: l'eseguibile reale si collega al simulatore, esegue la sync e salva
/// immagini PNG della propria interfaccia a dimensioni logiche esatte (1600×700, 1920×1080,
/// 1366×768…). Le immagini sono prodotte dal motore grafico dell'app (stesso albero di
/// widget, stessi font di sistema), senza catturare lo schermo dell'utente.
///
/// Uso: Mixora.exe --capture=<cartella> [--sim-port=10023]
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import 'controller/app_controller.dart';
import 'controller/prefs.dart';
import 'main.dart';
import 'theme.dart';
import 'ui/side_panel.dart';
import 'package:x32_core/x32_core.dart';
import 'ui/master_and_quick.dart';
import 'ui/dialogs/settings_dialog.dart';
import 'ui/dialogs/personalize_dialog.dart';
import 'ui/icons/strip_icons.dart';
import 'ui/dialogs/icon_picker.dart';

class CaptureScenario {
  const CaptureScenario(this.name, this.size, this.setup, {this.textScale = 1.0, this.overlay});
  final String name;
  final Size size;
  final void Function(AppController ctl) setup;

  /// Scala del testo (impostazione "Dimensione testo" di Windows / accessibilità).
  final double textScale;

  /// Finestra di dialogo da mostrare sopra l'interfaccia (personalizzazione, editor EQ…).
  final Widget Function(AppController ctl)? overlay;
}

// ignore: unused_element
void _prefs(AppController c, void Function(Prefs p) f) {
  f(c.prefs);
  c.applyAppearance();
  c.refresh();
}

void _page(AppController c, Layer l, {int tab = PanelTab.channel, int sel = 5}) {
  c
    ..setPage(AppPage.mixer)
    ..setLayer(l)
    ..panelTab.value = tab;
  final strips = c.stripsFor(l);
  if (strips.isNotEmpty) c.select(strips[sel.clamp(0, strips.length - 1)]);
}

void _fxType(AppController c, int slot, String code) {
  final spec = c.state.specOf('/fx/$slot/type');
  final i = spec?.labels?.indexOf(code) ?? -1;
  if (i < 0 || c.state.fxTypeCode(slot) == code) return;
  c.setIdx('/fx/$slot/type', i);
  c.state.resetFxParams(slot, ChangeOrigin.load);
  c.hub.refreshAll();
}

final _scenarios = <CaptureScenario>[
  CaptureScenario('01_mixer_ch1-8_1920x1080', const Size(1920, 1080), (c) => _page(c, Layer.ch1)),
  CaptureScenario('02_mixer_ch17-24_1366x768', const Size(1366, 768), (c) => _page(c, Layer.ch17, sel: 0)),
  CaptureScenario('03_canale_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1)),
  CaptureScenario('04_eq_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1, tab: PanelTab.eq)),
  CaptureScenario('05_gate_1600x900', const Size(1600, 900), (c) {
    // simulatore: gate di ch 6 (strip selezionata) acceso con soglia alta, così l'indicatore GR mostra la chiusura
    c.state.setIdx('/ch/06/gate/on', 1);
    c.state.setIdx('/ch/06/gate/thr', c.state.specOf('/ch/06/gate/thr')!.idxFromPhysical(-8));
    _page(c, Layer.ch1, tab: PanelTab.gate);
  }),
  CaptureScenario('06_compressore_1600x900', const Size(1600, 900), (c) {
    // simulatore: compressore di ch 6 (strip selezionata) acceso con soglia −30 dB, ratio 4: l'indicatore GR lavora
    c.state.setIdx('/ch/06/dyn/on', 1);
    c.state.setIdx('/ch/06/dyn/thr', c.state.specOf('/ch/06/dyn/thr')!.idxFromPhysical(-30));
    c.state.setIdx('/ch/06/dyn/ratio', 6);
    _page(c, Layer.ch1, tab: PanelTab.comp);
  }),
  CaptureScenario('07_mandate_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1, tab: PanelTab.sends)),
  CaptureScenario('08_effetti_riverbero_1600x900', const Size(1600, 900), (c) => c
    ..fxSlot = 1
    ..setPage(AppPage.effects)),
  CaptureScenario('09_effetti_pitch_1600x900', const Size(1600, 900), (c) {
    _fxType(c, 3, 'PIT2');
    c
      ..fxSlot = 3
      ..setPage(AppPage.effects);
  }),
  CaptureScenario('10_effetti_eq_valvolare_1600x900', const Size(1600, 900), (c) {
    _fxType(c, 6, 'P1A');
    c.setIdx('/ch/05/insert/on', 1);
    final spec = c.state.specOf('/ch/05/insert/sel');
    final i = spec?.labels?.indexOf('FX6L') ?? -1;
    if (i >= 0) c.setIdx('/ch/05/insert/sel', i);
    c
      ..fxSlot = 6
      ..setPage(AppPage.effects);
  }),
  CaptureScenario('11_routing_panoramica_1600x900', const Size(1600, 900), (c) => c
    ..routingTab = 4
    ..setPage(AppPage.routing)),
  CaptureScenario('12_routing_user_1600x900', const Size(1600, 900), (c) => c
    ..routingTab = 5
    ..setPage(AppPage.routing)),
  CaptureScenario('13_routing_1366x768', const Size(1366, 768), (c) => c
    ..routingTab = 4
    ..setPage(AppPage.routing)),
  CaptureScenario('14_dca_1600x900', const Size(1600, 900), (c) => c.setPage(AppPage.dca)),
  CaptureScenario('15_scene_1600x900', const Size(1600, 900), (c) {
    for (final (i, n) in const [(0, 'Soundcheck'), (1, 'Concerto set 1'), (2, 'Concerto set 2'), (3, 'Bis')]) {
      c.client?.datasetSave('scene', i, n, '');
    }
    c.client?.requestShowDump();
    c.setPage(AppPage.scenes);
  }),
  CaptureScenario('16_personalizza_profili_1600x900', const Size(1600, 900), (c) {
    c.prefs.colorProfiles = {'Concerto': c.prefs.captureProfile(), 'Studio sobrio': {'theme': 'studio'}};
    _page(c, Layer.ch1);
  }, overlay: (c) => PersonalizeDialog(ctl: c, initialSection: 2)),
  CaptureScenario('17_personalizza_layer_utente_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1), overlay: (c) => PersonalizeDialog(ctl: c, initialSection: 4)),
  CaptureScenario('18_personalizza_canali_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1), overlay: (c) => PersonalizeDialog(ctl: c, initialSection: 1)),
  CaptureScenario('19_diagnostica_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1), overlay: (c) => SettingsDialog(ctl: c, initialTab: 2)),
  CaptureScenario('20_selettore_icone_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1, sel: 0), overlay: (c) => IconPickerDialog(ctl: c, strip: c.selected, preselect: 2)),
  CaptureScenario('21_quick_editor_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1), overlay: (c) => QuickEditor(ctl: c, initial: c.prefs.quick.first)),
  CaptureScenario('22_layer_utente_1600x900', const Size(1600, 900), (c) {
    c.prefs.bandStrips = ['/ch/17', '/ch/01', '/ch/02', '/ch/09', '/ch/11', '/fxrtn/01', '/bus/03'];
    _page(c, Layer.band, sel: 0);
  }),
  CaptureScenario('23_libreria_icone_1600x900', const Size(1600, 900), (c) => _page(c, Layer.ch1), overlay: (c) => const _IconLibrary()),
  CaptureScenario('24_mixer_16_fader_1920x1080', const Size(1920, 1080), (c) {
    c.setStripsPerPage(16);
    _page(c, Layer.ch1);
  }),
  CaptureScenario('25_mixer_16_fader_1366x768', const Size(1366, 768), (c) {
    c.setStripsPerPage(16);
    _page(c, Layer.ch17, sel: 0);
  }),
];

/// Tavola della libreria delle icone (solo per la documentazione): identificativo, disegno, nome.
class _IconLibrary extends StatelessWidget {
  const _IconLibrary();
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: Rd.brL,
        child: Container(
          width: 1520,
          padding: const EdgeInsets.all(Sp.l),
          decoration: BoxDecoration(borderRadius: Rd.brL, border: Border.all(color: AppColors.border)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Icone delle strip (config/icon, 1–74)', style: Tx.pageTitle),
            const SizedBox(height: Sp.s),
            Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
              for (final i in kStripIcons)
                Container(
                  width: 184,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.s),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    SizedBox(width: 22, child: Text('${i.id}', style: Tx.value.copyWith(fontSize: 11, color: AppColors.textDim))),
                    StripIconView(i.id, size: 28),
                    const SizedBox(width: Sp.s),
                    Expanded(child: Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                  ]),
                ),
            ]),
          ]),
        ),
      );
}

/// Preferenze dimostrative (non salvate): icone e barra rapida come nel riferimento.
/// Lingua delle catture (--lang=xx); senza parametro le catture sono in italiano.
String captureLanguage = 'it';

Prefs capturePrefs() {
  final p = Prefs()
    ..persistent = false
    ..language = captureLanguage;
  p.quickLayouts = {
    'Concerto': [
      QuickControl(path: '/ch/17/mix/on', label: 'Vox Lead · Mute', color: 0xFFD25FD6),
      QuickControl(path: '/ch/17/mix/fader', label: 'Vox Lead · Fader', color: 0xFFD25FD6),
      QuickControl(path: '/fxrtn/01/mix/fader', label: 'FX 1 · Ritorno', color: 0xFF3E7BFA),
      QuickControl(path: '/fxrtn/05/mix/fader', label: 'FX 3 · Ritorno', color: 0xFF3E7BFA),
      QuickControl(path: '/dca/1/fader', label: 'DCA Batteria', color: 0xFFE8C547),
      QuickControl(path: '/main/st/mix/on', label: 'Main · Mute', color: 0xFFDDE1E8),
    ],
  };
  p.activeQuickLayout = 'Concerto';
  p.bandStrips = ['/ch/17', '/ch/18', '/ch/01', '/ch/02', '/ch/09', '/ch/11'];
  return p;
}

Future<void> runCapture(String dir, int simPort) async {
  final ctl = AppController(prefs: capturePrefs());
  final host = _CaptureHostState.instance;
  final key = GlobalKey();
  final size = ValueNotifier<Size>(_scenarios.first.size);
  final textScale = ValueNotifier<double>(1.0);
  final overlay = ValueNotifier<Widget? Function(AppController)?>(null);
  runApp(_CaptureApp(ctl: ctl, boundaryKey: key, size: size, textScale: textScale, overlay: overlay));
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final log = File('$dir${Platform.pathSeparator}capture_log.txt').openWrite();
  try {
    final info = await ctl.connect('127.0.0.1', port: simPort);
    log.writeln('connesso: $info');
    final r = await ctl.syncFromMixer((_, _) {}, () => false);
    log.writeln('sync: ${r.completed}/${r.total} ok=${r.ok}');
    ctl.select(ctl.stripsFor(Layer.ch1)[5]); // Ch 06 come nel riferimento
    for (final s in _scenarios) {
      size.value = s.size;
      textScale.value = s.textScale;
      overlay.value = s.overlay;
      s.setup(ctl);
      await Future<void>.delayed(const Duration(milliseconds: 900)); // layout, animazioni, meter
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$dir${Platform.pathSeparator}${s.name}.png');
      await f.writeAsBytes(png!.buffer.asUint8List());
      log.writeln('${s.name}: ${image.width}x${image.height}, eccezioni di layout: ${host?.errors.length ?? 0}');
      host?.errors.clear();
    }
  } on Object catch (e, st) {
    log.writeln('ERRORE: $e\n$st');
  } finally {
    await log.close();
    await ctl.disconnect();
    exit(0);
  }
}

class _CaptureApp extends StatefulWidget {
  const _CaptureApp({required this.ctl, required this.boundaryKey, required this.size, required this.textScale, required this.overlay});
  final AppController ctl;
  final GlobalKey boundaryKey;
  final ValueNotifier<Size> size;
  final ValueNotifier<double> textScale;
  final ValueNotifier<Widget? Function(AppController)?> overlay;
  @override
  State<_CaptureApp> createState() => _CaptureHostState();
}

class _CaptureHostState extends State<_CaptureApp> {
  static _CaptureHostState? instance;
  final errors = <String>[];

  @override
  void initState() {
    super.initState();
    instance = this;
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d.exceptionAsString());
      prev?.call(d);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: Listenable.merge([widget.size, widget.textScale, widget.overlay]),
        builder: (context, _) {
          final s = widget.size.value;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(size: s, devicePixelRatio: 1.0, textScaler: TextScaler.linear(widget.textScale.value)),
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: s.width,
              maxWidth: s.width,
              minHeight: s.height,
              maxHeight: s.height,
              child: RepaintBoundary(
                key: widget.boundaryKey,
                child: Stack(children: [
                  Positioned.fill(child: HomeScreen(ctl: widget.ctl)),
                  if (widget.overlay.value != null) ...[
                    const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
                    Positioned.fill(child: Center(child: KeyedSubtree(key: ValueKey(identityHashCode(widget.overlay.value)), child: widget.overlay.value!(widget.ctl) ?? const SizedBox()))),
                  ],
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
