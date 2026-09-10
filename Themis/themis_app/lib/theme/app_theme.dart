import 'package:flutter/material.dart';

class AppTheme {
  // Pure Apple Monochrome Palette
  static const Color black = Color(0xFF000000);
  static const Color surface = Color(0xFF141416);
  static const Color surfaceElevated = Color(0xFF1E1E22);
  static const Color surfaceBorder = Color(0xFF28282C);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF86868B);
  static const Color textMuted = Color(0xFF545458);

  // Status Indicator Beacons (Apple Monochrome with Crimson reserved for violations)
  static const Color compliant = Color(0xFFFFFFFF); // Clean Monochrome White
  static const Color warning = Color(0xFFA1A1A6);   // Apple Silver Monochrome
  static const Color violation = Color(0xFFFF453A); // Apple Crimson (kept for violations)
  static const Color neutral = Color(0xFF8E8E93);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      primaryColor: textPrimary,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: textPrimary,
        secondary: textSecondary,
        error: violation,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
