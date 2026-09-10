import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/glass_perf_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/sober_theme.dart';

/// A high-performance glass container with specular border highlighting,
/// soft ambient shadows, and optional GPU blur isolation.
///
/// PERFORMANCE NOTE (Snapdragon 765G / Adreno 620):
/// Every `BackdropFilter` forces a framebuffer read + two-pass Gaussian per
/// frame for EVERY visible card, with tap count scaling as sigma^2. The
/// adaptive GlassTier (Premium 12 / High 8 / Balanced 5 / Lite 2) caps sigma
/// everywhere, so all tiers keep live glass. Glows avoid MaskFilter, every
/// card sits in a RepaintBoundary, and the always-on bottom bar stays static
/// (pinned enableBlur:false) since it would tax every single frame.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  /// Null = follow the adaptive [GlassTier] sigma (12/8/5/2, live in every
  /// tier). Explicit true/false always wins — e.g. the always-on bottom bar
  /// pins false, the sample pill pins true.
  final bool? enableBlur;
  final Gradient? gradient;
  final Color? borderColor;
  /// Sober-only fill override (e.g. pure black graph cards). Ignored in
  /// glass mode. `borderColor` doubles as the sober hairline color.
  final Color? soberFill;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 24.0,
    // Small sigma by default; the adaptive tier caps/floors it (12/8/5/2).
    // Null enableBlur follows the tier (live in every tier now).
    this.blur = 8.0,
    this.enableBlur,
    this.gradient,
    this.borderColor,
    this.soberFill,
    this.onTap,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    // Hot-applies tier switches (Engine → Glass Quality) with no restart.
    // Each card rebuilds once per switch; steady-state cost is unchanged.
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) {
        // Sober skin: solid dark fill, thin flat border, zero blur. Every
        // GlassContainer in the app re-skins through this one branch, so the
        // glass theme is untouched — toggling back restores it exactly.
        if (GlassPerfService.instance.soberMode) {
          return _buildSoberCard();
        }
        final tier = GlassPerfService.instance.tier;
        // Live glass in every tier now; explicit opt-out (bottom bar) keeps
        // the static frosted fill.
        final effectiveBlur = enableBlur ?? true;
        // Premium floors sigma up to 12; all other tiers cap down to the
        // tier sigma (12/8/5/2) — "sigma everywhere".
        final tierSigma = GlassPerfService.sigmaForTier(tier);
        final sigma = tier == GlassTier.premium
            ? (blur < tierSigma ? tierSigma : blur)
            : (blur > tierSigma ? tierSigma : blur);
        return _buildCard(context, effectiveBlur, sigma);
      },
    );
  }

  /// Sober path: opaque card, no BackdropFilter, no specular painter, no
  /// glow shadows. Keeps margin/padding/radius/onTap so layout is identical.
  /// Honors `soberFill` (black-tone cards) and `borderColor` (accent hairlines
  /// like the graph's thin red border); defaults are the sober surface tokens.
  /// NOTE: asymmetric radii (e.g. merged summary card) can't flow through
  /// here — BorderRadius.circular only. Those cards build their own Container.
  Widget _buildSoberCard() {
    Widget card = RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: soberFill ?? SoberTheme.card,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
              color: borderColor ?? SoberTheme.cardBorder, width: 1),
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: card,
          ),
        ),
      );
    }

    return Container(margin: margin, child: card);
  }

  Widget _buildCard(BuildContext context, bool effectiveBlur, double sigma) {
    // Static frosted fill: slightly more opaque than the blurred variant to
    // compensate for the missing backdrop diffusion (keeps text legible over
    // busy wallpapers without any BackdropFilter cost).
    const staticFrostedGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x4D2A2E4A), // ~30% lightened slate
        Color(0x331A1C33),
      ],
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient ?? (effectiveBlur ? GlassTheme.glassCardGradient : staticFrostedGradient),
      ),
      child: child,
    );

    // Specular gradient border
    Widget bordered = CustomPaint(
      painter: _GlassBorderPainter(
        borderRadius: borderRadius,
        borderWidth: 1.2,
        highlightColor: borderColor ?? GlassTheme.borderHighlight,
        ambientColor: GlassTheme.borderAmbient,
      ),
      child: content,
    );

    // Live GPU blur at small sigma (widgets) or static frosted (lists/nav).
    // Isolated in a RepaintBoundary so scroll frames never re-rasterize
    // neighbors — Flutter's equivalent of CALayer.shouldRasterize.
    Widget surface = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: effectiveBlur && sigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: bordered,
              )
            : bordered,
      ),
    );

    Widget glassCard = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: GlassTheme.bgOceanCyan.withValues(alpha: 0.03),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 0),
              ),
            ],
      ),
      child: surface,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: glassCard,
        ),
      );
    }

    return glassCard;
  }
}

/// Custom painter that renders a realistic specular gradient border:
/// brighter at top-left (light source), softer at bottom-right (ambient).
class _GlassBorderPainter extends CustomPainter {
  final double borderRadius;
  final double borderWidth;
  final Color highlightColor;
  final Color ambientColor;

  _GlassBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.highlightColor,
    required this.ambientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(borderRadius - borderWidth / 2),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          highlightColor,
          highlightColor.withValues(alpha: 0.3),
          ambientColor,
          ambientColor.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.ambientColor != ambientColor;
  }
}
