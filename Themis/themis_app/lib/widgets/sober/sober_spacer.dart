import 'package:flutter/material.dart';
import '../../services/glass_perf_service.dart';

/// Bottom clearance above the nav bar. The sober notched bar (118 + safe
/// area) is taller than the floating glass pill, so sober mode needs ~160px
/// of clearance instead of ~90. Listens for toggles; zero cost otherwise.
class SoberBottomSpacer extends StatelessWidget {
  final double glassHeight;

  const SoberBottomSpacer({super.key, this.glassHeight = 90});

  static double clearanceOf(bool sober, double glassHeight) =>
      sober ? 160 : glassHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) => SizedBox(
        height: clearanceOf(
          GlassPerfService.instance.soberMode,
          glassHeight,
        ),
      ),
    );
  }
}
