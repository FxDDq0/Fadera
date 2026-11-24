import 'package:flutter/material.dart';

import 'design/tokens.dart';

export 'design/tokens.dart';

/// Tema Material costruito dai token del sistema grafico ([AppColors], [Tx], [Rd]).
ThemeData buildTheme() {
  final base = TextStyle(fontFamily: Tx.family, color: AppColors.text, letterSpacing: 0.1);
  final accent = AppColors.accent;
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: Tx.family,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: AppColors.surface,
      surfaceContainerHighest: AppColors.surface3,
      error: AppColors.error,
      onPrimary: Colors.white,
      outline: AppColors.border,
    ),
    textTheme: TextTheme(
      bodyMedium: base.copyWith(fontSize: 13),
      bodySmall: base.copyWith(fontSize: 11, color: AppColors.textDim),
      labelSmall: base.copyWith(fontSize: 10.5, color: AppColors.textDim, letterSpacing: 0.4),
      titleMedium: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      titleLarge: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: Rd.brL, side: BorderSide(color: AppColors.border)),
      titleTextStyle: Tx.pageTitle,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.surface3, borderRadius: Rd.brM),
      textStyle: TextStyle(color: AppColors.text, fontSize: 12),
      waitDuration: Duration(milliseconds: 500),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.textDim,
      indicatorColor: accent,
      dividerColor: AppColors.border,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: Rd.brM), minimumSize: const Size(0, Sz.controlL)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent, shape: const RoundedRectangleBorder(borderRadius: Rd.brM), minimumSize: const Size(0, Sz.controlL)),
    ),
    popupMenuTheme: const PopupMenuThemeData(color: AppColors.surface2, shape: RoundedRectangleBorder(borderRadius: Rd.brM, side: BorderSide(color: AppColors.border))),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface2,
      border: const OutlineInputBorder(borderRadius: Rd.brM, borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: const OutlineInputBorder(borderRadius: Rd.brM, borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: Rd.brM, borderSide: BorderSide(color: accent)),
      labelStyle: Tx.label,
    ),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.borderStrong),
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(3),
    ),
  );
}

const mono = Tx.value;
