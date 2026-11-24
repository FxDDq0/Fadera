// Coda di invio: coalescenza, ordine, barriere, limiti, errori.
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';

OscMessage fader(int ch, int idx) => OscMessage('/ch/${ch.toString().padLeft(2, '0')}/mix/fader', [OscFloat(idx / 1023)]);
OscMessage cmd(String a) => OscMessage(a, [const OscInt(1)]);

void main() {
  late List<OscMessage> out;
  late SendResult Function(Uint8List) behaviour;
  late SendQueue q;
  setUp(() {
    out = [];
    behaviour = (_) => SendResult.sent;
    q = SendQueue(sink: (d) {
      final r = behaviour(d);
      if (r == SendResult.sent) out.add(decodeOsc(d).single);
      return r;
    }, retryDelay: const Duration(milliseconds: 5), maxErrorRetries: 3);
  });
  tearDown(() => q.dispose());

  test('senza congestione: invio immediato di ogni valore', () {
    for (var i = 0; i < 10; i++) {
      q.enqueueLatest(fader(1, i));
    }
    expect(out.length, 10);
    expect(q.isEmpty, isTrue);
  });

  test('trascinamento sotto congestione: resta solo l\'ultimo valore, mai uno vecchio dopo', () {
    behaviour = (_) => SendResult.wouldBlock;
    for (var i = 0; i <= 1000; i++) {
      q.enqueueLatest(fader(1, i));
      q.enqueueLatest(fader(2, 1000 - i));
    }
    expect(q.length, 2); // una voce per parametro
    expect(q.coalesced, 2000 - 2 + 2);
    behaviour = (_) => SendResult.sent;
    q.onWritable();
    expect(out.map((m) => m.address), ['/ch/01/mix/fader', '/ch/02/mix/fader']);
    expect((out[0].args.single as OscFloat).value, closeTo(1000 / 1023, 1e-6));
    expect((out[1].args.single as OscFloat).value, 0);
  });

  test('i comandi non vengono mai fusi né scartati e restano in ordine', () {
    behaviour = (_) => SendResult.wouldBlock;
    for (var i = 0; i < 50; i++) {
      q.enqueueOrdered(cmd('/-stat/solosw/${(i % 80 + 1).toString().padLeft(2, '0')}'));
    }
    expect(q.length, 50);
    behaviour = (_) => SendResult.sent;
    q.onWritable();
    expect(out.length, 50);
    expect(out.first.address, '/-stat/solosw/01');
    expect(out.last.address, '/-stat/solosw/50');
  });

  test('barriera: un comando separa i valori dello stesso parametro (A=1, scena, A=2)', () {
    behaviour = (_) => SendResult.wouldBlock;
    q.enqueueLatest(fader(1, 1));
    q.enqueueOrdered(OscMessage('/load', [const OscString('scene'), const OscInt(3), const OscInt(0), const OscInt(0)]));
    q.enqueueLatest(fader(1, 2));
    q.enqueueLatest(fader(1, 3)); // si fonde con A=2, non con A=1
    behaviour = (_) => SendResult.sent;
    q.onWritable();
    expect(out.map((m) => m.address), ['/ch/01/mix/fader', '/load', '/ch/01/mix/fader']);
    expect((out[0].args.single as OscFloat).value, closeTo(1 / 1023, 1e-6));
    expect((out[2].args.single as OscFloat).value, closeTo(3 / 1023, 1e-6));
  });

  test('coda dei comandi limitata', () {
    final small = SendQueue(sink: (_) => SendResult.wouldBlock, maxOrdered: 10);
    for (var i = 0; i < 10; i++) {
      small.enqueueOrdered(cmd('/x$i'));
    }
    expect(() => small.enqueueOrdered(cmd('/oltre')), throwsA(isA<QueueFullException>()));
    // i parametri restano limitati dal numero di percorsi distinti
    for (var i = 0; i < 10000; i++) {
      small.enqueueLatest(fader(1 + i % 32, i % 1024));
    }
    expect(small.length, 10 + 32);
    small.dispose();
  });

  test('errore di invio: ritentativo, poi scarto segnalato', () async {
    final logs = <String>[];
    final eq = SendQueue(sink: (_) => SendResult.error, retryDelay: const Duration(milliseconds: 2), maxErrorRetries: 3, onLog: (l, m) => logs.add('$l $m'));
    eq.enqueueOrdered(cmd('/save'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(eq.isEmpty, isTrue);
    expect(eq.dropped, 1);
    expect(eq.sendErrors, 4);
    expect(logs.single, startsWith('E invio di /save fallito'));
    eq.dispose();
  });

  test('errore temporaneo: il messaggio parte quando la rete torna', () async {
    var fail = 2;
    final got = <String>[];
    final eq = SendQueue(sink: (d) {
      if (fail-- > 0) return SendResult.error;
      got.add(decodeOsc(d).single.address);
      return SendResult.sent;
    }, retryDelay: const Duration(milliseconds: 2));
    eq.enqueueOrdered(cmd('/a'));
    eq.enqueueOrdered(cmd('/b'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(got, ['/a', '/b']);
    eq.dispose();
  });

  test('clear() alla perdita del mixer: nulla parte alla ripresa', () {
    behaviour = (_) => SendResult.wouldBlock;
    q.enqueueOrdered(cmd('/load'));
    q.enqueueLatest(fader(1, 5));
    expect(q.clear(), 2);
    behaviour = (_) => SendResult.sent;
    q.onWritable();
    expect(out, isEmpty);
  });

  test('drained() completa quando la coda si svuota', () async {
    behaviour = (_) => SendResult.wouldBlock;
    q.enqueueOrdered(cmd('/a'));
    var done = false;
    unawaited(q.drained().then((_) => done = true));
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    behaviour = (_) => SendResult.sent;
    q.onWritable();
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
  });

  test('stress casuale: con congestione intermittente il valore finale di ogni fader è l\'ultimo scelto', () {
    var seed = 42;
    int rnd() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final last = <String, int>{};
    final seen = <String, int>{};
    final lastSentIndex = <String, int>{};
    var counter = 0;
    behaviour = (_) => rnd() % 3 == 0 ? SendResult.wouldBlock : SendResult.sent;
    for (var i = 0; i < 100000; i++) {
      final ch = 1 + rnd() % 16;
      final v = rnd() % 1024;
      final m = fader(ch, v);
      last[m.address] = v;
      q.enqueueLatest(m);
      if (rnd() % 10 == 0) q.onWritable();
    }
    behaviour = (_) => SendResult.sent;
    q.onWritable();
    for (final m in out) {
      seen[m.address] = ((m.args.single as OscFloat).value * 1023).round();
      lastSentIndex[m.address] = counter++;
    }
    expect(seen, last);
  });
}
