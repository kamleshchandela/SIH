import 'package:flutter/material.dart';

/// Design tokens and theme definition for the soft white-blue-purple
/// glassmorphic aesthetic inspired by modern fluid 3D UI designs.
class GlassTheme {
  // --- Background Fluid Mesh Gradients ---
  static const Color bgDark = Color(0xFF0A0C1B);
  static const Color bgDeepPurple = Color(0xFF1B143F);
  static const Color bgOceanCyan = Color(0xFF00C6FF);
  static const Color bgElectricBlue = Color(0xFF0072FF);
  static const Color bgViolet = Color(0xFF7F00FF);
  static const Color bgSoftLilac = Color(0xFFE0C3FC);
  static const Color bgNeonCyan = Color(0xFF00F2FE);

  // --- Glass Surface Colors ---
  static const Color glassSurfaceHigh = Color(0x38FFFFFF);  // 22% white
  static const Color glassSurfaceMid = Color(0x24FFFFFF);   // 14% white
  static const Color glassSurfaceLow = Color(0x12FFFFFF);   // 7% white
  static const Color glassSurfaceUltra = Color(0x0AFFFFFF); // 4% white

  // --- Specular Border Highlights ---
  static const Color borderHighlight = Color(0x66FFFFFF);  // 40% white
  static const Color borderAmbient = Color(0x1FFFFFFF);    // 12% white

  // --- Neumorphic Bevel Shadows ---
  static const Color neumorphicHighlight = Color(0x99FFFFFF); // Light reflection
  static const Color neumorphicShadow = Color(0x40000000);    // Ambient occlusion

  // --- Typography Colors ---
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);

  // --- Statutory Status & Severity Colors ---
  static const Color compliantCyan = Color(0xFF00F2FE);
  static const Color lowRiskBlue = Color(0xFF38BDF8);
  static const Color moderateRiskAmber = Color(0xFFFBBF24);
  static const Color highRiskMagenta = Color(0xFFF43F5E);
  static const Color criticalCrimson = Color(0xFFFF453A);

  // --- Gradients ---
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00F2FE), Color(0xFF0072FF)],
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33FFFFFF),
      Color(0x14FFFFFF),
    ],
  );

  static const LinearGradient glassCardPressedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x40FFFFFF),
      Color(0x20FFFFFF),
    ],
  );

  static const LinearGradient waveAreaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x8000F2FE), // 50% cyan
      Color(0x400072FF), // 25% blue
      Color(0x000072FF), // 0% fade
    ],
  );

  static const LinearGradient waveBackGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33E0C3FC), // 20% soft lilac
      Color(0x00E0C3FC), // 0% fade
    ],
  );

  // --- ThemeData ---
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.dark(
        primary: bgOceanCyan,
        secondary: bgElectricBlue,
        surface: bgDeepPurple,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1E1B4B),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
