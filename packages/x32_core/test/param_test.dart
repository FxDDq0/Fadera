import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';

void main() {
  final s = MixerState();
  ParamSpec spec(String p) => s.specOf(p)!;

  group('quantizzazione k/N (verificata su hardware T03/T03c)', () {
    final cases = <String, int>{
      '/ch/01/mix/fader': 1023,
      '/ch/01/mix/01/level': 160,
      '/ch/01/mix/pan': 100,
      '/ch/01/preamp/trim': 144,
      '/ch/01/preamp/hpf': 100,
      '/ch/01/gate/thr': 160,
      '/ch/01/dyn/thr': 120,
      '/ch/01/delay/time': 4997,
      '/ch/01/eq/2/f': 200,
      '/ch/01/eq/2/g': 120,
      '/headamp/000/gain': 144,
    };
    cases.forEach((path, n) {
      test('$path ha N = $n', () => expect(spec(path).steps, n));
    });

    test('ogni indice va e torna dal float OSC senza perdita', () {
      for (final p in cases.keys) {
        final sp = spec(p);
        for (var i = 0; i <= sp.steps; i++) {
          final f = (sp.toOsc(i) as OscFloat).value;
          // il float32 del filo deve dare lo stesso indice
          expect(sp.idxFromOsc(OscFloat(f)), i, reason: '$p idx $i');
        }
      }
    });
  });

  group('conversioni (valori osservati sul mixer reale)', () {
    test('fader 0.695015 → idx 711 → −2,2 dB', () {
      final sp = spec('/ch/01/mix/fader');
      final i = sp.idxFromOsc(const OscFloat(0.695015))!;
      expect(i, 711);
      expect(sp.physical(i), closeTo(-2.2, 0.05));
    });
    test('fader 0 dB → idx 767 → 0.74976', () {
      final sp = spec('/ch/01/mix/fader');
      expect(sp.idxFromPhysical(0), 767);
      expect((sp.toOsc(767) as OscFloat).value, closeTo(0.74976, 1e-5));
    });
    test('mandata 0.775 → idx 124 → +1,0 dB', () {
      final sp = spec('/ch/01/mix/01/level');
      final i = sp.idxFromOsc(const OscFloat(0.775))!;
      expect(i, 124);
      expect(sp.physical(i), closeTo(1.0, 1e-9));
    });
    test('mandata 0.01875 → idx 3 → −81 dB (segmento −90…−60)', () {
      final sp = spec('/ch/01/mix/01/level');
      expect(sp.physical(sp.idxFromOsc(const OscFloat(0.01875))!), closeTo(-81, 1e-9));
    });
    test('HPF 0.54 → 100,8 Hz', () {
      final sp = spec('/ch/01/preamp/hpf');
      expect(sp.physical(54), closeTo(100.8, 0.05));
    });
    test('delay 0.0192115 → idx 96 → 9,9 ms', () {
      final sp = spec('/ch/01/delay/time');
      final i = sp.idxFromOsc(const OscFloat(0.0192115))!;
      expect(i, 96);
      expect(sp.physical(i), closeTo(9.9, 1e-6));
    });
    test('EQ 1 kHz → idx 113 → 0.565', () {
      final sp = spec('/ch/01/eq/2/f');
      expect(sp.idxFromPhysical(1000), 113);
    });
    test('headamp +30 dB → idx 84', () {
      expect(spec('/headamp/000/gain').idxFromPhysical(30), 84);
    });
    test('trim 0.659722 → idx 95 → +5,75 dB', () {
      final sp = spec('/ch/01/preamp/trim');
      expect(sp.physical(sp.idxFromOsc(const OscFloat(0.659722))!), closeTo(5.75, 1e-9));
    });
  });

  group('curva dei livelli', () {
    test('estremi e segmenti', () {
      expect(levelDbToIdx(-200, 1023), 0);
      expect(levelDbToIdx(10, 1023), 1023);
      expect(levelDbToIdx(-10, 1023), 512);
      for (var i = 1; i <= 1023; i++) {
        final db = levelFloatToDb(i / 1023);
        expect(levelDbToIdx(db, 1023), i, reason: 'idx $i');
      }
    });
    test('testo dei livelli', () {
      expect(formatLevel(0.04), '  0.0');
      expect(formatLevel(-6), ' -6.0');
      expect(formatLevel(-144), '  -oo');
    });
  });

  group('testo delle frequenze', () {
    test('k e decimali', () {
      expect(formatNumber('%k1f', 124.7), '124.7');
      expect(formatNumber('%k1f', 1977.2), '1k97');
      expect(formatNumber('%k1f', 10023.7), '10k02');
      expect(parseNumberText('10k4'), closeTo(10400, 1e-6));
      expect(parseNumberText('1k97'), closeTo(1970, 1e-6));
    });
  });

  group('anti-eco nello stato', () {
    test('le modifiche portano la loro origine', () async {
      final st = MixerState();
      final seen = <ChangeOrigin>[];
      st.changes.listen((c) => seen.add(c.origin));
      st.setIdx('/ch/05/mix/fader', 700);
      st.applyOsc(OscMessage('/ch/05/mix/fader', [const OscFloat(0.5)]));
      st.applyNodeLine('/ch/05/mix ON  -6.0 ON +0 OFF   -oo', ChangeOrigin.sync);
      expect(seen, [ChangeOrigin.local, ChangeOrigin.remote, ChangeOrigin.sync]);
    });
    test('nessuna notifica se il valore non cambia', () {
      final st = MixerState();
      var n = 0;
      st.changes.listen((_) => n++);
      st.setIdx('/ch/05/mix/fader', 0);
      expect(n, 0);
    });
    test('messaggi con argomenti sbagliati vengono scartati', () {
      final st = MixerState();
      expect(st.applyOsc(OscMessage('/ch/01/mix/fader', [const OscString('x')])), isFalse);
      expect(st.applyOsc(OscMessage('/ch/01/mix/fader', [const OscFloat(0.1), const OscFloat(0.2)])), isFalse);
      expect(st.applyOsc(OscMessage('/ch/99/mix/fader', [const OscFloat(0.1)])), isFalse);
      expect(st.applyOsc(OscMessage('/ch/01/config/name', [const OscInt(3)])), isFalse);
    });
    test('valori fuori range vengono limitati', () {
      final st = MixerState();
      st.applyOsc(OscMessage('/ch/01/mix/fader', [const OscFloat(7.0)]));
      expect(st.getIdx('/ch/01/mix/fader'), 1023);
      st.applyOsc(OscMessage('/ch/01/dyn/ratio', [const OscInt(99)]));
      expect(st.getIdx('/ch/01/dyn/ratio'), 11);
    });
  });

  group('effetti', () {
    test('il cambio di tipo ricostruisce i parametri', () {
      final st = MixerState();
      final hall = kFxOrderSlots1to4.indexOf('HALL');
      final dly = kFxOrderSlots1to4.indexOf('DLY');
      st.setIdx('/fx/1/type', hall);
      expect(st.specOf('/fx/1/par/01')!.unit, 'ms');
      st.setIdx('/fx/1/type', dly);
      st.resetFxParams(1, ChangeOrigin.local);
      expect(st.fxTypeCode(1), 'DLY');
      expect(kFxTypes['DLY']!.params.length, 12);
      expect(st.hasParam('/fx/1/par/12'), isTrue);
      expect(st.hasParam('/fx/1/par/13'), isFalse);
    });
    test('61 tipi, 34 sugli slot 5–8', () {
      expect(kFxTypes.length, 61);
      expect(kFxOrderSlots1to4.length, 61);
      expect(kFxOrderSlots5to8.length, 34);
    });
  });
}
