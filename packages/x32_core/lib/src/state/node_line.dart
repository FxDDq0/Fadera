/// Righe di nodo X32: `<path>( <valore>)*` (doc 17 par. 4; formato confermato su T01b).
library;

/// Divide il testo di una riga in token. Le stringhe tra virgolette restano un
/// solo token (senza virgolette, con [NodeToken.quoted] vero); spazi multipli
/// vengono compressi (i valori sono allineati a destra con spazi).
List<NodeToken> tokenizeNodeLine(String line) {
  final out = <NodeToken>[];
  var i = 0;
  final s = line.trimRight();
  while (i < s.length) {
    final c = s[i];
    if (c == ' ' || c == '\t') {
      i++;
      continue;
    }
    if (c == '"') {
      final end = s.indexOf('"', i + 1);
      if (end < 0) {
        out.add(NodeToken(s.substring(i + 1), quoted: true));
        break;
      }
      out.add(NodeToken(s.substring(i + 1, end), quoted: true));
      i = end + 1;
      continue;
    }
    var j = i;
    while (j < s.length && s[j] != ' ' && s[j] != '\t') {
      j++;
    }
    out.add(NodeToken(s.substring(i, j)));
    i = j;
  }
  return out;
}

class NodeToken {
  const NodeToken(this.text, {this.quoted = false});
  final String text;
  final bool quoted;

  /// Testo come compare nella riga.
  String get raw => quoted ? '"$text"' : text;

  @override
  String toString() => raw;
}

/// Separa il percorso dal resto di una riga. Restituisce `null` per righe vuote o commenti.
(String path, List<NodeToken> values)? splitNodeLine(String line) {
  final t = line.trimLeft();
  if (t.isEmpty || t.startsWith('#')) return null;
  final tokens = tokenizeNodeLine(t);
  if (tokens.isEmpty || tokens.first.quoted) return null;
  return (tokens.first.text, tokens.sublist(1));
}
