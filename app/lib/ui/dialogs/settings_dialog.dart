import 'package:flutter/material.dart';

import '../../controller/app_controller.dart';
import '../../controller/prefs.dart';
import '../../controller/shortcuts.dart';
import 'package:flutter/services.dart';
import '../../theme.dart';
import '../../brand.g.dart';
import '../../version.dart';
import 'diagnostics.dart';
import '../widgets/language_picker.dart';
import 'welcome_dialog.dart' show showWelcome;
import '../../l10n/l10n.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.ctl, this.initialTab = 0});
  final AppController ctl;

  /// Scheda aperta all'avvio (0 Generale, 1 Tastiera, 2 Diagnostica, 3 Informazioni).
  final int initialTab;
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final p = ctl.prefs;
    final c = ctl.client;
    return AlertDialog(
      title: Text(tr('Impostazioni')),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 120).clamp(560.0, 1100.0),
        height: (MediaQuery.sizeOf(context).height - 200).clamp(460.0, 680.0),
        child: DefaultTabController(
          length: 4,
          initialIndex: widget.initialTab,
          child: Column(children: [
            TabBar(tabs: [Tab(text: tr('Generale')), Tab(text: tr('Tastiera')), Tab(text: tr('Diagnostica')), Tab(text: tr('Informazioni'))]),
            Expanded(
              child: TabBarView(children: [
                ListView(children: [
                  ListTile(
                    leading: const Icon(Icons.translate),
                    // bilingue: si trova anche se l'interfaccia è in una lingua che non si legge
                    title: Text(L10n.lang == 'en' ? 'Language' : tr('Lingua') + ' · Language'),
                    subtitle: Text(tr('Lingua dell\u2019interfaccia. "Automatica" segue la lingua di Windows.')),
                    trailing: LanguagePicker(ctl: widget.ctl),
                  ),
                  SwitchListTile(
                    title: Text(tr('Riconnessione automatica')),
                    subtitle: Text(tr('Se il mixer non risponde per 10 s, riprova ogni 2 s.')),
                    value: p.autoReconnect,
                    onChanged: (v) => setState(() {
                      p.autoReconnect = v;
                      c?.autoReconnect = v;
                      p.save();
                    }),
                  ),
                  SwitchListTile(
                    title: Text(tr('La selezione segue il mixer')),
                    subtitle: Text(tr('Quando premi SEL sul mixer, il pannello laterale mostra quella strip.')),
                    value: p.selectedFollowsMixer,
                    onChanged: (v) => setState(() {
                      p.selectedFollowsMixer = v;
                      p.save();
                    }),
                  ),
                  SwitchListTile(
                    title: Text(tr('Sperimentale: ambito di richiamo per i file di scena')),
                    subtitle: Text(tr('Permette di inviare al mixer solo alcune categorie di un file (configurazione parziale). '
                        'Le categorie sono ricostruite e non verificate su hardware. Disattivato per impostazione predefinita.')),
                    value: p.experimentalRecallScope,
                    onChanged: (v) => setState(() {
                      p.experimentalRecallScope = v;
                      p.save();
                    }),
                  ),
                  ListTile(
                    title: Text(tr('Meter dei canali')),
                    subtitle: Text(tr('Posizioni del banco 0 da documentazione esterna: 32 canali, 8 aux, 8 FX return, 16 bus, 6 matrici. '
                        'Il canale 1 è verificato sul mixer reale; le altre posizioni seguono lo stesso ordine. '
                        'Il meter del Main LR resta spento finché la sua posizione non è verificata.')),
                  ),
                  ListTile(title: Text(tr('Cartella dei dati')), subtitle: Text(appDataDir().path)),
                ]),
                _ShortcutsTab(ctl: ctl),
                DiagnosticsView(ctl: ctl),
                ListView(children: [
                  ListTile(
                    leading: Image.asset('assets/brand/icona_256.png', width: 40, height: 40),
                    title: const Text(Brand.name),
                    subtitle: Text(tr('{p0}\nVersione {p1} (build {p2}, {p3}) · {p4}', {'p0': Brand.tagline, 'p1': kAppVersion, 'p2': Brand.build, 'p3': kAppBuild, 'p4': Brand.publisher})),
                  ),
                  ListTile(
                    title: Text(tr('Compatibilità verificata')),
                    subtitle: Text(tr('Behringer X32 Producer, firmware 4.15: connessione, sincronizzazione, fader, mute, solo, pan, canale, '
                        'gate, compressore, EQ, mandate, DCA, nomi, icone, colori, meter dei canali e riduzione di guadagno. '
                        'Effetti, scene, routing e altri modelli non sono ancora verificati sull’hardware.')),
                  ),
                  ListTile(
                    title: Text(tr('Indipendenza')),
                    subtitle: Text(tr('{p0} Implementazione indipendente: nessun codice o risorsa grafica di altri programmi.', {'p0': Brand.compatibility})),
                  ),
                  ListTile(
                    title: Text(tr('Licenza')),
                    subtitle: Text(tr('Software libero: GNU General Public License versione 3 o successiva (GPL-3.0-or-later). '
                        'Nessuna garanzia. Il codice sorgente è pubblicato insieme al programma.')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(tr('Licenze dei componenti')),
                    subtitle: Text(tr('Flutter, Dart e le altre librerie incluse, con i loro avvisi di licenza.')),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: Brand.name,
                      applicationVersion: kAppVersion,
                      applicationLegalese: tr('{p0}. GPL-3.0-or-later.', {'p0': Brand.copyright}),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.waving_hand_outlined),
                    title: Text(tr('Rivedi la schermata di benvenuto')),
                    onTap: () {
                      Navigator.pop(context);
                      showWelcome(context, ctl);
                    },
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Chiudi')))],
    );
  }
}

/// Elenco delle scorciatoie con modifica: premi "Cambia" e poi il nuovo tasto.
class _ShortcutsTab extends StatefulWidget {
  const _ShortcutsTab({required this.ctl});
  final AppController ctl;
  @override
  State<_ShortcutsTab> createState() => _ShortcutsTabState();
}

class _ShortcutsTabState extends State<_ShortcutsTab> {
  Future<void> _capture(ShortcutAction a) async {
    final key = await showDialog<LogicalKeyboardKey>(
      context: context,
      builder: (c) => KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (e) {
          if (e is KeyDownEvent && e.logicalKey != LogicalKeyboardKey.escape) Navigator.pop(c, e.logicalKey);
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) Navigator.pop(c);
        },
        child: AlertDialog(title: Text(a.label), content: Text(tr('Premi il nuovo tasto (Esc per annullare).'))),
      ),
    );
    if (key == null) return;
    final p = widget.ctl.prefs;
    // un tasto per una sola azione: chi lo usava torna al proprio predefinito
    p.shortcuts.removeWhere((k, v) => v == key.keyId);
    p.shortcuts[a.name] = key.keyId;
    p.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return Column(children: [
      Expanded(
        child: ListView(children: [
          for (final a in ShortcutAction.values)
            ListTile(
              dense: true,
              title: Text(a.label),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(4)),
                  child: Text(keyFor(ctl, a).keyLabel, style: mono.copyWith(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => _capture(a), child: Text(tr('Cambia'))),
              ]),
            ),
        ]),
      ),
      Row(children: [
        Expanded(child: Text(tr('Maiusc con le frecce su/giù: passi da 10. Le scorciatoie non agiscono mentre scrivi in un campo di testo.'), style: Theme.of(context).textTheme.bodySmall)),
        TextButton(
          onPressed: () => setState(() {
            ctl.prefs.shortcuts.clear();
            ctl.prefs.save();
          }),
          child: Text(tr('Ripristina predefiniti')),
        ),
      ]),
    ]);
  }
}
