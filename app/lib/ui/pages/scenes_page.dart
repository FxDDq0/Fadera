import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:x32_core/x32_core.dart';

import '../../controller/app_controller.dart';
import '../../controller/scene_file.dart';
import '../../brand.g.dart';
import '../../controller/prefs.dart';
import '../../theme.dart';
import '../../design/components.dart';
import '../widgets/controls.dart';
import '../../l10n/l10n.dart';

// ===================================================================== SCENE

class ScenesPage extends StatefulWidget {
  const ScenesPage({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<ScenesPage> createState() => _ScenesPageState();
}

class _ScenesPageState extends State<ScenesPage> {
  Future<bool> _confirm(String title, String text, {String ok = /*l10n*/ 'Conferma', bool danger = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: SizedBox(width: 420, child: Text(text)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla'))),
              FilledButton(style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.mute) : null, onPressed: () => Navigator.pop(c, true), child: Text(tr(ok))),
            ],
          ),
        ) ??
        false;
  }

  Future<(String, String)?> _askName(String title, {String name = '', String notes = ''}) {
    final n = TextEditingController(text: name), d = TextEditingController(text: notes);
    return showDialog<(String, String)>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // il mixer accetta solo testo ASCII: lettere accentate non arriverebbero (invio scartato)
            TextField(controller: n, maxLength: 32, autofocus: true, inputFormatters: [_asciiOnly], decoration: InputDecoration(labelText: tr('Nome'), helperText: tr('Solo lettere senza accento, numeri e simboli comuni.'))),
            const SizedBox(height: Sp.s),
            TextField(controller: d, maxLength: 64, inputFormatters: [_asciiOnly], decoration: InputDecoration(labelText: tr('Note'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla'))),
          FilledButton(onPressed: () => Navigator.pop(c, (n.text, d.text)), child: const Text('OK')),
        ],
      ),
    );
  }

  String _type = 'scene';
  String _filter = '';

  static final _asciiOnly = FilteringTextInputFormatter.allow(RegExp(r'[ -~]'));

  /// Avvisa se un comando verso il mixer non è partito (mixer non raggiungibile nel frattempo).
  void _sent(bool ok) {
    if (!ok) widget.ctl.notify(tr('Comando non inviato: il mixer non è raggiungibile.'));
  }

