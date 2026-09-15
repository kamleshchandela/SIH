import 'package:flutter/material.dart';

/// Themis Unified Design System
///
/// Built for Legal Metrology field officers in Indian retail environments.
/// Implements dual-surface architecture:
/// - [Sunlight Light Mode]: Default for core officer workflow (Home, Guided Capture,
///   Processing, Results) optimized for direct midday sunlight legibility.
/// - [Dark Slate Mode]: Reserved strictly for supervisory analytics and Insights/Dashboard.
class ThemisTheme {
  ThemisTheme._();

  // ---------------------------------------------------------------------------
  // 1. Spacing Scale (8px Grid Foundation)
  // ---------------------------------------------------------------------------
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // Geometry & Radii (Strictly uniform 8px & 12px)
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;

  // Touch Target Minimums (GIGW 3.0 / Outdoor fast-paced accessibility)
  static const double minTouchTarget = 48.0;
  static const double primaryTouchTarget = 56.0;

  // ---------------------------------------------------------------------------
  // 2. Color Palette (Restrained, Confident, Zero Gradients)
  // ---------------------------------------------------------------------------

  // Primary Accent Identity: Legal Metrology Amber/Saffron (Authoritative & Distinct)
  static const Color amberPrimary = Color(0xFFD97706); // Deep Saffron/Amber
  static const Color amberHover = Color(0xFFB45309);
  static const Color amberLight = Color(0xFFF59E0B);
  static const Color amberTint = Color(0xFFFEF3C7);

  // Sunlight Light Mode Palette (Default Field Inspector Flow)
  static const Color sunlightBg = Color(0xFFF8FAFC); // Cool, glare-resistant slate tint
  static const Color sunlightSurface = Color(0xFFFFFFFF); // Pure white card surface
  static const Color sunlightSurfaceElevated = Color(0xFFF1F5F9); // Muted tile background
  static const Color sunlightBorder = Color(0xFFCBD5E1); // Crisp 1px structural border
  static const Color sunlightBorderStrong = Color(0xFF94A3B8);

  // Sunlight Light Typography (High Contrast > 14:1 against sunlightBg)
  static const Color sunlightTextPrimary = Color(0xFF0F172A); // Deep Slate Ink
  static const Color sunlightTextSecondary = Color(0xFF334155); // Slate Body (>8:1)
  static const Color sunlightTextMuted = Color(0xFF64748B); // Metadata (>4.5:1 AA)

  // Dark Slate Mode Palette (Reserved for Insights/Dashboard Screen)
  static const Color darkSlateBg = Color(0xFF0B0E14); // Deep Midnight Slate
  static const Color darkSlateSurface = Color(0xFF141A24); // Raised analytics card
  static const Color darkSlateSurfaceElevated = Color(0xFF1C2433);
  static const Color darkSlateBorder = Color(0xFF283244);
  static const Color darkSlateBorderStrong = Color(0xFF3B4861);

  // Dark Slate Typography
  static const Color darkSlateTextPrimary = Color(0xFFF8FAFC);
  static const Color darkSlateTextSecondary = Color(0xFF94A3B8);
  static const Color darkSlateTextMuted = Color(0xFF64748B);

  // Statutory Status Colors (Color carries meaning, not decoration)
  static const Color statusCompliant = Color(0xFF059669); // Emerald Green
  static const Color statusCompliantDark = Color(0xFF10B981);
  static const Color statusCompliantBgLight = Color(0xFFECFDF5);
  static const Color statusCompliantBgDark = Color(0xFF064E3B);

  static const Color statusWarning = Color(0xFFD97706); // Amber Advisory
  static const Color statusWarningDark = Color(0xFFF59E0B);
  static const Color statusWarningBgLight = Color(0xFFFFFBEB);
  static const Color statusWarningBgDark = Color(0xFF451A03);

  static const Color statusViolation = Color(0xFFDC2626); // Statutory Violation Crimson
  static const Color statusViolationDark = Color(0xFFEF4444);
  static const Color statusViolationBgLight = Color(0xFFFEF2F2);
  static const Color statusViolationBgDark = Color(0xFF450A0A);

  static const Color statusNeutral = Color(0xFF64748B); // Slate
  static const Color statusNeutralBgLight = Color(0xFFF1F5F9);
  static const Color statusNeutralBgDark = Color(0xFF1E293B);

  // ---------------------------------------------------------------------------
  // 3. Typography Hierarchy (Max 2 Weights: Regular 400 & SemiBold 600)
  // ---------------------------------------------------------------------------
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.2,
  );

  // ---------------------------------------------------------------------------
  // 4. Flutter ThemeData Builders
  // ---------------------------------------------------------------------------

  /// Default Sunlight Light Theme (Core Field Flow)
  static ThemeData get sunlightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: sunlightBg,
      primaryColor: amberPrimary,
      fontFamily: 'Poppins',
      colorScheme: const ColorScheme.light(
        surface: sunlightSurface,
        primary: amberPrimary,
        onPrimary: Colors.white,
        secondary: amberHover,
        error: statusViolation,
        outline: sunlightBorder,
      ),
      cardTheme: CardThemeData(
        color: sunlightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius8),
          side: const BorderSide(color: sunlightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: sunlightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: sunlightTextPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: sunlightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: sunlightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Dark Slate Theme (Reserved for Insights/Dashboard)
  static ThemeData get darkSlateTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSlateBg,
      primaryColor: amberPrimary,
      fontFamily: 'Poppins',
      colorScheme: const ColorScheme.dark(
        surface: darkSlateSurface,
        primary: amberPrimary,
        onPrimary: Colors.white,
        secondary: amberLight,
        error: statusViolationDark,
        outline: darkSlateBorder,
      ),
      cardTheme: CardThemeData(
        color: darkSlateSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius8),
          side: const BorderSide(color: darkSlateBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSlateBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkSlateTextPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: darkSlateTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkSlateBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
