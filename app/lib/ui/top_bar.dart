import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../controller/app_controller.dart';
import '../theme.dart';
import 'dialogs/connect_dialog.dart';
import 'dialogs/personalize_dialog.dart';
import 'dialogs/settings_dialog.dart';
import '../l10n/l10n.dart';

/// Barra superiore, disposizione del riferimento: connessione · layer · Band · Effetti · "+" ·
/// (a destra) destinazione dei fader · Assegna · Personalizzazione · Impostazioni.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.ctl});
  final AppController ctl;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 1700;
    final inputs = ctl.inputLayers;
    const others = [Layer.auxFx, Layer.bus, Layer.mtx];
    return Container(
      height: MxDensity.s(Sz.topBar),
      padding: const EdgeInsets.symmetric(horizontal: Sp.m),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        _ConnectionChip(ctl: ctl),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              // le quattro pagine degli ingressi, raggruppate e sempre a un clic
              Tooltip(
                message: ctl.prefs.stripsPerPage == 16
                    ? tr('Ingressi: due pagine da 16 canali (tasti 1–2; 8 o 16 fader per pagina in Personalizzazione → Interfaccia)')
                    : tr('Ingressi: quattro pagine da 8 canali (tasti 1–4; 8 o 16 fader per pagina in Personalizzazione → Interfaccia)'),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: AppColors.well, borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    if (compact) Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('CH', style: Tx.section)),
                    for (final l in inputs)
                      _Tab(label: compact ? ctl.layerLabel(l).replaceFirst('Ch ', '') : ctl.layerLabel(l), active: ctl.page == AppPage.mixer && ctl.layer == l, onTap: () => ctl.setLayer(l)),
                    _PerPageSwitch(ctl: ctl),
                  ]),
                ),
              ),
              Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: Sp.s), color: AppColors.border),
              for (final l in others)
                _Tab(label: compact && l == Layer.mtx ? tr('Mtx · Main') : l.label, active: ctl.page == AppPage.mixer && ctl.layer == l, onTap: () => ctl.setLayer(l)),
              // layer utente: strip scelte da te (come i banchi "User" di X32-Edit), salvato solo sul PC
              _Tab(
                label: tr('Utente'),
                icon: Icons.star_rounded,
                iconColor: AppColors.selection,
                tooltip: tr('Layer utente: le strip che scegli tu, da qualsiasi categoria (tasto 9). Salvato solo su questo PC, non cambia nulla sul mixer.'),
                active: ctl.page == AppPage.mixer && ctl.layer == Layer.band,
                onTap: () => ctl.setLayer(Layer.band),
              ),
              Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: Sp.s), color: AppColors.border),
              // pagine: un clic, nessun menu secondario
              _Tab(label: tr('DCA'), icon: Icons.tune, iconColor: AppColors.textDim, compact: compact, tooltip: tr('DCA: fader dei gruppi e assegnazioni (tasto 8, F6)'), active: ctl.page == AppPage.dca, onTap: () => ctl.setPage(AppPage.dca)),
              _Tab(label: tr('Effetti'), icon: Icons.auto_awesome, iconColor: AppColors.series[1], compact: compact, tooltip: tr('Effetti: rack degli 8 slot (F7)'), active: ctl.page == AppPage.effects, onTap: () => ctl.setPage(AppPage.effects)),
              _Tab(label: tr('Scene'), icon: Icons.photo_library_outlined, iconColor: AppColors.textDim, compact: compact, tooltip: tr('Scene, snippet e cue (F9)'), active: ctl.page == AppPage.scenes, onTap: () => ctl.setPage(AppPage.scenes)),
              _Tab(label: tr('Routing'), icon: Icons.cable, iconColor: AppColors.textDim, compact: compact, tooltip: tr('Routing di ingressi e uscite, bloccato per impostazione predefinita (F8)'), active: ctl.page == AppPage.routing, onTap: () => ctl.setPage(AppPage.routing)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        if (!compact) ...[
          Text(tr('I fader controllano'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
        ],
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: ctl.faderTarget,
              isDense: true,
              dropdownColor: AppColors.surface2,
              icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textDim),
              style: const TextStyle(fontSize: 12, color: AppColors.text),
              items: [
                DropdownMenuItem(value: 0, child: Text(compact ? tr('Main LR') : tr('Mix principale (Main LR)'))),
                for (var i = 1; i <= 16; i++) DropdownMenuItem(value: i, child: Text(tr('Mandate → {p0}', {'p0': _busName(ctl, i)}))),
              ],
              onChanged: (v) => ctl.setFaderTarget(v ?? 0),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.bolt,
          label: tr('Assegna'),
          active: ctl.assignMode,
          tooltip: tr('Assegnazione: tocca una strip per aggiungere un suo controllo alla barra rapida'),
          onTap: () {
            ctl.assignMode = !ctl.assignMode;
            ctl.refresh();
          },
        ),
        const SizedBox(width: 6),
        _IconSquare(
          icon: Icons.search,
          tooltip: tr('Cerca un canale per nome o numero (Ctrl+F)'),
          onTap: () => ctl.searchRequest.value++,
        ),
        const SizedBox(width: 6),
        _IconSquare(
          icon: Icons.palette_outlined,
          tooltip: tr('Personalizzazione: temi colore, colori dei canali, layer utente, barra rapida'),
          onTap: () => showDialog(context: context, builder: (_) => PersonalizeDialog(ctl: ctl)),
        ),
        const SizedBox(width: 6),
        _IconSquare(
          icon: Icons.settings,
          tooltip: tr('Impostazioni'),
          onTap: () => showDialog(context: context, builder: (_) => SettingsDialog(ctl: ctl)),
        ),
      ]),
    );
  }

  static String _busName(AppController ctl, int i) {
    final n = ctl.state.getString('/bus/${i.toString().padLeft(2, '0')}/config/name');
    return (n == null || n.isEmpty) ? tr('Bus {p0}', {'p0': i}) : n;
  }
}

