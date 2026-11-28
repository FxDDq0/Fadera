import 'dart:async';

import 'package:flutter/material.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../design/components.dart';
import '../../theme.dart';
import '../icons/strip_icons.dart';
import '../../l10n/l10n.dart';

/// Selettore dell'icona di una strip. L'icona è un parametro del mixer (`<strip>/config/icon`):
/// - senza connessione il selettore si può consultare ma non modificare;
/// - con la connessione la scelta viene inviata al mixer e poi riletta con `/node`:
///   l'esito mostrato è quello letto dal mixer, non quello inviato.
class IconPickerDialog extends StatefulWidget {
  const IconPickerDialog({super.key, required this.ctl, required this.strip, this.preselect});
  final AppController ctl;
  final StripRef strip;

  /// Icona già scelta all'apertura (catture e scorciatoie); la scelta non viene inviata finché non si preme "Invia".
  final int? preselect;
  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

enum _Status { idle, sending, confirmed, mismatch, timeout }

class _IconPickerDialogState extends State<IconPickerDialog> {
  late final String _path = '${widget.strip.base}/config/icon';
  late int? _choice = widget.preselect ?? widget.ctl.idx(_path);
  _Status _status = _Status.idle;
  int? _readBack;
  StreamSubscription<String>? _sub;
  Timer? _timer;
  bool _armed = false;

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  /// Icona letta da una riga `config` (`/ch/01/config "nome" ICONA COLORE …`).
  static int? _iconFromLine(String line) {
    final m = RegExp(r'^\S+\s+(?:"[^"]*"|\S+)\s+(\d+)').firstMatch(line);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  Future<void> _send() async {
    final ctl = widget.ctl;
    final c = ctl.client;
    final id = _choice;
    if (c == null || !ctl.isOnline || id == null) return;
    setState(() {
      _status = _Status.sending;
      _readBack = null;
    });
    _sub?.cancel();
    _timer?.cancel();
    final nodePath = '${widget.strip.base}/config';
    _armed = false;
    _sub = c.nodeLines.listen((line) {
      if (!_armed || !line.startsWith('$nodePath ')) return;
      final v = _iconFromLine(line);
      _timer?.cancel();
      _sub?.cancel();
      if (mounted) {
        setState(() {
          _readBack = v;
          _status = v == id ? _Status.confirmed : _Status.mismatch;
        });
      }
    });
    ctl.setIdx(_path, id);
    // rilettura dal mixer: la conferma è la sua risposta, non il nostro invio
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) {
      _sub?.cancel();
      return;
    }
    // si ascolta solo da qui: una riga arrivata prima della richiesta non è una conferma
    _armed = true;
    if (!c.requestNode(nodePath)) {
      _sub?.cancel();
      setState(() => _status = _Status.timeout);
      return;
    }
    _timer = Timer(const Duration(seconds: 2), () {
      _sub?.cancel();
      if (mounted && _status == _Status.sending) setState(() => _status = _Status.timeout);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final online = ctl.isOnline && ctl.client != null;
    return ValueListenableBuilder<Object?>(
      valueListenable: ctl.hub.listen(_path),
      builder: (context, cur, _) {
        final current = cur as int?;
        final sel = stripIconInfo(_choice);
        return Dialog(
          insetPadding: const EdgeInsets.all(Sp.l),
          child: SizedBox(
            width: 900,
            height: (MediaQuery.sizeOf(context).height - 40).clamp(420.0, 660.0),
            child: Padding(
              padding: const EdgeInsets.all(Sp.l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                MxPageHeader(
                  title: tr('Icona · {p0}', {'p0': ctl.stripName(widget.strip)}),
                  subtitle: tr('L\'icona è un parametro del mixer ({p0}/config/icon, valori 1–74), separato dal nome e dal colore.', {'p0': widget.strip.base}),
                  actions: [MxIconButton(icon: Icons.close, tooltip: tr('Chiudi'), onTap: () => Navigator.pop(context))],
                ),
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // griglia per gruppi
                    Expanded(
                      child: ListView(children: [
                        for (final g in kStripIconGroups) ...[
                          Padding(padding: const EdgeInsets.fromLTRB(0, Sp.s, 0, Sp.xs), child: Text(tr(g).toUpperCase(), style: Tx.section)),
                          Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
                            for (final i in kStripIcons.where((i) => i.group == g))
                              Tooltip(
                                message: '${i.name} (n. ${i.id})',
                                waitDuration: const Duration(milliseconds: 300),
                                child: InkWell(
                                  borderRadius: Rd.brM,
                                  onTap: () => setState(() {
                                    _choice = i.id;
                                    _status = _Status.idle;
                                  }),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: i.id == _choice ? AppColors.selection.withValues(alpha: 0.18) : AppColors.surface2,
                                      borderRadius: Rd.brM,
                                      border: Border.all(
                                          color: i.id == _choice ? AppColors.selection : (i.id == current ? AppColors.ok : AppColors.border), width: i.id == _choice ? 2 : 1),
                                    ),
                                    child: Center(child: StripIconView(i.id, size: 28)),
                                  ),
                                ),
                              ),
                          ]),
                        ],
                      ]),
                    ),
                    const SizedBox(width: Sp.l),
                    // anteprima e invio
                    SizedBox(
                      width: 240,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        MxPanel(
                          title: tr('Sul mixer adesso'),
                          child: Row(children: [
                            StripIconView(current, size: 32, tooltip: true),
                            const SizedBox(width: Sp.s),
                            Expanded(
                              child: Text(
                                current == null ? tr('Non ancora letta') : (stripIconInfo(current)?.name ?? tr('Icona n. {p0} non riconosciuta (valore conservato)', {'p0': current})),
                                style: Tx.body,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: Sp.s),
                        MxPanel(
                          title: tr('Scelta'),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Center(child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(color: AppColors.well, borderRadius: Rd.brL, border: Border.all(color: AppColors.border)),
                              child: Center(child: StripIconView(_choice, size: 64)),
                            )),
                            const SizedBox(height: Sp.s),
                            Text(sel == null ? '—' : sel.name, style: Tx.title),
                            Text(sel == null ? '' : tr('Identificativo {p0}', {'p0': sel.id}), style: Tx.caption),
                          ]),
                        ),
                        const Spacer(),
                        _StatusLine(status: _status, readBack: _readBack, online: online),
                        const SizedBox(height: Sp.s),
                        MxButton(
                          label: tr('Invia al mixer'),
                          icon: Icons.upload_outlined,
                          kind: MxButtonKind.primary,
                          tooltip: online ? null : tr('Serve la connessione al mixer'),
                          onTap: online && _choice != null && _choice != current && _status != _Status.sending ? _send : null,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.readBack, required this.online});
  final _Status status;
  final int? readBack;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = !online
        ? (Icons.link_off, AppColors.textDim, tr('Non connesso: l\'icona si cambia solo con il mixer collegato. Fadera non salva icone solo sul PC.'))
        : switch (status) {
            _Status.idle => (Icons.info_outline, AppColors.textDim, tr('Scegli un\'icona e premi "Invia al mixer". L\'esito viene riletto dal mixer.')),
            _Status.sending => (Icons.sync, AppColors.warn, tr('Inviata. In attesa della rilettura dal mixer…')),
            _Status.confirmed => (Icons.check_circle, AppColors.ok, tr('Confermata: il mixer riporta l\'icona n. {p0}.', {'p0': readBack})),
            _Status.mismatch => (Icons.error_outline, AppColors.error, tr('Il mixer riporta l\'icona n. {p0}, diversa da quella inviata.', {'p0': readBack})),
            _Status.timeout => (Icons.help_outline, AppColors.warn, tr('Nessuna risposta dal mixer entro 2 s: la modifica non è confermata.')),
          };
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: Sp.xs),
      Expanded(child: Text(text, style: Tx.caption.copyWith(color: color))),
    ]);
  }
}
