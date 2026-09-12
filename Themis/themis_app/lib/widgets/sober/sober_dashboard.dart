import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/audit_storage_service.dart';
import '../../services/glass_perf_service.dart';
import '../../services/themis_api.dart';
import '../../theme/sober_theme.dart';

/// Sober dashboard header — faithful to reference screen 1 (Dashboard):
/// avatar + centered title + hamburger, overline + big count, vertical
/// category rail, asymmetric snap cards with corner badges, people row,
/// and the four scan actions shrunk to mini icons.
///
/// Cards read the dossier registry (fine = badge, risk = art). With no
/// backend/history they fall back to entry cards (Sample / New Scan), so
/// the layout never looks broken offline.
class SoberDashboard extends StatefulWidget {
  final VoidCallback onCamera;
  final VoidCallback onBrowseFiles;
  final VoidCallback onMultiPanel;
  final VoidCallback onSample;
  final VoidCallback? onLoadOats;
  final VoidCallback? onLoadDishwash;
  final VoidCallback? onLoadMaggi;
  final VoidCallback? onSearchTap;
  final ValueChanged<int>? onOpenTab;
  final String? latestInspectionId;
  final List<String> sessionPanels;

  const SoberDashboard({
    super.key,
    required this.onCamera,
    required this.onBrowseFiles,
    required this.onMultiPanel,
    required this.onSample,
    this.onLoadOats,
    this.onLoadDishwash,
    this.onLoadMaggi,
    this.onSearchTap,
    this.onOpenTab,
    this.latestInspectionId,
    this.sessionPanels = const [],
  });

  @override
  State<SoberDashboard> createState() => _SoberDashboardState();
}

class _SoberDashboardState extends State<SoberDashboard> {
  final ThemisApiService _api = ThemisApiService();
  final PageController _cardsController = PageController(viewportFraction: 0.66);

  List<Map<String, dynamic>> _history = [];
  String _railFilter = 'All';

  @override
  void initState() {
    super.initState();
    AuditStorageService.instance.addListener(_onStorageUpdated);
    _fetch();
  }

  void _onStorageUpdated() {
    if (mounted) _fetch();
  }

  @override
  void didUpdateWidget(covariant SoberDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A completed audit refreshes the cards/count without leaving Inspect.
    if (oldWidget.latestInspectionId != widget.latestInspectionId) _fetch();
  }

