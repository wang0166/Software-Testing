import 'package:flutter/material.dart';

/// 潘多拉企业级视觉系统：深海军蓝 + 商务青绿 + 冷白灰。
/// 色彩别名继续兼容原有页面，避免影响业务与 API。
class Palette {
  static const Color primary = Color(0xFF066C78);
  static const Color deep = Color(0xFF102C43);
  static const Color ink = Color(0xFF25364A);
  static const Color sage = Color(0xFFE5F0F1);
  static const Color paper = Color(0xFFF1F4F7);
  static const Color pastel = Color(0xFFFFF1DF);
  static const Color coral = Color(0xFFC65D50);
  static const Color muted = Color(0xFF637389);
  static const Color divider = Color(0xFFD5DDE4);
  static const Color lavender = Color(0xFFEDF1F7);
  static const Color gold = Color(0xFFD2A052);
  static const Color darkGreen = Color(0xFF09615E);
  static const Color surface = Colors.white;
  static const Color mutedBlue = Color(0xFFEAF0F7);
}

ThemeData pandoraTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: Palette.primary,
    brightness: Brightness.light,
  );
  const corners = BorderRadius.all(Radius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors.copyWith(
      primary: Palette.primary,
      onPrimary: Colors.white,
      surface: Palette.surface,
      onSurface: Palette.ink,
      outline: Palette.divider,
    ),
    scaffoldBackgroundColor: Palette.paper,
    fontFamilyFallback: const ['Noto Sans CJK SC', 'Microsoft YaHei'],
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.paper,
      foregroundColor: Palette.deep,
      scrolledUnderElevation: 0,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.deep),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.35, color: Palette.deep),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.2, color: Palette.deep),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.deep),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: Palette.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.48, color: Palette.ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: Palette.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: Palette.muted, fontSize: 13),
      labelStyle: const TextStyle(color: Palette.muted),
      border: OutlineInputBorder(borderRadius: corners, borderSide: const BorderSide(color: Palette.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: corners, borderSide: const BorderSide(color: Palette.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: corners, borderSide: const BorderSide(color: Palette.primary, width: 1.5)),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: corners, side: BorderSide(color: Palette.divider)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Palette.divider,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        minimumSize: const Size.fromHeight(47),
        shape: const RoundedRectangleBorder(borderRadius: corners),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.deep,
        side: const BorderSide(color: Palette.divider),
        minimumSize: const Size.fromHeight(44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        shape: const RoundedRectangleBorder(borderRadius: corners),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Palette.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(47),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: corners),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Palette.deep,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.deep,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: corners),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Palette.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Palette.deep),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Palette.paper, showDragHandle: true),
    dividerColor: Palette.divider,
  );
}
