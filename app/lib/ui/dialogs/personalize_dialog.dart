import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../design/components.dart';
import '../../theme.dart';
import '../widgets/controls.dart';
import 'color_picker.dart';
import 'icon_picker.dart';
import '../../l10n/l10n.dart';

/// Personalizzazione, organizzata per categorie: temi dei colori, colori dei canali,
/// configurazioni salvate, layer utente e layout della barra rapida.
/// Tutto è salvato solo sul PC, tranne il "colore del mixer" (/config/color), che è un parametro del mixer.
class PersonalizeDialog extends StatefulWidget {
  const PersonalizeDialog({super.key, required this.ctl, this.initialSection = 0});
  final AppController ctl;
  final int initialSection;
  @override
  State<PersonalizeDialog> createState() => _PersonalizeDialogState();
}

class _PersonalizeDialogState extends State<PersonalizeDialog> {
  late int _section = widget.initialSection;

  static const _sections = [
    (Icons.palette_outlined, /*l10n*/ 'Temi colore', /*l10n*/ "Palette dell'interfaccia"),
    (Icons.view_column_outlined, /*l10n*/ 'Colori dei canali', /*l10n*/ 'Singoli canali e gruppi'),
    (Icons.bookmarks_outlined, /*l10n*/ 'Profili', /*l10n*/ 'Salva e richiama tutto'),
    (Icons.touch_app_outlined, /*l10n*/ 'Interfaccia e meter', /*l10n*/ 'Touch, picchi, discesa'),
    (Icons.star_border_rounded, /*l10n*/ 'Layer utente', /*l10n*/ 'Le tue strip preferite'),
    (Icons.dashboard_customize_outlined, /*l10n*/ 'Barra rapida', /*l10n*/ 'Layout salvati'),
  ];

