import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/glass_perf_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/sober_theme.dart';
import 'glass_container.dart';

/// A premium dual-layer cubic Bézier wave area graph widget with an interactive
/// timeline scrubber slider, glowing peak node, and frosted glass container,
/// inspired directly by the graph widget in neo/redesign/image copy 2.png.
class GlassWaveChart extends StatefulWidget {
  final String title;
  final String metricValue;
  final String subtitle;
  final List<double> dataPoints;
  final List<double>? backWaveData;
  final ValueChanged<int>? onScrubbed;
  final int initialScrubIndex;
  final double height;
  /// Sober-only styling hooks (ignored in glass mode — see GlassContainer):
  /// hairline color (e.g. thin red border) and fill (e.g. black tone).
  final Color? borderColor;
  final Color? soberFill;

  const GlassWaveChart({
    super.key,
    this.title = 'COMPLIANCE AUDIT VOLUME',
    this.metricValue = '2,201',
    this.subtitle = 'Active statutory inspections across SKUs',
    this.dataPoints = const [18, 32, 24, 60, 42, 88, 52, 95, 70],
    this.backWaveData = const [12, 22, 18, 45, 30, 65, 38, 70, 50],
    this.onScrubbed,
    this.initialScrubIndex = 5,
    this.height = 230,
    this.borderColor,
    this.soberFill,
  });

  @override
  State<GlassWaveChart> createState() => _GlassWaveChartState();
}

class _GlassWaveChartState extends State<GlassWaveChart> {
  late int _scrubIndex;
  late double _scrubFraction;

  @override
  void initState() {
    super.initState();
    _scrubIndex = widget.initialScrubIndex.clamp(0, widget.dataPoints.length - 1);
    _scrubFraction = _scrubIndex / (widget.dataPoints.length - 1);
  }

  void _updateScrub(double fraction) {
    setState(() {
      _scrubFraction = fraction.clamp(0.0, 1.0);
      _scrubIndex = (_scrubFraction * (widget.dataPoints.length - 1)).round();
    });
    widget.onScrubbed?.call(_scrubIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Sober: saffron/red waves (reference palette). Glass: cyan/blue.
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) {
        final sober = GlassPerfService.instance.soberMode;
        final accent = SoberTheme.swap(GlassTheme.bgNeonCyan, sober);
        final ocean = SoberTheme.swap(GlassTheme.bgOceanCyan, sober);
        return GlassContainer(
          borderColor: widget.borderColor,
          soberFill: widget.soberFill,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Title & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: GlassTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'REALTIME',
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Big Metric Value & Subtitle
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.metricValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: GlassTheme.textMuted,
                    fontSize: 11,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Dual-Wave Area Canvas (isolated repaint island)
          SizedBox(
            height: widget.height - 110,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _DualWavePainter(
                  dataPoints: widget.dataPoints,
                  backWaveData: widget.backWaveData ?? widget.dataPoints.map((v) => v * 0.7).toList(),
                  activeFraction: _scrubFraction,
                  sober: sober,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Interactive Timeline Scrubber Slider
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final localX = details.localPosition.dx;
                    _updateScrub(localX / trackWidth);
                  }
                },
                onTapDown: (details) {
                  _updateScrub(details.localPosition.dx / trackWidth);
                },
                child: SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Base Track
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Active Progress Track
                      Container(
                        height: 4,
                        width: trackWidth * _scrubFraction,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ocean, accent],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Interactive Handle Pill
                      Positioned(
                        left: ((trackWidth - 16) * _scrubFraction).clamp(0.0, trackWidth - 16),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(
                              color: ocean,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        ),
      );
      },
    );
  }
}

/// Custom painter for smooth dual-layer cubic Bézier wave curves.
class _DualWavePainter extends CustomPainter {
  final List<double> dataPoints;
  final List<double> backWaveData;
  final double activeFraction;
  final bool sober;

