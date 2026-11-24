/// Trasporto UDP astratto: il motore non conosce il socket reale.
///
/// Il trasporto non accoda: `trySend` dice se il sistema ha accettato il datagramma.
/// La politica (coalescenza, ordine, limiti, ritentativi) è in `SendQueue`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'send_queue.dart';

class UdpPacket {
  UdpPacket(this.data, this.address, this.port);
  final Uint8List data;
  final InternetAddress address;
  final int port;
}

/// Destinazioni ammesse. [loopbackOnly] è usata da test e simulatore: qualunque
/// invio verso un indirizzo non di loopback lancia un errore, così nessun test
/// automatico può raggiungere un mixer fisico (regola 6 del progetto).
enum TransportPolicy { any, loopbackOnly }

class TransportPolicyViolation implements Exception {
  TransportPolicyViolation(this.address);
  final InternetAddress address;
  @override
  String toString() => 'Invio verso $address bloccato: il trasporto ammette solo 127.0.0.1';
}

abstract class Transport {
  Stream<UdpPacket> get incoming;

  /// Eventi "il socket è di nuovo scrivibile" dopo un `wouldBlock`.
  Stream<void> get writable;
  int get localPort;

  /// Tenta l'invio. Non accoda mai. Lancia [TransportPolicyViolation] per destinazioni vietate.
  SendResult trySend(Uint8List data, InternetAddress address, int port);

  /// Invio "fire and forget" (discovery): l'esito viene ignorato.
  void send(Uint8List data, InternetAddress address, int port) => trySend(data, address, port);

  /// Ultimo errore del socket (per la diagnostica).
  Object? get lastError;
  Future<void> close();
}

/// Trasporto su `RawDatagramSocket` (Windows, Android, iOS).
class UdpTransport extends Transport {
  UdpTransport._(this._socket, this.policy) {
    _socket.listen((e) {
      if (e == RawSocketEvent.read) {
        UdpPacket? d;
        while ((d = _readOne()) != null) {
          _incoming.add(d!);
        }
      } else if (e == RawSocketEvent.write) {
        _socket.writeEventsEnabled = false;
        if (!_writable.isClosed) _writable.add(null);
      }
    }, onError: (Object e) {
      // Su Windows un ICMP "port unreachable" produce un errore in ricezione:
      // non è fatale, il socket resta utilizzabile.
      lastError = e;
      _incoming.addError(e);
    }, onDone: () => _incoming.close());
  }

  static Future<UdpTransport> bind({
    InternetAddress? address,
    int port = 0,
    bool broadcast = false,
    TransportPolicy policy = TransportPolicy.any,
  }) async {
    final bindAddr = address ?? (policy == TransportPolicy.loopbackOnly ? InternetAddress.loopbackIPv4 : InternetAddress.anyIPv4);
    final s = await RawDatagramSocket.bind(bindAddr, port);
    s.broadcastEnabled = broadcast;
    _enlargeReceiveBuffer(s);
    return UdpTransport._(s, policy);
  }

  final RawDatagramSocket _socket;
  final TransportPolicy policy;
  final _incoming = StreamController<UdpPacket>.broadcast();
  final _writable = StreamController<void>.broadcast();

  @override
  Object? lastError;

  UdpPacket? _readOne() {
    final r = _socket.receive();
    if (r == null) return null;
    return UdpPacket(r.data, r.address, r.port);
  }

  @override
  Stream<UdpPacket> get incoming => _incoming.stream;

  @override
  Stream<void> get writable => _writable.stream;

  @override
  int get localPort => _socket.port;

  @override
  SendResult trySend(Uint8List data, InternetAddress address, int port) {
    if (policy == TransportPolicy.loopbackOnly && !address.isLoopback) {
      throw TransportPolicyViolation(address);
    }
    try {
      if (_socket.send(data, address, port) == 0) {
        _socket.writeEventsEnabled = true;
        return SendResult.wouldBlock;
      }
      return SendResult.sent;
    } on SocketException catch (e) {
      lastError = e;
      return SendResult.error;
    }
  }

  @override
  Future<void> close() async {
    _socket.close();
    await _writable.close();
  }
}

/// Porta il buffer di ricezione a 1 MiB: durante la sync e con molti meter i
/// pacchetti arrivano a raffiche e il buffer predefinito di Windows (64 KiB) può
/// traboccare mentre il thread dell'interfaccia è occupato.
void _enlargeReceiveBuffer(RawDatagramSocket s) {
  final soRcvBuf = (Platform.isLinux || Platform.isAndroid) ? 8 : 0x1002; // Windows, macOS, iOS
  try {
    s.setRawOption(RawSocketOption.fromInt(RawSocketOption.levelSocket, soRcvBuf, 1 << 20));
  } on Object {
    // opzione non supportata: si resta con il buffer di sistema
  }
}

/// Trasporto in memoria per i test di unità (nessun socket). [accept] simula la
/// congestione o gli errori del sistema.
class MemoryTransport extends Transport {
  MemoryTransport({this.localPort = 50000});
  final _incoming = StreamController<UdpPacket>.broadcast(sync: true);
  final _writable = StreamController<void>.broadcast(sync: true);
  final List<(Uint8List, InternetAddress, int)> sent = [];
  SendResult Function(Uint8List data)? accept;
  bool closed = false;

  @override
  Object? lastError;

  @override
  final int localPort;

  @override
  Stream<UdpPacket> get incoming => _incoming.stream;

  @override
  Stream<void> get writable => _writable.stream;

  void deliver(Uint8List data, InternetAddress from, int port) => _incoming.add(UdpPacket(data, from, port));

  /// Simula il ritorno della scrivibilità del socket.
  void signalWritable() => _writable.add(null);

  @override
  SendResult trySend(Uint8List data, InternetAddress address, int port) {
    if (closed) throw StateError('trasporto chiuso');
    final r = accept?.call(data) ?? SendResult.sent;
    if (r == SendResult.sent) sent.add((data, address, port));
    return r;
  }

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
    await _writable.close();
  }
}
