// Fase B: scrittura di parametri SOLO sui canali 31 e 32, con rilettura indipendente.
//
// Per ogni percorso: lettura del valore attuale dal mixer (/node), scrittura tramite il motore
// di Fadera (MixerState.setIdx/setString → X32Client), poi rilettura da una SECONDA connessione
// separata, così il valore riletto viene davvero dal mixer e non dallo stato locale.
//
// Uso: dart run tool/hw_write.dart <ip> <percorso=valore> [percorso=valore ...]
//      dart run tool/hw_write.dart <ip> get <percorso> [percorso ...]
// Il valore è il testo di una riga di nodo (es. -10, -oo, ON, OFF, 1k00, @123 per un indice).
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:x32_core/x32_core.dart';

final _allowed = RegExp(r'^(/ch/3[12]/|/-stat/solosw/3[12]$)');
final _solo = RegExp(r'^/-stat/solosw/(3[12])$');

String _nodeOf(String leaf) => leaf.substring(1, leaf.lastIndexOf('/'));

Future<(X32Client, UdpTransport)> _open(String ip) async {
  final t = await UdpTransport.bind();
  final c = X32Client(transport: t, state: MixerState())..autoReconnect = false;
  await c.connect(InternetAddress(ip));
  return (c, t);
}

Future<void> _read(X32Client c, Iterable<String> leaves) async {
  for (final n in {for (final l in leaves) if (!_solo.hasMatch(l)) _nodeOf(l)}) {
    c.requestNode(n);
  }
  await Future<void>.delayed(const Duration(milliseconds: 600));
}

String _show(MixerState s, String leaf) {
  final spec = s.specOf(leaf);
  if (spec == null) return '(percorso sconosciuto)';
  if (spec.kind == ParamKind.string) return '"${s.getString(leaf) ?? ''}"';
  final i = s.getIdx(leaf);
  return i == null ? '(non letto)' : '${spec.display(i)} [idx $i]';
}

Future<void> main(List<String> args) async {
  final ip = args[0];
  final getOnly = args.length > 1 && args[1] == 'get';
  final items = <(String, String?)>[
    for (final a in args.skip(getOnly ? 2 : 1))
      if (getOnly) (a, null) else (a.substring(0, a.indexOf('=')), a.substring(a.indexOf('=') + 1)),
  ];
  for (final (p, _) in items) {
    if (!_allowed.hasMatch(p)) {
      stderr.writeln('RIFIUTATO: $p non è sui canali 31/32 autorizzati');
      exit(2);
    }
  }

  final (c, t) = await _open(ip);
  final s = c.state;
  await _read(c, items.map((e) => e.$1));
  for (final (p, _) in items) {
    stdout.writeln('prima   $p = ${_show(s, p)}');
  }
  if (!getOnly) {
    for (final (p, v) in items) {
      final sm = _solo.firstMatch(p);
      if (sm != null) {
        c.setSolo(int.parse(sm.group(1)!), v == '1');
        stdout.writeln('scritto $p = $v (solo tramite /-stat/solosw)');
        continue;
      }
      final spec = s.specOf(p);
      if (spec == null) {
        stderr.writeln('percorso sconosciuto: $p');
        exit(3);
      }
      if (v!.startsWith('drag:')) {
        // Trascinamento rapido: 150 valori ogni 10 ms lungo tutta la corsa, poi il valore finale.
        final fin = spec.parseText(v.substring(5)) ?? (throw FormatException('valore finale non valido: $v'));
        for (var k = 0; k < 150; k++) {
          s.setIdx(p, spec.idxFromFraction(0.5 + 0.5 * sin(k / 8)));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        s.setIdx(p, fin);
        stdout.writeln('scritto $p: 150 valori in 1,5 s, poi ${v.substring(5)} [idx $fin] (inviati in totale ${c.queue.sent}, fusi ${c.queue.coalesced})');
        continue;
      }
      final ok = spec.kind == ParamKind.string
          ? s.setString(p, v)
          : s.setIdx(p, v.startsWith('@') ? int.parse(v.substring(1)) : (spec.parseText(v) ?? (throw FormatException('valore non valido per $p: $v'))));
      stdout.writeln('scritto $p = $v (${ok ? 'inviato' : 'nessuna modifica'})');
    }
    await c.queue.drained();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  await c.disconnect();
  await t.close();

  if (!getOnly) {
    final (c2, t2) = await _open(ip);
    await _read(c2, items.map((e) => e.$1));
    for (final (p, v) in items) {
      stdout.writeln('riletto $p = ${_solo.hasMatch(p) ? 'solo ${c2.solo[int.parse(_solo.firstMatch(p)!.group(1)!)]}' : _show(c2.state, p)}   (richiesto $v)');
    }
    await c2.disconnect();
    await t2.close();
  }
  exit(0);
}
