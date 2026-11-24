// Strumento della sessione hardware (fase A, sola lettura): connessione, sync Mixer → PC,
// riepilogo di nomi, colori e icone, poi ascolto delle modifiche fatte sulla console.
// Non invia nessun valore al mixer: solo /xinfo, /status, /xremote, /renew e le richieste /node della sync.
//
// Uso: dart run tool/hw_session.dart <ip> <cartella_uscita> [secondi_di_ascolto]
import 'dart:async';
import 'dart:io';

import 'package:x32_core/x32_core.dart';

Future<void> main(List<String> args) async {
  final ip = args[0];
  final out = Directory(args[1])..createSync(recursive: true);
  final listen = args.length > 2 ? int.parse(args[2]) : 0;
  final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '');
  final state = MixerState();
  final t = await UdpTransport.bind();
  final c = X32Client(transport: t, state: state)..autoReconnect = false;
  final log = File('${out.path}/S_A_sessione_$ts.log').openWrite();
  void p(String s) {
    stdout.writeln(s);
    log.writeln(s);
  }

  c.log.listen((e) => log.writeln('[log] $e'));
  final info = await c.connect(InternetAddress(ip));
  p('A1 connessione: ${info.name} · ${info.model} · firmware ${info.firmware} · ${info.ip}');
  final sw = Stopwatch()..start();
  final r = await c.syncFromMixer();
  p('A2 sync: ${r.completed}/${r.total} nodi · ${r.retransmissions} ritrasmissioni · ${sw.elapsedMilliseconds} ms · ok=${r.ok}${r.error == null ? '' : ' · errore ${r.error}'}');
  p('A2 avvisi di lettura: ${state.warnings.length}');
  for (final w in state.warnings) {
    p('   $w');
  }
  final snap = File('${out.path}/S_A2_sync_$ts.txt')..writeAsStringSync(state.snapshot());
  p('A2 istantanea: ${snap.path}');

  // A3: nomi, icone e colori come li legge Fadera
  String two(int i) => i.toString().padLeft(2, '0');
  final strips = <(String, String)>[
    for (var i = 1; i <= 32; i++) ('Ch ${two(i)}', '/ch/${two(i)}'),
    for (var i = 1; i <= 8; i++) ('Aux ${i}', '/auxin/${two(i)}'),
    for (var i = 1; i <= 8; i++) ('FxRtn ${i}', '/fxrtn/${two(i)}'),
    for (var i = 1; i <= 16; i++) ('Bus ${two(i)}', '/bus/${two(i)}'),
    for (var i = 1; i <= 6; i++) ('Mtx ${i}', '/mtx/${two(i)}'),
    ('Main LR', '/main/st'),
    ('Mono', '/main/m'),
    for (var i = 1; i <= 8; i++) ('DCA ${i}', '/dca/$i'),
  ];
  final t3 = StringBuffer('strip\tnome\ticona\tcolore\tfader\tmute(on)\n');
  for (final (label, b) in strips) {
    final fader = state.specOf(b.startsWith('/dca') ? '$b/fader' : '$b/mix/fader');
    final fi = state.getIdx(b.startsWith('/dca') ? '$b/fader' : '$b/mix/fader');
    final colorSpec = state.specOf('$b/config/color');
    final ci = state.getIdx('$b/config/color');
    t3.writeln([
      label,
      state.getString('$b/config/name') ?? '',
      state.getIdx('$b/config/icon') ?? '—',
      ci == null || colorSpec?.labels == null ? '—' : colorSpec!.labels![ci],
      fi == null || fader == null ? '—' : fader.display(fi),
      state.getIdx(b.startsWith('/dca') ? '$b/on' : '$b/mix/on') ?? '—',
    ].join('\t'));
  }
  final f3 = File('${out.path}/S_A3_nomi_icone_colori_$ts.tsv')..writeAsStringSync(t3.toString());
  p('A3 tabella: ${f3.path}');

  if (listen > 0) {
    // A6/A7: modifiche fatte sulla console, ricevute da Fadera
    p('ascolto delle modifiche dalla console per $listen s…');
    final sub = state.changes.listen((ch) {
      if (ch.origin == ChangeOrigin.remote) p('${DateTime.now().toIso8601String().substring(11, 23)}  ${ch.path} = ${ch.value}');
    });
    await Future<void>.delayed(Duration(seconds: listen));
    await sub.cancel();
  }
  p('inviati ${c.sentCount} · ricevuti ${c.receivedCount} · scartati ${c.droppedCount}');
  await c.disconnect();
  await t.close();
  await log.close();
  exit(0);
}
