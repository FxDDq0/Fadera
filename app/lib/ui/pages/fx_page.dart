import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../design/components.dart';
import '../../theme.dart';
import '../fx_visuals.dart';
import '../widgets/controls.dart';
import '../../l10n/l10n.dart';

// ================================================================ CATALOGO

/// Famiglia di un effetto, usata solo per presentarlo (icona, colore, raggruppamento).
/// I nomi descrittivi sono generici: i parametri restano quelli dell'Appendice C.
enum FxFamily {
  reverb(/*l10n*/ 'Riverbero', Icons.blur_on),
  delay(/*l10n*/ 'Delay', Icons.more_time),
  modulation(/*l10n*/ 'Modulazione', Icons.waves),
  combo(/*l10n*/ 'Combinato', Icons.layers_outlined),
  pitch(/*l10n*/ 'Intonazione', Icons.music_note_outlined),
  geq(/*l10n*/ 'EQ grafico', Icons.equalizer),
  eq(/*l10n*/ 'EQ', Icons.tune),
  dynamics(/*l10n*/ 'Dinamica', Icons.compress),
  enhancer(/*l10n*/ 'Enfasi e immagine', Icons.auto_awesome_outlined),
  saturation(/*l10n*/ 'Saturazione', Icons.local_fire_department_outlined),
  other(/*l10n*/ 'Effetto', Icons.graphic_eq);

  const FxFamily(this._label, this.icon);
  final String _label;
  String get label => tr(_label);
  final IconData icon;

  Color get color => switch (this) {
        reverb => AppColors.series[4],
        delay => AppColors.series[3],
        modulation => AppColors.series[5],
        combo => AppColors.series[4],
        pitch => AppColors.series[2],
        geq || eq => AppColors.series[2],
        dynamics => AppColors.series[0],
        enhancer => AppColors.series[1],
        saturation => AppColors.series[0],
        other => AppColors.textDim,
      };
}

