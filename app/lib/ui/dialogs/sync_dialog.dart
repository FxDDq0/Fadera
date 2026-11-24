import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../theme.dart';
import '../../l10n/l10n.dart';

/// Scelta della direzione di sincronizzazione dopo la connessione.
/// PC → Mixer richiede una seconda conferma esplicita e salva prima un backup.
class SyncDialog extends StatefulWidget {
  const SyncDialog({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  int _done = 0;
  int _total = kSyncNodes.length;
  bool _running = false;
  bool _cancel = false;
  String? _result;

  Future<void> _fromMixer() async {
    setState(() {
      _running = true;
      _cancel = false;
      _result = null;
    });
    final r = await widget.ctl.syncFromMixer((d, t) {
      if (mounted && (d % 25 == 0 || d == t)) {
        setState(() {
          _done = d;
          _total = t;
        });
      }
    }, () => _cancel);
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = r.ok
          ? tr('Sincronizzazione completata: {p0} nodi in {p1} s.', {'p0': r.completed, 'p1': (r.elapsed.inMilliseconds / 1000).toStringAsFixed(1)})
          : r.cancelled
              ? tr('Interrotta dopo {p0} nodi: lo stato locale è parziale.', {'p0': r.completed})
              : tr('Errore: {p0}', {'p0': r.error});
    });
    if (r.ok) Navigator.pop(context);
  }

  Future<void> _toMixer() async {
    final ctl = widget.ctl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Inviare lo stato del PC al mixer?')),
        content: SizedBox(
          width: 440,
          child: Text(
            tr('Tutti i parametri del mixer {p0} ({p1}) verranno sostituiti con quelli '
'presenti in questa applicazione: {p2} nodi (canali, bus, effetti, routing, uscite).\n\n'
'Prima dell\'invio viene salvato un backup dello stato locale.\n\n'
'Attenzione: la risposta del mixer a questo tipo di invio non è ancora stata verificata su hardware reale.', {'p0': ctl.mixer?.name ?? '', 'p1': ctl.mixer?.ip ?? '', 'p2': kSyncNodes.length}),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(c, true), child: Text(tr('Sostituisci i parametri del mixer'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final f = ctl.backupLocalState('prima_di_PC_a_Mixer');
    setState(() {
      _running = true;
      _cancel = false;
    });
    final r = await ctl.syncToMixer((d, t) {
      if (mounted && (d % 25 == 0 || d == t)) {
        setState(() {
          _done = d;
          _total = t;
        });
      }
    }, () => _cancel);
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = tr('{p0} righe inviate. Backup: {p1}', {'p0': r.completed, 'p1': f.path});
    });
    ctl.synced = r.ok;
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return AlertDialog(
      title: Text(tr('Connesso a {p0}', {'p0': ctl.mixer?.name ?? ''})),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ctl.isSimulator)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.sim.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.sim)),
              child: Text(tr('Sessione con il SIMULATORE locale: nessun mixer reale è coinvolto.')),
            ),
          Text(tr('{p0} · firmware {p1} · {p2}', {'p0': ctl.mixer?.model ?? '', 'p1': ctl.mixer?.firmware ?? '', 'p2': ctl.mixer?.ip ?? ''}), style: const TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 14),
          Text(tr('Per lavorare serve uno stato allineato. Scegli la direzione:')),
          const SizedBox(height: 14),
          if (_running) ...[
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            const SizedBox(height: 6),
            Text(tr('{p0} / {p1} nodi', {'p0': _done, 'p1': _total}), style: mono.copyWith(fontSize: 12)),
          ],
          if (_result != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_result!)),
        ]),
      ),
      actions: _running
          ? [TextButton(onPressed: () => setState(() => _cancel = true), child: Text(tr('Interrompi')))]
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Più tardi'))),
              OutlinedButton(onPressed: _toMixer, child: Text(tr('PC → Mixer…'))),
              FilledButton(onPressed: _fromMixer, child: Text(tr('Mixer → PC (consigliato)'))),
            ],
    );
  }
}
