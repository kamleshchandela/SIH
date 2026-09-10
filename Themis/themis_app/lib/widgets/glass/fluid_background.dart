import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/wallpaper_service.dart';
import '../../theme/glass_theme.dart';

/// An ultra-high-performance dynamic background that renders either a static
/// high-definition crystal / glass wallpaper backdrop with zero idle GPU/CPU cycles,
/// or an animated 3D luminous gradient mesh using native radial shader stops (no heavy ImageFiltered blurs).
class FluidBackground extends StatefulWidget {
  final Widget child;
  final bool animate;

  const FluidBackground({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  State<FluidBackground> createState() => _FluidBackgroundState();
}

class _FluidBackgroundState extends State<FluidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final WallpaperService _wallpaperService = WallpaperService.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    _syncAnimationState();
    _wallpaperService.addListener(_onWallpaperChanged);
  }

  void _syncAnimationState() {
    // ONLY run 60fps animation loop if Dynamic Fluid Mesh is explicitly active!
    // For all static wallpapers (Frosted Glass, Crystal, etc.), keep controller paused at 0% CPU.
    if (_wallpaperService.isMeshSelected && widget.animate) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  void _onWallpaperChanged() {
    _syncAnimationState();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(FluidBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _syncAnimationState();
    }
  }

  @override
  void dispose() {
    _wallpaperService.removeListener(_onWallpaperChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _wallpaperService.mode;
    final isMesh = mode == WallpaperMode.mesh;
    final isImageMode = mode == WallpaperMode.asset || mode == WallpaperMode.custom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Deep Gradient Underlayer
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A091A),
                  Color(0xFF120E2E),
                  Color(0xFF070817),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Static Wallpaper Image (Zero CPU/GPU repaint loop)
        if (isImageMode) ...[
          Positioned.fill(
            child: RepaintBoundary(
              child: _buildWallpaperImage(),
            ),
          ),
          // Optical Glass Scrim (Ensures typography & cards maintain high contrast)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: _wallpaperService.tintOpacity),
            ),
          ),
        ],

        // Luminous Gradient Mesh (Only active in Mesh Mode)
        if (isMesh)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final val = _controller.value;
                final t = val * 2 * math.pi;

                return Stack(
                  children: [
                    // Top-Left Luminous Cyan Orb
                    Positioned(
                      top: -60 + 30 * math.sin(t),
                      left: -40 + 25 * math.cos(t),
                      child: _buildSmoothOrb(
                        size: 300,
                        color: GlassTheme.bgNeonCyan.withValues(alpha: 0.38),
                        secondaryColor: GlassTheme.bgOceanCyan.withValues(alpha: 0.16),
                      ),
                    ),

                    // Top-Right Electric Blue / Indigo Orb
                    Positioned(
                      top: 80 + 40 * math.cos(t * 0.8),
                      right: -70 + 30 * math.sin(t * 0.8),
                      child: _buildSmoothOrb(
                        size: 340,
                        color: GlassTheme.bgElectricBlue.withValues(alpha: 0.35),
                        secondaryColor: GlassTheme.bgViolet.withValues(alpha: 0.20),
                      ),
                    ),

                    // Mid-Left Soft Lilac Glow
                    Positioned(
                      top: 360 + 35 * math.sin(t * 1.2),
                      left: -50 + 20 * math.cos(t * 1.2),
                      child: _buildSmoothOrb(
                        size: 260,
                        color: GlassTheme.bgSoftLilac.withValues(alpha: 0.25),
                        secondaryColor: GlassTheme.bgViolet.withValues(alpha: 0.10),
                      ),
                    ),

                    // Bottom-Right Deep Magenta / Violet Ribbon
                    Positioned(
                      bottom: -50 + 30 * math.cos(t),
                      right: -30 + 25 * math.sin(t),
                      child: _buildSmoothOrb(
                        size: 360,
                        color: GlassTheme.bgViolet.withValues(alpha: 0.30),
                        secondaryColor: GlassTheme.bgOceanCyan.withValues(alpha: 0.12),
                      ),
                    ),

                    // Bottom-Left Cyan Ambient Accent
                    Positioned(
                      bottom: 120 + 25 * math.sin(t * 0.7),
                      left: 20 + 20 * math.cos(t * 0.7),
                      child: _buildSmoothOrb(
                        size: 220,
                        color: GlassTheme.bgNeonCyan.withValues(alpha: 0.18),
                        secondaryColor: Colors.transparent,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        // Foreground Content
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }

  Widget _buildWallpaperImage() {
    final mode = _wallpaperService.mode;
    final path = _wallpaperService.activePath;

    if (mode == WallpaperMode.asset) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // Decode at ~screen width once: BackdropFilter samples this texture
        // every frame, so a 4K decode multiplies compositor cost.
        cacheWidth: 1080,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } else if (mode == WallpaperMode.custom) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 1080,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  /// High-performance native radial gradient orb that requires ZERO GPU blur passes.
  Widget _buildSmoothOrb({
    required double size,
    required Color color,
    required Color secondaryColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            secondaryColor,
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
      ),
    );
  }
}