  @override
  void dispose() {
    AuditStorageService.instance.removeListener(_onStorageUpdated);
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final items = await _api.fetchInspections();
      if (mounted) setState(() => _history = items);
    } catch (_) {
      // Offline / backend down: entry cards carry the layout.
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_railFilter == 'All') return _history;
    return _history.where((h) {
      final risk = (h['risk_tier'] as String? ?? '').toLowerCase();
      if (_railFilter == 'Critical') {
        return risk.contains('critical') || risk.contains('severe') || risk.contains('high');
      }
      return risk.contains('moderate') || risk.contains('medium');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const ff = SoberTheme.fontFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Top bar: seal avatar | Dashboard | hamburger ---
        Row(
          children: [
            _SealAvatar(onTap: () => widget.onOpenTab?.call(3)),
            const Expanded(
              child: Center(
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    fontFamily: ff,
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _HamburgerButton(onTap: () => widget.onOpenTab?.call(3)),
          ],
        ),
        const SizedBox(height: 18),

        // --- Overline + big count + pin shortcut ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Legal Metrology',
                    style: TextStyle(
                      fontFamily: ff,
                      color: SoberTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_history.length} audits',
                    style: const TextStyle(
                      fontFamily: ff,
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => widget.onOpenTab?.call(1),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SoberTheme.inset,
                  border: Border.all(color: SoberTheme.cardBorder),
                ),
                child: const Icon(
                  CupertinoIcons.location_solid,
                  color: SoberTheme.accent,
                  size: 19,
                ),
              ),
            ),
          ],
        ),
        if (widget.onSearchTap != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.onSearchTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: SoberTheme.inset,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SoberTheme.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.search, color: SoberTheme.accent, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    'Search audit registry, SKUs, rules...',
                    style: const TextStyle(
                      fontFamily: SoberTheme.fontFamily,
                      color: SoberTheme.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // --- Rail + snap cards ---
        SizedBox(
          height: 248,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategoryRail(
                active: _railFilter,
                onSelect: (v) => setState(() => _railFilter = v),
              ),
              Expanded(child: _buildCards()),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // --- Mini scan actions (one-shot bypass surface: hidden until the
        // Inspector quick scan unlock in Engine settings) ---
        ListenableBuilder(
          listenable: GlassPerfService.instance,
          builder: (context, _) {
            if (!GlassPerfService.instance.oneShotUnlocked) {
              return const SizedBox.shrink();
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniAction(
                  icon: CupertinoIcons.camera_fill,
                  label: 'SCAN',
                  onTap: widget.onCamera,
                ),
                _MiniAction(
                  icon: CupertinoIcons.folder_fill,
                  label: 'FILES',
                  onTap: widget.onBrowseFiles,
                ),
                _MiniAction(
                  icon: CupertinoIcons.square_stack_3d_up_fill,
                  label: 'MULTI',
                  onTap: widget.onMultiPanel,
                ),
                _MiniAction(
                  icon: CupertinoIcons.sparkles,
                  label: 'SAMPLE',
                  onTap: widget.onLoadDishwash ?? widget.onSample,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCards() {
    final items = _filtered;
    if (items.isEmpty) return _buildEntryCards();
    return PageView.builder(
      controller: _cardsController,
      padEnds: false,
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final h = items[i];
        final name = h['product_name'] as String? ?? 'Pre-packaged Commodity';
        final fine = h['compounding_fine_inr'] ?? 0;
        final risk = h['risk_tier'] as String? ?? '';
        final rl = risk.toLowerCase();
        final isGood = rl.contains('compliant');
        final badgeColor = isGood ? SoberTheme.pinGreen : SoberTheme.pinRed;
        final art = isGood
            ? const [Color(0xFF1E5C46), Color(0xFF0F2E24)]
            : const [Color(0xFF7A2E1D), Color(0xFF2E140F)];
        final photo = _resolvePanelImage(h);
        return _PlaceCard(
          title: name,
          subtitle: _shortId(h['inspection_id'] as String? ?? ''),
          badge: '₹$fine',
          badgeColor: badgeColor,
          art: art,
          artIcon: isGood
              ? CupertinoIcons.checkmark_seal_fill
              : CupertinoIcons.exclamationmark_octagon_fill,
          imageAsset: photo.asset,
          imageFile: photo.file,
          onTap: () => widget.onOpenTab?.call(1),
        );
      },
    );
  }

  /// Two curated demo cards: Saffola Oats and SaveMore Dishwash
  Widget _buildEntryCards() {
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      children: [
        _PlaceCard(
          title: 'Saffola Oats',
          subtitle: '400g Pouch • Rule 7',
          badge: '₹185',
          badgeColor: SoberTheme.accent,
          imageAsset: 'assets/demo/oats_demo.jpg',
          onTap: widget.onLoadOats ?? widget.onSample,
        ),
        _PlaceCard(
          title: 'SaveMore Dishwash',
          subtitle: '500ml Bottle • LMPC',
          badge: '₹99',
          badgeColor: SoberTheme.pinGreen,
          imageAsset: 'assets/demo/dishwash_demo.jpg',
          onTap: widget.onLoadDishwash ?? widget.onSample,
        ),
      ],
    );
  }

  /// Resolves a history item's card photo: bundled demo asset by name match,
  /// else the scanned panel file if it still exists on disk. Returns
  /// (null, null) when no photo survives — the card falls back to gradient.
  /// (Cleared app data wipes panel files, which is why post-clear scans can
  /// render photo-less until a panel-bearing audit lands.)
  ({String? asset, String? file}) _resolvePanelImage(
      Map<String, dynamic> h) {
    final name = (h['product_name'] as String? ?? '').toLowerCase();
    final panels = (h['scanned_panels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final first = panels.isNotEmpty ? panels.first : '';
    if (first.contains('oats_demo.jpg') || name.contains('oats')) {
      return (asset: 'assets/demo/oats_demo.jpg', file: null);
    }
    if (first.contains('dishwash_demo.jpg') || name.contains('dishwash')) {
      return (asset: 'assets/demo/dishwash_demo.jpg', file: null);
    }
    if (first.contains('maggi_demo.jpg') || name.contains('maggi')) {
      return (asset: 'assets/demo/maggi_demo.jpg', file: null);
    }
    if (first.isNotEmpty && File(first).existsSync()) {
      return (asset: null, file: first);
    }
    return (asset: null, file: null);
  }

  String _shortId(String id) {
    if (id.isEmpty) return 'No records yet';
    return id.length > 18 ? '${id.substring(0, 18)}…' : id;
  }
}

/// Vertical category rail (reference: Cycling / Mountain / Popular).
/// Filters the snap cards by risk tier — decorative nowhere.
class _CategoryRail extends StatelessWidget {
  final String active;
  final ValueChanged<String> onSelect;

  const _CategoryRail({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = ['All', 'Critical', 'Moderate'];
    return SizedBox(
      width: 36,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.map((label) {
            final selected = label == active;
            return GestureDetector(
              onTap: () => onSelect(label),
              behavior: HitTestBehavior.opaque,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: SoberTheme.fontFamily,
                    color: selected ? Colors.white : SoberTheme.iconDim,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Asymmetric snap card (reference: Bali / Lahore): photo/gradient art with
/// a floating rounded badge in the top-left and the title overlaid bottom-left.
class _PlaceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final List<Color>? art;
  final IconData? artIcon;
  final String? imageAsset;
  /// Device-local panel photo (checked for existence at build time).
  /// Precedence: asset → file → gradient + watermark icon (never blank).
  final String? imageFile;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    this.art,
    this.artIcon,
    this.imageAsset,
    this.imageFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile =
        imageFile != null && File(imageFile!).existsSync();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 172,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: (imageAsset == null && !hasFile)
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: art ?? const [Color(0xFF1E2433), Color(0xFF0F141E)],
                )
              : null,
          border: Border.all(color: SoberTheme.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset!,
                fit: BoxFit.cover,
              )
            else if (hasFile)
              Image.file(
                File(imageFile!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              )
            else if (artIcon != null)
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(
                  artIcon,
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),

            // Subtle dark overlay to ensure high-contrast legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Top-left floating rounded rectangle badge (matching reference image)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.40),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontFamily: SoberTheme.fontFamily,
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            // Bottom title & subtitle
            Positioned(
              left: 14,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: SoberTheme.fontFamily,
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: SoberTheme.fontFamily,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontFamilyFallback: const ['monospace'],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini scan action: 48px circle + micro label. The old bento tiles,
/// shrunk under the cards per the reference's compact language.
class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SoberTheme.inset,
              border: Border.all(color: SoberTheme.cardBorder),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: SoberTheme.fontFamily,
              color: SoberTheme.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seal avatar with presence dot (reference: photo avatar + online dot).
class _SealAvatar extends StatelessWidget {
  final VoidCallback onTap;

  const _SealAvatar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF08A3C), SoberTheme.accent],
              ),
            ),
            child: const Icon(
              CupertinoIcons.shield_fill,
              color: Colors.white,
              size: 19,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SoberTheme.pinGreen,
                border: Border.all(color: SoberTheme.pageBg, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hamburger with short middle bar, as in the reference.
class _HamburgerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HamburgerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
                width: 20, height: 2.2,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1))),
            const SizedBox(height: 5),
            Container(
                width: 13, height: 2.2,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1))),
            const SizedBox(height: 5),
            Container(
                width: 20, height: 2.2,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1))),
          ],
        ),
      ),
    );
  }
}