  static final _labels = {'scene': (tr('Scene'), tr('la scena'), 100), 'snippet': ('Snippet', tr('lo snippet'), 100), 'cue': ('Cue', tr('il cue'), 500)};

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final c = ctl.client;
    final online = ctl.isOnline && c != null;
    final (title, noun, slots) = _labels[_type]!;
    final names = ctl.datasetNames[_type]!;
    final items = names.entries.where((e) => _filter.isEmpty || e.value.toLowerCase().contains(_filter.toLowerCase()) || '${e.key}'.contains(_filter)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    int firstFree() => List.generate(slots, (i) => i).firstWhere((i) => !names.containsKey(i), orElse: () => -1);
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MxPageHeader(
              title: tr('Scene, snippet e cue'),
              subtitle: online
                  ? tr('Memorie salvate nel mixer. Il richiamo cambia i parametri: viene sempre chiesta conferma e prima si salva un backup locale. '
'Le risposte del mixer a questi comandi non sono ancora verificate su hardware.')
                  : tr('Connettiti a un mixer per gestire le memorie della console. I file sul PC restano disponibili.'),
              actions: [
                MxSegmented<String>(options: [for (final t in _labels.keys) (t, _labels[t]!.$1)], value: _type, onChanged: (v) => setState(() => _type = v)),
              ],
            ),
            Expanded(
              child: MxPanel(
              expand: true,
              padding: const EdgeInsets.all(Sp.s),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // barra degli strumenti: ricerca a sinistra, operazioni generali a destra
                Row(children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(hintText: tr('Cerca in {p0}', {'p0': title}), hintStyle: Tx.caption.copyWith(fontSize: 13), prefixIcon: const Icon(Icons.search, size: 18)),
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                  const Spacer(),
                  MxButton(label: tr('Aggiorna elenco'), icon: Icons.refresh, kind: MxButtonKind.ghost, onTap: online ? () => _sent(c.requestShowDump()) : null),
                  const SizedBox(width: Sp.s),
                  MxButton(
                    label: _type == 'cue' ? tr('Nuovo cue') : tr('Salva nuovo'),
                    icon: _type == 'cue' ? Icons.add : Icons.save_outlined,
                    kind: MxButtonKind.primary,
                    onTap: !online
                        ? null
                        : () async {
                            final free = firstFree();
                            if (free < 0) return;
                            if (_type == 'cue') {
                              _sent(c.cueAdd(free));
                              return;
                            }
                            final r = await _askName(tr('Salva lo stato corrente in posizione {p0}', {'p0': free}));
                            if (r != null) _sent(c.datasetSave(_type, free, r.$1, r.$2));
                          },
                  ),
                ]),
                const SizedBox(height: Sp.s),
                // intestazione della tabella
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: 6),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(children: [
                    SizedBox(width: 56, child: Text('N°', style: Tx.section)),
                    Expanded(child: Text(tr('NOME'), style: Tx.section)),
                    SizedBox(width: 250, child: Text(tr('OPERAZIONI'), style: Tx.section, textAlign: TextAlign.right)),
                  ]),
                ),
                Expanded(
                  child: items.isEmpty
                      ? MxEmpty(
                          icon: Icons.photo_library_outlined,
                          text: names.isEmpty ? tr('Nessun elemento noto.\nDopo la connessione usa "Aggiorna elenco".') : tr('Nessun risultato per "{p0}".', {'p0': _filter}),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final e = items[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.xs),
                              decoration: BoxDecoration(
                                color: i.isOdd ? AppColors.surface2.withValues(alpha: 0.5) : Colors.transparent,
                                border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                              ),
                              child: Row(children: [
                                SizedBox(width: 56, child: Text(e.key.toString().padLeft(3, '0'), style: Tx.value.copyWith(color: AppColors.selection))),
                                Expanded(child: Text(e.value.isEmpty ? tr('(senza nome)') : e.value, style: e.value.isEmpty ? Tx.caption : Tx.body)),
                                // operazione principale separata dalle secondarie
                                MxButton(
                                  label: tr('Richiama'),
                                  icon: Icons.play_arrow_rounded,
                                  height: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () async {
                                          if (await _confirm(tr('Richiamare "{p0}"?', {'p0': e.value}), tr('Il mixer applicherà {p0} {p1}: i parametri attuali verranno modificati. Prima viene salvato un backup locale.', {'p0': noun, 'p1': e.key}),
                                              ok: tr('Richiama'))) {
                                            try {
                                              ctl.backupLocalState('prima_di_richiamo_${_type}_${e.key}');
                                            } on Object catch (err) {
                                              ctl.notify(tr('Backup non riuscito ({p0}): richiamo annullato.', {'p0': err}));
                                              return;
                                            }
                                            final ok = c.datasetLoad(_type, e.key);
                                            _sent(ok);
                                            if (ok) ctl.clearUndo();
                                          }
                                        },
                                ),
                                const SizedBox(width: Sp.m),
                                MxIconButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: tr('Rinomina'),
                                  size: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () async {
                                          final r = await _askName(tr('Rinomina {p0}', {'p0': e.key}), name: e.value);
                                          if (r != null) _sent(c.datasetRename(_type, e.key, r.$1, r.$2));
                                        },
                                ),
                                const SizedBox(width: Sp.xs),
                                MxIconButton(
                                  icon: Icons.copy,
                                  tooltip: tr('Copia nella prima posizione libera'),
                                  size: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () {
                                          final free = firstFree();
                                          if (free >= 0) _sent(c.datasetCopy(_type, e.key, free));
                                        },
                                ),
                                const SizedBox(width: Sp.xs),
                                MxIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: tr('Elimina'),
                                  color: AppColors.mute,
                                  size: Sz.controlM,
                                  onTap: !online
                                      ? null
                                      : () async {
                                          if (await _confirm(tr('Eliminare "{p0}"?', {'p0': e.value}), tr('La posizione {p0} verrà cancellata dal mixer. L\'operazione non si può annullare.', {'p0': e.key}),
                                              ok: tr('Elimina'), danger: true)) {
                                            _sent(c.datasetDelete(_type, e.key));
                                          }
                                        },
                                ),
                              ]),
                            );
                          },
                        ),
                ),
              ]),
            ),
            ),
          ]),
        ),
        const SizedBox(width: Sp.m),
        SizedBox(width: 360, child: _LocalFiles(ctl: ctl, confirm: _confirm)),
      ]),
    );
  }
}

/// File locali in formato righe di nodo (stesso formato delle scene X32, doc 13).
class _LocalFiles extends StatefulWidget {
  const _LocalFiles({required this.ctl, required this.confirm});
  final AppController ctl;
  final Future<bool> Function(String, String, {String ok, bool danger}) confirm;
  @override
  State<_LocalFiles> createState() => _LocalFilesState();
}

class _LocalFilesState extends State<_LocalFiles> {
  Directory get _dir => appSubDir('scene');