/// Nome descrittivo e famiglia per ogni codice di tipo.
const Map<String, (String, FxFamily)> kFxCatalog = {
  'HALL': (/*l10n*/ 'Riverbero Hall', FxFamily.reverb),
  'AMBI': (/*l10n*/ 'Ambience', FxFamily.reverb),
  'RPLT': (/*l10n*/ 'Plate ricco', FxFamily.reverb),
  'ROOM': (/*l10n*/ 'Riverbero Room', FxFamily.reverb),
  'CHAM': (/*l10n*/ 'Riverbero Chamber', FxFamily.reverb),
  'PLAT': (/*l10n*/ 'Riverbero Plate', FxFamily.reverb),
  'VREV': (/*l10n*/ 'Riverbero vintage', FxFamily.reverb),
  'VRM': (/*l10n*/ 'Room vintage', FxFamily.reverb),
  'GATE': (/*l10n*/ 'Riverbero con gate', FxFamily.reverb),
  'RVRS': (/*l10n*/ 'Riverbero inverso', FxFamily.reverb),
  'DLY': (/*l10n*/ 'Delay stereo', FxFamily.delay),
  '3TAP': (/*l10n*/ 'Delay a 3 tap', FxFamily.delay),
  '4TAP': (/*l10n*/ 'Delay a 4 tap', FxFamily.delay),
  'CRS': (/*l10n*/ 'Chorus', FxFamily.modulation),
  'FLNG': (/*l10n*/ 'Flanger', FxFamily.modulation),
  'PHAS': (/*l10n*/ 'Phaser', FxFamily.modulation),
  'DIMC': (/*l10n*/ 'Chorus dimensionale', FxFamily.modulation),
  'FILT': (/*l10n*/ 'Filtro modulato', FxFamily.modulation),
  'ROTA': (/*l10n*/ 'Altoparlante rotante', FxFamily.modulation),
  'PAN': (/*l10n*/ 'Tremolo / panner', FxFamily.modulation),
  'MODD': (/*l10n*/ 'Delay modulato', FxFamily.combo),
  'D/RV': (/*l10n*/ 'Delay + riverbero', FxFamily.combo),
  'CR/R': (/*l10n*/ 'Chorus + riverbero', FxFamily.combo),
  'FL/R': (/*l10n*/ 'Flanger + riverbero', FxFamily.combo),
  'D/CR': (/*l10n*/ 'Delay + chorus', FxFamily.combo),
  'D/FL': (/*l10n*/ 'Delay + flanger', FxFamily.combo),
  'PIT': (/*l10n*/ 'Pitch shifter', FxFamily.pitch),
  'PIT2': (/*l10n*/ 'Pitch shifter doppio', FxFamily.pitch),
  'SUB': (/*l10n*/ 'Sub-ottava', FxFamily.pitch),
  'GEQ': (/*l10n*/ 'EQ grafico 31 bande', FxFamily.geq),
  'GEQ2': (/*l10n*/ 'EQ grafico doppio', FxFamily.geq),
  'TEQ': (/*l10n*/ 'EQ grafico (True)', FxFamily.geq),
  'TEQ2': (/*l10n*/ 'EQ grafico doppio (True)', FxFamily.geq),
  'P1A': (/*l10n*/ 'EQ valvolare', FxFamily.eq),
  'P1A2': (/*l10n*/ 'EQ valvolare doppio', FxFamily.eq),
  'PQ5': (/*l10n*/ 'EQ valvolare mid', FxFamily.eq),
  'PQ5S': (/*l10n*/ 'EQ valvolare mid doppio', FxFamily.eq),
  'DES': (/*l10n*/ 'De-esser', FxFamily.dynamics),
  'DES2': (/*l10n*/ 'De-esser doppio', FxFamily.dynamics),
  'WAVD': (/*l10n*/ 'Modellatore di transienti', FxFamily.dynamics),
  'LIM': (/*l10n*/ 'Limiter', FxFamily.dynamics),
  'CMB': (/*l10n*/ 'Compressore multibanda', FxFamily.dynamics),
  'CMB2': (/*l10n*/ 'Compressore multibanda doppio', FxFamily.dynamics),
  'FAC': (/*l10n*/ 'Compressore vintage', FxFamily.dynamics),
  'FAC1M': (/*l10n*/ 'Compressore vintage M/S', FxFamily.dynamics),
  'FAC2': (/*l10n*/ 'Compressore vintage doppio', FxFamily.dynamics),
  'LEC': (/*l10n*/ 'Compressore ottico', FxFamily.dynamics),
  'LEC2': (/*l10n*/ 'Compressore ottico doppio', FxFamily.dynamics),
  'ULC': (/*l10n*/ 'Compressore FET', FxFamily.dynamics),
  'ULC2': (/*l10n*/ 'Compressore FET doppio', FxFamily.dynamics),
  'ENH': (/*l10n*/ 'Enhancer', FxFamily.enhancer),
  'ENH2': (/*l10n*/ 'Enhancer doppio', FxFamily.enhancer),
  'EXC': (/*l10n*/ 'Exciter', FxFamily.enhancer),
  'EXC2': (/*l10n*/ 'Exciter doppio', FxFamily.enhancer),
  'SON': (/*l10n*/ 'Sonic enhancer', FxFamily.enhancer),
  'IMG': (/*l10n*/ 'Immagine stereo', FxFamily.enhancer),
  'EDI': (/*l10n*/ 'Allargatore stereo', FxFamily.enhancer),
  'AMP': (/*l10n*/ 'Amplificatore chitarra', FxFamily.saturation),
  'AMP2': (/*l10n*/ 'Amplificatore doppio', FxFamily.saturation),
  'DRV': (/*l10n*/ 'Saturazione valvolare', FxFamily.saturation),
  'DRV2': (/*l10n*/ 'Saturazione doppia', FxFamily.saturation),
};

(String, FxFamily) fxInfo(String code) {
  final e = kFxCatalog[code];
  return e == null ? (code, FxFamily.other) : (tr(e.$1), e.$2);
}

// ======================================================= GRUPPI DI PARAMETRI

/// Gruppi funzionali, nell'ordine in cui compaiono nell'editor.
enum FxGroup {
  space(/*l10n*/ 'Tempo e ripetizioni'),
  room(/*l10n*/ 'Ambiente e decadimento'),
  modulation(/*l10n*/ 'Modulazione'),
  pitch(/*l10n*/ 'Intonazione'),
  tone(/*l10n*/ 'Filtri e tono'),
  character(/*l10n*/ 'Carattere'),
  dynamics(/*l10n*/ 'Dinamica'),
  setup(/*l10n*/ 'Impostazioni'),
  output(/*l10n*/ 'Uscita e mix');

  const FxGroup(this._label);
  final String _label;
  String get label => tr(_label);
}

