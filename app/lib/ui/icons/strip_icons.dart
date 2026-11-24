import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../l10n/l10n.dart';

/// Icone delle strip della X32: identificativo 1…74 nel campo `icon` del nodo `config`
/// (`/ch/NN/config "nome" ICONA COLORE sorgente`), distinto dal colore.
///
/// Significato degli identificativi: elenco [EXT] (appendice "X32/M32 Icons" del protocollo OSC
/// non ufficiale), coerente con i valori predefiniti di X32-Edit [A] (aux in 55 = presa TRS,
/// fx return 61 = FX, bus 71 = MixBus, matrix 72 = Matrix, main 66/67 = altoparlanti, DCA 70 = fader).
/// I disegni sono originali (vettoriali), non le immagini di Behringer, Midas o X32-Edit.
class StripIconInfo {
  const StripIconInfo(this.id, this._name, this.group);
  final int id;
  final String _name;

  /// Nome tradotto nella lingua attiva.
  String get name => tr(_name);

  /// Gruppo: testo italiano, è anche la chiave del raggruppamento (mostrarlo con tr).
  final String group;
}

const kStripIconGroups = [
  /*l10n*/ 'Nessuna',
  /*l10n*/ 'Batteria e percussioni',
  /*l10n*/ 'Bassi e chitarre',
  /*l10n*/ 'Tastiere',
  /*l10n*/ 'Fiati e archi',
  /*l10n*/ 'Voci e comunicazione',
  /*l10n*/ 'Microfoni',
  /*l10n*/ 'Connettori e sorgenti',
  /*l10n*/ 'Sistema',
];

