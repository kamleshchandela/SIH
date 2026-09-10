import 'package:flutter/material.dart';
import '../../theme/sober_theme.dart';

/// Sober fee/penalty badge (reference: the $2,100 Bali price tag).
///
/// Looks like a custom clip path — it is one line:
/// `BorderRadius.only(topLeft: 20, bottomRight: 20)` on a saffron container
/// pinned to the top-left of its card.
class SoberBadge extends StatelessWidget {
  final String amount;
  final String caption;

  const SoberBadge({
    super.key,
    required this.amount,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: SoberTheme.accent,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid dark card helper for explicit sober-only surfaces.
/// (Most screens get this for free via [GlassContainer]'s sober path.)
class SoberCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const SoberCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: SoberTheme.card,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: SoberTheme.cardBorder, width: 1),
        ),
        child: child,
      ),
    );
  }
}