/// Selettore rapido "8 | 16" fader per pagina, dentro il gruppo delle pagine dei canali.
class _PerPageSwitch extends StatelessWidget {
  const _PerPageSwitch({required this.ctl});
  final AppController ctl;

  @override
  Widget build(BuildContext context) {
    final n = ctl.prefs.stripsPerPage;
    Widget seg(int v) => InkWell(
          key: ValueKey('per-page-$v'),
          borderRadius: BorderRadius.circular(4),
          onTap: n == v ? null : () => ctl.setStripsPerPage(v),
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: n == v ? AppColors.surface3 : Colors.transparent, borderRadius: BorderRadius.circular(4)),
            child: Text('$v', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: n == v ? AppColors.text : AppColors.textFaint)),
          ),
        );
    return Tooltip(
      message: tr('Fader per pagina: 8 (quattro pagine) o 16 (due pagine). Anche in Personalizzazione → Interfaccia.'),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [seg(8), seg(16)]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap, this.icon, this.iconColor, this.tooltip, this.compact = false});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final String? tooltip;

  /// Solo icona (finestre strette): il nome resta nel suggerimento.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.text : (icon != null ? (iconColor ?? AppColors.textDim) : AppColors.textDim);
    final iconOnly = compact && icon != null;
    final w = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 30,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 8 : 12),
          decoration: BoxDecoration(
            color: active ? AppColors.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? AppColors.textFaint.withValues(alpha: 0.6) : Colors.transparent),
          ),
          child: Row(children: [
            if (icon != null) Icon(icon, size: iconOnly ? 16 : 13, color: active ? AppColors.text : (iconColor ?? fg)),
            if (!iconOnly) ...[
              if (icon != null) const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: fg)),
            ],
          ]),
        ),
      ),
    );
    return Tooltip(message: tooltip ?? label, waitDuration: const Duration(milliseconds: 500), child: w);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.active, required this.onTap, required this.tooltip});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.accent : AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: active ? AppColors.accent : AppColors.border)),
            child: Row(children: [
              Icon(icon, size: 15, color: active ? Colors.black : AppColors.accent),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.black : AppColors.text)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _IconSquare extends StatelessWidget {
  // ignore: unused_element_parameter
  const _IconSquare({required this.icon, required this.tooltip, required this.onTap, this.color = AppColors.textDim});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

/// Stato della connessione: non mostra mai "connesso" senza una risposta reale.
class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.ctl});
  final AppController ctl;

  @override
  Widget build(BuildContext context) {
    final link = ctl.link;
    final info = ctl.mixer;
    final (Color dot, String text) = switch (link) {
      LinkState.connected => (ctl.synced ? AppColors.ok : AppColors.warn, info?.name ?? ''),
      LinkState.syncing => (AppColors.warn, 'Sincronizzazione…'),
      LinkState.connecting => (AppColors.warn, 'Connessione…'),
      LinkState.lost => (AppColors.error, tr('Mixer non raggiungibile')),
      LinkState.disconnected => (AppColors.textFaint, tr('Non connesso')),
    };
    final sim = ctl.isSimulator;
    final showIp = info != null && link != LinkState.disconnected;
    return Tooltip(
      message: switch (link) {
        LinkState.connected when !ctl.synced => tr('Connesso, ma lo stato non è sincronizzato: esegui la sync Mixer → PC.'),
        LinkState.lost => tr('Nessun dato dal mixer da oltre 10 secondi. Riconnessione automatica in corso.'),
        _ => info?.toString() ?? tr('Clicca per connetterti a un mixer'),
      },
      child: Material(
        color: sim ? AppColors.sim.withValues(alpha: 0.16) : AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => showDialog(context: context, builder: (_) => ConnectDialog(ctl: ctl)),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: sim ? AppColors.sim : AppColors.border)),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.6), blurRadius: 6)])),
              const SizedBox(width: 8),
              if (sim) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.sim, borderRadius: BorderRadius.circular(3)),
                  child: Text(tr('SIMULATORE'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 6),
              ],
              Text(showIp ? '$text · ${info.ip}' : text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}
