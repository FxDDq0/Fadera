/// Codifica e decodifica OSC 1.0 (doc 15 par. 1.1, verificato su hardware in T01b).
///
/// * stringhe ASCII terminate da NUL con padding a 4 byte;
/// * `i` int32 big-endian, `f` float32 big-endian, `b` blob con lunghezza big-endian;
/// * i bundle sono accettati in ricezione, mai generati in invio (X32-Edit non li usa).
library;

import 'dart:convert';
import 'dart:typed_data';

/// Un argomento OSC. Sottotipi: [OscInt], [OscFloat], [OscString], [OscBlob].
sealed class OscArg {
  const OscArg();
  String get tag;
}

final class OscInt extends OscArg {
  const OscInt(this.value);
  final int value;
  @override
  String get tag => 'i';
  @override
  bool operator ==(Object other) => other is OscInt && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'i:$value';
}

final class OscFloat extends OscArg {
  const OscFloat(this.value);
  final double value;
  @override
  String get tag => 'f';
  @override
  bool operator ==(Object other) => other is OscFloat && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'f:$value';
}

final class OscString extends OscArg {
  const OscString(this.value);
  final String value;
  @override
  String get tag => 's';
  @override
  bool operator ==(Object other) => other is OscString && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 's:"$value"';
}

