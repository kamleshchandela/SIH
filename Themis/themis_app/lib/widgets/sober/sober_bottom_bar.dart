import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/sober_theme.dart';

/// Sober bottom navigation, faithful to the reference Dashboard: a plain
/// solid rounded bar with four icon-only slots — no notch, no docked FAB,
/// no labels. Scan actions live in the dashboard's mini action row instead.
class SoberBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onSearchTap;

  const SoberBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      height: 72,
      decoration: BoxDecoration(
        color: SoberTheme.barBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SoberTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildItem(0, CupertinoIcons.house_fill),
          _buildItem(1, CupertinoIcons.calendar),
          _buildCenterSearchButton(),
          _buildItem(2, CupertinoIcons.folder_fill),
          _buildItem(3, CupertinoIcons.gear_alt_fill),
        ],
      ),
    );
  }

  Widget _buildCenterSearchButton() {
    return GestureDetector(
      onTap: onSearchTap ?? () => onTap(1),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF232A3B),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.search,
            size: 21,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, IconData icon) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(
          icon,
          size: 23,
          color: isSelected ? Colors.white : const Color(0xFF8B93A7),
        ),
      ),
    );
  }
}