  Future<void> _onFileAction(BuildContext context, File f, String action) async {
    final ctl = widget.ctl;
    final List<String> lines;
    try {
      lines = readSceneFile(f);
    } on SceneFileException catch (e) {
      ctl.log('E', 'file di scena ${f.path}: $e');
      ctl.notify(tr('File non usato: {p0}', {'p0': e.message}));
      return;
    }
    if (action == 'load') {
      try {
        ctl.backupLocalState('prima_di_import_locale');
      } on Object catch (e) {
        ctl.notify(tr('Backup non riuscito ({p0}): file non caricato.', {'p0': e}));
        return;
      }
      // anche nel solo caricamento valgono le regole dell'invio: righe di nodi noti, mai `/-…`
      // (altrimenti una sync PC → Mixer successiva le invierebbe)
      var skipped = 0;
      for (final l in lines) {
        if (!l.trim().startsWith('/')) continue;
        if (!isSceneNodeLine(l, ctl.state) || !ctl.state.applyNodeLine(l, ChangeOrigin.load)) skipped++;
      }
      ctl.hub.refreshAll();
      ctl.clearUndo();
      if (skipped > 0) ctl.notify(tr("File caricato nell'app: {p0} righe non riconosciute ignorate.", {'p0': skipped}));
      return;
    }
    if (action != 'send' || !ctl.isOnline || !context.mounted) return;
    var source = lines;
    var partial = false;
    if (ctl.prefs.experimentalRecallScope) {
      // Funzione sperimentale: invio parziale solo con una conferma esplicita in più.
      final scope = await showDialog<RecallScope>(context: context, builder: (_) => RecallScopeDialog(ctl: ctl));
      if (scope == null || !context.mounted) return;
      final all = [for (final l in lines) if (l.trim().startsWith('/')) l.trim()];
      source = scope.filter(lines);
      partial = source.length != all.length;
      if (partial &&
          !await widget.confirm(tr('Invio PARZIALE (funzione sperimentale)'),
              tr('Verranno inviate solo {p0} righe su {p1}. Il mixer riceverà una configurazione parziale, '
'con categorie ricostruite e non verificate su hardware. Continuare solo se sai esattamente cosa resta escluso.', {'p0': source.length, 'p1': all.length}),
              ok: tr('Ho capito, continua'), danger: true)) {
        return;
      }
    }
    final plan = planSceneSend(source, ctl.state);
    if (plan.sendable.isEmpty) {
      ctl.notify(tr('Nel file non ci sono righe inviabili al mixer ({p0} scartate).', {'p0': plan.rejected.length}));
      return;
    }
    final details = [
      if (plan.rejected.isNotEmpty) tr('{p0} righe non verranno inviate (comandi, preferenze o percorsi sconosciuti).', {'p0': plan.rejected.length}),
      if (plan.phantomLines > 0) tr('ATTENZIONE: {p0} righe cambiano guadagno e alimentazione phantom (+48 V) degli ingressi.', {'p0': plan.phantomLines}),
    ];
    if (!context.mounted) return;
    final ok = await widget.confirm(
        tr('Inviare il file al mixer?'),
        tr('{p0} righe{p1} verranno applicate al mixer. '
'Prima viene salvato un backup locale. La risposta del mixer a questo invio non è ancora verificata su hardware.', {'p0': plan.sendable.length, 'p1': partial ? tr(' (invio parziale)') : ''}) +
            (details.isEmpty ? '' : '\n\n${details.join('\n')}'),
        ok: tr('Invia'),
        danger: true);
    // le finestre di conferma lasciano tempo al collegamento di cadere
    final client = ctl.client;
    if (!ok || !context.mounted) return;
    if (client == null || !ctl.isOnline) {
      ctl.notify(tr('File non inviato: il mixer non è più raggiungibile.'));
      return;
    }
    try {
      ctl.backupLocalState('prima_di_invio_file');
    } on Object catch (e) {
      ctl.notify(tr('Backup non riuscito ({p0}): invio annullato, il mixer non è stato modificato.', {'p0': e}));
      return;
    }
    final sent = await client.sendNodeLines(plan.sendable);
    final complete = sent == plan.sendable.length && ctl.isOnline;
    // invio parziale: non si sa con certezza quali righe sono arrivate, lo stato va riallineato
    if (!complete) ctl.synced = false;
    // lo stato locale segue solo ciò che è partito davvero
    for (final l in plan.sendable.take(sent)) {
      ctl.state.applyNodeLine(l, ChangeOrigin.load);
    }
    ctl.hub.refreshAll();
    ctl.clearUndo();
    ctl.log(complete ? 'I' : 'W', 'file ${f.path}: $sent/${plan.sendable.length} righe inviate, ${plan.rejected.length} scartate');
    ctl.notify(complete
        ? tr('File inviato: {p0} righe.', {'p0': sent})
        : tr('Invio incompleto: {p0} di {p1} righe. Il mixer è stato modificato solo in parte; il backup è nella cartella backup.', {'p0': sent, 'p1': plan.sendable.length}));
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final files = _dir.listSync().whereType<File>().where((f) => f.path.endsWith('.scn')).toList()..sort((a, b) => b.path.compareTo(a.path));
    return Container(
      padding: const EdgeInsets.all(Sp.m),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: Rd.brL, border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('FILE SUL PC'), style: Tx.section),
        const SizedBox(height: 2),
        Text(_dir.path, style: Tx.caption),
        const SizedBox(height: Sp.s),
        Text(tr('Stesso formato delle scene X32. "Carica solo nell’app" non tocca il mixer; "Invia al mixer" chiede conferma e salva prima un backup.'), style: Tx.caption),
        const SizedBox(height: Sp.s),
        FilledButton.icon(
          onPressed: () {
            final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '');
            try {
              File('${_dir.path}${Platform.pathSeparator}scena_$ts.scn')
                  .writeAsStringSync('# ${Brand.name}: esportazione dello stato locale, ${DateTime.now()}\n${ctl.state.snapshot()}\n');
            } on FileSystemException catch (e) {
              ctl.log('E', 'esportazione dello stato non riuscita: $e');
              ctl.notify(tr('Esportazione non riuscita: {p0}', {'p0': e.message}));
            }
            setState(() {});
          },
          icon: const Icon(Icons.download, size: 16),
          label: Text(tr('Esporta stato corrente')),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            for (final f in files)
              ListTile(
                dense: true,
                title: Text(f.uri.pathSegments.last, style: const TextStyle(fontSize: 12)),
                trailing: PopupMenuButton<String>(
                  onSelected: (a) => _onFileAction(context, f, a),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'load', child: Text(tr('Carica solo nell\'app'))),
                    PopupMenuItem(value: 'send', enabled: ctl.isOnline, child: Text(tr('Invia al mixer…'))),
                  ],
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Ambito di richiamo per l'invio di un file di scena: categorie e strip protette.
/// Le scelte restano salvate nelle preferenze. Non modifica le impostazioni safe del mixer.
class RecallScopeDialog extends StatefulWidget {
  const RecallScopeDialog({super.key, required this.ctl});
  final AppController ctl;
  @override
  State<RecallScopeDialog> createState() => _RecallScopeDialogState();
}

class _RecallScopeDialogState extends State<RecallScopeDialog> {
  late final Set<String> _excluded = widget.ctl.prefs.scopeExcluded.toSet();
  late final Set<String> _safe = widget.ctl.prefs.safeStrips.toSet();

  static final _strips = <StripRef>[
    for (var i = 1; i <= 32; i++) StripRef(StripKind.ch, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.auxin, i),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.fxrtn, i),
    for (var i = 1; i <= 16; i++) StripRef(StripKind.bus, i),
    for (var i = 1; i <= 6; i++) StripRef(StripKind.mtx, i),
    const StripRef(StripKind.mainSt, 1),
    const StripRef(StripKind.mainM, 1),
    for (var i = 1; i <= 8; i++) StripRef(StripKind.dca, i),
  ];

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    return AlertDialog(
      title: Text(tr('Ambito di richiamo (sperimentale)')),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 280,
            child: ListView(children: [
              Text(tr('Cosa inviare'), style: Theme.of(context).textTheme.titleMedium),
              for (final c in ScopeCategory.values)
                CheckboxListTile(
                  dense: true,
                  value: !_excluded.contains(c.name),
                  title: Text(c.label, style: const TextStyle(fontSize: 12)),
                  onChanged: (v) => setState(() => v == true ? _excluded.remove(c.name) : _excluded.add(c.name)),
                ),
            ]),
          ),
          const VerticalDivider(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Strip protette (non modificate)'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final s in _strips)
                      PillButton(
                        label: ctl.stripName(s),
                        active: _safe.contains(s.base),
                        activeColor: AppColors.warn,
                        width: 72,
                        height: 26,
                        onTap: () => setState(() => _safe.contains(s.base) ? _safe.remove(s.base) : _safe.add(s.base)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annulla'))),
        FilledButton(
          onPressed: () {
            ctl.prefs
              ..scopeExcluded = _excluded.toList()
              ..safeStrips = _safe.toList()
              ..save();
            Navigator.pop(
              context,
              RecallScope(enabled: {for (final c in ScopeCategory.values) if (!_excluded.contains(c.name)) c}, safeStrips: _safe),
            );
          },
          child: Text(tr('Continua')),
        ),
      ],
    );
  }
}
