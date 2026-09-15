import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

// =============================================================================
// 1. ThemisButton — High-Contrast Accessible Action Target (48dp / 56dp)
// =============================================================================

enum ThemisButtonVariant {
  primaryAmber,
  secondaryOutline,
  dangerCrimson,
}

class ThemisButton extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final VoidCallback? onPressed;
  final ThemisButtonVariant variant;
  final bool isPrimaryCTA;
  final bool isLoading;
  final bool isDark;

  const ThemisButton({
    super.key,
    required this.label,
    this.leadingIcon,
    this.onPressed,
    this.variant = ThemisButtonVariant.primaryAmber,
    this.isPrimaryCTA = false,
    this.isLoading = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = isPrimaryCTA ? ThemisTheme.primaryTouchTarget : ThemisTheme.minTouchTarget;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case ThemisButtonVariant.primaryAmber:
        bg = ThemisTheme.amberPrimary;
        fg = Colors.white;
        break;
      case ThemisButtonVariant.secondaryOutline:
        bg = isDark ? ThemisTheme.darkSlateSurface : ThemisTheme.sunlightSurface;
        fg = isDark ? ThemisTheme.darkSlateTextPrimary : ThemisTheme.sunlightTextPrimary;
        border = BorderSide(
          color: isDark ? ThemisTheme.darkSlateBorderStrong : ThemisTheme.sunlightBorderStrong,
          width: 1.5,
        );
        break;
      case ThemisButtonVariant.dangerCrimson:
        bg = isDark ? ThemisTheme.statusViolationBgDark : ThemisTheme.statusViolationBgLight;
        fg = isDark ? ThemisTheme.statusViolationDark : ThemisTheme.statusViolation;
        border = BorderSide(
          color: isDark ? ThemisTheme.statusViolationDark : ThemisTheme.statusViolation,
          width: 1.5,
        );
        break;
    }

    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(ThemisTheme.radius12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemisTheme.radius12),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  ),
                  const SizedBox(width: ThemisTheme.space12),
                ] else if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 20, color: fg),
                  const SizedBox(width: ThemisTheme.space12),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: ThemisTheme.labelLarge.copyWith(color: fg),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. StatutoryBadge — High-Visibility Status Pill (Icon + Explicit Label)
// =============================================================================

enum StatutoryStatus {
  compliant,
  warning,
  violation,
  notInspected,
}

class StatutoryBadge extends StatelessWidget {
  final StatutoryStatus status;
  final String? customLabel;
  final bool isDark;

  const StatutoryBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    IconData icon;
    String label;

    switch (status) {
      case StatutoryStatus.compliant:
        bg = isDark ? ThemisTheme.statusCompliantBgDark : ThemisTheme.statusCompliantBgLight;
        fg = isDark ? ThemisTheme.statusCompliantDark : ThemisTheme.statusCompliant;
        border = fg.withValues(alpha: 0.4);
        icon = CupertinoIcons.checkmark_seal_fill;
        label = customLabel ?? 'COMPLIANT';
        break;
      case StatutoryStatus.warning:
        bg = isDark ? ThemisTheme.statusWarningBgDark : ThemisTheme.statusWarningBgLight;
        fg = isDark ? ThemisTheme.statusWarningDark : ThemisTheme.statusWarning;
        border = fg.withValues(alpha: 0.4);
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        label = customLabel ?? 'WARNING';
        break;
      case StatutoryStatus.violation:
        bg = isDark ? ThemisTheme.statusViolationBgDark : ThemisTheme.statusViolationBgLight;
        fg = isDark ? ThemisTheme.statusViolationDark : ThemisTheme.statusViolation;
        border = fg.withValues(alpha: 0.4);
        icon = CupertinoIcons.xmark_octagon_fill;
        label = customLabel ?? 'VIOLATION';
        break;
      case StatutoryStatus.notInspected:
        bg = isDark ? ThemisTheme.statusNeutralBgDark : ThemisTheme.statusNeutralBgLight;
        fg = ThemisTheme.statusNeutral;
        border = fg.withValues(alpha: 0.3);
        icon = CupertinoIcons.minus_circle;
        label = customLabel ?? 'NOT INSPECTED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ThemisTheme.space8 + 2,
        vertical: ThemisTheme.space4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ThemisTheme.radius8),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: ThemisTheme.space4 + 2),
          Text(
            label,
            style: ThemisTheme.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. MetricCard — Sunlight-Legible KPI Display
// =============================================================================

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final bool isDark;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? ThemisTheme.darkSlateSurface : ThemisTheme.sunlightSurface;
    final border = isDark ? ThemisTheme.darkSlateBorder : ThemisTheme.sunlightBorder;
    final titleColor = isDark ? ThemisTheme.darkSlateTextSecondary : ThemisTheme.sunlightTextSecondary;
    final valueColor = accentColor ?? (isDark ? ThemisTheme.darkSlateTextPrimary : ThemisTheme.sunlightTextPrimary);
    final subColor = isDark ? ThemisTheme.darkSlateTextMuted : ThemisTheme.sunlightTextMuted;

    return Container(
      padding: const EdgeInsets.all(ThemisTheme.space16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ThemisTheme.radius8),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: ThemisTheme.labelSmall.copyWith(
                    color: titleColor,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: ThemisTheme.space8),
                Icon(icon, size: 18, color: accentColor ?? titleColor),
              ],
            ],
          ),
          const SizedBox(height: ThemisTheme.space8),
          Text(
            value,
            style: ThemisTheme.headlineLarge.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: ThemisTheme.space4),
            Text(
              subtitle!,
              style: ThemisTheme.bodyMedium.copyWith(
                color: subColor,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 4. SectionCard — Flat Structural Content Surface
// =============================================================================

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool isDark;
  final VoidCallback? onTap;
  final BorderSide? borderOverride;

  const SectionCard({
    super.key,
    required this.child,
    this.padding,
    this.isDark = false,
    this.onTap,
    this.borderOverride,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? ThemisTheme.darkSlateSurface : ThemisTheme.sunlightSurface;
    final border = borderOverride ??
        BorderSide(
          color: isDark ? ThemisTheme.darkSlateBorder : ThemisTheme.sunlightBorder,
          width: 1,
        );

    final card = Container(
      padding: padding ?? const EdgeInsets.all(ThemisTheme.space16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ThemisTheme.radius8),
        border: Border.fromBorderSide(border),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ThemisTheme.radius8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThemisTheme.radius8),
          child: card,
        ),
      );
    }

    return card;
  }
}

