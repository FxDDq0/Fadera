// Robustezza verso dati di rete anomali o ostili (fase 3, tappa 1.3).
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:x32_core/x32_core.dart';

Uint8List _bundle(List<Uint8List> elements) {
  final b = BytesBuilder();
  b.add(encodeOsc(OscMessage('#bundle', const [], false)));
  b.add(Uint8List(8)); // timetag
  for (final e in elements) {
    b.add((ByteData(4)..setInt32(0, e.length)).buffer.asUint8List());
    b.add(e);
  }
  return b.toBytes();
}

void main() {
  final msg = encodeOsc(OscMessage('/ch/01/mix/fader', [const OscFloat(0.5)]));

  group('bundle OSC', () {
    test('annidamento normale accettato', () {
      expect(decodeOsc(_bundle([_bundle([msg])])), hasLength(1));
    });
    test('annidamento eccessivo rifiutato', () {
      var d = msg;
      for (var i = 0; i < 8; i++) {
        d = _bundle([d]);
      }
      expect(() => decodeOsc(d), throwsA(isA<OscFormatException>()));
    });
    test('troppi messaggi in un datagramma rifiutati', () {
      final tiny = encodeOsc(OscMessage('/a', const [], false));
      expect(() => decodeOsc(_bundle(List.filled(kMaxOscMessagesPerDatagram + 1, tiny))), throwsA(isA<OscFormatException>()));
    });
  });

  group('stato del mixer', () {
    test('nodo fuori tabella valido conservato', () {
      final s = MixerState();
      expect(s.applyNodeLine('/-show/showfile/scene/001 "Prova" "" %000000000 1', ChangeOrigin.sync), isTrue);
      expect(s.node('/-show/showfile/scene/001'), isNotNull);
    });
    test('percorso con caratteri non ammessi rifiutato', () {
      final s = MixerState();
      expect(s.applyNodeLine('/x<script> 1', ChangeOrigin.sync), isFalse);
      expect(s.node('/x<script>'), isNull);
    });
    test('righe troppo lunghe rifiutate', () {
      final s = MixerState();
      expect(s.applyNodeLine('/-show/showfile/scene/002 "${'a' * 5000}"', ChangeOrigin.sync), isFalse);
    });
    test('numero di nodi fuori tabella limitato', () {
      final s = MixerState();
      var accepted = 0;
      for (var i = 0; i < kMaxDynamicNodes + 500; i++) {
        if (s.applyNodeLine('/zz/$i 1', ChangeOrigin.sync)) accepted++;
      }
      expect(accepted, kMaxDynamicNodes);
    });
    test('elenco degli avvisi limitato', () {
      final s = MixerState();
      for (var i = 0; i < 2000; i++) {
        s.applyNodeLine('/ch/01/mix ON XX', ChangeOrigin.sync);
      }
      expect(s.warnings.length, lessThanOrEqualTo(kMaxWarnings));
    });
  });

  test('testi di /xinfo ripuliti (niente caratteri di controllo, lunghezza limitata)', () {
    final t = cleanInfoText('\u0001Mixer\nFinto\u001b[31m${'x' * 200}');
    expect(t.contains(RegExp(r'[\x00-\x1f\x7f]')), isFalse);
    expect(t.length, lessThanOrEqualTo(64));
    expect(t, startsWith('Mixer Finto'));
    // direzione del testo invertita e caratteri a larghezza zero tolti
    expect(cleanInfoText('X32‮esrever​'), 'X32 esrever');
  });
}
