// Prova dei meter (T04/T13), sola lettura: iscrizione ai banchi meter e registrazione dei valori.
// Invia solo /xinfo, /status, /xremote, /batchsubscribe, /renew e /unsubscribe: nessun valore al mixer.
//
// Uso: dart run tool/hw_meters.dart <ip> <file_uscita.tsv> <secondi> [banchi separati da virgola]
import 'dart:async';
import 'dart:io';

import 'package:x32_core/x32_core.dart';

Future<void> main(List<String> args) async {
  final ip = args[0];
  final out = File(args[1])..parent.createSync(recursive: true);
  final seconds = int.parse(args[2]);
  final banks = args.length > 3 ? args[3].split(',').map(int.parse).toList() : [0, 1, 2, 5, 7, 8, 12, 13, 16];
  final t = await UdpTransport.bind();
  final c = X32Client(transport: t, state: MixerState())..autoReconnect = false;
  final w = out.openWrite()..writeln('ms\tbank\tdb...');
  final sw = Stopwatch()..start();
  final counts = <int, int>{};
  c.meters.listen((f) {
    counts[f.bank] = (counts[f.bank] ?? 0) + 1;
    if (f.values.isEmpty) {
      w.writeln('${sw.elapsedMilliseconds}\t${f.bank}\traw:${f.words.length}');
      return;
    }
    w.writeln('${sw.elapsedMilliseconds}\t${f.bank}\t${[for (var i = 0; i < f.values.length; i++) f.db(i).toStringAsFixed(1)].join('\t')}');
  });
  final info = await c.connect(InternetAddress(ip));
  stdout.writeln('connesso: ${info.name} ${info.model} ${info.firmware}; banchi $banks; registrazione $seconds s');
  sw.reset();
  for (final b in banks) {
    c.subscribeMeters(b);
  }
  await Future<void>.delayed(Duration(seconds: seconds));
  for (final b in banks) {
    c.unsubscribeMeters(b);
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  stdout.writeln('frame ricevuti per banco: $counts');
  await w.close();
  await c.disconnect();
  await t.close();
  exit(0);
}
