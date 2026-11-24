import 'package:flutter/material.dart';

import '../../brand.g.dart';
import '../../controller/app_controller.dart';
import '../../theme.dart';
import 'connect_dialog.dart';
import '../widgets/language_picker.dart';
import 'sync_dialog.dart';
import '../../l10n/l10n.dart';

/// Mostra la schermata di benvenuto al primo avvio (una sola volta).
class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key, required this.ctl, required this.child});
  final AppController ctl;
  final Widget child;
  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  @override
  void initState() {
    super.initState();
    if (!widget.ctl.prefs.welcomeDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showWelcome(context, widget.ctl);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Apre la schermata di benvenuto (anche dalle Impostazioni, per rivederla).
Future<void> showWelcome(BuildContext context, AppController ctl) async {
  final choice = await showDialog<String>(context: context, barrierDismissible: false, builder: (_) => WelcomeDialog(ctl: ctl));
  ctl.prefs.welcomeDone = true;
  ctl.prefs.save();
  if (!context.mounted) return;
  switch (choice) {
    case 'search':
      await showDialog(context: context, builder: (_) => ConnectDialog(ctl: ctl));
    case 'sim':
      await startDemo(context, ctl);
  }
}

/// Avvia il simulatore integrato e la sincronizzazione (lettura), con un messaggio chiaro se non riesce.
Future<void> startDemo(BuildContext context, AppController ctl) async {
  try {
    await ctl.connectBuiltinSimulator();
    if (!context.mounted) return;
    await showDialog(context: context, barrierDismissible: false, builder: (_) => SyncDialog(ctl: ctl));
  } on Object catch (e) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Simulatore non avviato')),
        content: Text(tr('Il simulatore integrato non è partito: {p0}', {'p0': e})),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Chiudi')))],
      ),
    );
  }
}

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key, required this.ctl});
  final AppController ctl;

  @override
  Widget build(BuildContext context) {
    Widget step(String n, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(11)),
              child: Text(n, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
              ]),
            ),
          ]),
        );
    return AlertDialog(
      key: const ValueKey('welcome'),
      title: Row(children: [
        Image.asset('assets/brand/icona_256.png', width: 36, height: 36),
        const SizedBox(width: 12),
        Expanded(child: Text(tr('Benvenuto in {p0}', {'p0': Brand.name}))),
        LanguagePicker(ctl: ctl, dense: true),
      ]),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tr('Fadera controlla dal PC i mixer digitali della famiglia X32/M32 tramite la rete (protocollo OSC). '
            'Verificata su Behringer X32 Producer, firmware 4.15; gli altri modelli non sono ancora verificati.'),
            style: TextStyle(fontSize: 13, color: AppColors.text),
          ),
          const SizedBox(height: 14),
          step('1', tr('Stessa rete del mixer'), tr('Collega il PC con il cavo allo stesso router o switch del mixer, oppure al Wi-Fi di quel router. '
'L\'hotspot del telefono è un\'altra rete: da lì il mixer non si trova.')),
          step('2', tr('Internet non serve'), tr('Fadera comunica solo nella rete locale. Se Windows segnala "Nessuna connessione Internet", va bene lo stesso.')),
          step('3', tr('Il primo collegamento non cambia nulla'), tr('Al collegamento Fadera legge lo stato del mixer e non invia modifiche. '
'Il mixer cambia solo quando muovi un controllo.')),
          const SizedBox(height: 4),
          Text(tr('Fadera è un progetto indipendente, non affiliato a Behringer, Midas o Music Tribe.'),
              style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
        ]),
      ),
      actions: [
        TextButton(key: const ValueKey('welcome-later'), onPressed: () => Navigator.pop(context, 'later'), child: Text(tr('Più tardi'))),
        OutlinedButton.icon(
          key: const ValueKey('welcome-sim'),
          onPressed: () => Navigator.pop(context, 'sim'),
          icon: const Icon(Icons.science_outlined, size: 18),
          label: Text(tr('Prova con il simulatore')),
        ),
        FilledButton.icon(
          key: const ValueKey('welcome-search'),
          onPressed: () => Navigator.pop(context, 'search'),
          icon: const Icon(Icons.search, size: 18),
          label: Text(tr('Cerca il mixer')),
        ),
      ],
    );
  }
}
