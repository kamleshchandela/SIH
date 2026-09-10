import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/compliance_report.dart';
import '../theme/glass_theme.dart';
import 'glass/glass_container.dart';

class ClauseTile extends StatelessWidget {
  final RuleEvaluation evaluation;
  final VoidCallback? onTap;

  const ClauseTile({
    super.key,
    required this.evaluation,
    this.onTap,
  });

  Color get statusColor {
    if (evaluation.isViolation) return GlassTheme.criticalCrimson;
    if (evaluation.isCompliant) return GlassTheme.compliantCyan;
    if (evaluation.isWarning) return GlassTheme.moderateRiskAmber;
    return GlassTheme.textMuted;
  }

  IconData get statusIcon {
    if (evaluation.isCompliant) return CupertinoIcons.checkmark_circle_fill;
    if (evaluation.isWarning) return CupertinoIcons.exclamationmark_triangle_fill;
    if (evaluation.isViolation) return CupertinoIcons.xmark_circle_fill;
    return CupertinoIcons.minus_circle_fill;
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(statusIcon, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evaluation.clause.toUpperCase(),
                    style: const TextStyle(
                      color: GlassTheme.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (evaluation.sourcePanel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      evaluation.sourcePanel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
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
                color: GlassTheme.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