const _rules = <(FxGroup, List<String>)>[
  (FxGroup.setup, ['Mode', 'Rtype', 'Stages', 'Wave', 'InMode', 'OutMode', 'MeterSel', 'Range', 'Sw', 'Stop', /*l10n*/ 'Solo', 'Lock', 'MS', 'Male']),
  (FxGroup.space, ['PreDelay', 'RevDelay', 'Delay', 'Time', 'Factor', 'Pattern', 'Rise', 'Feedback', 'Offset']),
  (FxGroup.pitch, ['Semi', 'Cent', 'Oct']),
  (FxGroup.room, ['Decay', 'Size', 'Damp', 'Diffusion', 'Density', 'Shape', 'Spread', 'Spin', 'BassMult', 'Xover', 'ER', 'Ec', 'LoMult', 'HiMult', 'Freeze', 'TailGain', 'Distance']),
  (FxGroup.modulation, ['ModSpeed', 'ModDepth', 'Mod', 'Speed', 'Width', 'Depth', 'Phase', 'Feed', 'Reso', 'Base', 'Env', 'LoSpeed', 'HiSpeed', 'Accel']),
  (FxGroup.character, ['Drive', 'Even', 'Odd', 'PreAmp', 'Buzz', 'Punch', 'Crunch', 'Cabinet', 'Tune', 'Peak', 'ZeroFill', 'Timbre', 'Harmon', 'Process', 'Transf', 'DCBias', 'Vintage', 'LoCont']),
  (FxGroup.dynamics, ['Thresh', 'Thr', 'Ratio', 'Attack', 'Release', 'Hold', 'Knee', 'Squeeze', 'InGain', 'PeakRed', 'AutoRel', 'AutoGain', 'STLink', 'Sustain', 'SBC', 'Slope', 'XOSpc', 'SoloBd']),
  (FxGroup.tone, ['LoCut', 'HiCut', 'LC', 'HC', 'HiSv', 'LoBoost', 'LoFreq', 'LoAtten', 'HiWidth', 'HiBoost', 'HiFreq', 'HiAtten', 'MidFreq', 'MidCut', 'MidGain', 'MidQ', 'BassGain', 'BassFreq', 'HiGain', 'LoGain', 'Low', 'High', 'Shv', 'Lo', 'Hi']),
  (FxGroup.output, ['Level', 'Lvl', 'Mix', 'OutGain', 'Gain', 'Balance', 'Pan', 'Dry', 'MonoPan', 'StereoPan', 'StSpread', 'LMFSpread', 'CntrDist']),
];

/// Gruppo di un parametro, dal nome documentato (senza il suffisso A/B dei tipi doppi).
FxGroup fxGroupOf(String name, FxFamily family) {
  if (name == 'Attack' && family == FxFamily.reverb) return FxGroup.room;
  // nei delay "Feed" è la ripetizione (feedback), non una modulazione
  if (name == 'FeedLC' || name == 'FeedHC') return FxGroup.tone; // filtri della ripetizione
  if (name.startsWith('Feed') && (family == FxFamily.delay || family == FxFamily.combo)) return FxGroup.space;
  for (final (g, prefixes) in _rules) {
    for (final p in prefixes) {
      if (name.startsWith(p)) return g;
    }
  }
  return FxGroup.setup;
}

/// Interruttore di attivazione dell'effetto, quando il tipo ne ha uno documentato (`On`, `OnA`, `OnB`).
bool _isBypass(FxParamDef p) => p.name == 'On' || p.name == 'OnA' || p.name == 'OnB';

String _fxPath(int slot, FxParamDef p) => '/fx/$slot/par/${p.index.toString().padLeft(2, '0')}';

// ==================================================================== PAGINA

