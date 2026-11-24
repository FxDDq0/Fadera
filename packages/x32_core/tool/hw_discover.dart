// Prova della ricerca (sola lettura: solo pacchetti /xinfo): ricerca su ogni scheda di rete.
// Uso: dart run tool/hw_discover.dart [ultimo_ip]
import 'dart:io';

import 'package:x32_core/x32_core.dart';

Future<void> main(List<String> args) async {
  final last = args.isNotEmpty ? args[0] : '';
  final ip = InternetAddress.tryParse(last);
  final r = await X32Client.discoverAll(hosts: [if (ip != null) ip]);
  stdout.writeln('schede: ${r.interfaces.map((i) => '${i.name}=${i.address.address}').join(', ')}');
  for (final m in r.mixers) {
    stdout.writeln('trovato: ${m.name} ${m.model} FW ${m.firmware} ${m.ip} (risposta da ${m.address.address})');
  }
  if (r.mixers.isEmpty) r.explain(last).forEach(stdout.writeln);
  exit(0);
}
