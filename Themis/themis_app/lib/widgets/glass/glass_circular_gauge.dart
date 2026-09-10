import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/glass_perf_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/sober_theme.dart';
import 'glass_container.dart';

/// A neumorphic circular progress meter with an embossed inner dial,
/// dual-light bevels, and a glowing cyan-amber-crimson statutory compliance arc,
/// inspired directly by the progress meter in neo/redesign/image copy 2.png.
class GlassCircularGauge extends StatelessWidget {
  final double scorePct;
  final String? riskTier;
  final double size;
  final String title;

  const GlassCircularGauge({
    super.key,
    required this.scorePct,
    this.riskTier,
    this.size = 180,
    this.title = 'STATUTORY COMPLIANCE SCORE',
  });

  Color _resolveArcColor(bool sober) {
    // Sober: good scores read green (reference palette), not cyan.
    if (scorePct >= 70.0) {
      return SoberTheme.swap(GlassTheme.compliantCyan, sober);
    }
    if (scorePct >= 40.0) return GlassTheme.moderateRiskAmber;
    return GlassTheme.criticalCrimson;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) {
        final sober = GlassPerfService.instance.soberMode;
        final arcColor = _resolveArcColor(sober);
        // Sober: saffron arc start (reference red). Glass: ocean cyan.
        final arcStartColor = SoberTheme.swap(GlassTheme.bgOceanCyan, sober);
        final progress = (scorePct / 100.0).clamp(0.0, 1.0);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Column(
        children: [
          // Header title
          Text(
            title,
            style: const TextStyle(
              color: GlassTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Circular Neumorphic Gauge
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing Arc Painter (static repaint island after 900ms intro)
                RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) {
                      return CustomPaint(
                        isComplex: true,
                        size: Size(size, size),
                        painter: _CircularGaugePainter(
                          progress: val,
                          arcColor: arcColor,
                          arcStartColor: arcStartColor,
                        ),
                      );
                    },
                  ),
                ),

                // Embossed Neumorphic Center Disk
                Container(
                  width: size * 0.62,
                  height: size * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x38FFFFFF),
                        Color(0x14FFFFFF),
                      ],
                    ),
                    boxShadow: [
                      // Bottom-right shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(4, 6),
                      ),
                      // Top-left highlight reflection
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(-3, -3),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${scorePct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size * 0.18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        if (riskTier != null)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: arcColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              riskTier!.toUpperCase(),
                              style: TextStyle(
                                color: arcColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      );
      },
    );
  }
}

class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color arcStartColor;

  _CircularGaugePainter({
    required this.progress,
    required this.arcColor,
    required this.arcStartColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 10.0;

    // Background track (soft translucent white)
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Arc starts from -220° to 40° (260° sweep)
    const startAngle = -math.pi * 1.22;
    const totalSweep = math.pi * 1.44;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    if (progress > 0) {
      final sweepAngle = totalSweep * progress;

      // Glow halo paint (wide translucent stroke — no MaskFilter saveLayer)
      final glowPaint = Paint()
        ..color = arcColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 8
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      // Gradient progress arc
      final arcPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [
            arcStartColor,
            arcColor,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.arcStartColor != arcStartColor;
  }
}
