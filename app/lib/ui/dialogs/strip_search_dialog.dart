import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../design/tokens.dart';
import '../../l10n/l10n.dart';

/// Ricerca rapida dei canali (Ctrl+F): scrivi un nome o un numero, Invio va al primo risultato.
/// Solo navigazione nell'app: nulla viene inviato al mixer.
class StripSearchDialog extends StatefulWidget {
  const StripSearchDialog({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<StripSearchDialog> createState() => _StripSearchDialogState();
}

class _StripSearchDialogState extends State<StripSearchDialog> {
  final _field = TextEditingController();
  List<StripRef> _results = const [];

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _go(StripRef s) {
    widget.ctl.goToStrip(s);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return AlertDialog(
      key: const ValueKey('strip-search'),
      title: Text(tr('Cerca un canale')),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const ValueKey('strip-search-field'),
            controller: _field,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: tr('Nome o numero: Kick, 12, bus 3, dca 2'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _results = ctl.searchStrips(v)),
            onSubmitted: (_) {
              if (_results.isNotEmpty) _go(_results.first);
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _field.text.trim().isEmpty ? tr('Scrivi per cercare tra canali, bus, matrici e DCA.') : tr('Nessun canale trovato.'),
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  )
                : ListView(children: [
                    for (final s in _results)
                      ListTile(
                        dense: true,
                        leading: Icon(s.kind == StripKind.dca ? Icons.tune : Icons.graphic_eq, size: 18, color: AppColors.textDim),
                        title: Text(ctl.stripName(s)),
                        subtitle: Text(s.label, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
                        onTap: () => _go(s),
                      ),
                  ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Chiudi')))],
    );
  }
}
