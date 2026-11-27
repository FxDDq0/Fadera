import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'brand.g.dart';
import 'capture.dart';
import 'controller/app_controller.dart';
import 'error_handling.dart';
import 'controller/shortcuts.dart';
import 'theme.dart';
import 'ui/master_and_quick.dart';
import 'ui/pages/mixer_page.dart';
import 'ui/pages/other_pages.dart';
import 'ui/pages/fx_page.dart';
import 'ui/top_bar.dart';
import 'ui/dialogs/welcome_dialog.dart';
import 'ui/widgets/controls.dart';
import 'l10n/l10n.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  String? arg(String name) {
    for (final a in args) {
      if (a.startsWith('--$name=')) return a.substring(name.length + 3);
    }
    return null;
  }

  final captureDir = arg('capture');
  if (captureDir != null) {
    final lang = arg('lang'); // --lang=en: catture in un'altra lingua
    if (lang != null) captureLanguage = lang;
    runCapture(captureDir, int.tryParse(arg('sim-port') ?? '') ?? 10023);
    return;
  }
  // --demo: preferenze dimostrative non salvate; --connect=host[:porta]: connessione e sync automatiche
  final ctl = AppController(prefs: args.contains('--demo') ? capturePrefs() : null);
  installErrorHandlers(ctl);
  runApp(ControllerApp(controller: ctl, splash: true));
  final target = arg('connect');
  if (target != null) {
    final parts = target.split(':');
    () async {
      try {
        await ctl.connect(parts[0], port: parts.length > 1 ? int.parse(parts[1]) : 10023);
        await ctl.syncFromMixer((_, _) {}, () => false);
        ctl.select(ctl.stripsFor(Layer.ch1)[5]);
      } on Object catch (e) {
        ctl.log('E', tr('connessione automatica a {p0} non riuscita: {p1}', {'p0': target, 'p1': e}));
      }
    }();
  }
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key, required this.controller, this.splash = false});
  final AppController controller;

  /// Schermata iniziale con il marchio (solo all'avvio normale, non nei test né nelle catture).
  final bool splash;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L10n.current,
      builder: (context, lang, _) => MaterialApp(
        title: Brand.name,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: L10n.locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // al cambio di lingua ogni testo viene ridisegnato, senza chiudere le finestre aperte
        builder: (context, child) => LanguageRebuilder(child: child!),
        home: splash ? SplashGate(child: WelcomeGate(ctl: controller, child: HomeScreen(ctl: controller))) : HomeScreen(ctl: controller),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _clock = MeterClock();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // alla chiusura della finestra le preferenze in attesa vengono scritte subito
    _lifecycle = AppLifecycleListener(onExitRequested: () async {
      widget.ctl.prefs.saveNow();
      return AppExitResponse.exit;
    });
    widget.ctl.noticeTick.addListener(_showNotices);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNotices());
  }

  @override
  void dispose() {
    widget.ctl.noticeTick.removeListener(_showNotices);
    _lifecycle.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _showNotices() {
    if (!mounted) return;
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    final ctl = widget.ctl;
    while (ctl.pendingNotices.isNotEmpty) {
      final text = ctl.pendingNotices.removeAt(0);
      m.showSnackBar(SnackBar(
        content: Text(text, key: const ValueKey('notice')),
        duration: const Duration(seconds: 8),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeterTickerHost(
      clock: _clock,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, e) => handleShortcut(widget.ctl, e),
        child: Scaffold(
          body: ListenableBuilder(
            listenable: widget.ctl,
            builder: (context, _) {
              final ctl = widget.ctl;
              return Column(
                children: [
                  TopBar(ctl: ctl),
                  if (ctl.isSimulator) const _SimBanner(),
                  Expanded(
                    child: switch (ctl.page) {
                      AppPage.mixer => MixerPage(ctl: ctl, clock: _clock),
                      AppPage.dca => DcaPage(ctl: ctl, clock: _clock),
                      AppPage.effects => FxPage(ctl: ctl),
                      AppPage.routing => RoutingPage(ctl: ctl),
                      AppPage.scenes => ScenesPage(ctl: ctl),
                    },
                  ),
                  QuickBar(ctl: ctl),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fascia sempre visibile durante una sessione simulata: impossibile confonderla con un mixer reale.
class _SimBanner extends StatelessWidget {
  const _SimBanner();
  @override
  Widget build(BuildContext context) => Container(
    height: 18,
    color: AppColors.sim,
    alignment: Alignment.center,
    child: Text(
      tr('SESSIONE SIMULATA · 127.0.0.1 · nessun mixer reale collegato'),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8),
    ),
  );
}

/// Schermata iniziale: icona, nome, descrizione e versione per circa un secondo, poi l'app.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _done
          ? widget.child
          : Scaffold(
              key: const ValueKey('splash'),
              backgroundColor: Brand.background,
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/brand/icona_256.png', width: 112, height: 112),
                  const SizedBox(height: 18),
                  const Text(Brand.name, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1, color: Brand.foreground)),
                  const SizedBox(height: 6),
                  Text(Brand.tagline, style: TextStyle(fontSize: 14, color: Brand.foreground.withValues(alpha: 0.6))),
                  const SizedBox(height: 22),
                  Text(tr('Versione {p0}', {'p0': Brand.version}), style: TextStyle(fontSize: 12, color: Brand.foreground.withValues(alpha: 0.4))),
                ]),
              ),
            ),
    );
  }
}

/// Ridisegna tutta l'interfaccia (finestre aperte comprese) quando cambia la lingua,
/// perché i testi tradotti con tr vengono letti al momento del disegno.
class LanguageRebuilder extends StatefulWidget {
  const LanguageRebuilder({super.key, required this.child});
  final Widget child;
  @override
  State<LanguageRebuilder> createState() => _LanguageRebuilderState();
}

class _LanguageRebuilderState extends State<LanguageRebuilder> {
  @override
  void initState() {
    super.initState();
    L10n.current.addListener(_onLanguage);
  }

  @override
  void dispose() {
    L10n.current.removeListener(_onLanguage);
    super.dispose();
  }

  void _onLanguage() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    if (mounted) (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