/// Effetti: rack degli 8 slot a sinistra, editor dello slot scelto a destra.
class FxPage extends StatefulWidget {
  const FxPage({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<FxPage> createState() => _FxPageState();
}

class _FxPageState extends State<FxPage> {
  int get _slot => widget.ctl.fxSlot;
  set _slot(int v) => widget.ctl.fxSlot = v;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return Padding(
      padding: const EdgeInsets.all(Sp.s),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 260,
          child: MxPanel(
            title: tr('Rack effetti'),
            subtitle: tr('Slot 1–4: insert o mandata · 5–8: insert'),
            padding: const EdgeInsets.all(Sp.s),
            expand: true,
            child: ListView(children: [
              for (var s = 1; s <= 8; s++) _SlotCard(ctl: ctl, slot: s, selected: s == _slot, onTap: () => setState(() => _slot = s)),
            ]),
          ),
        ),
        const SizedBox(width: Sp.s),
        Expanded(child: _FxEditor(ctl: ctl, slot: _slot, key: ValueKey(_slot))),
      ]),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.ctl, required this.slot, required this.selected, required this.onTap});
  final AppController ctl;
  final int slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen('/fx/$slot/type'),
      builder: (context, _, _) {
        final code = ctl.state.fxTypeCode(slot) ?? '?';
        final t = ctl.state.fxType(slot);
        final (name, fam) = fxInfo(code);
        final bypass = t?.params.where(_isBypass).firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: Sp.xs + 2),
          child: Material(
            color: selected ? AppColors.surface3 : AppColors.surface2,
            borderRadius: Rd.brM,
            child: InkWell(
              borderRadius: Rd.brM,
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(Sp.s, Sp.s, Sp.s, Sp.s),
                decoration: BoxDecoration(
                  borderRadius: Rd.brM,
                  border: Border.all(color: selected ? AppColors.selection : AppColors.border, width: selected ? 2 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: fam.color.withValues(alpha: 0.16), borderRadius: Rd.brM, border: Border.all(color: fam.color.withValues(alpha: 0.55))),
                    child: Icon(fam.icon, size: 18, color: fam.color),
                  ),
                  const SizedBox(width: Sp.s),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('FX $slot', style: Tx.caption.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text(code, style: Tx.value.copyWith(fontSize: 11, color: AppColors.textDim)),
                      ]),
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tx.strong),
                      _SlotUsage(ctl: ctl, slot: slot),
                    ]),
                  ),
                  if (bypass != null)
                    ValueListenableBuilder<Object?>(
                      valueListenable: ctl.hub.listen(_fxPath(slot, bypass)),
                      builder: (context, v, _) => MxStateBadge(on: v == 1, onTap: () => ctl.toggle(_fxPath(slot, bypass))),
                    ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FxEditor extends StatelessWidget {
  const _FxEditor({super.key, required this.ctl, required this.slot});
  final AppController ctl;
  final int slot;

  static bool _isGraphicEq(String c) => c == 'GEQ' || c == 'GEQ2' || c == 'TEQ' || c == 'TEQ2';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen('/fx/$slot/type'),
      builder: (context, _, _) {
        final t = ctl.state.fxType(slot);
        final code = ctl.state.fxTypeCode(slot) ?? '?';
        final (name, fam) = fxInfo(code);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _EditorHeader(ctl: ctl, slot: slot, name: name, family: fam, type: t),
          const SizedBox(height: Sp.s),
          Expanded(
            child: t == null
                ? MxEmpty(icon: Icons.help_outline, text: tr('Tipo di effetto sconosciuto.'))
                : _isGraphicEq(t.code)
                    ? _GeqEditor(ctl: ctl, slot: slot, t: t)
                    : SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          FxVisual(ctl: ctl, slot: slot, type: t, color: fam.color),
                          if (fam == FxFamily.pitch) _PitchReadout(ctl: ctl, slot: slot, t: t),
                          if (fam == FxFamily.eq) _BandColumns(ctl: ctl, slot: slot, t: t, color: fam.color) else _ParamGroups(ctl: ctl, slot: slot, t: t, family: fam),
                        ]),
                      ),
          ),
        ]);
      },
    );
  }
}

