import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/components.dart';
import '../../theme.dart';
import '../../l10n/l10n.dart';

/// Selettore di colore: area saturazione/luminosità, barra della tinta, codice HEX,
/// colori pronti e anteprima su un'intestazione di strip. Restituisce il colore scelto.
Future<Color?> pickColor(BuildContext context, {required Color initial, String title = /*l10n*/ 'Scegli un colore', String previewName = /*l10n*/ 'Canale'}) {
  return showDialog<Color>(context: context, builder: (_) => _ColorPickerDialog(initial: initial, title: tr(title), previewName: tr(previewName)));
}

/// Colori pronti in stile console (pieni, poco saturi), oltre alle palette dei temi.
const kConsoleSwatches = <Color>[
  Color(0xFFB5524C), Color(0xFFC46A3C), Color(0xFFC4A24A), Color(0xFF8E9A45), Color(0xFF4E9468), Color(0xFF3F8C7E),
  Color(0xFF3F95A3), Color(0xFF4B76B8), Color(0xFF5B62B0), Color(0xFF7D5FAD), Color(0xFF9763A0), Color(0xFFA85A7A),
  Color(0xFF8A6A4F), Color(0xFF5A6170), Color(0xFF7E8592), Color(0xFFC3C8D0),
];

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title, required this.previewName});
  final Color initial;
  final String title;
  final String previewName;
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: _toHex(widget.initial));

  static String _toHex(Color c) => (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _set(HSVColor h, {bool updateHex = true}) {
    setState(() => _hsv = h);
    if (updateHex) _hex.text = _toHex(h.toColor());
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: 190, child: _SvArea(hsv: _hsv, onChanged: _set)),
              const SizedBox(height: Sp.m),
              SizedBox(height: 18, child: _HueBar(hsv: _hsv, onChanged: _set)),
              const SizedBox(height: Sp.m),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in kConsoleSwatches) MxSwatch(color: c, size: 22, selected: c.toARGB32() == color.toARGB32(), onTap: () => _set(HSVColor.fromColor(c))),
              ]),
            ]),
          ),
          const SizedBox(width: Sp.l),
          SizedBox(
            width: 150,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('ANTEPRIMA'), style: Tx.section),
              const SizedBox(height: Sp.s),
              _HeaderPreview(color: color, name: widget.previewName),
              const SizedBox(height: Sp.l),
              Text(tr('CODICE HEX'), style: Tx.section),
              const SizedBox(height: Sp.s),
              TextField(
                controller: _hex,
                maxLength: 6,
                style: Tx.value.copyWith(fontSize: 14),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]'))],
                decoration: const InputDecoration(prefixText: '# ', counterText: ''),
                onChanged: (v) {
                  if (v.length == 6) _set(HSVColor.fromColor(Color(0xFF000000 | int.parse(v, radix: 16))), updateHex: false);
                },
              ),
              const SizedBox(height: Sp.s),
              Text(tr('Contrasto del testo bianco: {p0}:1', {'p0': _contrast(color).toStringAsFixed(1)}), style: Tx.caption),
              if (_contrast(color) < 3) Text(tr('Poco leggibile: scegli un tono più scuro.'), style: TextStyle(fontSize: 11, color: AppColors.warn)),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annulla'))),
        FilledButton(onPressed: () => Navigator.pop(context, color), child: Text(tr('Applica'))),
      ],
    );
  }

  /// Contrasto (WCAG) fra testo bianco e l'intestazione scurita nel tema attivo.
  static double _contrast(Color c) {
    final l = AppColors.header(c).computeLuminance();
    return 1.05 / (l + 0.05);
  }
}

class _HeaderPreview extends StatelessWidget {
  const _HeaderPreview({required this.color, required this.name});
  final Color color;
  final String name;
  @override
  Widget build(BuildContext context) => Container(
        width: 84,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.header(color),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rd.m)),
          border: Border(top: BorderSide(color: color, width: 3)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('01', style: TextStyle(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w700)),
          const Icon(Icons.mic, size: 15, color: Colors.white),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      );
}

class _SvArea extends StatelessWidget {
  const _SvArea({required this.hsv, required this.onChanged});
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      void at(Offset p) => onChanged(hsv.withSaturation((p.dx / c.maxWidth).clamp(0.0, 1.0)).withValue(1 - (p.dy / c.maxHeight).clamp(0.0, 1.0)));
      return GestureDetector(
        onPanDown: (d) => at(d.localPosition),
        onPanUpdate: (d) => at(d.localPosition),
        child: ClipRRect(
          borderRadius: Rd.brM,
          child: CustomPaint(size: Size(c.maxWidth, c.maxHeight), painter: _SvPainter(hsv)),
        ),
      );
    });
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter(this.hsv);
  final HSVColor hsv;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..shader = LinearGradient(colors: [Colors.white, HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor()]).createShader(r));
    canvas.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black]).createShader(r));
    final p = Offset(hsv.saturation * size.width, (1 - hsv.value) * size.height);
    canvas.drawCircle(p, 7, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white);
    canvas.drawCircle(p, 8.5, Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black54);
  }

  @override
  bool shouldRepaint(_SvPainter o) => o.hsv != hsv;
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hsv, required this.onChanged});
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      void at(Offset p) => onChanged(hsv.withHue((p.dx / c.maxWidth).clamp(0.0, 1.0) * 359.9));
      return GestureDetector(
        onPanDown: (d) => at(d.localPosition),
        onPanUpdate: (d) => at(d.localPosition),
        child: CustomPaint(size: Size(c.maxWidth, c.maxHeight), painter: _HuePainter(hsv.hue)),
      );
    });
  }
}

class _HuePainter extends CustomPainter {
  _HuePainter(this.hue);
  final double hue;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Rd.s));
    canvas.drawRRect(r, Paint()..shader = LinearGradient(colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h % 360 == 0 && h > 0 ? 359.9 : h.toDouble(), 1, 1).toColor()]).createShader(r.outerRect));
    final x = hue / 360 * size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, size.height / 2), width: 6, height: size.height + 4), const Radius.circular(2)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white);
  }

  @override
  bool shouldRepaint(_HuePainter o) => o.hue != hue;
}
