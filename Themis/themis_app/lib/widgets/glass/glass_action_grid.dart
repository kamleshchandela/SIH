import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/glass_perf_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/sober_theme.dart';
import 'glass_container.dart';

/// 4-tile bento action grid inspired directly by Screen 1 of neo/redesign/image copy 2.png:
/// One hero electric-gradient card + three frosted glass cards with specular highlights.
class GlassActionGrid extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onBrowseFilesTap;
  final VoidCallback onMultiPanelTap;
  final VoidCallback onSampleTap;

  const GlassActionGrid({
    super.key,
    required this.onCameraTap,
    required this.onBrowseFilesTap,
    required this.onMultiPanelTap,
    required this.onSampleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Tile 1: Hero Cyan-to-Blue Gradient Tile (Camera)
            Expanded(
              child: _HeroActionTile(
                icon: CupertinoIcons.camera_fill,
                title: 'CAMERA SCAN',
                subtitle: 'Field camera capture',
                onTap: onCameraTap,
              ),
            ),
            const SizedBox(width: 12),
            // Tile 2: Frosted Glass Tile (Android Native SAF Document Picker)
            Expanded(
              child: _FrostedActionTile(
                icon: CupertinoIcons.folder_fill_badge_plus,
                title: 'BROWSE FILES',
                subtitle: 'Native SAF picker',
                badgeText: 'CRASH-PROOF',
                onTap: onBrowseFilesTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Tile 3: Multi-Panel SKU Pooling
            Expanded(
              child: _FrostedActionTile(
                icon: CupertinoIcons.square_stack_3d_up_fill,
                title: 'MULTI-PANEL',
                subtitle: 'Cross-panel pooling',
                onTap: onMultiPanelTap,
              ),
            ),
            const SizedBox(width: 12),
            // Tile 4: Ground Truth Demonstration Sample
            Expanded(
              child: _FrostedActionTile(
                icon: CupertinoIcons.sparkles,
                title: 'SAMPLE SKU',
                subtitle: 'Maggi 2-Min audit',
                onTap: onSampleTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vibrant cyan-to-electric-blue gradient hero tile from image copy 2.png
class _HeroActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HeroActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sober: saffron hero gradient (reference red). Glass: cyan-blue.
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) {
        final sober = GlassPerfService.instance.soberMode;
        final start = sober ? const Color(0xFFF08A3C) : const Color(0xFF00F2FE);
        final end = sober ? SoberTheme.accent : const Color(0xFF0072FF);
        return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [start, end],
            ),
            boxShadow: [
              BoxShadow(
                color: end.withValues(alpha: 0.40),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

/// Frosted translucent glass card with subtle line icon and specular border
class _FrostedActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final VoidCallback onTap;

  const _FrostedActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      height: 120,
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              if (badgeText != null)
                ListenableBuilder(
                  listenable: GlassPerfService.instance,
                  builder: (context, _) {
                    final accent = SoberTheme.swap(
                      GlassTheme.bgNeonCyan,
                      GlassPerfService.instance.soberMode,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          color: accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: GlassTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