/// Intestazione dell'editor: slot, nome e famiglia, scelta del tipo, interruttore, sorgenti e ritorno.
class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.ctl, required this.slot, required this.name, required this.family, required this.type});
  final AppController ctl;
  final int slot;
  final String name;
  final FxFamily family;
  final FxTypeDef? type;

  @override
  Widget build(BuildContext context) {
    final bypass = type?.params.where(_isBypass).toList() ?? const [];
    final rtn = StripRef(StripKind.fxrtn, slot * 2 - 1);
    return MxPanel(
      child: Wrap(spacing: Sp.l, runSpacing: Sp.m, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: family.color.withValues(alpha: 0.16), borderRadius: Rd.brM, border: Border.all(color: family.color.withValues(alpha: 0.6))),
            child: Icon(family.icon, color: family.color),
          ),
          const SizedBox(width: Sp.m),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('FX $slot · ${family.label.toUpperCase()}', style: Tx.section.copyWith(color: family.color)),
            Text(name, style: Tx.pageTitle),
          ]),
        ]),
        MxLabeled(tr('Tipo'), _TypeSelector(ctl: ctl, slot: slot)),
        for (final p in bypass)
          MxLabeled(p.name == 'On' ? tr('Attivo') : tr('Attivo {p0}', {'p0': p.name.substring(2)}), ParamToggle(ctl: ctl, path: _fxPath(slot, p), label: 'ON', width: 52)),
        if (slot <= 4) ...[
          MxLabeled(tr('Sorgente L'), ParamDropdown(ctl: ctl, path: '/fx/$slot/source/l', width: 96)),
          MxLabeled(tr('Sorgente R'), ParamDropdown(ctl: ctl, path: '/fx/$slot/source/r', width: 96)),
          MxLabeled(
            tr('Ritorno ({p0})', {'p0': ctl.stripName(rtn)}),
            Row(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<Object?>(
                valueListenable: ctl.hub.listen('${rtn.base}/mix/fader'),
                builder: (context, v, _) {
                  final spec = ctl.state.specOf('${rtn.base}/mix/fader');
                  return MxValueBox(spec == null ? '—' : spec.display(v as int? ?? 0), width: 64);
                },
              ),
              const SizedBox(width: Sp.xs),
              ParamToggle(ctl: ctl, path: ctl.mutePath(rtn), label: tr('MUTE'), invert: true, activeColor: AppColors.mute, width: 56),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.ctl, required this.slot});
  final AppController ctl;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final spec = ctl.state.specOf('/fx/$slot/type')!;
    return Container(
      height: Sz.controlM,
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: Sp.s),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: Rd.brS, border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          isDense: true,
          value: ctl.idx('/fx/$slot/type'),
          dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textDim),
          style: const TextStyle(fontSize: 12.5, color: AppColors.text),
          // tipi raggruppati per famiglia; le intestazioni non sono selezionabili
          items: [
            for (final fam in FxFamily.values)
              if (List.generate(spec.steps + 1, (i) => i).any((i) => fxInfo(spec.labels![i]).$2 == fam)) ...[
                DropdownMenuItem<int>(
                  enabled: false,
                  value: -1 - fam.index,
                  child: Text(fam.label.toUpperCase(), style: Tx.section.copyWith(color: fam.color)),
                ),
                for (var i = 0; i <= spec.steps; i++)
                  if (fxInfo(spec.labels![i]).$2 == fam)
                    DropdownMenuItem(
                      value: i,
                      child: Row(children: [
                        Icon(fam.icon, size: 14, color: fam.color),
                        const SizedBox(width: 6),
                        SizedBox(width: 44, child: Text(spec.labels![i], style: Tx.value.copyWith(fontSize: 11, color: AppColors.textDim))),
                        Expanded(child: Text(fxInfo(spec.labels![i]).$1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
              ],
          ],
          selectedItemBuilder: (context) => [
            for (final fam in FxFamily.values)
              if (List.generate(spec.steps + 1, (i) => i).any((i) => fxInfo(spec.labels![i]).$2 == fam)) ...[
                const SizedBox.shrink(),
                for (var i = 0; i <= spec.steps; i++)
                  if (fxInfo(spec.labels![i]).$2 == fam)
                    Row(children: [
                      Icon(fam.icon, size: 14, color: fam.color),
                      const SizedBox(width: 6),
                      SizedBox(width: 44, child: Text(spec.labels![i], style: Tx.value.copyWith(fontSize: 11, color: AppColors.textDim))),
                      Expanded(child: Text(fxInfo(spec.labels![i]).$1, overflow: TextOverflow.ellipsis)),
                    ]),
              ],
          ],
          onChanged: (i) async {
            if (i == null || i < 0) return;
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(tr('Cambiare effetto?')),
                content: Text(tr('FX {p0} passerà a {p1} ({p2}). I parametri attuali dello slot andranno persi sul mixer.', {'p0': slot, 'p1': fxInfo(spec.labels![i]).$1, 'p2': spec.labels![i]})),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla'))),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Cambia'))),
                ],
              ),
            );
            if (ok != true) return;
            ctl.setIdx('/fx/$slot/type', i);
            // valori di partenza locali dall'Appendice C, poi lettura dei valori reali dal mixer
            ctl.state.resetFxParams(slot, ChangeOrigin.load);
            // senza rilettura i valori mostrati sono quelli predefiniti, non quelli del mixer: lo si dice
            if (!(ctl.client?.requestNode('/fx/$slot/par') ?? false)) {
              ctl.notify(tr("Parametri dell'effetto non riletti dal mixer: i valori mostrati sono quelli predefiniti."));
            }
            ctl.hub.refreshAll();
          },
        ),
      ),
    );
  }
}

/// Parametri raggruppati per funzione; nei tipi doppi, una colonna per il canale A e una per il B.
class _ParamGroups extends StatelessWidget {
  const _ParamGroups({required this.ctl, required this.slot, required this.t, required this.family});
  final AppController ctl;
  final int slot;
  final FxTypeDef t;
  final FxFamily family;

  static const _cell = 78.0;

  static String? _side(FxTypeDef t, FxParamDef p) {
    if (!t.isDual || p.name.length < 3) return null;
    final last = p.name[p.name.length - 1];
    return last == 'A' || last == 'B' ? last : null;
  }