const kStripIcons = <StripIconInfo>[
  StripIconInfo(1, /*l10n*/ 'Nessuna', /*l10n*/ 'Nessuna'),
  StripIconInfo(2, /*l10n*/ 'Cassa (retro)', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(3, /*l10n*/ 'Cassa (fronte)', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(4, /*l10n*/ 'Rullante sopra', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(5, /*l10n*/ 'Rullante sotto', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(6, /*l10n*/ 'Tom alto', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(7, /*l10n*/ 'Tom medio', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(8, /*l10n*/ 'Timpano (floor tom)', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(9, /*l10n*/ 'Hi-hat', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(10, /*l10n*/ 'Ride', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(11, /*l10n*/ 'Batteria completa', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(12, /*l10n*/ 'Campanaccio', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(13, /*l10n*/ 'Bonghi', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(14, /*l10n*/ 'Conga', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(15, /*l10n*/ 'Tamburello', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(16, /*l10n*/ 'Vibrafono', /*l10n*/ 'Batteria e percussioni'),
  StripIconInfo(17, /*l10n*/ 'Basso elettrico', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(18, /*l10n*/ 'Basso acustico', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(19, /*l10n*/ 'Contrabbasso', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(20, /*l10n*/ 'Chitarra elettrica (single cut)', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(21, /*l10n*/ 'Chitarra elettrica (superstrat)', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(22, /*l10n*/ 'Chitarra elettrica (offset)', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(23, /*l10n*/ 'Chitarra acustica', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(24, /*l10n*/ 'Amplificatore per basso', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(25, /*l10n*/ 'Amplificatore per chitarra', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(26, /*l10n*/ 'Cassa per amplificatore', /*l10n*/ 'Bassi e chitarre'),
  StripIconInfo(27, /*l10n*/ 'Pianoforte', /*l10n*/ 'Tastiere'),
  StripIconInfo(28, /*l10n*/ 'Organo', /*l10n*/ 'Tastiere'),
  StripIconInfo(29, /*l10n*/ 'Clavicembalo', /*l10n*/ 'Tastiere'),
  StripIconInfo(30, /*l10n*/ 'Tastiera', /*l10n*/ 'Tastiere'),
  StripIconInfo(31, /*l10n*/ 'Sintetizzatore 1', /*l10n*/ 'Tastiere'),
  StripIconInfo(32, /*l10n*/ 'Sintetizzatore 2', /*l10n*/ 'Tastiere'),
  StripIconInfo(33, /*l10n*/ 'Sintetizzatore 3', /*l10n*/ 'Tastiere'),
  StripIconInfo(34, /*l10n*/ 'Keytar', /*l10n*/ 'Tastiere'),
  StripIconInfo(35, /*l10n*/ 'Tromba', /*l10n*/ 'Fiati e archi'),
  StripIconInfo(36, /*l10n*/ 'Trombone', /*l10n*/ 'Fiati e archi'),
  StripIconInfo(37, /*l10n*/ 'Sassofono', /*l10n*/ 'Fiati e archi'),
  StripIconInfo(38, /*l10n*/ 'Clarinetto', /*l10n*/ 'Fiati e archi'),
  StripIconInfo(39, /*l10n*/ 'Violino', /*l10n*/ 'Fiati e archi'),
  StripIconInfo(40, /*l10n*/ 'Violoncello', /*l10n*/ 'Fiati e archi'),
  StripIconInfo(41, /*l10n*/ 'Voce maschile', /*l10n*/ 'Voci e comunicazione'),
  StripIconInfo(42, /*l10n*/ 'Voce femminile', /*l10n*/ 'Voci e comunicazione'),
  StripIconInfo(43, /*l10n*/ 'Coro', /*l10n*/ 'Voci e comunicazione'),
  StripIconInfo(44, /*l10n*/ 'Segnale con la mano', /*l10n*/ 'Voci e comunicazione'),
  StripIconInfo(45, /*l10n*/ 'Talkback A', /*l10n*/ 'Voci e comunicazione'),
  StripIconInfo(46, /*l10n*/ 'Talkback B', /*l10n*/ 'Voci e comunicazione'),
  StripIconInfo(47, /*l10n*/ 'Microfono a diaframma largo', /*l10n*/ 'Microfoni'),
  StripIconInfo(48, /*l10n*/ 'Microfono a condensatore sinistro', /*l10n*/ 'Microfoni'),
  StripIconInfo(49, /*l10n*/ 'Microfono a condensatore destro', /*l10n*/ 'Microfoni'),
  StripIconInfo(50, /*l10n*/ 'Microfono a mano', /*l10n*/ 'Microfoni'),
  StripIconInfo(51, /*l10n*/ 'Radiomicrofono', /*l10n*/ 'Microfoni'),
  StripIconInfo(52, /*l10n*/ 'Microfono da leggio', /*l10n*/ 'Microfoni'),
  StripIconInfo(53, /*l10n*/ 'Microfono ad archetto', /*l10n*/ 'Microfoni'),
  StripIconInfo(54, /*l10n*/ 'Connettore XLR', /*l10n*/ 'Connettori e sorgenti'),
  StripIconInfo(55, /*l10n*/ 'Jack TRS', /*l10n*/ 'Connettori e sorgenti'),
  StripIconInfo(56, /*l10n*/ 'Jack TRS sinistro', /*l10n*/ 'Connettori e sorgenti'),
  StripIconInfo(57, /*l10n*/ 'Jack TRS destro', /*l10n*/ 'Connettori e sorgenti'),
  StripIconInfo(58, /*l10n*/ 'RCA sinistro', /*l10n*/ 'Connettori e sorgenti'),
  StripIconInfo(59, /*l10n*/ 'RCA destro', /*l10n*/ 'Connettori e sorgenti'),
  StripIconInfo(60, /*l10n*/ 'Registratore a bobine', /*l10n*/ 'Connettori e sorgenti'),
  StripIconInfo(61, /*l10n*/ 'Effetti (FX)', /*l10n*/ 'Sistema'),
  StripIconInfo(62, /*l10n*/ 'Computer', /*l10n*/ 'Sistema'),
  StripIconInfo(63, /*l10n*/ 'Monitor da palco (wedge)', /*l10n*/ 'Sistema'),
  StripIconInfo(64, /*l10n*/ 'Altoparlante sinistro', /*l10n*/ 'Sistema'),
  StripIconInfo(65, /*l10n*/ 'Altoparlante destro', /*l10n*/ 'Sistema'),
  StripIconInfo(66, /*l10n*/ 'Line array', /*l10n*/ 'Sistema'),
  StripIconInfo(67, /*l10n*/ 'Altoparlante su stativo', /*l10n*/ 'Sistema'),
  StripIconInfo(68, /*l10n*/ 'Rack di amplificatori', /*l10n*/ 'Sistema'),
  StripIconInfo(69, /*l10n*/ 'Controlli', /*l10n*/ 'Sistema'),
  StripIconInfo(70, /*l10n*/ 'Fader', /*l10n*/ 'Sistema'),
  StripIconInfo(71, /*l10n*/ 'Mix bus', /*l10n*/ 'Sistema'),
  StripIconInfo(72, /*l10n*/ 'Matrix', /*l10n*/ 'Sistema'),
  StripIconInfo(73, /*l10n*/ 'Routing', /*l10n*/ 'Sistema'),
  StripIconInfo(74, /*l10n*/ 'Faccina', /*l10n*/ 'Sistema'),
];

StripIconInfo? stripIconInfo(int? id) => id != null && id >= 1 && id <= kStripIcons.length ? kStripIcons[id - 1] : null;

/// Icona di una strip. Un identificativo sconosciuto mostra un'icona neutra con il numero
/// e conserva il valore originale (nessuna sostituzione).
class StripIconView extends StatelessWidget {
  const StripIconView(this.id, {super.key, this.size = 18, this.color, this.tooltip = false});
  final int? id;
  final double size;
  final Color? color;
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final info = stripIconInfo(id);
    final w = SizedBox.square(dimension: size, child: CustomPaint(painter: _IconPainter(id, color ?? AppColors.text)));
    if (!tooltip) return w;
    return Tooltip(message: info == null ? (id == null ? tr('Icona non ancora letta dal mixer') : tr('Icona n. {p0} non riconosciuta (valore conservato)', {'p0': id})) : '${info.name} (n. ${info.id})', child: w);
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.id, this.color);
  final int? id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);
    final d = _D(canvas, color);
    final info = stripIconInfo(id);
    if (info == null) {
      d.unknown(id);
    } else {
      _draw(id!, d);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter o) => o.id != id || o.color != color;
}

/// Primitivi di disegno su griglia 24×24, tratto uniforme.
class _D {
  _D(this.c, this.color)
      : s = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
        f = Paint()..color = color;
  final Canvas c;
  final Color color;
  final Paint s, f;

  void line(double x1, double y1, double x2, double y2) => c.drawLine(Offset(x1, y1), Offset(x2, y2), s);
  void circle(double x, double y, double r, {bool fill = false}) => c.drawCircle(Offset(x, y), r, fill ? f : s);
  void oval(double x, double y, double w, double h, {bool fill = false}) => c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h), fill ? f : s);
  void rect(double l, double t, double r, double b, {double rad = 1.5, bool fill = false}) =>
      c.drawRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)), fill ? f : s);
  void path(List<Offset> pts, {bool close = false, bool fill = false}) {
    final p = Path()..addPolygon(pts, close);
    c.drawPath(p, fill ? f : s);
  }

  void arc(double x, double y, double r, double start, double sweep) => c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: r), start, sweep, false, s);
  void curve(List<Offset> p) {
    final pa = Path()..moveTo(p[0].dx, p[0].dy);
    for (var i = 1; i + 2 < p.length; i += 3) {
      pa.cubicTo(p[i].dx, p[i].dy, p[i + 1].dx, p[i + 1].dy, p[i + 2].dx, p[i + 2].dy);
    }
    c.drawPath(pa, s);
  }

  void text(String t, double x, double y, {double size = 7}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  /// Lettera in un piccolo riquadro pieno in basso a destra (L, R, A, B, 1, 2, 3).
  void badge(String t) {
    c.drawRRect(RRect.fromLTRBR(15.5, 15.5, 23.5, 23.5, const Radius.circular(2)), f);
    final tp = TextPainter(
      text: TextSpan(text: t, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Color(0xFF0D1016), height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(19.5 - tp.width / 2, 19.6 - tp.height / 2));
  }

  void unknown(int? id) {
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: 0.6);
    c.drawRRect(RRect.fromLTRBR(3, 3, 21, 21, const Radius.circular(4)), dash);
    text(id == null ? '–' : '$id', 12, 12, size: id != null && id > 99 ? 6.5 : 8);
  }

  // forme ricorrenti
  void drumSide(double l, double t, double r, double b) {
    oval((l + r) / 2, t, r - l, 4);
    line(l, t, l, b);
    line(r, t, r, b);
    c.drawArc(Rect.fromLTRB(l, b - 2, r, b + 2), 0, math.pi, false, s);
  }

  void cymbal(double cx, double y, double w) => path([Offset(cx - w / 2, y + 1), Offset(cx, y - 1), Offset(cx + w / 2, y + 1)]);

  void keys(double l, double t, double r, double b, int n) {
    rect(l, t, r, b, rad: 1);
    final w = (r - l) / n;
    for (var i = 1; i < n; i++) {
      line(l + i * w, t + (b - t) * 0.45, l + i * w, b);
    }
    for (var i = 1; i < n; i++) {
      if (i % 7 == 3 || i % 7 == 0) continue;
      c.drawRect(Rect.fromLTRB(l + i * w - w * 0.3, t, l + i * w + w * 0.3, t + (b - t) * 0.5), f);
    }
  }

  void guitarNeck(double x1, double y1, double x2, double y2, {int tuners = 3}) {
    line(x1, y1, x2, y2);
    rect(x2 - 1.6, y2 - 2.6, x2 + 1.6, y2 + 0.4, rad: 0.8);
  }

  void speakerBox(double l, double t, double r, double b) {
    rect(l, t, r, b);
    final cx = (l + r) / 2;
    circle(cx, t + (b - t) * 0.32, (r - l) * 0.16);
    circle(cx, t + (b - t) * 0.68, (r - l) * 0.28);
  }

  void head(double cx, double cy, double r) {
    circle(cx, cy, r);
  }

  void shoulders(double cx, double y, double w) => c.drawArc(Rect.fromCenter(center: Offset(cx, y + w * 0.5), width: w, height: w), math.pi, math.pi, false, s);

  void handheldMic(double x, double y, double ang) {
    c.save();
    c.translate(x, y);
    c.rotate(ang);
    circle(0, -5.5, 3.2);
    line(-2.4, -7.6, 2.4, -3.4);
    line(-2.4, -3.4, 2.4, -7.6);
    path([const Offset(-2, -2.6), const Offset(-1, 8), const Offset(1, 8), const Offset(2, -2.6)], close: true);
    c.restore();
  }

  void pencilMic(double x, double y, double ang) {
    c.save();
    c.translate(x, y);
    c.rotate(ang);
    rect(-1.8, -9, 1.8, 7, rad: 1.5);
    line(-1.8, -5, 1.8, -5);
    c.restore();
  }

  void plug(double y, {String? letter}) {
    // jack TRS orizzontale: corpo, collare, punta con anelli
    rect(2, y - 3, 11, y + 3, rad: 1.2);
    rect(11, y - 2, 13, y + 2, rad: 0.5);
    line(13, y, 21, y);
    line(16, y - 1.2, 16, y + 1.2);
    line(18.5, y - 1.2, 18.5, y + 1.2);
    circle(21.3, y, 0.9, fill: true);
    if (letter != null) badge(letter);
  }

  void rca(String letter) {
    rect(2, 7, 11, 15, rad: 1.5);
    rect(11, 8.5, 16, 13.5, rad: 1);
    line(16, 11, 21, 11);
    line(11, 8.5, 16, 8.5);
    badge(letter);
  }
}

void _draw(int id, _D d) {
  switch (id) {
    case 1: // nessuna
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = d.color.withValues(alpha: 0.55);
      d.c.drawRRect(RRect.fromLTRBR(4, 4, 20, 20, const Radius.circular(4)), p);
      d.c.drawLine(const Offset(7, 17), const Offset(17, 7), p);
    case 2: // cassa retro: pelle con foro
      d.circle(12, 12, 9);
      d.circle(15, 15, 2.4);
    case 3: // cassa fronte: pelle con anello
      d.circle(12, 12, 9);
      d.circle(12, 12, 5.5);
      d.line(4, 21, 7, 18.5);
      d.line(20, 21, 17, 18.5);
    case 4: // rullante sopra: fusto + bacchette sopra
      d.drumSide(4, 13, 20, 20);
      d.line(6, 4, 13, 11);
      d.line(18, 4, 11, 11);
    case 5: // rullante sotto: fusto + cordiera
      d.drumSide(4, 6, 20, 13);
      d.path([const Offset(5, 18), const Offset(7, 16.5), const Offset(9, 18), const Offset(11, 16.5), const Offset(13, 18), const Offset(15, 16.5), const Offset(17, 18), const Offset(19, 16.5)]);
    case 6:
      d.drumSide(7, 9, 17, 15);
      d.line(12, 17, 12, 21);
    case 7:
      d.drumSide(5, 8, 19, 16);
      d.line(12, 18, 12, 21);
    case 8: // floor tom con gambe
      d.drumSide(5, 5, 19, 16);
      d.line(6, 17, 5, 21);
      d.line(18, 17, 19, 21);
    case 9: // hi-hat
      d.cymbal(12, 7, 16);
      d.cymbal(12, 10, 16);
      d.line(12, 6, 12, 21);
      d.line(8, 21, 16, 21);
    case 10: // ride
      d.path([const Offset(3, 10), const Offset(12, 6), const Offset(21, 10)]);
      d.circle(12, 6.5, 0.9, fill: true);
      d.line(12, 8, 12, 21);
      d.line(8, 21, 16, 21);
    case 11: // batteria
      d.circle(12, 15, 5.5);
      d.oval(5, 9, 6, 3);
      d.oval(19, 9, 6, 3);
      d.cymbal(4, 4, 6);
      d.cymbal(20, 4, 6);
    case 12: // campanaccio
      d.path([const Offset(8, 6), const Offset(16, 6), const Offset(19, 19), const Offset(5, 19)], close: true);
      d.line(10, 6, 10, 3);
      d.line(14, 6, 14, 3);
      d.line(10, 3, 14, 3);
    case 13: // bonghi
      d.drumSide(3, 8, 11, 17);
      d.drumSide(13, 9, 21, 17);
      d.line(11, 13, 13, 13);
    case 14: // conga
      d.oval(12, 4.5, 9, 3);
      d.curve([const Offset(7.5, 4.5), const Offset(5.5, 11), const Offset(9.5, 15), const Offset(9, 21)]);
      d.curve([const Offset(16.5, 4.5), const Offset(18.5, 11), const Offset(14.5, 15), const Offset(15, 21)]);
      d.line(9, 21, 15, 21);
    case 15: // tamburello
      d.circle(12, 12, 8);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        d.circle(12 + math.cos(a) * 8, 12 + math.sin(a) * 8, 1.5, fill: true);
      }
    case 16: // vibrafono
      for (var i = 0; i < 6; i++) {
        d.line(4 + i * 3.2, 7 + i * 0.8, 4 + i * 3.2, 18 - i * 0.8);
      }
      d.line(7, 3, 11, 6);
      d.line(15, 3, 19, 6);
    case 17: // basso elettrico
      d.curve([const Offset(5, 19), const Offset(3, 14), const Offset(7, 11), const Offset(10, 13)]);
      d.curve([const Offset(5, 19), const Offset(8, 22), const Offset(13, 19), const Offset(11, 14)]);
      d.guitarNeck(10, 14, 20, 3);
    case 18: // basso acustico
      d.circle(8, 17, 4.5);
      d.circle(10.5, 12.5, 3.2);
      d.circle(8.3, 16.5, 1.2, fill: true);
      d.guitarNeck(12, 11, 20, 3);
    case 19: // contrabbasso
      d.curve([const Offset(12, 6), const Offset(6, 7), const Offset(9, 12), const Offset(7, 15)]);
      d.curve([const Offset(7, 15), const Offset(5, 19), const Offset(9, 21), const Offset(12, 21)]);
      d.curve([const Offset(12, 6), const Offset(18, 7), const Offset(15, 12), const Offset(17, 15)]);
      d.curve([const Offset(17, 15), const Offset(19, 19), const Offset(15, 21), const Offset(12, 21)]);
      d.line(12, 2, 12, 17);
      d.line(12, 21, 12, 23);
    case 20: // single cut
      d.curve([const Offset(9, 10), const Offset(3, 12), const Offset(3, 21), const Offset(10, 21)]);
      d.curve([const Offset(10, 21), const Offset(16, 21), const Offset(15, 15), const Offset(13, 13)]);
      d.line(9, 10, 11, 12);
      d.guitarNeck(12, 13, 20, 3);
    case 21: // superstrat a corni appuntiti
      d.path([const Offset(4, 21), const Offset(3, 14), const Offset(7, 13), const Offset(6, 8), const Offset(11, 12), const Offset(15, 12), const Offset(13, 16), const Offset(14, 21)], close: true);
      d.guitarNeck(12, 12, 20, 3);
    case 22: // offset
      d.curve([const Offset(5, 10), const Offset(2, 14), const Offset(4, 21), const Offset(9, 20)]);
      d.curve([const Offset(9, 20), const Offset(14, 22), const Offset(16, 16), const Offset(13, 12)]);
      d.line(5, 10, 13, 12);
      d.guitarNeck(11, 13, 20, 3);
    case 23: // acustica
      d.circle(8.5, 16.5, 4.8);
      d.circle(11.5, 11.8, 3.4);
      d.circle(9, 16, 1.4);
      d.guitarNeck(13, 10.5, 20, 3);
    case 24: // ampli basso
      d.rect(4, 3, 20, 21);
      d.circle(12, 13, 5.5);
      d.circle(12, 13, 1.8, fill: true);
      d.line(6, 5.5, 18, 5.5);
    case 25: // ampli chitarra
      d.rect(3, 6, 21, 20);
      d.line(3, 10, 21, 10);
      for (var i = 0; i < 4; i++) {
        d.circle(6 + i * 2.6, 8, 0.7, fill: true);
      }
      d.rect(6, 12.5, 18, 18, rad: 0.8);
      d.line(10, 6, 14, 6);
      d.line(10, 6, 10, 4);
      d.line(14, 6, 14, 4);
      d.line(10, 4, 14, 4);
    case 26: // cassa 4×12
      d.rect(3, 3, 21, 21);
      d.circle(8, 8, 3);
      d.circle(16, 8, 3);
      d.circle(8, 16, 3);
      d.circle(16, 16, 3);
    case 27: // pianoforte a coda (vista dall'alto)
      d.curve([const Offset(5, 4), const Offset(5, 4), const Offset(19, 6), const Offset(19, 14)]);
      d.curve([const Offset(19, 14), const Offset(19, 19), const Offset(12, 17), const Offset(11, 21)]);
      d.line(5, 4, 5, 21);
      d.line(5, 21, 11, 21);
      d.line(5, 18, 11, 18);
    case 28: // organo: due manuali e registri
      d.keys(3, 11, 21, 15, 9);
      d.keys(3, 16.5, 21, 20.5, 9);
      for (var i = 0; i < 5; i++) {
        d.line(6 + i * 3, 4, 6 + i * 3, 4.0 + (i % 3) * 2 + 2);
      }
    case 29: // clavicembalo
      d.path([const Offset(4, 5), const Offset(20, 5), const Offset(20, 9), const Offset(10, 19), const Offset(4, 19)], close: true);
      d.keys(4, 5, 20, 9, 8);
    case 30:
      d.keys(2, 7, 22, 17, 10);
    case 31 || 32 || 33: // sintetizzatori numerati
      d.keys(2, 10, 22, 17, 10);
      for (var i = 0; i < 3; i++) {
        d.circle(5 + i * 3.6, 6, 1.1);
      }
      d.badge('${id - 30}');
    case 34: // keytar
      d.c.save();
      d.c.translate(12, 12);
      d.c.rotate(-0.45);
      d.keys(-9, -3, 4, 3, 7);
      d.line(4, 0, 10, 0);
      d.rect(10, -2, 12, 2, rad: 0.8);
      d.c.restore();
    case 35: // tromba
      d.line(3, 12, 14, 12);
      d.path([const Offset(14, 9), const Offset(21, 6), const Offset(21, 18), const Offset(14, 15)], close: true);
      d.rect(6, 14, 13, 17, rad: 1);
      for (var i = 0; i < 3; i++) {
        d.line(8 + i * 2, 9.5, 8 + i * 2, 12);
      }
    case 36: // trombone
      d.line(2, 9, 16, 9);
      d.line(2, 14, 16, 14);
      d.line(2, 9, 2, 14);
      d.path([const Offset(16, 7), const Offset(22, 4), const Offset(22, 13), const Offset(16, 10)], close: true);
      d.line(9, 14, 9, 19);
      d.line(9, 19, 16, 19);
    case 37: // sax
      d.line(9, 3, 11, 5);
      d.curve([const Offset(11, 5), const Offset(9, 10), const Offset(9, 16), const Offset(12, 19)]);
      d.curve([const Offset(12, 19), const Offset(15, 21), const Offset(18, 19), const Offset(17, 14)]);
      d.path([const Offset(15, 15), const Offset(19, 12), const Offset(20, 15), const Offset(17, 14)]);
      for (var i = 0; i < 3; i++) {
        d.circle(9.6, 9 + i * 2.6, 0.8, fill: true);
      }
    case 38: // clarinetto
      d.line(12, 2, 12, 18);
      d.path([const Offset(9.5, 18), const Offset(14.5, 18), const Offset(16, 22), const Offset(8, 22)], close: true);
      for (var i = 0; i < 4; i++) {
        d.circle(12, 6 + i * 3, 0.9, fill: true);
      }
    case 39 || 40: // violino / violoncello (con puntale)
      d.curve([const Offset(12, 7), const Offset(7, 7), const Offset(9.5, 11.5), const Offset(8, 13.5)]);
      d.curve([const Offset(8, 13.5), const Offset(6, 17.5), const Offset(9, 20), const Offset(12, 20)]);
      d.curve([const Offset(12, 7), const Offset(17, 7), const Offset(14.5, 11.5), const Offset(16, 13.5)]);
      d.curve([const Offset(16, 13.5), const Offset(18, 17.5), const Offset(15, 20), const Offset(12, 20)]);
      d.line(12, 2, 12, 16);
      if (id == 40) {
        d.line(12, 20, 12, 23);
      } else {
        d.line(4, 22, 20, 10);
      }
    case 41: // voce maschile
      d.head(12, 9, 4.2);
      d.shoulders(12, 15, 14);
      d.line(8, 7, 16, 7);
    case 42: // voce femminile
      d.head(12, 9, 4.2);
      d.curve([const Offset(7.8, 9), const Offset(7, 14), const Offset(6, 15), const Offset(6, 16)]);
      d.curve([const Offset(16.2, 9), const Offset(17, 14), const Offset(18, 15), const Offset(18, 16)]);
      d.shoulders(12, 16, 13);
    case 43: // coro
      d.head(6, 10, 2.6);
      d.head(18, 10, 2.6);
      d.head(12, 8, 2.9);
      d.shoulders(6, 14, 8);
      d.shoulders(18, 14, 8);
      d.shoulders(12, 12.5, 10);
    case 44: // mano
      d.rect(7, 11, 17, 21, rad: 3);
      for (var i = 0; i < 4; i++) {
        d.line(8.5 + i * 2.6, 11, 8.5 + i * 2.6, 4.5 + (i == 0 || i == 3 ? 1.5 : 0));
      }
      d.line(7, 15, 4, 11.5);
    case 45 || 46: // talkback A/B
      d.rect(3, 4, 18, 15, rad: 3);
      d.path([const Offset(6, 15), const Offset(5, 19), const Offset(10, 15)]);
      d.line(6.5, 8, 14.5, 8);
      d.line(6.5, 11, 12, 11);
      d.badge(id == 45 ? 'A' : 'B');
    case 47: // diaframma largo
      d.rect(8, 2.5, 16, 14, rad: 4);
      d.line(8, 7, 16, 7);
      d.line(8, 10, 16, 10);
      d.circle(12, 16, 6.5);
      d.line(12, 14, 12, 22);
    case 48 || 49: // condensatore L/R
      d.pencilMic(10, 11, id == 48 ? -0.5 : 0.5);
      d.badge(id == 48 ? 'L' : 'R');
    case 50: // a mano
      d.handheldMic(12, 12, 0.35);
    case 51: // radiomicrofono
      d.handheldMic(11, 13, 0.35);
      d.arc(16, 6, 3, -1.2, 1.4);
      d.arc(16, 6, 5.5, -1.2, 1.4);
    case 52: // da leggio
      d.rect(5, 18, 19, 21.5, rad: 1);
      d.curve([const Offset(12, 18), const Offset(12, 11), const Offset(9, 9), const Offset(10, 4)]);
      d.oval(10.5, 3.5, 3.5, 2.5, fill: true);
    case 53: // archetto
      d.arc(12, 11, 7.5, math.pi, math.pi);
      d.line(4.5, 11, 4.5, 14);
      d.curve([const Offset(4.5, 14), const Offset(5, 18), const Offset(9, 19), const Offset(13, 18.5)]);
      d.circle(14.5, 18.5, 1.5, fill: true);
    case 54: // XLR
      d.circle(12, 12, 9);
      d.circle(8.5, 10, 1.4, fill: true);
      d.circle(15.5, 10, 1.4, fill: true);
      d.circle(12, 16, 1.4, fill: true);
      d.line(11, 3.4, 13, 3.4);
    case 55:
      d.plug(12);
    case 56:
      d.plug(9, letter: 'L');
    case 57:
      d.plug(9, letter: 'R');
    case 58:
      d.rca('L');
    case 59:
      d.rca('R');
    case 60: // bobine
      d.circle(7, 9, 4.5);
      d.circle(17, 9, 4.5);
      d.circle(7, 9, 1, fill: true);
      d.circle(17, 9, 1, fill: true);
      d.line(4, 19, 20, 19);
      d.line(4, 13.5, 4, 19);
      d.line(20, 13.5, 20, 19);
    case 61: // FX
      d.text('FX', 11, 13, size: 10);
      d.path([const Offset(19, 3), const Offset(19.8, 5.2), const Offset(22, 6), const Offset(19.8, 6.8), const Offset(19, 9), const Offset(18.2, 6.8), const Offset(16, 6), const Offset(18.2, 5.2)], close: true, fill: true);
    case 62: // computer
      d.rect(3, 4, 21, 16);
      d.line(12, 16, 12, 19.5);
      d.line(7, 20, 17, 20);
    case 63: // wedge
      d.path([const Offset(3, 19), const Offset(21, 19), const Offset(17, 7), const Offset(3, 13)], close: true);
      d.circle(10, 15, 2.4);
    case 64 || 65:
      d.speakerBox(4, 3, 15, 21);
      d.badge(id == 64 ? 'L' : 'R');
    case 66: // line array
      for (var i = 0; i < 4; i++) {
        d.path([Offset(5 + i * 0.6, 3 + i * 4.5), Offset(19 - i * 0.6, 3 + i * 4.5), Offset(19 - i * 0.9, 6.8 + i * 4.5), Offset(5 + i * 0.9, 6.8 + i * 4.5)], close: true);
      }
    case 67: // su stativo
      d.speakerBox(7, 2, 17, 13);
      d.line(12, 13, 12, 20);
      d.line(12, 20, 6, 22.5);
      d.line(12, 20, 18, 22.5);
    case 68: // rack
      d.rect(3, 3, 21, 21);
      d.line(3, 9, 21, 9);
      d.line(3, 15, 21, 15);
      for (var r = 0; r < 3; r++) {
        d.circle(16.5, 6 + r * 6, 1, fill: true);
        d.line(6, 6 + r * 6, 12, 6 + r * 6);
      }
    case 69: // controlli
      for (var i = 0; i < 3; i++) {
        d.circle(5.5 + i * 6.5, 12, 2.8);
        d.line(5.5 + i * 6.5, 12, 5.5 + i * 6.5 + math.cos(-1.0 - i * 0.6) * 2.8, 12 + math.sin(-1.0 - i * 0.6) * 2.8);
      }
    case 70: // fader
      for (var i = 0; i < 3; i++) {
        d.line(6 + i * 6, 3, 6 + i * 6, 21);
        d.rect(4 + i * 6, 6.0 + i * 4, 8 + i * 6, 9.0 + i * 4, rad: 0.8, fill: true);
      }
    case 71: // mix bus: somma
      d.line(3, 5, 12, 12);
      d.line(3, 12, 12, 12);
      d.line(3, 19, 12, 12);
      d.line(12, 12, 21, 12);
      d.path([const Offset(17.5, 9), const Offset(21, 12), const Offset(17.5, 15)]);
    case 72: // matrix: griglia
      for (var r = 0; r < 3; r++) {
        for (var cc = 0; cc < 3; cc++) {
          d.circle(6 + cc * 6, 6 + r * 6, r == cc ? 1.8 : 1.1, fill: true);
        }
      }
    case 73: // routing: percorsi incrociati
      d.curve([const Offset(3, 6), const Offset(12, 6), const Offset(12, 18), const Offset(20, 18)]);
      d.curve([const Offset(3, 18), const Offset(12, 18), const Offset(12, 6), const Offset(20, 6)]);
      d.path([const Offset(17.5, 3.5), const Offset(20.5, 6), const Offset(17.5, 8.5)]);
      d.path([const Offset(17.5, 15.5), const Offset(20.5, 18), const Offset(17.5, 20.5)]);
    case 74: // faccina
      d.circle(12, 12, 9);
      d.circle(9, 10, 1.1, fill: true);
      d.circle(15, 10, 1.1, fill: true);
      d.arc(12, 12.5, 4.5, 0.4, math.pi - 0.8);
    default:
      d.unknown(id);
  }
}
