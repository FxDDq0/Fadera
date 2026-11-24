import 'package:flutter/material.dart';

import 'tokens.dart';

/// Componenti riutilizzabili del sistema grafico. Ogni pagina li usa per pannelli,
/// titoli, schede, pulsanti e badge: così Mixer, DCA, Effetti, Routing e Scene
/// appartengono alla stessa famiglia visiva.

/// Pannello: superficie con bordo, titolo di sezione facoltativo e azioni a destra.
class MxPanel extends StatelessWidget {
  const MxPanel({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(Sp.m), this.color, this.expand = false, this.subtitle});
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  /// Il contenuto occupa tutto lo spazio verticale disponibile.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final head = title == null && trailing == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: Row(children: [
              if (title != null)
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title!.toUpperCase(), style: Tx.section),
                    if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: Tx.caption)),
                  ]),
                )
              else
                const Spacer(),
              ?trailing,
            ]),
          );
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color ?? AppColors.surface, borderRadius: Rd.brL, border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [
        ?head,
        if (expand) Expanded(child: child) else child,
      ]),
    );
  }
}

/// Intestazione di pagina: titolo, sottotitolo e azioni.
class MxPageHeader extends StatelessWidget {
  const MxPageHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.leading});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.m),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: Sp.m)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: Tx.pageTitle),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: Tx.caption, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        for (final a in actions) Padding(padding: const EdgeInsets.only(left: Sp.s), child: a),
      ]),
    );
  }
}

/// Selettore a segmenti (schede del pannello, tipi di scena, categorie): un solo stile in tutta l'app.
class MxSegmented<T> extends StatelessWidget {
  const MxSegmented({super.key, required this.options, required this.value, required this.onChanged, this.height = Sz.controlL, this.expand = false});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  /// I segmenti si dividono tutta la larghezza disponibile.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget seg((T, String) o) {
      final active = o.$1 == value;
      final w = InkWell(
        borderRadius: Rd.brS,
        onTap: () => onChanged(o.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: MxDensity.s(height) - 6,
          padding: const EdgeInsets.symmetric(horizontal: Sp.m),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface3 : Colors.transparent,
            borderRadius: Rd.brS,
            border: Border.all(color: active ? AppColors.borderStrong : Colors.transparent),
          ),
          child: Text(o.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.text : AppColors.textDim)),
        ),
      );
      return expand ? Expanded(child: w) : w;
    }

    return Container(
      height: MxDensity.s(height),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.well, borderRadius: Rd.brM, border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [for (final o in options) seg(o)]),
    );
  }
}

/// Badge ON/OFF cliccabile (sezioni Gate, Compressore, slot FX…).
class MxStateBadge extends StatelessWidget {
  const MxStateBadge({super.key, required this.on, this.onTap, this.onLabel = 'ON', this.offLabel = 'OFF', this.color = AppColors.ok});
  final bool on;
  final VoidCallback? onTap;
  final String onLabel, offLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Rd.brS,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minWidth: 38),
        height: 20,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Sp.s),
        decoration: BoxDecoration(color: on ? color : Colors.transparent, borderRadius: Rd.brS, border: Border.all(color: on ? color : AppColors.borderStrong)),
        child: Text(on ? onLabel : offLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: on ? AppColors.onColor(color) : AppColors.textFaint)),
      ),
    );
  }
}

/// Pulsante quadrato con icona (barra superiore, azioni di riga).
class MxIconButton extends StatelessWidget {
  const MxIconButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.color, this.active = false, this.size = Sz.controlL});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null ? AppColors.textFaint : (active ? AppColors.onColor(AppColors.accent) : (color ?? AppColors.textDim));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.accent : AppColors.surface2,
        borderRadius: Rd.brM,
        child: InkWell(
          borderRadius: Rd.brM,
          onTap: onTap,
          child: Container(
            width: MxDensity.s(size),
            height: MxDensity.s(size),
            decoration: BoxDecoration(borderRadius: Rd.brM, border: Border.all(color: active ? AppColors.accent : AppColors.border)),
            child: Icon(icon, size: MxDensity.s(size) * 0.5, color: fg),
          ),
        ),
      ),
    );
  }
}

enum MxButtonKind { primary, secondary, danger, ghost }

/// Pulsante con testo (e icona): primario, secondario, pericoloso o leggero.
class MxButton extends StatelessWidget {
  const MxButton({super.key, required this.label, required this.onTap, this.icon, this.kind = MxButtonKind.secondary, this.height = Sz.controlL, this.tooltip});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final MxButtonKind kind;
  final double height;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final (Color bg, Color fg, Color border) = switch (kind) {
      MxButtonKind.primary => (AppColors.accent, AppColors.onColor(AppColors.accent), AppColors.accent),
      MxButtonKind.danger => (AppColors.mute.withValues(alpha: 0.14), AppColors.mute, AppColors.mute.withValues(alpha: 0.5)),
      MxButtonKind.ghost => (Colors.transparent, AppColors.textDim, Colors.transparent),
      MxButtonKind.secondary => (AppColors.surface2, AppColors.text, AppColors.border),
    };
    final b = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: Rd.brM,
        child: InkWell(
          borderRadius: Rd.brM,
          onTap: onTap,
          child: Container(
            height: MxDensity.s(height),
            padding: const EdgeInsets.symmetric(horizontal: Sp.m),
            decoration: BoxDecoration(borderRadius: Rd.brM, border: Border.all(color: border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
            ]),
          ),
        ),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// Riquadro con un valore numerico (valori dei fader, frequenze, guadagni).
class MxValueBox extends StatelessWidget {
  const MxValueBox(this.text, {super.key, this.width, this.color, this.align = TextAlign.center, this.fontSize = 11.5});
  final String text;
  final double? width;
  final Color? color;
  final TextAlign align;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 20,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
        decoration: BoxDecoration(color: AppColors.well, borderRadius: Rd.brS, border: Border.all(color: AppColors.border)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.clip, textAlign: align, style: Tx.value.copyWith(fontSize: fontSize, color: color ?? AppColors.text)),
      );
}

/// Etichetta sopra un controllo (menu a tendina, interruttori).
class MxLabeled extends StatelessWidget {
  const MxLabeled(this.label, this.child, {super.key});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Tx.label),
        const SizedBox(height: Sp.xs),
        child,
      ]);
}

/// Stato vuoto: icona e messaggio centrati.
class MxEmpty extends StatelessWidget {
  const MxEmpty({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 36, color: AppColors.textFaint),
          const SizedBox(height: Sp.s),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim)),
          if (action != null) ...[const SizedBox(height: Sp.m), action!],
        ]),
      );
}

/// Pallino di colore selezionabile (palette, colori delle strip).
class MxSwatch extends StatelessWidget {
  const MxSwatch({super.key, required this.color, required this.selected, required this.onTap, this.size = 22, this.tooltip});
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final w = GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? AppColors.text : AppColors.bg.withValues(alpha: 0.6), width: selected ? 2.5 : 1),
            boxShadow: selected ? Shadows.glow(color, 0.5) : null,
          ),
        ),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}
