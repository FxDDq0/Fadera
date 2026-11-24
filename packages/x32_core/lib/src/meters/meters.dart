/// Meter: decodifica dei blob `meters/N` e dinamica di visualizzazione (doc 20).
///
/// Verificato su hardware (T01b): count little-endian = numero di valori;
/// count 70/49/27/4/32/32/80/48 per i banchi 0/2/5/6/9/10/14/16; un blob ogni 50 ms.
/// Il contenuto di ogni posizione è verificato solo dove indicato.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Numero di parole a 32 bit attese per banco (, doc 20 par. 2).
const List<int> kMeterBankWords = [70, 96, 49, 22, 82, 27, 4, 16, 6, 32, 32, 5, 4, 48, 80, 50, 48];

enum MeterValueType {
  /// float32 little-endian lineare (banchi 0–6, 9–11, 14).
  float32,

  /// int16 little-endian, due per parola (banchi 15 e 16).
  int16,

  /// Significato non determinato (banchi 7, 8, 12, 13): solo parole grezze.
  unknown,
}

MeterValueType meterBankType(int bank) {
  if (bank == 15 || bank == 16) return MeterValueType.int16;
  if (bank == 7 || bank == 8 || bank == 12 || bank == 13) return MeterValueType.unknown;
  return MeterValueType.float32;
}

/// Un blob di meter decodificato.
class MeterFrame {
  MeterFrame(this.bank, this.words, this.values);
  final int bank;

  /// Parole grezze (little-endian), sempre disponibili.
  final Uint32List words;

  /// Valori lineari 0..1 (float32) oppure int16 normalizzati a s/32767;
  /// vuoto per i banchi di tipo sconosciuto.
  final Float32List values;

  /// Livello in dB come lo calcola X32-Edit: 20·log10(x) se x > 5e−7, altrimenti −127.
  double db(int i) => linearToDb(values[i]);
}

double linearToDb(double x) => x > 5e-7 ? 20 * math.log(x) / math.ln10 : -127;

/// Decodifica un blob `meters/N`. Restituisce `null` se count non coincide con la
/// lunghezza o con il valore atteso del banco (doc 15 par. 7: il blob va scartato).
MeterFrame? decodeMeterBlob(int bank, Uint8List blob) {
  if (bank < 0 || bank >= kMeterBankWords.length) return null;
  if (blob.length < 4 || blob.length % 4 != 0) return null;
  final bd = ByteData.sublistView(blob);
  final count = bd.getInt32(0, Endian.little);
  if (count != blob.length ~/ 4 - 1 || count != kMeterBankWords[bank]) return null;
  final words = Uint32List(count);
  for (var i = 0; i < count; i++) {
    words[i] = bd.getUint32(4 + i * 4, Endian.little);
  }
  final type = meterBankType(bank);
  Float32List values;
  switch (type) {
    case MeterValueType.float32:
      values = Float32List(count);
      for (var i = 0; i < count; i++) {
        values[i] = bd.getFloat32(4 + i * 4, Endian.little);
      }
    case MeterValueType.int16:
      values = Float32List(count * 2);
      for (var i = 0; i < count * 2; i++) {
        values[i] = bd.getInt16(4 + i * 2, Endian.little) / 32767.0;
      }
    case MeterValueType.unknown:
      values = Float32List(0);
  }
  return MeterFrame(bank, words, values);
}

/// Codifica un blob (usata dal simulatore e dai test).
Uint8List encodeMeterBlob(int bank, List<double> values) {
  final type = meterBankType(bank);
  final count = kMeterBankWords[bank];
  final bd = ByteData(4 + count * 4)..setInt32(0, count, Endian.little);
  if (type == MeterValueType.int16) {
    for (var i = 0; i < count * 2 && i < values.length; i++) {
      bd.setInt16(4 + i * 2, (values[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
  } else {
    for (var i = 0; i < count && i < values.length; i++) {
      bd.setFloat32(4 + i * 4, values[i], Endian.little);
    }
  }
  return bd.buffer.asUint8List();
}

/// Posizioni nel banco 0 secondo la documentazione esterna [EXT] (P.-G. Maillot):
/// 32 canali, 8 aux in, 8 FX return (4 coppie stereo), 16 bus, 6 matrici = 70.
/// La somma coincide con il count verificato (70). Su X32P FW 4.15 (prova A4 del 2026-11-23)
/// è verificata la posizione 0 = ch 1; le altre posizioni seguono [EXT].
class MeterBank0Map {
  static const bool verifiedOnHardware = false;
  static int ch(int n) => n - 1;
  static int auxin(int n) => 31 + n;
  static int fxrtn(int n) => 39 + n;
  static int bus(int n) => 47 + n;
  static int mtx(int n) => 63 + n;
}

/// Posizioni della riduzione di guadagno nel banco 16 (96 valori int16, guadagno lineare:
/// 20·log10(valore) = riduzione in dB, 0 dB = nessuna riduzione).
/// Verificato su X32P FW 4.15 (prove A5/A5b del 2026-11-23) per il canale 1: posizione 0 = gate
/// (−60 dB chiuso con range 60, 0 dB aperto), posizione 32 = compressore (−4 dB con soglia −36,
/// ratio 4). Gli altri canali seguono lo stesso ordine secondo [EXT]; bus, matrici e main non sono
/// esposti finché la loro posizione non è verificata.
class MeterBank16Map {
  static const int bank = 16;
  static const bool verifiedCh1 = true;
  static int gate(int ch) => ch - 1;
  static int comp(int ch) => 31 + ch;
}

/// Dinamica di visualizzazione, separata dalla frequenza di rete: il valore
/// arriva a 20 Hz, il disegno avviene a 60 Hz con caduta e picco calcolati sul tempo.
class MeterBallistics {
  MeterBallistics({this.fallDbPerSecond = 26, this.peakHoldMs = 1500, this.peakFallDbPerSecond = 12, this.floorDb = -90});

  final double fallDbPerSecond;
  final int peakHoldMs;
  final double peakFallDbPerSecond;
  final double floorDb;

  double _level = -127;
  double _target = -127;
  double _peak = -127;
  int _peakAgeMs = 0;
  bool _clip = false;

  double get level => _level;
  double get peak => _peak;
  bool get clip => _clip;

  /// Nuovo valore dalla rete (dB).
  void input(double db) {
    _target = db;
    if (db >= _level) _level = db; // attacco istantaneo
    if (db >= _peak) {
      _peak = db;
      _peakAgeMs = 0;
    }
    if (db >= -0.1) _clip = true;
  }

  /// Avanza la dinamica di [dtMs] millisecondi (chiamato dal rendering).
  void tick(int dtMs) {
    final dt = dtMs / 1000.0;
    if (_level > _target) _level = math.max(_target, _level - fallDbPerSecond * dt);
    _peakAgeMs += dtMs;
    if (_peakAgeMs > peakHoldMs) _peak = math.max(_level, _peak - peakFallDbPerSecond * dt);
    if (_level < floorDb) _level = math.max(_level, -127);
  }

  void resetClip() => _clip = false;
}
