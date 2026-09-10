import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import 'glass_container.dart';

/// Floating rounded frosted glass bottom navigation bar inspired directly
/// by the floating pill navigation in neo/redesign/image copy 2.png.
class GlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderRadius: 32,
        // Translucent static: the bar is always on screen, so a live blur
        // here taxes every single frame. Static frosted reads as glass.
        enableBlur: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, CupertinoIcons.viewfinder, 'INSPECT'),
            _buildNavItem(1, CupertinoIcons.doc_text, 'DOSSIER'),
            _buildNavItem(2, CupertinoIcons.chart_bar_alt_fill, 'METRICS'),
            _buildNavItem(3, CupertinoIcons.gear_alt, 'ENGINE'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [GlassTheme.bgOceanCyan, GlassTheme.bgElectricBlue],
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: GlassTheme.bgOceanCyan.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? Colors.white : GlassTheme.textMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
