import 'dart:io';

import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../theme.dart';
import 'sync_dialog.dart';
import '../../l10n/l10n.dart';

/// Connessione: ricerca automatica (broadcast `/xinfo`) o indirizzo manuale.
class ConnectDialog extends StatefulWidget {
  const ConnectDialog({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<ConnectDialog> {
  late final _host = TextEditingController(text: widget.ctl.prefs.lastHost);
  List<MixerInfo> _found = [];
  List<String> _why = [];
  bool _scanning = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final r = await widget.ctl.discover();
      if (mounted) {
        setState(() {
          _found = r.mixers;
          _why = r.mixers.isEmpty ? r.explain(widget.ctl.prefs.lastHost) : const [];
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = tr('Ricerca non riuscita: {p0}', {'p0': e}));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(String host) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final parts = host.trim().split(':');
      await widget.ctl.connect(parts[0], port: parts.length > 1 ? int.parse(parts[1]) : kX32Port);
      if (!mounted) return;
      Navigator.pop(context);
      await showDialog(context: context, barrierDismissible: false, builder: (_) => SyncDialog(ctl: widget.ctl));
    } on Object catch (e) {
      if (mounted) setState(() => _error = friendlyConnectError(host, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return AlertDialog(
      title: Text(tr('Connessione al mixer')),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr('Mixer trovati in rete'), style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (_scanning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) else TextButton.icon(onPressed: _scan, icon: const Icon(Icons.refresh, size: 16), label: Text(tr('Cerca'))),
          ]),
          const SizedBox(height: 8),
          if (_found.isEmpty && !_scanning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Nessun mixer ha risposto alla ricerca.'), style: TextStyle(color: AppColors.textDim)),
                for (final w in _why)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(w, key: const ValueKey('connect-why'), style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                  ),
              ]),
            ),
          for (final m in _found)
            Card(
              color: AppColors.surface3,
              child: ListTile(
                leading: Icon(Icons.developer_board, color: m.isSimulator ? AppColors.sim : AppColors.accent),
                title: Text(m.name),
                subtitle: Text('${m.model} · FW ${m.firmware} · ${m.ip}${m.isSimulator ? ' · SIMULATORE' : ''}'),
                trailing: FilledButton(onPressed: _busy ? null : () => _connect('${m.address.address}:${m.port}'), child: Text(tr('Connetti'))),
              ),
            ),
          const Divider(height: 28),
          Text(tr('Indirizzo manuale'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _host,
                decoration: InputDecoration(hintText: tr('es. 192.168.1.2'), isDense: true, border: OutlineInputBorder()),
                onSubmitted: _busy ? null : _connect,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : () => _connect(_host.text), child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('Connetti'))),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, key: const ValueKey('connect-error'), style: const TextStyle(color: AppColors.error)),
          ],
        ]),
      ),
      actions: [
        if (ctl.isOnline || ctl.link == LinkState.lost)
          TextButton(
            onPressed: () async {
              await ctl.disconnect();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(tr('Disconnetti')),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Chiudi'))),
      ],
    );
  }
}

/// Messaggio comprensibile per un collegamento non riuscito.
String friendlyConnectError(String host, Object e) {
  final h = host.trim();
  if (h.isEmpty) return tr("Scrivi l'indirizzo IP del mixer (si legge sul mixer in Setup → Network), per esempio 192.168.1.2.");
  if (e is FormatException) return tr('Indirizzo non valido: "{p0}". Usa la forma 192.168.1.2 oppure 192.168.1.2:10023.', {'p0': h});
  if (e is SocketException) {
    return tr('Indirizzo "{p0}" non raggiungibile da questo PC ({p1}). '
"Controlla di aver scritto bene l'indirizzo e che il PC sia sulla stessa rete del mixer.", {'p0': h, 'p1': e.osError?.message ?? e.message});
  }
  if (e is ConnectException && e.message.contains('non risponde')) {
    return tr("{p0} Controlla che il mixer sia acceso, collegato alla rete e che l'indirizzo sia quello indicato "
"sul mixer (Setup → Network). Il PC deve essere sulla stessa rete: l'hotspot del telefono è una rete diversa.", {'p0': e.message});
  }
  return e.toString();
}

