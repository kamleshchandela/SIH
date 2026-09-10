import 'package:flutter/material.dart';
import 'glass_theme.dart';

/// Judge-safe "sober" design tokens — solid dark surfaces, zero backdrop
/// blur, zero wallpaper compositing. See doc/redisign/05_SOBER_VARIANT_SPEC.
///
/// Every value is opaque on purpose: no translucency means no saveLayer,
/// no framebuffer reads, and WCAG-AA-capable contrast everywhere.
class SoberTheme {
  // --- Surfaces (AMOLED-first: true black page, surfaces separated by
  // light grayish-white hairlines instead of translucency) ---
  static const Color pageBg = Color(0xFF000000);
  static const Color surface = Color(0xFF1B1E25);
  static const Color card = Color(0xFF23262F);
  static const Color inset = Color(0xFF262A34);
  static const Color cardBorder = Color(0xFF7A8090);
  static const Color barBg = Color(0xFF23242E);

  // --- Accent (gov-appropriate saffron-amber, replaces neon cyan) ---
  static const Color accent = Color(0xFFE8762B);
  static const Color accentSoft = Color(0xFF3A2A1C);

  // --- Timeline pin colors (mirror clause severity) ---
  static const Color pinRed = Color(0xFFFF4A3D);
  static const Color pinGreen = Color(0xFF2ECC71);
  static const Color pinBlue = Color(0xFF2E9BFF);
  static const Color pinPurple = Color(0xFFA259FF);
  static const Color pinAmber = Color(0xFFFBBF24);

  // --- Lines & text ---
  static const Color dashedLine = Color(0xFF3A3E48);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9AA0AE);
  static const Color iconDim = Color(0xFF6B7280);

  /// Sober skin typeface (bundled Poppins — offline-safe).
  static const String fontFamily = 'Poppins';

  /// Central accent swap — the single choke point for "red only" sober.
  ///
  /// Brand blues (neon/ocean/electric) become saffron; status hues keep
  /// their meaning via the reference palette (good = green, info = blue,
  /// exotic = purple). Glass mode passes through untouched.
  /// Usage: `SoberTheme.swap(GlassTheme.bgNeonCyan, sober)` — chains fine
  /// with `.withValues(alpha: …)` and inside gradient color lists.
  static Color swap(Color glassColor, bool sober) {
    if (!sober) return glassColor;
    if (glassColor == GlassTheme.bgNeonCyan ||
        glassColor == GlassTheme.bgOceanCyan ||
        glassColor == GlassTheme.bgElectricBlue) {
      return accent;
    }
    if (glassColor == GlassTheme.compliantCyan) return pinGreen;
    if (glassColor == GlassTheme.lowRiskBlue) return pinBlue;
    if (glassColor == GlassTheme.bgViolet ||
        glassColor == GlassTheme.bgSoftLilac) {
      return pinPurple;
    }
    return glassColor;
  }
}