  _DualWavePainter({
    required this.dataPoints,
    required this.backWaveData,
    required this.activeFraction,
    this.sober = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final double maxVal = math.max(
      dataPoints.reduce(math.max),
      backWaveData.reduce(math.max),
    ).clamp(1.0, double.infinity);

    // 1. Draw Back Wave (Soft lilac translucent silhouette)
    final backPath = _buildSplinePath(backWaveData, size, maxVal);
    final backArea = Path.from(backPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final backFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SoberTheme.swap(GlassTheme.bgSoftLilac, sober).withValues(alpha: 0.25),
          SoberTheme.swap(GlassTheme.bgSoftLilac, sober).withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(backArea, backFillPaint);

    // 2. Draw Front Wave Area Fill (Electric Cyan to Blue Gradient)
    final frontPath = _buildSplinePath(dataPoints, size, maxVal);
    final frontArea = Path.from(frontPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final frontFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SoberTheme.swap(GlassTheme.bgNeonCyan, sober).withValues(alpha: 0.50),
          SoberTheme.swap(GlassTheme.bgElectricBlue, sober).withValues(alpha: 0.22),
          SoberTheme.swap(GlassTheme.bgElectricBlue, sober).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawPath(frontArea, frontFillPaint);

    // 3. Draw Front Wave Stroke
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          SoberTheme.swap(GlassTheme.bgOceanCyan, sober),
          SoberTheme.swap(GlassTheme.bgNeonCyan, sober),
          Colors.white,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(frontPath, strokePaint);

    // 4. Draw Active Scrub Indicator & Glowing Peak Node
    final activeX = size.width * activeFraction;
    final activeY = _interpolateY(dataPoints, activeFraction, size, maxVal);

    // Dotted vertical guideline
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    for (double y = activeY; y < size.height; y += 6) {
      canvas.drawLine(Offset(activeX, y), Offset(activeX, y + 3), guidePaint);
    }

    // Outer glow halo (layered alpha circles — no MaskFilter saveLayer)
    final glowOuter = Paint()
      ..color = SoberTheme.swap(GlassTheme.bgNeonCyan, sober).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(activeX, activeY), 13, glowOuter);

    final glowMid = Paint()
      ..color = SoberTheme.swap(GlassTheme.bgNeonCyan, sober).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(activeX, activeY), 9, glowMid);

    // Middle colored ring
    final nodeRing = Paint()
      ..color = SoberTheme.swap(GlassTheme.bgElectricBlue, sober)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(activeX, activeY), 5.5, nodeRing);

    // Inner bright white core
    final nodeCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(activeX, activeY), 3.0, nodeCore);
  }

  Path _buildSplinePath(List<double> points, Size size, double maxVal) {
    final path = Path();
    final stepX = size.width / (points.length - 1);

    final List<Offset> coords = [];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      // Invert Y and keep 15% top padding for glow
      final normalized = points[i] / maxVal;
      final y = size.height * (1.0 - (normalized * 0.82 + 0.08));
      coords.add(Offset(x, y));
    }

    path.moveTo(coords.first.dx, coords.first.dy);

    for (int i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];

      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    return path;
  }

  double _interpolateY(List<double> points, double fraction, Size size, double maxVal) {
    final floatIndex = fraction * (points.length - 1);
    final lowerIndex = floatIndex.floor();
    final upperIndex = (lowerIndex + 1).clamp(0, points.length - 1);
    final remainder = floatIndex - lowerIndex;

    final lowerVal = points[lowerIndex];
    final upperVal = points[upperIndex];
    final interpolatedVal = lowerVal + (upperVal - lowerVal) * remainder;

    final normalized = interpolatedVal / maxVal;
    return size.height * (1.0 - (normalized * 0.82 + 0.08));
  }

  @override
  bool shouldRepaint(covariant _DualWavePainter oldDelegate) {
    return oldDelegate.activeFraction != activeFraction ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.sober != sober ||
        oldDelegate.backWaveData != backWaveData;
  }
}