  void _changed() {
    final ctl = widget.ctl;
    ctl.applyAppearance();
    ctl.prefs.save();
    ctl.refresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(Sp.l),
      child: SizedBox(
        width: (size.width - 32).clamp(600.0, 1000.0),
        height: (size.height - 32).clamp(420.0, 660.0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // navigazione per categorie
          Container(
            width: 220,
            decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.horizontal(left: Radius.circular(Rd.l)), border: Border(right: BorderSide(color: AppColors.border))),
            padding: const EdgeInsets.all(Sp.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: EdgeInsets.fromLTRB(Sp.xs, Sp.xs, 0, Sp.m), child: Text(tr('Personalizzazione'), style: Tx.pageTitle)),
              Expanded(child: ListView(children: [
              for (var i = 0; i < _sections.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.xs),
                  child: Material(
                    color: i == _section ? AppColors.surface3 : Colors.transparent,
                    borderRadius: Rd.brM,
                    child: InkWell(
                      borderRadius: Rd.brM,
                      onTap: () => setState(() => _section = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.s),
                        child: Row(children: [
                          Icon(_sections[i].$1, size: 18, color: i == _section ? AppColors.selection : AppColors.textDim),
                          const SizedBox(width: Sp.s),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr(_sections[i].$2), style: TextStyle(fontSize: 13, fontWeight: i == _section ? FontWeight.w700 : FontWeight.w500)),
                              Text(tr(_sections[i].$3), style: Tx.caption),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ])),
              const SizedBox(height: Sp.s),
              MxButton(label: tr('Chiudi'), onTap: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Sp.l),
              child: switch (_section) {
                0 => _ThemesSection(ctl: widget.ctl, onChanged: _changed),
                1 => _ChannelColorsSection(ctl: widget.ctl, onChanged: _changed),
                2 => _ProfilesSection(ctl: widget.ctl, onChanged: _changed),
                3 => _InterfaceSection(ctl: widget.ctl, onChanged: _changed),
                4 => _BandSection(ctl: widget.ctl, onChanged: _changed),
                _ => _QuickLayoutsSection(ctl: widget.ctl, onChanged: _changed),
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Nomi degli 8 colori del mixer, nella lingua attiva.
List<String> get _colorNames => [tr('Spento'), tr('Rosso'), tr('Verde'), tr('Giallo'), tr('Blu'), tr('Magenta'), tr('Ciano'), tr('Bianco')];

// ============================================================ TEMI COLORE

class _ThemesSection extends StatelessWidget {
  const _ThemesSection({required this.ctl, required this.onChanged});
  final AppController ctl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = ctl.prefs;
    final custom = MxTheme.custom(p.customPalette);
    return ListView(children: [
      MxPageHeader(
        title: tr('Temi colore'),
        subtitle: tr('Il tema decide come appaiono gli 8 colori del mixer (Spento, Rosso, Verde, Giallo, Blu, Magenta, Ciano, Bianco). '
            'L\'anteprima è immediata. Mute, solo, selezione ed errori hanno colori propri e non cambiano.'),
      ),
      for (final t in [...MxTheme.presets, custom])
        _ThemeCard(
          theme: t,
          selected: p.colorTheme == t.id,
          onTap: () {
            p.colorTheme = t.id;
            if (t.id == 'custom' && p.customPalette.length != 8) p.customPalette = [for (final c in MxTheme.studio.strip) c.toARGB32()];
            onChanged();
          },
        ),
      if (p.colorTheme == 'custom') ...[
        const SizedBox(height: Sp.s),
        MxPanel(
          title: tr('Palette personalizzata'),
          subtitle: tr('Tocca un colore per modificarlo.'),
          child: Wrap(spacing: Sp.m, runSpacing: Sp.m, children: [
            for (var i = 0; i < 8; i++)
              InkWell(
                borderRadius: Rd.brM,
                onTap: () async {
                  final c = await pickColor(context, initial: MxTheme.current.strip[i], title: tr('Colore "{p0}"', {'p0': _colorNames[i]}), previewName: _colorNames[i]);
                  if (c == null) return;
                  final pal = p.customPalette.length == 8 ? [...p.customPalette] : [for (final x in MxTheme.studio.strip) x.toARGB32()];
                  pal[i] = c.toARGB32();
                  p.customPalette = pal;
                  onChanged();
                },
                child: Column(children: [
                  _MiniHeader(color: MxTheme.current.strip[i], label: _colorNames[i], width: 64),
                  const SizedBox(height: 2),
                  Text(_colorNames[i], style: Tx.caption),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.selected, required this.onTap});
  final MxTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Material(
        color: selected ? AppColors.surface2 : AppColors.surface,
        borderRadius: Rd.brL,
        child: InkWell(
          borderRadius: Rd.brL,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(Sp.m),
            decoration: BoxDecoration(borderRadius: Rd.brL, border: Border.all(color: selected ? AppColors.selection : AppColors.border, width: selected ? 2 : 1)),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: selected ? AppColors.selection : AppColors.textFaint),
              const SizedBox(width: Sp.m),
              SizedBox(
                width: 170,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(theme.name, style: Tx.title),
                  Text(tr(theme.description), style: Tx.caption, maxLines: 2),
                ]),
              ),
              const SizedBox(width: Sp.m),
              // anteprima: le 8 intestazioni come apparirebbero nelle strip
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 1; i < 8; i++) Padding(padding: const EdgeInsets.only(right: 3), child: _MiniHeader(color: theme.strip[i], label: _colorNames[i], width: 52, mix: theme.headerMix)),
                    _MiniHeader(color: theme.strip[0], label: _colorNames[0], width: 52, mix: theme.headerMix),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Intestazione di strip in miniatura (anteprima dei colori).
class _MiniHeader extends StatelessWidget {
  const _MiniHeader({required this.color, required this.label, this.width = 56, this.mix});
  final Color color;
  final String label;
  final double width;
  final double? mix;

  @override
  Widget build(BuildContext context) {
    final bg = mix == null ? AppColors.header(color) : Color.lerp(color, const Color(0xFF0F1218), mix!)!;
    return Container(
      width: width,
      height: 34,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(Rd.s)), border: Border(top: BorderSide(color: color, width: 3))),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

// ======================================================= COLORI DEI CANALI

class _ChannelColorsSection extends StatefulWidget {
  const _ChannelColorsSection({required this.ctl, required this.onChanged});
  final AppController ctl;
  final VoidCallback onChanged;
  @override
  State<_ChannelColorsSection> createState() => _ChannelColorsSectionState();
}

class _ChannelColorsSectionState extends State<_ChannelColorsSection> {
  int _group = 0;
  final _sel = <String>{};

  static final _groups = <(String, List<StripRef>)>[
    ('Ch 1–16', [for (var i = 1; i <= 16; i++) StripRef(StripKind.ch, i)]),
    ('Ch 17–32', [for (var i = 17; i <= 32; i++) StripRef(StripKind.ch, i)]),
    (tr('Aux · FX'), [for (var i = 1; i <= 8; i++) StripRef(StripKind.auxin, i), for (var i = 1; i <= 8; i++) StripRef(StripKind.fxrtn, i)]),
    ('Bus', [for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i)]),
    (tr('Matrix · DCA'), [for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i), for (var i = 1; i <= 8; i++) StripRef(StripKind.dca, i)]),
  ];

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final strips = _groups[_group].$2;
    final selected = [for (final s in strips) if (_sel.contains(s.base)) s];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MxPageHeader(
        title: tr('Colori dei canali'),
        subtitle: tr('Seleziona uno o più canali (anche un gruppo intero), poi scegli un colore del mixer o un colore locale. '
            'Il colore del mixer viene inviato alla console; il colore locale resta solo in Fadera.'),
      ),
      Row(children: [
        Expanded(child: MxSegmented<int>(options: [for (var i = 0; i < _groups.length; i++) (i, _groups[i].$1)], value: _group, expand: true, onChanged: (v) => setState(() => _group = v))),
        const SizedBox(width: Sp.s),
        MxButton(label: tr('Tutti'), kind: MxButtonKind.ghost, onTap: () => setState(() => _sel.addAll(strips.map((s) => s.base)))),
        MxButton(label: tr('Nessuno'), kind: MxButtonKind.ghost, onTap: () => setState(_sel.clear)),
      ]),
      const SizedBox(height: Sp.m),
      Expanded(
        child: SingleChildScrollView(
          child: Wrap(spacing: Sp.xs, runSpacing: Sp.s, children: [
            for (final s in strips)
              ValueListenableBuilder<Object?>(
                valueListenable: ctl.hub.listen('${s.base}/config/color'),
                builder: (context, ci, _) {
                  final isSel = _sel.contains(s.base);
                  final local = MxTheme.overrides.containsKey(s.base);
                  return GestureDetector(
                    onTap: () => setState(() => isSel ? _sel.remove(s.base) : _sel.add(s.base)),
                    child: Container(
                      width: 78,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(borderRadius: Rd.brM, border: Border.all(color: isSel ? AppColors.selection : Colors.transparent, width: 2)),
                      child: Column(children: [
                        _MiniHeader(color: AppColors.stripColorFor(s.base, ci as int?), label: ctl.stripName(s), width: 70),
                        const SizedBox(height: 2),
                        Text(local ? tr('locale') : _colorNames[(ci ?? 0) % 8], style: Tx.caption.copyWith(fontSize: 10, color: local ? AppColors.selection : AppColors.textFaint)),
                      ]),
                    ),
                  );
                },
              ),
          ]),
        ),
      ),
      const SizedBox(height: Sp.s),
      MxPanel(
        title: selected.isEmpty ? tr('Nessun canale selezionato') : tr('{p0} {p1}', {'p0': selected.length, 'p1': selected.length == 1 ? tr('canale selezionato') : tr('canali selezionati')}),
        child: Opacity(
          opacity: selected.isEmpty ? 0.45 : 1,
          child: IgnorePointer(
            ignoring: selected.isEmpty,
            child: Wrap(spacing: Sp.l, runSpacing: Sp.s, crossAxisAlignment: WrapCrossAlignment.center, children: [
              // un solo canale: nome e icona del mixer
              if (selected.length == 1) ...[
                MxLabeled(tr('Nome (sul mixer)'), SizedBox(width: 160, child: _RenameField(ctl: ctl, strip: selected.single))),
                MxLabeled(
                  tr('Icona (sul mixer)'),
                  MxButton(
                    label: tr('Scegli…'),
                    icon: Icons.image_outlined,
                    onTap: () => showDialog<void>(context: context, builder: (_) => IconPickerDialog(ctl: ctl, strip: selected.single)),
                  ),
                ),
              ],
              MxLabeled(
                tr('Colore del mixer (inviato alla console)'),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 8; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: MxSwatch(
                        color: AppColors.strip[i],
                        tooltip: _colorNames[i],
                        selected: false,
                        onTap: () {
                          for (final s in selected) {
                            ctl.setIdx('${s.base}/config/color', i);
                            ctl.prefs.stripColorOverride.remove(s.base);
                          }
                          widget.onChanged();
                        },
                      ),
                    ),
                ]),
              ),
              MxLabeled(
                tr('Colore locale (solo in Fadera)'),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  MxButton(
                    label: tr('Scegli…'),
                    icon: Icons.colorize,
                    onTap: () async {
                      final first = selected.first;
                      final c = await pickColor(context,
                          initial: AppColors.stripColorFor(first.base, ctl.idx('${first.base}/config/color')), title: tr('Colore locale'), previewName: ctl.stripName(first));
                      if (c == null) return;
                      for (final s in selected) {
                        ctl.prefs.stripColorOverride[s.base] = c.toARGB32();
                      }
                      widget.onChanged();
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: Sp.s),
                  MxButton(
                    label: tr('Ripristina originale'),
                    icon: Icons.restart_alt,
                    kind: MxButtonKind.ghost,
                    tooltip: tr('Toglie il colore locale: torna il colore del mixer'),
                    onTap: () {
                      for (final s in selected) {
                        ctl.prefs.stripColorOverride.remove(s.base);
                      }
                      widget.onChanged();
                      setState(() {});
                    },
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ========================================================= CONFIGURAZIONI

class _ProfilesSection extends StatelessWidget {
  const _ProfilesSection({required this.ctl, required this.onChanged});
  final AppController ctl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = ctl.prefs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MxPageHeader(
        title: tr('Profili salvati'),
        subtitle: tr('Un profilo contiene tutto l’aspetto di Fadera su questo PC: tema, palette, colori locali, layout della barra rapida, layer utente, modalità touch e meter. '
            'Nomi, colori e icone del mixer non sono inclusi: stanno nelle scene della console.'),
        actions: [
          MxButton(
            label: tr('Salva attuale…'),
            icon: Icons.save_outlined,
            kind: MxButtonKind.primary,
            onTap: () async {
              final n = await _ask(context, tr('Nome della configurazione'), '');
              if (n == null || n.isEmpty) return;
              p.colorProfiles[n] = p.captureProfile();
              onChanged();
            },
          ),
        ],
      ),
      Expanded(
        child: p.colorProfiles.isEmpty
            ? MxEmpty(icon: Icons.bookmarks_outlined, text: tr('Nessuna configurazione salvata.\nScegli tema e colori, poi "Salva attuale".'))
            : ListView(children: [
                for (final e in p.colorProfiles.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.s),
                    child: MxPanel(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.key, style: Tx.title),
                            Text(
                                tr('Tema {p0} · {p1} colori locali'
'{p2}', {'p0': MxTheme.byId(e.value['theme'] as String? ?? 'studio', const []).name, 'p1': (e.value['overrides'] as Map?)?.length ?? 0, 'p2': e.value['quickLayouts'] == null ? '' : tr(' · {p0} layout della barra · {p1} strip nel layer utente', {'p0': (e.value['quickLayouts'] as Map).length, 'p1': (e.value['bandStrips'] as List?)?.length ?? 0})}),
                                style: Tx.caption),
                          ]),
                        ),
                        MxButton(
                          label: tr('Applica'),
                          onTap: () {
                            p.applyProfile(e.value);
                            onChanged();
                          },
                        ),
                        const SizedBox(width: Sp.s),
                        MxIconButton(
                          icon: Icons.delete_outline,
                          tooltip: tr('Elimina'),
                          color: AppColors.mute,
                          onTap: () {
                            p.colorProfiles.remove(e.key);
                            onChanged();
                          },
                        ),
                      ]),
                    ),
                  ),
              ]),
      ),
    ]);
  }
}

// ===================================================== INTERFACCIA E METER

class _InterfaceSection extends StatelessWidget {
  const _InterfaceSection({required this.ctl, required this.onChanged});
  final AppController ctl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = ctl.prefs;
    Widget row(String title, String sub, Widget control) => Padding(
          padding: const EdgeInsets.only(bottom: Sp.m),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Tx.strong),
                Text(sub, style: Tx.caption),
              ]),
            ),
            const SizedBox(width: Sp.m),
            control,
          ]),
        );
    return ListView(children: [
      MxPageHeader(title: tr('Interfaccia e meter'), subtitle: tr('Le modifiche si vedono subito e restano salvate su questo PC.')),
      MxPanel(
        title: tr('Modalità touch'),
        child: row(
          tr('Controlli più grandi'),
          tr('Cursori, pulsanti, manopole e barre crescono del 30 % per l’uso con le dita. "Automatica" la attiva su tablet e telefoni. '
'Sugli schermi touch: pressione lunga su una strip per aprirne i parametri.'),
          MxSegmented<String>(
            options: [('auto', tr('Automatica')), ('on', tr('Sempre')), ('off', tr('Mai'))],
            value: p.touchMode,
            onChanged: (v) {
              p.touchMode = v;
              onChanged();
            },
          ),
        ),
      ),
      const SizedBox(height: Sp.s),
      MxPanel(
        title: tr('Pagine dei canali'),
        child: row(
          tr('Fader per pagina'),
          tr('8: quattro pagine (Ch 1–8 … 25–32), strip più larghe. 16: due pagine (Ch 1–16, 17–32), tutti i canali di metà mixer insieme. '
'Aux · FX e Bus mostrano sempre 16 strip.'),
          MxSegmented<int>(
            key: const ValueKey('strips-per-page'),
            options: const [(8, '8'), (16, '16')],
            value: p.stripsPerPage,
            onChanged: (v) {
              ctl.setStripsPerPage(v); // tiene visibile la pagina corrente (Ch 9–16 → Ch 1–16)
              onChanged();
            },
          ),
        ),
      ),
      const SizedBox(height: Sp.s),
      MxPanel(
        title: tr('Meter'),
        child: Column(children: [
          row(
            tr('Tenuta del picco'),
            tr('Per quanto resta visibile la linea del picco. "Tenuto": finché non tocchi il meter.'),
            MxSegmented<int>(
              options: [(0, tr('Nessuna')), (1500, '1,5 s'), (3000, '3 s'), (-1, tr('Tenuto'))],
              value: p.meterPeakHoldMs,
              onChanged: (v) {
                p.meterPeakHoldMs = v;
                onChanged();
              },
            ),
          ),
          row(
            tr('Velocità di discesa'),
            tr('Quanto velocemente la barra scende quando il segnale cala.'),
            MxSegmented<double>(
              options: [(12.0, tr('Lenta')), (26.0, tr('Media')), (48.0, tr('Veloce'))],
              value: p.meterFall,
              onChanged: (v) {
                p.meterFall = v;
                onChanged();
              },
            ),
          ),
          row(
            tr('Valore del picco nelle strip'),
            tr('Mostra il picco in dBFS sopra il meter, al posto del LED di segnale. Tocca il valore per azzerarlo.'),
            Switch(
              value: p.meterPeakReadout,
              onChanged: (v) {
                p.meterPeakReadout = v;
                onChanged();
              },
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(tr('Clip: l’indicatore rosso in cima al meter resta acceso finché non tocchi il meter. '
                'Il meter del Main resta spento finché la sua posizione non è verificata sul mixer reale.'), style: Tx.caption),
          ),
        ]),
      ),
    ]);
  }
}

// ============================================================== LAYER BAND

class _BandSection extends StatelessWidget {
  const _BandSection({required this.ctl, required this.onChanged});
  final AppController ctl;
  final VoidCallback onChanged;

  static final _strips = <StripRef>[
    for (var i = 1; i <= 32; i++) StripRef(StripKind.ch, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.auxin, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.fxrtn, i),
    for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i),
    for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.dca, i),
  ];

  @override
  Widget build(BuildContext context) {
    final p = ctl.prefs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MxPageHeader(
        title: tr('Layer utente'),
        subtitle: tr('Scegli le strip del tuo layer personale, nell’ordine in cui le tocchi ({p0} scelte). Come i banchi "User" di X32-Edit: salvato solo su questo PC, non cambia nulla sul mixer.', {'p0': p.bandStrips.length}),
        actions: [MxButton(label: tr('Svuota'), kind: MxButtonKind.ghost, onTap: p.bandStrips.isEmpty ? null : () {
          p.bandStrips.clear();
          onChanged();
        })],
      ),
      // ordine attuale: trascina per riordinare
      if (p.bandStrips.isNotEmpty) ...[
        Text(tr('ORDINE NEL LAYER (TRASCINA PER RIORDINARE)'), style: Tx.section),
        const SizedBox(height: Sp.xs),
        SizedBox(
          height: 44,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: true,
            onReorderItem: (a, b) {
              final s = p.bandStrips.removeAt(a);
              p.bandStrips.insert(b.clamp(0, p.bandStrips.length), s);
              onChanged();
            },
            children: [
              for (final base in p.bandStrips)
                Padding(
                  key: ValueKey('ord$base'),
                  padding: const EdgeInsets.only(right: Sp.xs),
                  child: Chip(
                    label: Text(AppController.parseStrip(base) == null ? base : ctl.stripName(AppController.parseStrip(base)!), style: const TextStyle(fontSize: 12)),
                    onDeleted: () {
                      p.bandStrips.remove(base);
                      onChanged();
                    },
                    backgroundColor: AppColors.surface2,
                    side: BorderSide(color: AppColors.selection.withValues(alpha: 0.6)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Sp.m),
      ],
      Text(tr('STRIP DISPONIBILI'), style: Tx.section),
      const SizedBox(height: Sp.xs),
      Expanded(
        child: SingleChildScrollView(
          child: Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
            for (final s in _strips)
              PillButton(
                label: ctl.stripName(s),
                active: p.bandStrips.contains(s.base),
                activeColor: AppColors.selection,
                width: 78,
                height: 28,
                onTap: () {
                  p.bandStrips.contains(s.base) ? p.bandStrips.remove(s.base) : p.bandStrips.add(s.base);
                  onChanged();
                },
              ),
          ]),
        ),
      ),
    ]);
  }
}

// ========================================================== BARRA RAPIDA

class _QuickLayoutsSection extends StatelessWidget {
  const _QuickLayoutsSection({required this.ctl, required this.onChanged});
  final AppController ctl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = ctl.prefs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MxPageHeader(
        title: tr('Layout della barra rapida'),
        subtitle: tr('I controlli si aggiungono con "Assegna" o con le caselle vuote. Sulla barra: clic destro o pressione lunga per modificare, trascina per riordinare.'),
        actions: [
          MxButton(
            label: tr('Nuovo layout'),
            icon: Icons.add,
            onTap: () async {
              final n = await _ask(context, tr('Nuovo layout'), '');
              if (n == null || n.isEmpty || p.quickLayouts.containsKey(n)) return;
              p.quickLayouts[n] = [];
              p.activeQuickLayout = n;
              onChanged();
            },
          ),
        ],
      ),
      MxPanel(
        title: tr('Aspetto della barra'),
        child: Wrap(spacing: Sp.xl, runSpacing: Sp.m, children: [
          MxLabeled(
            tr('Caselle visibili'),
            MxSegmented<int>(
              options: const [(8, '8'), (10, '10'), (12, '12'), (16, '16')],
              value: p.quickSlots,
              onChanged: (v) {
                p.quickSlots = v;
                onChanged();
              },
            ),
          ),
          MxLabeled(
            tr('Altezza'),
            MxSegmented<bool>(
              options: [(false, tr('Normale')), (true, tr('Grande'))],
              value: p.quickBarLarge,
              onChanged: (v) {
                p.quickBarLarge = v;
                onChanged();
              },
            ),
          ),
        ]),
      ),
      const SizedBox(height: Sp.s),
      Expanded(
        child: ListView(children: [
          for (final name in p.quickLayouts.keys.toList())
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: MxPanel(
                padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
                child: Row(children: [
                  InkWell(
                    onTap: () {
                      p.activeQuickLayout = name;
                      onChanged();
                    },
                    child: Icon(name == p.activeQuickLayout ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18, color: name == p.activeQuickLayout ? AppColors.selection : AppColors.textFaint),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: Tx.strong),
                      Text(tr('{p0} controlli', {'p0': p.quickLayouts[name]!.length}), style: Tx.caption),
                    ]),
                  ),
                  MxIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: tr('Rinomina'),
                    onTap: () async {
                      final n = await _ask(context, tr('Rinomina layout'), name);
                      if (n == null || n.isEmpty || p.quickLayouts.containsKey(n)) return;
                      p.quickLayouts = {for (final e in p.quickLayouts.entries) (e.key == name ? n : e.key): e.value};
                      if (p.activeQuickLayout == name) p.activeQuickLayout = n;
                      onChanged();
                    },
                  ),
                  const SizedBox(width: Sp.xs),
                  MxIconButton(
                    icon: Icons.copy,
                    tooltip: tr('Duplica'),
                    onTap: () {
                      var n = tr('{p0} (copia)', {'p0': name});
                      while (p.quickLayouts.containsKey(n)) {
                        n = '$n+';
                      }
                      p.quickLayouts[n] = [for (final q in p.quickLayouts[name]!) q.copy()];
                      onChanged();
                    },
                  ),
                  const SizedBox(width: Sp.xs),
                  MxIconButton(
                    icon: Icons.delete_outline,
                    tooltip: tr('Elimina'),
                    color: AppColors.mute,
                    onTap: p.quickLayouts.length <= 1
                        ? null
                        : () {
                            p.quickLayouts.remove(name);
                            if (p.activeQuickLayout == name) p.activeQuickLayout = p.quickLayouts.keys.first;
                            onChanged();
                          },
                  ),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

Future<String?> _ask(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 320, child: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(d, v.trim()))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('Annulla'))),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

/// Campo del nome di una strip: invio con Invio, solo caratteri ammessi dal mixer.
class _RenameField extends StatefulWidget {
  const _RenameField({required this.ctl, required this.strip});
  final AppController ctl;
  final StripRef strip;
  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final _c = TextEditingController(text: widget.ctl.state.getString('${widget.strip.base}/config/name') ?? '');

  @override
  void didUpdateWidget(covariant _RenameField old) {
    super.didUpdateWidget(old);
    if (old.strip != widget.strip) _c.text = widget.ctl.state.getString('${widget.strip.base}/config/name') ?? '';
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        maxLength: 12,
        decoration: InputDecoration(counterText: '', hintText: tr('Invio per inviare')),
        onSubmitted: (v) => widget.ctl.setString('${widget.strip.base}/config/name', v.replaceAll(RegExp(r'[^ -~]'), '').replaceAll('"', '')),
      );
}
