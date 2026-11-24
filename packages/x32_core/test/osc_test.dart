import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';

Uint8List b(List<int> x) => Uint8List.fromList(x);

void main() {
  group('codifica', () {
    test('/xinfo grezzo: 8 byte senza type tag (T01b)', () {
      final out = encodeOsc(OscMessage('/xinfo', const [], false));
      expect(out, b([0x2f, 0x78, 0x69, 0x6e, 0x66, 0x6f, 0, 0]));
    });

    test('/status con type tag vuoto: 12 byte (T01b)', () {
      final out = encodeOsc(OscMessage('/status'));
      expect(out.length, 12);
      expect(out.sublist(8), b([0x2c, 0, 0, 0]));
    });

    test('float big-endian: fader a 0 dB = 767/1023', () {
      final out = encodeOsc(OscMessage('/ch/01/mix/fader', [OscFloat(767 / 1023)]));
      expect(out.length, 28);
      final bd = ByteData.sublistView(out);
      expect(bd.getFloat32(24, Endian.big), closeTo(0.74976, 1e-5));
    });

    test('int, stringa e blob con padding', () {
      final m = OscMessage('/a', [const OscInt(-2), const OscString('abc'), OscBlob(b([1, 2, 3, 4, 5]))]);
      final back = decodeOsc(encodeOsc(m)).single;
      expect(back.address, '/a');
      expect(back.typeTag, ',isb');
      expect(back.args[0], const OscInt(-2));
      expect(back.args[1], const OscString('abc'));
      expect((back.args[2] as OscBlob).bytes, b([1, 2, 3, 4, 5]));
    });

    test('limite di 1500 byte', () {
      expect(() => encodeOsc(OscMessage('/x', [OscString('a' * 1600)])), throwsA(isA<OscFormatException>()));
    });

    test('rifiuta testo non ASCII in invio', () {
      expect(() => encodeOsc(OscMessage('/ch/01/config/name', [const OscString('Città')])), throwsA(isA<OscFormatException>()));
    });
  });

  group('decodifica robusta', () {
    test('lunghezza non multipla di 4', () {
      expect(() => decodeOsc(b([0x2f, 0x61, 0, 0, 0x2c])), throwsA(isA<OscFormatException>()));
    });
    test('stringa senza terminatore', () {
      expect(() => decodeOsc(b([0x2f, 0x61, 0x62, 0x63])), throwsA(isA<OscFormatException>()));
    });
    test('argomento troncato', () {
      final ok = encodeOsc(OscMessage('/a', [const OscInt(1)]));
      expect(() => decodeOsc(Uint8List.sublistView(ok, 0, ok.length - 4)), throwsA(isA<OscFormatException>()));
    });
    test('type tag sconosciuto', () {
      final d = b([0x2f, 0x61, 0, 0, 0x2c, 0x54, 0, 0]); // ",T"
      expect(() => decodeOsc(d), throwsA(isA<OscFormatException>()));
    });
    test('blob con lunghezza falsa', () {
      final d = b([0x2f, 0x61, 0, 0, 0x2c, 0x62, 0, 0, 0, 0, 0x10, 0, 1, 2, 3, 4]);
      expect(() => decodeOsc(d), throwsA(isA<OscFormatException>()));
    });
    test('datagramma vuoto', () {
      expect(() => decodeOsc(Uint8List(0)), throwsA(isA<OscFormatException>()));
    });
    test('bundle appiattito', () {
      final m1 = encodeOsc(OscMessage('/a', [const OscInt(1)]));
      final m2 = encodeOsc(OscMessage('/b', [const OscFloat(0.5)]));
      final bb = BytesBuilder()
        ..add(b([0x23, 0x62, 0x75, 0x6e, 0x64, 0x6c, 0x65, 0]))
        ..add(Uint8List(8))
        ..add((ByteData(4)..setInt32(0, m1.length)).buffer.asUint8List())
        ..add(m1)
        ..add((ByteData(4)..setInt32(0, m2.length)).buffer.asUint8List())
        ..add(m2);
      final out = decodeOsc(bb.toBytes());
      expect(out.map((m) => m.address), ['/a', '/b']);
    });
    test('fuzz: byte casuali non fanno crashare il decoder', () {
      var seed = 12345;
      int rnd() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      for (var n = 0; n < 5000; n++) {
        final len = (rnd() % 16 + 1) * 4;
        final d = Uint8List.fromList(List.generate(len, (_) => rnd() & 0xff));
        if (n.isEven) d[0] = 0x2f;
        try {
          decodeOsc(d);
        } on OscFormatException {
          // atteso
        }
      }
    });
  });
}
