import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/compliance_report.dart';
import '../../theme/sober_theme.dart';

/// Sober pin-timeline clause row (reference: Trip Plan screen).
///
/// Each row is self-contained: a 64px rail holding a full-height dashed line
/// (painted per-row, once — static, `shouldRepaint: false`) with the colored
/// pin node centered on it, plus a solid dark card. Rows are separated by
/// 12px gaps, so no cross-row line continuity is needed.
///
/// Pin color carries clause meaning for free:
/// violation = red, compliant = green, warning = amber, unknown = muted.
class SoberClauseRow extends StatelessWidget {
  final RuleEvaluation evaluation;

  const SoberClauseRow({super.key, required this.evaluation});

  Color get pinColor {
    if (evaluation.isViolation) return SoberTheme.pinRed;
    if (evaluation.isCompliant) return SoberTheme.pinGreen;
    if (evaluation.isWarning) return SoberTheme.pinAmber;
    return SoberTheme.iconDim;
  }

  IconData get pinIcon {
    if (evaluation.isCompliant) return CupertinoIcons.check_mark;
    if (evaluation.isWarning) return CupertinoIcons.exclamationmark;
    if (evaluation.isViolation) return CupertinoIcons.xmark;
    return CupertinoIcons.minus;
  }

  String get statusLabel {
    if (evaluation.isViolation) return 'VIOLATION';
    if (evaluation.isCompliant) return 'PASS';
    if (evaluation.isWarning) return 'REVIEW';
    return 'UNCHECKED';
  }

  @override
  Widget build(BuildContext context) {
    final color = pinColor;
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Timeline rail: dashed line + pin node ---
              SizedBox(
                width: 64,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      left: 20,
                      child: CustomPaint(painter: _DashedLinePainter()),
                    ),
                    Center(
                      child: _PinNode(color: color, icon: pinIcon),
                    ),
                  ],
                ),
              ),
              // --- Clause card ---
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SoberTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SoberTheme.cardBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              evaluation.clause.toUpperCase(),
                              style: const TextStyle(
                                color: SoberTheme.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: color,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        evaluation.field,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        evaluation.remarks,
                        style: const TextStyle(
                          color: SoberTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      if (evaluation.sourcePanel != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          evaluation.sourcePanel!,
                          style: const TextStyle(
                            color: SoberTheme.iconDim,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pin node: small dot on the timeline, short capsule tail, 34px filled
/// circle with a white glyph. Pure widgets — no paths.
class _PinNode extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _PinNode({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        Container(width: 10, height: 8, color: color),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
      ],
    );
  }
}

/// Vertical dashed line (dash 6 / gap 6). One instance per row, painted once.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SoberTheme.dashedLine
      ..strokeWidth = 2;
    const dash = 6.0;
    const gap = 6.0;
    double y = 0;
    while (y < size.height) {
      final end = (y + dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(0, y), Offset(0, end), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
