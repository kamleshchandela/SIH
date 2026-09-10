import 'package:flutter/cupertino.dart';
import '../services/glass_perf_service.dart';
import '../theme/glass_theme.dart';
import '../theme/sober_theme.dart';

class RiskTierBadge extends StatelessWidget {
  final String riskTier;

  const RiskTierBadge({super.key, required this.riskTier});

  Color _statusColor(bool sober) {
    final t = riskTier.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    // Sober: good = green, low = blue (reference palette), never cyan.
    if (t.contains('compliant')) {
      return SoberTheme.swap(GlassTheme.compliantCyan, sober);
    }
    if (t.contains('low')) {
      return SoberTheme.swap(GlassTheme.lowRiskBlue, sober);
    }
    if (t.contains('moderat')) return GlassTheme.moderateRiskAmber;
    if (t.contains('high')) return GlassTheme.highRiskMagenta;
    return GlassTheme.criticalCrimson;
  }

  IconData get statusIcon {
    final t = riskTier.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (t.contains('compliant')) return CupertinoIcons.checkmark_seal_fill;
    if (t.contains('low')) return CupertinoIcons.info_circle_fill;
    if (t.contains('moderat')) return CupertinoIcons.exclamationmark_triangle_fill;
    if (t.contains('high')) return CupertinoIcons.exclamationmark_circle_fill;
    return CupertinoIcons.xmark_shield_fill;
  }

  String get labelText {
    final t = riskTier.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (t.contains('compliant')) return 'COMPLIANT';
    if (t.contains('low')) return 'LOW RISK';
    if (t.contains('moderat')) return 'MODERATE RISK';
    if (t.contains('high')) return 'HIGH RISK';
    return 'CRITICAL RISK';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) {
        final color = _statusColor(GlassPerfService.instance.soberMode);
        return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            labelText,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