  Widget _groups(List<FxParamDef> params) {
    final by = <FxGroup, List<FxParamDef>>{};
    for (final p in params) {
      final n = _side(t, p) == null ? p.name : p.name.substring(0, p.name.length - 1);
      by.putIfAbsent(fxGroupOf(n, family), () => []).add(p);
    }
    return Wrap(spacing: Sp.s, runSpacing: Sp.s, children: [
      for (final g in FxGroup.values)
        if (by[g] != null)
          SizedBox(
            // larghezza fissa per cella: fino a 6 parametri per riga, pannelli allineati
            width: (by[g]!.length.clamp(2, 6)) * _cell + 2 * Sp.m + 2,
            child: MxPanel(
              title: g.label,
              child: Wrap(runSpacing: Sp.m, crossAxisAlignment: WrapCrossAlignment.end, children: [for (final p in by[g]!) SizedBox(width: _cell, child: Center(child: _param(p)))]),
            ),
          ),
    ]);
  }

  Widget _param(FxParamDef p) {
    final path = _fxPath(slot, p);
    if (p.labels != null && p.labels!.length > 2) {
      return MxLabeled(p.name, ParamDropdown(ctl: ctl, path: path, width: _cell - 8));
    }
    if (p.labels != null) {
      return MxLabeled(p.name, ParamToggle(ctl: ctl, path: path, label: p.labels!.last, width: _cell - 14));
    }
    return Knob(ctl: ctl, path: path, label: p.name, defaultIdx: p.defaultIdx, size: 46, color: family.color);
  }

  @override
  Widget build(BuildContext context) {
    final params = t.params.where((p) => !_isBypass(p)).toList();
    if (!t.isDual) return _groups(params);
    final a = params.where((p) => _side(t, p) != 'B').toList();
    final b = params.where((p) => _side(t, p) == 'B').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('CANALE A'), style: Tx.section.copyWith(color: AppColors.text)),
      const SizedBox(height: Sp.xs),
      _groups(a),
      if (b.isNotEmpty) ...[
        const SizedBox(height: Sp.m),
        Text(tr('CANALE B'), style: Tx.section.copyWith(color: AppColors.text)),
        const SizedBox(height: Sp.xs),
        _groups(b),
      ],
    ]);
  }
}

/// EQ grafici (GEQ/TEQ): un cursore per banda, con frequenze e scala; i tipi doppi hanno A e B.
class _GeqEditor extends StatefulWidget {
  const _GeqEditor({required this.ctl, required this.slot, required this.t});
  final AppController ctl;
  final int slot;
  final FxTypeDef t;
  @override
  State<_GeqEditor> createState() => _GeqEditorState();
}

class _GeqEditorState extends State<_GeqEditor> {
  int _side = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    // bande: parametri il cui nome inizia con una cifra (20 … 20k); livelli: Lvl, LvlA, LvlB
    final all = t.params;
    final groups = <List<FxParamDef>>[];
    var cur = <FxParamDef>[];
    final levels = <FxParamDef>[];
    for (final p in all) {
      if (RegExp(r'^\d').hasMatch(p.name)) {
        cur.add(p);
      } else if (p.name.startsWith('Lvl')) {
        levels.add(p);
        groups.add(cur);
        cur = [];
      }
    }
    if (cur.isNotEmpty) groups.add(cur);
    final side = _side.clamp(0, groups.length - 1);
    final bands = groups.isEmpty ? <FxParamDef>[] : groups[side];
    final level = side < levels.length ? levels[side] : null;
    return MxPanel(
      title: tr('Bande'),
      subtitle: tr('Doppio clic su un cursore: 0 dB'),
      expand: true,
      trailing: groups.length > 1 ? MxSegmented<int>(options: [(0, tr('Canale A')), (1, tr('Canale B'))], value: side, onChanged: (v) => setState(() => _side = v)) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // curva dei guadagni delle bande (sola lettura: si modifica con i cursori)
        SizedBox(
          height: 96,
          child: ListenableBuilder(
            listenable: Listenable.merge([for (final p in bands) widget.ctl.hub.listen(_fxPath(widget.slot, p))]),
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _GeqCurvePainter([for (final p in bands) widget.ctl.state.getPhysical(_fxPath(widget.slot, p)) ?? 0], [for (final p in bands) p.name]),
            ),
          ),
        ),
        const SizedBox(height: Sp.s),
        Expanded(child: LayoutBuilder(builder: (context, c) {
        final w = ((c.maxWidth - 110) / bands.length).clamp(22.0, 40.0);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 30,
            child: Padding(padding: const EdgeInsets.only(bottom: 22), child: _GeqScale()),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final p in bands)
                  SizedBox(
                    width: w,
                    height: c.maxHeight,
                    child: Column(children: [
                      Expanded(child: Fader(ctl: widget.ctl, path: _fxPath(widget.slot, p), accent: FxFamily.geq.color, capGap: 12)),
                      const SizedBox(height: Sp.xs),
                      SizedBox(height: 18, child: FittedBox(child: Text(p.name, style: const TextStyle(fontSize: 10, color: AppColors.textDim)))),
                    ]),
                  ),
              ]),
            ),
          ),
          if (level != null) ...[
            const VerticalDivider(width: Sp.l),
            SizedBox(
              width: 56,
              child: Column(children: [
                Expanded(child: Fader(ctl: widget.ctl, path: _fxPath(widget.slot, level), accent: AppColors.text)),
                const SizedBox(height: Sp.xs),
                SizedBox(height: 18, child: Text(tr('Livello'), style: TextStyle(fontSize: 10, color: AppColors.textDim))),
              ]),
            ),
          ],
        ]);
      })),
      ]),
    );
  }
}

