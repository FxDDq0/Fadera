// Avvio del simulatore da riga di comando.
//   dart run x32_sim [--port 10023] [--model X32] [--init righe_di_nodo.txt]
// Comandi da tastiera: p = pausa (simula la perdita di connessione), r = ripresa,
// f = muove un fader "dalla superficie", s = statistiche, q = esci.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:x32_sim/x32_sim.dart';

Future<void> main(List<String> args) async {
  var port = 10023;
  var model = 'X32';
  String? init;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port':
        port = int.parse(args[++i]);
      case '--model':
        model = args[++i];
      case '--init':
        init = args[++i];
    }
  }
  final sim = await X32Simulator.start(port: port, model: model, initFile: init);
  stdout.writeln('==============================================================');
  stdout.writeln(' SIMULATORE X32 (non è un mixer reale)');
  stdout.writeln(' In ascolto SOLO su 127.0.0.1:${sim.port}, modello "$model"');
  stdout.writeln(' Comandi: p pausa | r ripresa | f fader | s statistiche | q esci');
  stdout.writeln('==============================================================');
  var fader = 0;
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    switch (line.trim()) {
      case 'p':
        sim.paused = true;
        stdout.writeln('in pausa: il client dovrebbe segnalare la perdita di connessione entro 10 s');
      case 'r':
        sim.paused = false;
        stdout.writeln('ripreso');
      case 'f':
        fader = (fader + 128) % 1024;
        sim.surfaceSet('/ch/01/mix/fader', fader);
        stdout.writeln('fader ch 01 → idx $fader');
      case 's':
        stdout.writeln('ricevuti ${sim.received}, inviati ${sim.sent}, scene ${sim.scenes.length}');
      case 'q':
        await sim.close();
        exit(0);
    }
  }
}
