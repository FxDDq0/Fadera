import 'dart:io';

import 'package:x32_core/x32_core.dart';

/// File di scena oltre questa dimensione vengono rifiutati (una scena X32 completa è circa 100 KB).
const kMaxSceneFileBytes = 1024 * 1024;

class SceneFileException implements Exception {
  SceneFileException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Legge un file di scena controllandone prima la dimensione.
List<String> readSceneFile(File f) {
  final int size;
  try {
    size = f.lengthSync();
  } on FileSystemException catch (e) {
    throw SceneFileException('file non leggibile: ${e.message}');
  }
  if (size > kMaxSceneFileBytes) {
    throw SceneFileException('file troppo grande (${(size / 1024).round()} KB, massimo ${kMaxSceneFileBytes ~/ 1024} KB)');
  }
  try {
    return f.readAsLinesSync();
  } on FileSystemException catch (e) {
    throw SceneFileException('file non leggibile: ${e.message}');
  } on FormatException {
    throw SceneFileException('il file non è un testo valido');
  }
}

/// Cosa verrebbe inviato al mixer da un file di scena.
class SceneFilePlan {
  SceneFilePlan(this.sendable, this.rejected, this.phantomLines);

  /// Righe inviabili: nodi della tabella di sync (gli stessi della sincronizzazione).
  final List<String> sendable;

  /// Righe che iniziano con `/` ma non verranno inviate (comandi, preferenze, percorsi sconosciuti).
  final List<String> rejected;

  /// Righe `/headamp/NNN` (guadagno e alimentazione phantom): segnalate a parte nella conferma.
  final int phantomLines;
}

final Set<String> _syncNodes = kSyncNodes.toSet();
final _headamp = RegExp(r'^/headamp/\d{3}$');

/// Filtra le righe di un file di scena: si inviano solo i nodi noti della tabella di sync.
/// Sono sempre esclusi i percorsi `/-…` (azioni, preferenze, stato), che una scena X32 non contiene.
SceneFilePlan planSceneSend(Iterable<String> lines, MixerState state) {
  final sendable = <String>[];
  final rejected = <String>[];
  var phantom = 0;
  for (final raw in lines) {
    final l = raw.trim();
    if (!l.startsWith('/')) continue;
    final path = splitNodeLine(l)?.$1;
    if (path == null || path.startsWith('/-') || !_syncNodes.contains(path) || state.node(path) == null || l.length > kMaxNodeLineLength) {
      rejected.add(l);
      continue;
    }
    if (_headamp.hasMatch(path)) phantom++;
    sendable.add(l);
  }
  return SceneFilePlan(sendable, rejected, phantom);
}