/// Curva dei guadagni dell'EQ grafico: una linea che unisce le bande, su griglia ±15 dB.
class _GeqCurvePainter extends CustomPainter {
  _GeqCurvePainter(this.gains, this.names);
  final List<double> gains;
  final List<String> names;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Rd.m)), Paint()..color = AppColors.well);
    if (gains.isEmpty) return;
    const l = 30.0, r = 10.0;
    final mid = size.height / 2;
    final amp = size.height / 2 - 8;
    final grid = Paint()..color = AppColors.border;
    for (final db in [-12, -6, 0, 6, 12]) {
      final y = mid - db / 15 * amp;
      canvas.drawLine(Offset(l, y), Offset(size.width - r, y), db == 0 ? (Paint()..color = AppColors.textFaint) : grid);
      final tp = TextPainter(text: TextSpan(text: db > 0 ? '+$db' : '$db', style: const TextStyle(fontSize: 9, color: AppColors.textFaint)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(l - tp.width - 4, y - tp.height / 2));
    }
    double x(int i) => l + i / (gains.length - 1) * (size.width - l - r);
    final p = Path();
    for (var i = 0; i < gains.length; i++) {
      final y = mid - gains[i].clamp(-15.0, 15.0) / 15 * amp;
      i == 0 ? p.moveTo(x(i), y) : p.lineTo(x(i), y);
    }
    final fill = Path.from(p)
      ..lineTo(x(gains.length - 1), mid)
      ..lineTo(x(0), mid)
      ..close();
    final c = FxFamily.geq.color;
    canvas.drawPath(fill, Paint()..color = c.withValues(alpha: 0.18));
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = c);
    for (var i = 0; i < gains.length; i++) {
      canvas.drawCircle(Offset(x(i), mid - gains[i].clamp(-15.0, 15.0) / 15 * amp), 2, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_GeqCurvePainter o) => true;
}

/// Scala ±15 dB accanto ai cursori dell'EQ grafico (posizione lineare nel range della banda).
class _GeqScale extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GeqScalePainter(), size: Size.infinite);
}

class _GeqScalePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final top = Fader.inset;
    final travel = size.height - Fader.thumbHeight;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final db in [15, 10, 5, 0, -5, -10, -15]) {
      final y = top + (1 - (db + 15) / 30) * travel;
      tp.text = TextSpan(text: db > 0 ? '+$db' : '$db', style: TextStyle(fontSize: 9, color: db == 0 ? AppColors.textDim : AppColors.textFaint, fontWeight: db == 0 ? FontWeight.w700 : FontWeight.w400));
      tp.layout();
      tp.paint(canvas, Offset(size.width - tp.width - 4, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_GeqScalePainter o) => false;
}

/// Dove è usato lo slot come insert (`<strip>/insert/sel` = FXnL/FXnR), letto dallo stato.
class _SlotUsage extends StatelessWidget {
  const _SlotUsage({required this.ctl, required this.slot});
  final AppController ctl;
  final int slot;

  static final _strips = <StripRef>[
    for (var i = 1; i <= 32; i++) StripRef(StripKind.ch, i),
    for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i),
    for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i),
    const StripRef(StripKind.mainSt, 1),
    const StripRef(StripKind.mainM, 1),
  ];

  @override
  Widget build(BuildContext context) {
    final users = <String>[];
    for (final s in _strips) {
      final spec = ctl.state.specOf('${s.base}/insert/sel');
      final i = ctl.idx('${s.base}/insert/sel');
      if (spec?.labels == null || i == null || ctl.idx('${s.base}/insert/on') != 1) continue;
      final l = spec!.labels![i.clamp(0, spec.labels!.length - 1)];
      if (l == 'FX${slot}L' || l == 'FX${slot}R') users.add(ctl.stripName(s));
    }
    if (users.isEmpty) return Text(slot <= 4 ? tr('mandata (nessun insert attivo)') : tr('nessun insert attivo'), style: Tx.caption.copyWith(fontSize: 10));
    return Text(tr('insert su {p0}', {'p0': users.join(', ')}), maxLines: 1, overflow: TextOverflow.ellipsis, style: Tx.caption.copyWith(fontSize: 10, color: AppColors.selection));
  }
}