final class OscBlob extends OscArg {
  OscBlob(this.bytes);
  final Uint8List bytes;
  @override
  String get tag => 'b';
  @override
  bool operator ==(Object other) {
    if (other is! OscBlob || other.bytes.length != bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (other.bytes[i] != bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);
  @override
  String toString() => 'b:${bytes.length}B';
}

/// Un messaggio OSC. [hasTypeTag] è falso solo per il pacchetto grezzo
/// `"/xinfo\0\0"` della discovery (doc 15 par. 1.1, verificato in T01b).
class OscMessage {
  OscMessage(this.address, [List<OscArg>? args, this.hasTypeTag = true]) : args = List.unmodifiable(args ?? const []);

  final String address;
  final List<OscArg> args;
  final bool hasTypeTag;

  String get typeTag => ',${args.map((a) => a.tag).join()}';

  @override
  String toString() => '$address $typeTag ${args.join(' ')}';
}

class OscFormatException implements Exception {
  OscFormatException(this.message);
  final String message;
  @override
  String toString() => 'OscFormatException: $message';
}

int _pad4(int n) => (n + 3) & ~3;

void _writeString(BytesBuilder b, String s) {
  final bytes = ascii.encode(s);
  b.add(bytes);
  final total = _pad4(bytes.length + 1);
  b.add(Uint8List(total - bytes.length));
}

/// Codifica un messaggio OSC in un datagramma. Lancia [OscFormatException]
/// se l'indirizzo o le stringhe non sono ASCII o se si supera [maxBytes].
Uint8List encodeOsc(OscMessage m, {int maxBytes = 1500}) {
  // Nota: le risposte del mixer usano anche indirizzi senza "/" iniziale ("node", "meters/N").
  final b = BytesBuilder(copy: false);
  try {
    _writeString(b, m.address);
    if (m.hasTypeTag) {
      _writeString(b, m.typeTag);
      for (final a in m.args) {
        switch (a) {
          case OscInt(:final value):
            final d = ByteData(4)..setInt32(0, value, Endian.big);
            b.add(d.buffer.asUint8List());
          case OscFloat(:final value):
            final d = ByteData(4)..setFloat32(0, value, Endian.big);
            b.add(d.buffer.asUint8List());
          case OscString(:final value):
            _writeString(b, value);
          case OscBlob(:final bytes):
            final d = ByteData(4)..setInt32(0, bytes.length, Endian.big);
            b.add(d.buffer.asUint8List());
            b.add(bytes);
            b.add(Uint8List(_pad4(bytes.length) - bytes.length));
        }
      }
    } else if (m.args.isNotEmpty) {
      throw OscFormatException('un pacchetto senza type tag non può avere argomenti');
    }
  } on ArgumentError catch (e) {
    throw OscFormatException('testo non ASCII: ${e.message}');
  }
  final out = b.toBytes();
  if (out.length > maxBytes) {
    throw OscFormatException('messaggio di ${out.length} byte oltre il limite di $maxBytes');
  }
  return out;
}

class _Reader {
  _Reader(this.data) : bd = ByteData.sublistView(data);
  final Uint8List data;
  final ByteData bd;
  int pos = 0;

  String readString() {
    final start = pos;
    var end = start;
    while (end < data.length && data[end] != 0) {
      end++;
    }
    if (end >= data.length) throw OscFormatException('stringa senza terminatore');
    final next = start + _pad4(end - start + 1);
    if (next > data.length) throw OscFormatException('padding della stringa incompleto');
    pos = next;
    // latin1 non fallisce mai: i nomi dei canali possono contenere byte > 127.
    return latin1.decode(data.sublist(start, end));
  }

  int readInt() {
    if (pos + 4 > data.length) throw OscFormatException('int32 incompleto');
    final v = bd.getInt32(pos, Endian.big);
    pos += 4;
    return v;
  }

  double readFloat() {
    if (pos + 4 > data.length) throw OscFormatException('float32 incompleto');
    final v = bd.getFloat32(pos, Endian.big);
    pos += 4;
    return v;
  }

  Uint8List readBlob() {
    final n = readInt();
    if (n < 0 || pos + n > data.length) throw OscFormatException('blob di lunghezza non valida: $n');
    final out = Uint8List.fromList(data.sublist(pos, pos + n));
    pos += _pad4(n);
    if (pos > data.length) throw OscFormatException('padding del blob incompleto');
    return out;
  }
}

/// Decodifica un datagramma. Restituisce uno o più messaggi (i bundle vengono
/// appiattiti). Lancia [OscFormatException] per datagrammi malformati
/// (lunghezza non multipla di 4, stringhe senza terminatore, tag sconosciuti).
///
/// Limiti di sicurezza: bundle annidati al massimo [kMaxOscBundleDepth] livelli e al massimo
/// [kMaxOscMessagesPerDatagram] messaggi per datagramma (il mixer non si avvicina a questi valori).
List<OscMessage> decodeOsc(Uint8List data) {
  final out = <OscMessage>[];
  _decodeInto(data, 0, out);
  return out;
}

/// Profondità massima dei bundle annidati in un datagramma.
const kMaxOscBundleDepth = 4;

/// Numero massimo di messaggi in un datagramma.
const kMaxOscMessagesPerDatagram = 512;

void _decodeInto(Uint8List data, int depth, List<OscMessage> out) {
  if (data.isEmpty || data.length % 4 != 0) {
    throw OscFormatException('lunghezza ${data.length} non multipla di 4');
  }
  final r = _Reader(data);
  if (data[0] == 0x23) {
    if (depth >= kMaxOscBundleDepth) throw OscFormatException('bundle annidati oltre $kMaxOscBundleDepth livelli');
    final tag = r.readString();
    if (tag != '#bundle') throw OscFormatException('bundle non valido');
    if (r.pos + 8 > data.length) throw OscFormatException('timetag incompleto');
    r.pos += 8;
    while (r.pos < data.length) {
      final n = r.readInt();
      if (n <= 0 || r.pos + n > data.length) throw OscFormatException('elemento del bundle non valido');
      _decodeInto(Uint8List.sublistView(data, r.pos, r.pos + n), depth + 1, out);
      r.pos += n;
    }
    return;
  }
  if (out.length >= kMaxOscMessagesPerDatagram) {
    throw OscFormatException('oltre $kMaxOscMessagesPerDatagram messaggi nel datagramma');
  }
  out.add(_decodeMessage(r, data));
}

OscMessage _decodeMessage(_Reader r, Uint8List data) {
  final address = r.readString();
  if (r.pos >= data.length) return OscMessage(address, const [], false);
  if (data[r.pos] != 0x2c) return OscMessage(address, const [], false);
  final tags = r.readString();
  final args = <OscArg>[];
  for (final t in tags.substring(1).split('')) {
    switch (t) {
      case 'i':
        args.add(OscInt(r.readInt()));
      case 'f':
        args.add(OscFloat(r.readFloat()));
      case 's':
        args.add(OscString(r.readString()));
      case 'b':
        args.add(OscBlob(r.readBlob()));
      default:
        throw OscFormatException('type tag non supportato: $t');
    }
  }
  return OscMessage(address, args);
}
