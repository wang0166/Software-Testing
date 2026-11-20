import 'package:flutter/material.dart';

/// Pandora 软萌全局设计系统：莓果粉、奶油白、云朵紫、薄荷绿。
/// 深色文字始终保持足够对比度，业务状态色和字段含义不变。
class Palette {
  static const Color primary = Color(0xFFB85186); // 莓果粉 / CTA
  static const Color deep = Color(0xFF573950); // 深莓紫 / 标题
  static const Color ink = Color(0xFF594C5B);
  static const Color sage = Color(0xFFE6F7EB); // 薄荷绿
  static const Color paper = Color(0xFFFFF9FC); // 奶油粉底
  static const Color pastel = Color(0xFFFFF0DB); // 蜜桃黄
  static const Color coral = Color(0xFFCC647B);
  static const Color muted = Color(0xFF817286);
  static const Color divider = Color(0xFFF0DCE8);
  static const Color lavender = Color(0xFFF0E9FF);
  static const Color gold = Color(0xFFD19A50);
  static const Color darkGreen = Color(0xFF387C6C);
  static const Color surface = Colors.white;
  static const Color mutedBlue = Color(0xFFF1EDFF);
  static const Color rose = Color(0xFFFFE5F0);
  static const Color sky = Color(0xFFE8F5FF);
  static const Color cream = Color(0xFFFFF8E8);
}

ThemeData pandoraTheme() {
  const corners = BorderRadius.all(Radius.circular(22));
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.primary, brightness: Brightness.light,
  ).copyWith(
    primary: Palette.primary,
    onPrimary: Colors.white,
    primaryContainer: Palette.rose,
    onPrimaryContainer: Palette.deep,
    secondary: const Color(0xFF8470BE),
    secondaryContainer: Palette.lavender,
    onSecondaryContainer: Palette.deep,
    tertiary: Palette.gold,
    surface: Palette.surface,
    onSurface: Palette.ink,
    outline: Palette.divider,
    outlineVariant: Palette.divider,
    error: Palette.coral,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.paper,
    canvasColor: Palette.paper,
    fontFamilyFallback: const ['Noto Sans CJK SC', 'Microsoft YaHei'],
    visualDensity: VisualDensity.standard,
    splashColor: Palette.rose,
    highlightColor: Palette.lavender,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.paper,
      foregroundColor: Palette.deep,
      scrolledUnderElevation: 0,
      centerTitle: true,
      elevation: 0,
      iconTheme: IconThemeData(color: Palette.primary),
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w900,
        letterSpacing: .2, color: Palette.deep),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 27, fontWeight: FontWeight.w900,
        letterSpacing: -.25, color: Palette.deep),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
        letterSpacing: -.2, color: Palette.deep),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Palette.deep),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: Palette.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: Palette.ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: Palette.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      hintStyle: const TextStyle(color: Palette.muted, fontSize: 13),
      labelStyle: const TextStyle(color: Palette.muted),
      prefixIconColor: Palette.primary,
      suffixIconColor: Palette.primary,
      border: OutlineInputBorder(borderRadius: corners,
        borderSide: const BorderSide(color: Palette.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: corners,
        borderSide: const BorderSide(color: Palette.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: corners,
        borderSide: const BorderSide(color: Palette.primary, width: 1.7)),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white, elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: corners,
        side: BorderSide(color: Palette.divider)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Palette.rose,
      disabledColor: Palette.divider,
      side: const BorderSide(color: Palette.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700,
        color: Palette.deep, fontSize: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: Palette.primary, foregroundColor: Colors.white,
      disabledBackgroundColor: Palette.divider,
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      minimumSize: const Size.fromHeight(47),
      shape: const RoundedRectangleBorder(borderRadius: corners),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: Palette.primary,
      side: const BorderSide(color: Palette.divider, width: 1.2),
      minimumSize: const Size.fromHeight(44),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      shape: const RoundedRectangleBorder(borderRadius: corners),
    )),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: Palette.primary, foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(47), elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: corners),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
      foregroundColor: Palette.primary,
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    )),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Palette.primary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(23))),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? Palette.primary : Colors.white),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: Palette.primary, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? Colors.white : Palette.muted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? Palette.primary : Palette.divider),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.deep,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: corners),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Palette.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Palette.deep),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.paper, showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius:
        BorderRadius.vertical(top: Radius.circular(30))),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Palette.paper,
      headerBackgroundColor: Palette.rose,
      headerForegroundColor: Palette.deep,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: Palette.paper,
      dialBackgroundColor: Palette.rose,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.primary),
    dividerColor: Palette.divider,
  );
}