/// Pitch shifter: intonazione risultante (semitoni + centesimi) per ogni voce, dai parametri documentati.
class _PitchReadout extends StatelessWidget {
  const _PitchReadout({required this.ctl, required this.slot, required this.t});
  final AppController ctl;
  final int slot;
  final FxTypeDef t;

  @override
  Widget build(BuildContext context) {
    final voices = <(String, FxParamDef, FxParamDef?)>[];
    for (final p in t.params) {
      if (p.name.startsWith('Semi')) {
        final suffix = p.name.substring(4);
        final cent = t.params.where((q) => q.name == 'Cent$suffix').firstOrNull;
        voices.add((suffix.isEmpty ? tr('Voce') : tr('Voce {p0}', {'p0': suffix}), p, cent));
      }
    }
    if (voices.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: ListenableBuilder(
        listenable: Listenable.merge([for (final (_, s, c) in voices) ...[ctl.hub.listen(_fxPath(slot, s)), if (c != null) ctl.hub.listen(_fxPath(slot, c))]]),
        builder: (context, _) => Wrap(spacing: Sp.s, runSpacing: Sp.s, children: [
          for (final (name, s, c) in voices)
            Container(
              width: 220,
              padding: const EdgeInsets.all(Sp.m),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: Rd.brL, border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.toUpperCase(), style: Tx.section.copyWith(color: FxFamily.pitch.color)),
                const SizedBox(height: Sp.xs),
                Builder(builder: (context) {
                  final st = ctl.state.getPhysical(_fxPath(slot, s)) ?? 0;
                  final ct = c == null ? 0.0 : (ctl.state.getPhysical(_fxPath(slot, c)) ?? 0);
                  final total = st + ct / 100;
                  return Text(tr('{p0}{p1} semitoni', {'p0': total >= 0 ? '+' : '', 'p1': total.toStringAsFixed(2)}), style: Tx.pageTitle.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
                }),
                Text(tr('{p0} + {p1} (valori documentati)', {'p0': s.name, 'p1': c?.name ?? ''}), style: Tx.caption),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// EQ "a selettori" (valvolari): una colonna per banda (basse, medie, alte) con i parametri
/// documentati di quella banda, più i comandi generali. Le frequenze sono valori fissi del tipo.
class _BandColumns extends StatelessWidget {
  const _BandColumns({required this.ctl, required this.slot, required this.t, required this.color});
  final AppController ctl;
  final int slot;
  final FxTypeDef t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bands = <(String, List<FxParamDef>)>[(tr('Basse'), []), (tr('Medie'), []), (tr('Alte'), []), (tr('Generali'), [])];
    for (final p in t.params) {
      if (p.name == 'On' || p.name == 'OnA' || p.name == 'OnB') continue;
      final n = p.name;
      final i = n.startsWith('Lo') ? 0 : (n.startsWith('Mid') ? 1 : (n.startsWith('Hi') ? 2 : 3));
      bands[i].$2.add(p);
    }
    Widget control(FxParamDef p) {
      final path = _fxPath(slot, p);
      if (p.labels != null && p.labels!.length > 2) return MxLabeled(p.name, ParamDropdown(ctl: ctl, path: path, width: 96));
      if (p.labels != null) return MxLabeled(p.name, ParamToggle(ctl: ctl, path: path, label: p.labels!.last, width: 72));
      return Knob(ctl: ctl, path: path, label: p.name, defaultIdx: p.defaultIdx, size: 48, color: color);
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (name, ps) in bands)
        if (ps.isNotEmpty)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: Sp.s),
              child: MxPanel(
                title: name,
                child: Wrap(spacing: Sp.s, runSpacing: Sp.m, crossAxisAlignment: WrapCrossAlignment.end, children: [for (final p in ps) control(p)]),
              ),
            ),
          ),
    ]);
  }
}
