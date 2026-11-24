import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../controller/prefs.dart';
import '../../design/components.dart';
import '../../theme.dart';
import '../../version.dart';
import '../../l10n/l10n.dart';

/// Diagnostica: stato della connessione, mixer, sync, traffico, coda di invio, errori,
/// eventi del collegamento e registro filtrabile; esportazione di un file di testo.
/// Si apre da Impostazioni: non occupa la schermata principale.
class DiagnosticsView extends StatefulWidget {
  const DiagnosticsView({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends State<DiagnosticsView> {
  String _level = 'tutti';
  Timer? _tick;
  String? _exported;

  @override
  void initState() {
    super.initState();
    // aggiornamento periodico dei contatori
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: Tx.label)),
          Expanded(child: SelectableText(v, style: Tx.value.copyWith(fontSize: 12, color: color ?? AppColors.text))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final c = ctl.client;
    final q = c?.queue;
    final m = ctl.mixer;
    final link = ctl.link;
    final linkColor = switch (link) {
      LinkState.connected => ctl.synced ? AppColors.ok : AppColors.warn,
      LinkState.lost => AppColors.error,
      LinkState.disconnected => AppColors.textDim,
      _ => AppColors.warn,
    };
    final errors = ctl.logs.where((e) => e.level == 'E').length;
    final warns = ctl.logs.where((e) => e.level == 'W').length;
    final logs = ctl.logs.reversed.where((e) => _level == 'tutti' || (_level == 'errori' && e.level == 'E') || (_level == 'avvisi' && (e.level == 'W' || e.level == 'E'))).take(400).toList();
    final s = ctl.lastSync;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: Sp.s),
      Wrap(spacing: Sp.s, runSpacing: Sp.s, children: [
        SizedBox(
          width: 520,
          child: MxPanel(
            title: tr('Connessione'),
            child: Column(children: [
              _kv(tr('Stato'), tr('{p0}{p1}', {'p0': link.name, 'p1': link == LinkState.connected ? (ctl.synced ? tr(' · sincronizzato') : tr(' · non sincronizzato')) : ''}), color: linkColor),
              _kv('Mixer', m == null ? '—' : tr('{p0} · {p1} · firmware {p2}{p3}', {'p0': m.name, 'p1': m.model, 'p2': m.firmware, 'p3': m.isSimulator ? ' · SIMULATORE' : ''})),
              _kv(tr('Indirizzo'), m == null ? '—' : '${m.ip}:${m.port}'),
              _kv(tr('Perdite del mixer'), '${ctl.lostCount}', color: ctl.lostCount > 0 ? AppColors.warn : null),
              _kv(tr('Ultima sync'), s == null ? tr('nessuna') : '${s.completed}/${s.total} nodi · ${s.retransmissions} ritrasmissioni · ${s.elapsed.inMilliseconds} ms${s.ok ? '' : ' · INCOMPLETA'}',
                  color: s == null ? null : (s.ok ? AppColors.ok : AppColors.error)),
              _kv(tr('Avvisi di lettura'), tr('{p0} righe con valori inattesi', {'p0': ctl.state.warnings.length}), color: ctl.state.warnings.isEmpty ? null : AppColors.warn),
            ]),
          ),
        ),
        SizedBox(
          width: 520,
          child: MxPanel(
            title: tr('Traffico e coda di invio'),
            child: Column(children: [
              _kv(tr('Messaggi'), tr('inviati {p0} · ricevuti {p1}', {'p0': c?.sentCount ?? 0, 'p1': c?.receivedCount ?? 0})),
              _kv(tr('Pacchetti non validi'), tr('{p0} scartati', {'p0': c?.droppedCount ?? 0}), color: (c?.droppedCount ?? 0) > 0 ? AppColors.warn : null),
              _kv(tr('Rifiutati'), tr('{p0} comandi durante la perdita del mixer', {'p0': c?.rejectedWhileLost ?? 0})),
              _kv(tr('Coda'), tr('in attesa {p0} (ordinati {p1}) · max {p2}', {'p0': q?.length ?? 0, 'p1': q?.orderedLength ?? 0, 'p2': q?.maxDepth ?? 0})),
              _kv(tr('Esiti'), tr('accorpati {p0} · rete occupata {p1} · errori {p2} · scartati {p3}', {'p0': q?.coalesced ?? 0, 'p1': q?.wouldBlockCount ?? 0, 'p2': q?.sendErrors ?? 0, 'p3': q?.dropped ?? 0}),
                  color: (q?.sendErrors ?? 0) + (q?.dropped ?? 0) > 0 ? AppColors.warn : null),
              _kv(tr('Registro'), tr('{p0} errori · {p1} avvisi', {'p0': errors, 'p1': warns})),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: Sp.s),
      Row(children: [
        MxSegmented<String>(options: [('tutti', tr('Tutto')), ('avvisi', tr('Avvisi ed errori')), ('errori', tr('Solo errori'))], value: _level, onChanged: (v) => setState(() => _level = v)),
        const Spacer(),
        if (_exported != null) Flexible(child: Text(_exported!, style: Tx.caption, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: Sp.s),
        MxButton(
          label: tr('Esporta diagnostica'),
          icon: Icons.save_alt,
          kind: MxButtonKind.primary,
          tooltip: tr('Salva un file di testo con stato, contatori, eventi e registro, da allegare a una segnalazione'),
          onTap: () {
            final f = ctl.exportDiagnostics(appVersion: '$kAppVersion ($kAppBuild)');
            setState(() => _exported = f.path);
          },
        ),
        const SizedBox(width: Sp.xs),
        MxIconButton(
          icon: Icons.folder_open,
          tooltip: tr('Apri la cartella dei file di diagnostica'),
          onTap: Platform.isWindows ? () => Process.run('explorer', [appSubDirPath('diagnostica')]) : null,
        ),
      ]),
      const SizedBox(height: Sp.s),
      Expanded(
        child: Container(
          decoration: BoxDecoration(color: AppColors.well, borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
          child: logs.isEmpty
              ? MxEmpty(icon: Icons.check_circle_outline, text: tr('Nessun evento per questo filtro.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(Sp.s),
                  itemCount: logs.length,
                  itemBuilder: (_, i) => Text(logs[i].toString(),
                      style: Tx.value.copyWith(fontSize: 11, color: logs[i].level == 'E' ? AppColors.error : (logs[i].level == 'W' ? AppColors.warn : AppColors.textDim))),
                ),
        ),
      ),
    ]);
  }
}
