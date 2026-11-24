// Prova A8 (sola lettura): connessione con riconnessione automatica; registra i cambi di stato
// del collegamento e, al ritorno del mixer, rifà la sync e verifica che sia completa.
//
// Uso: dart run tool/hw_link.dart <ip> <secondi>
import 'dart:async';
import 'dart:io';

import 'package:x32_core/x32_core.dart';

Future<void> main(List<String> args) async {
  final ip = args[0];
  final seconds = int.parse(args[1]);
  final state = MixerState();
  final t = await UdpTransport.bind();
  final c = X32Client(transport: t, state: state)..autoReconnect = true;
  final sw = Stopwatch()..start();
  String ts() => '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1).padLeft(6)} s';
  // Diagnostica del socket: errori in ricezione, fine del flusso, ultimo pacchetto ricevuto.
  var lastRx = 0;
  t.incoming.listen((_) => lastRx = sw.elapsedMilliseconds,
      onError: (Object e) => stdout.writeln('${ts()}  [socket] errore in ricezione: $e'),
      onDone: () => stdout.writeln('${ts()}  [socket] flusso di ricezione CHIUSO'));
  Timer.periodic(const Duration(seconds: 10), (_) {
    final q = c.queue;
    stdout.writeln('${ts()}  [stato] ${c.link.name} · ultimo rx a ${(lastRx / 1000).toStringAsFixed(1)} s · '
        'inviati ${q.sent} · wouldBlock ${q.wouldBlockCount} · errori invio ${q.sendErrors} · scartati ${q.dropped} · in coda ${q.length} · lastError ${t.lastError}');
  });
  var lostSeen = false;
  var resynced = false;
  var metersAfterResume = 0;
  c.meters.listen((_) {
    if (resynced) metersAfterResume++;
  });
  c.linkChanges.listen((s) async {
    stdout.writeln('${ts()}  collegamento: ${s.name}');
    if (s == LinkState.lost) lostSeen = true;
    if (s == LinkState.connected && lostSeen && !resynced) {
      resynced = true;
      final r = await c.syncFromMixer();
      stdout.writeln('${ts()}  sync dopo la ripresa: ${r.completed}/${r.total} · ok=${r.ok} · ritrasmissioni ${r.retransmissions}');
    }
  });
  c.log.listen((e) {
    if (e.level != 'I' || e.message.contains('riconness') || e.message.contains('perso')) stdout.writeln('${ts()}  [${e.level}] ${e.message}');
  });
  final info = await c.connect(InternetAddress(ip));
  stdout.writeln('${ts()}  connesso a ${info.name}');
  final r = await c.syncFromMixer();
  c.subscribeMeters(0);
  stdout.writeln('${ts()}  sync iniziale ${r.completed}/${r.total} ok=${r.ok}. Ora scollegare il cavo per ~30 s, poi ricollegarlo.');
  await Future<void>.delayed(Duration(seconds: seconds));
  stdout.writeln('${ts()}  fine: stato ${c.link.name}, perdita vista=$lostSeen, sync dopo la ripresa=$resynced, rifiutati durante la perdita ${c.rejectedWhileLost}, frame meter dopo la ripresa $metersAfterResume');
  c.unsubscribeMeters(0);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await c.disconnect();
  await t.close();
  exit(0);
}
