// Orologio dei meter (fase 3, prestazioni): fermo quando non arrivano dati, attivo appena arrivano.
import 'package:flutter_test/flutter_test.dart';
import 'package:x32_remote/ui/widgets/controls.dart';

void main() {
  test('senza dati dei meter l\'orologio smette di ridisegnare dopo la caduta delle barre', () {
    var live = true;
    var idleCalls = 0;
    final clock = MeterClock(isLive: () => live, onIdle: () => idleCalls++);
    var frames = 0;
    clock.addListener(() => frames++);
    var t = Duration.zero;
    void run(int n) {
      for (var i = 0; i < n; i++) {
        t += const Duration(milliseconds: 16);
        clock.tick(t);
      }
    }

    run(60); // 1 s con dati: un ridisegno per frame
    expect(frames, 60);
    live = false;
    run(60 * 10); // 10 s senza dati
    final afterIdle = frames;
    expect(afterIdle, lessThan(60 + 60 * 5)); // si ferma entro qualche secondo (tempo per svuotare le barre)
    run(120);
    expect(frames, afterIdle); // fermo
    expect(idleCalls, 1); // un solo svuotamento, seguito da un ultimo ridisegno
    live = true;
    run(10);
    expect(frames, afterIdle + 10); // riparte subito
  });

  test('senza funzione di attività l\'orologio resta sempre attivo (comportamento precedente)', () {
    final clock = MeterClock();
    var frames = 0;
    clock.addListener(() => frames++);
    for (var i = 1; i <= 600; i++) {
      clock.tick(Duration(milliseconds: 16 * i));
    }
    expect(frames, 600);
  });
}