// =============================================================================
// 5. ThemisAppBar — Departmental Header (Strictly NO State Emblem Replication)
// =============================================================================

class ThemisAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String roleBadge;
  final bool isOffline;
  final List<Widget>? actions;
  final bool isDark;

  const ThemisAppBar({
    super.key,
    this.title = 'THEMIS',
    this.subtitle = 'Directorate of Legal Metrology',
    this.roleBadge = 'INSPECTOR',
    this.isOffline = false,
    this.actions,
    this.isDark = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? ThemisTheme.darkSlateBg : ThemisTheme.sunlightSurface;
    final border = isDark ? ThemisTheme.darkSlateBorder : ThemisTheme.sunlightBorder;
    final titleColor = isDark ? ThemisTheme.darkSlateTextPrimary : ThemisTheme.sunlightTextPrimary;
    final subColor = isDark ? ThemisTheme.darkSlateTextMuted : ThemisTheme.sunlightTextMuted;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space16),
          child: Row(
            children: [
              // Clean Amber Status Indicator
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: ThemisTheme.amberPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: ThemisTheme.space12),

              // Title and Department text (No emblem, strictly typographic)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: ThemisTheme.titleMedium.copyWith(
                            color: titleColor,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: ThemisTheme.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? ThemisTheme.darkSlateSurfaceElevated : ThemisTheme.sunlightSurfaceElevated,
                            borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                            border: Border.all(
                              color: isDark ? ThemisTheme.darkSlateBorder : ThemisTheme.sunlightBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            roleBadge,
                            style: ThemisTheme.labelSmall.copyWith(
                              fontSize: 10,
                              color: ThemisTheme.amberPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: ThemisTheme.space2),
                      Text(
                        subtitle!,
                        style: ThemisTheme.bodyMedium.copyWith(
                          fontSize: 11,
                          color: subColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Network Status Chip (Offline/Online)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOffline
                      ? (isDark ? ThemisTheme.statusWarningBgDark : ThemisTheme.statusWarningBgLight)
                      : (isDark ? ThemisTheme.statusCompliantBgDark : ThemisTheme.statusCompliantBgLight),
                  borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOffline ? ThemisTheme.statusWarning : ThemisTheme.statusCompliant,
                      ),
                    ),
                    const SizedBox(width: ThemisTheme.space4),
                    Text(
                      isOffline ? 'OFFLINE' : 'LOCAL ENGINE',
                      style: ThemisTheme.labelSmall.copyWith(
                        fontSize: 9.5,
                        color: isOffline ? ThemisTheme.statusWarning : ThemisTheme.statusCompliant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              if (actions != null) ...[
                const SizedBox(width: ThemisTheme.space8),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
