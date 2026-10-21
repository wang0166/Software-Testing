import 'package:flutter/material.dart';

/// A warmer editorial identity: midnight-teal + sea-glass + sunlit apricot.
class Palette {
  static const Color primary = Color(0xFF158E85);
  static const Color deep = Color(0xFF123A40);
  static const Color ink = Color(0xFF172F37);
  static const Color sage = Color(0xFFDDF5EC);
  static const Color paper = Color(0xFFF6F7F3);
  static const Color pastel = Color(0xFFFFF0D9);
  static const Color coral = Color(0xFFF08B72);
  static const Color muted = Color(0xFF7D9091);
  static const Color divider = Color(0xFFE8EEEA);
  static const Color lavender = Color(0xFFEFECFC);
  static const Color gold = Color(0xFFFFC670);
  static const Color darkGreen = Color(0xFF0B5351);
}

ThemeData pandoraTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.primary, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(primary: Palette.primary, surface: Colors.white),
    scaffoldBackgroundColor: Palette.paper,
    fontFamilyFallback: const ['Noto Sans CJK SC', 'Microsoft YaHei'],
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.paper,
      foregroundColor: Palette.deep,
      scrolledUnderElevation: 0,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Palette.deep),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.6, color: Palette.deep),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.3, color: Palette.deep),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Palette.deep),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: Palette.ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: Palette.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      hintStyle: const TextStyle(color: Palette.muted, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: Palette.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: Palette.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: Palette.primary, width: 1.6)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: Palette.primary, foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      minimumSize: const Size.fromHeight(51),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    )),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: Palette.primary, foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
      minimumSize: const Size.fromHeight(51),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    )),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Palette.primary, foregroundColor: Colors.white),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Palette.deep, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    dividerColor: Palette.divider,
  );
}
