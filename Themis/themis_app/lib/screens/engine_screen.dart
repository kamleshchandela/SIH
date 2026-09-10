import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/glass_perf_service.dart';
import '../services/themis_api.dart';
import '../services/wallpaper_service.dart';
import '../theme/glass_theme.dart';
import '../theme/sober_theme.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/sober/sober_spacer.dart';
import 'dev_logs_screen.dart';

class EngineScreen extends StatefulWidget {
  const EngineScreen({super.key});

  @override
  State<EngineScreen> createState() => _EngineScreenState();
}

class _EngineScreenState extends State<EngineScreen> {
  final ThemisApiService _api = ThemisApiService();
  final WallpaperService _wallpaperService = WallpaperService.instance;
  late final TextEditingController _urlController;

  bool _isChecking = false;
  bool? _isHealthy;
  String _selectedProfile = '5/6 Workers (~83%)';
  late EngineModelOption _selectedModelTier;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  bool get _shouldShowConcurrencyCard {
    if (!_isMobile) {
      // Desktop workstation runs multi-worker rayon threadpool locally or remotely
      return true;
    }
    // On mobile: strictly only show if Remote Server mode is selected AND connected over LAN/WAN
    return _selectedModelTier == EngineModelOption.remoteServer && _isHealthy == true;
  }

  void _onModelTierChanged(EngineModelOption option) {
    setState(() => _selectedModelTier = option);
    _api.setModelOption(option);
  }

  /// Sober brand swap — safe anywhere in this screen: Engine already
  /// rebuilds on every GlassPerfService change (line 33 listener).
  Color _acc(Color c) =>
      SoberTheme.swap(c, GlassPerfService.instance.soberMode);

  @override
  void initState() {
    super.initState();
    _selectedModelTier = _api.modelOption;
    _urlController = TextEditingController(text: _api.baseUrl);
    _wallpaperService.addListener(_onWallpaperUpdated);
    GlassPerfService.instance.addListener(_onWallpaperUpdated);
    _testConnection();
  }

  void _onWallpaperUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _wallpaperService.removeListener(_onWallpaperUpdated);
    GlassPerfService.instance.removeListener(_onWallpaperUpdated);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isChecking = true);
    _api.updateBaseUrl(_urlController.text.trim());
    final healthy = await _api.checkHealth();
    setState(() {
      _isHealthy = healthy;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'THEMIS // SYSTEM & BACKDROP CONFIG',
                style: TextStyle(
                  color: GlassTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Settings & Engine',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // SECTION 1: WALLPAPER & GLASS BACKDROP
              // ==========================================
              _buildWallpaperSection(),

              const SizedBox(height: 18),

              // ==========================================
              // SECTION 1B: GLASS QUALITY (PERF TIERS)
              // ==========================================
              _buildGlassQualityCard(),

              const SizedBox(height: 18),

              // ==========================================
              // SECTION 1C: SOBER MODE (JUDGE-SAFE SKIN)
              // ==========================================
              _buildSoberModeCard(),

              const SizedBox(height: 18),

              // ==========================================
              // SECTION 2: AI VISION MODEL TIER
              // ==========================================
              _buildModelTierCard(),

              const SizedBox(height: 18),

              // ==========================================
              // SECTION 3: BACKEND DAEMON HOST (LAN/WAN)
              // ==========================================
              _buildDaemonHostCard(),

              if (_shouldShowConcurrencyCard) ...[
                const SizedBox(height: 18),
                // ==========================================
                // SECTION 4: HARDWARE CONCURRENCY PROFILE
                // ==========================================
                _buildConcurrencyCard(),
              ] else if (_isMobile && _selectedModelTier == EngineModelOption.remoteServer) ...[
                const SizedBox(height: 18),
                _buildRemoteDisconnectedNotice(),
              ],

              const SizedBox(height: 18),

              // ==========================================
              // SECTION 5: DIAGNOSTICS & TELEMETRY
              // ==========================================
              _buildDiagnosticsCard(),

              const SizedBox(height: 18),

              // ==========================================
              // SECTION 6: INSPECTOR PROFILE
              // ==========================================
              _buildInspectorProfileCard(),

              SoberBottomSpacer(glassHeight: 100), // Space for floating bottom nav
            ],
          ),
        ),
      ),
    );
  }

  // --- WALLPAPER SELECTOR SECTION ---

  Widget _buildWallpaperSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.sparkles, size: 16, color: _acc(GlassTheme.bgNeonCyan)),
                  SizedBox(width: 8),
                  Text(
                    'WALLPAPER & GLASS BACKDROP',
                    style: TextStyle(
                      color: GlassTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.35)),
                ),
                child: Text(
                  _wallpaperService.activeName,
                  style: TextStyle(
                    color: _acc(GlassTheme.bgNeonCyan),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a crystal backdrop or attach custom art to shine beneath the frosted refraction layer.',
            style: TextStyle(color: GlassTheme.textMuted, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 16),

          // Attachment Button: Native SAF file picker
          GestureDetector(
            onTap: () async {
              final ok = await _wallpaperService.pickCustomWallpaper();
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom wallpaper applied successfully!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x3300F2FE), Color(0x220072FF)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.paperclip, color: _acc(GlassTheme.bgNeonCyan), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '+ Attach Any Image (Native SAF)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select PNG, JPG, or WebP from storage (bypasses gallery issues)',
                          style: TextStyle(color: GlassTheme.textMuted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  if (_wallpaperService.isCustomSelected)
                    Icon(CupertinoIcons.checkmark_seal_fill, color: _acc(GlassTheme.bgNeonCyan), size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Horizontal Carousel of Presets
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                // Preset 0: Dynamic Fluid Mesh
                _buildDynamicMeshCard(),

                // Presets 1..N: Bundled Wallpapers
                ...WallpaperService.presets.map((preset) => _buildPresetThumbnailCard(preset)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tint Scrim Opacity Slider
          Row(
            children: [
              const Icon(CupertinoIcons.sun_min, size: 14, color: GlassTheme.textMuted),
              const SizedBox(width: 8),
              const Text(
                'Glass Scrim Tint:',
                style: TextStyle(color: GlassTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _acc(GlassTheme.bgNeonCyan),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _wallpaperService.tintOpacity,
                    min: 0.10,
                    max: 0.65,
                    onChanged: (val) {
                      _wallpaperService.setTintOpacity(val);
                    },
                  ),
                ),
              ),
              Text(
                '${(_wallpaperService.tintOpacity * 100).toInt()}%',
                style: const TextStyle(
                  color: GlassTheme.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicMeshCard() {
    final isSelected = _wallpaperService.isMeshSelected;

    return GestureDetector(
      onTap: () => _wallpaperService.setMesh(),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _acc(GlassTheme.bgNeonCyan) : Colors.white.withValues(alpha: 0.18),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dynamic Gradient Swatch
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00F2FE),
                      Color(0xFF0072FF),
                      Color(0xFF7F00FF),
                      Color(0xFFE0C3FC),
                    ],
                  ),
                ),
              ),
              Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSelected)
                      const Align(
                        alignment: Alignment.topRight,
                        child: Icon(CupertinoIcons.checkmark_circle_fill, size: 16, color: Colors.white),
                      )
                    else
                      const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Dynamic',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Fluid Mesh',
                          style: TextStyle(color: Colors.white70, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetThumbnailCard(WallpaperPreset preset) {
    final isSelected = _wallpaperService.isSelected(preset);

    return GestureDetector(
      onTap: () => _wallpaperService.setPreset(preset),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _acc(GlassTheme.bgNeonCyan) : Colors.white.withValues(alpha: 0.18),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                preset.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF1B143F)),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC05060F)],
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSelected)
                      Align(
                        alignment: Alignment.topRight,
                        child: Icon(CupertinoIcons.checkmark_circle_fill, size: 16, color: _acc(GlassTheme.bgNeonCyan)),
                      )
                    else
                      const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          preset.tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: GlassTheme.textMuted, fontSize: 8.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- GLASS QUALITY CARD (ADAPTIVE PERF TIERS) ---

  Widget _buildGlassQualityCard() {
    final perf = GlassPerfService.instance;
    final isSober = perf.soberMode;
    final resolved = perf.tierLabel;
    final mem = perf.totalMemMb;

    final cardContent = GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GLASS QUALITY',
                style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSober
                      ? Colors.white.withValues(alpha: 0.08)
                      : _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSober
                        ? Colors.white.withValues(alpha: 0.18)
                        : _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isSober
                      ? 'Disabled in Sober Mode'
                      : (mem != null ? '$resolved • ${(mem / 1024).toStringAsFixed(1)}GB' : resolved),
                  style: TextStyle(
                    color: isSober ? Colors.white60 : _acc(GlassTheme.bgNeonCyan),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isSober
                ? 'Sober Mode uses solid high-contrast surfaces without GPU backdrop blur shaders. Turn off Sober Mode to configure live glass quality tiers.'
                : 'Live backdrop blur is GPU-expensive (cost scales with sigma²). Every tier keeps live glass — only sigma changes. Auto picks Lite on ≤4GB devices; manual override applies instantly, no restart.',
            style: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _buildGlassOption(
            GlassMode.auto,
            'Auto (Active: $resolved)',
            'RAM-aware default — Balanced, or Lite on low-memory devices',
            enabled: !isSober,
          ),
          _buildGlassOption(
            GlassMode.premium,
            'Premium',
            'Sigma 12 everywhere — flagships & desktop',
            enabled: !isSober,
          ),
          _buildGlassOption(
            GlassMode.high,
            'High',
            'Sigma 8 everywhere — smooth on most field phones',
            enabled: !isSober,
          ),
          _buildGlassOption(
            GlassMode.balanced,
            'Balanced',
            'Sigma 5 everywhere — the everyday sweet spot',
            enabled: !isSober,
          ),
          _buildGlassOption(
            GlassMode.lite,
            'Lite',
            'Sigma 2 everywhere — max fps & battery',
            enabled: !isSober,
          ),
        ],
      ),
    );

    if (isSober) {
      return Opacity(
        opacity: 0.40,
        child: IgnorePointer(
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  Widget _buildGlassOption(GlassMode mode, String title, String subtitle, {bool enabled = true}) {
    final perf = GlassPerfService.instance;
    final isSelected = perf.mode == mode;
    return GestureDetector(
      onTap: enabled ? () => perf.setMode(mode) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (isSelected && enabled) ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (isSelected && enabled) ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              size: 16,
              color: (isSelected && enabled) ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SOBER MODE CARD (JUDGE-SAFE SKIN) ---

  /// One-tap alternate skin for conservative judging panels / outdoor field
  /// readability: solid dark surfaces, wallpaper off, notched nav + docked
  /// scan FAB, pin-timeline checklist, saffron fee badges. Zero blur, so it
  /// holds 60fps on any device with no tier involved. Selling line:
  /// "high-contrast field mode for outdoor readability".
  Widget _buildSoberModeCard() {
    final perf = GlassPerfService.instance;
    final sober = perf.soberMode;
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SOBER MODE',
                style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Switch.adaptive(
                value: sober,
                activeThumbColor: const Color(0xFFE8762B),
                onChanged: (v) => perf.setSoberMode(v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sober ? 'Active — solid judge-safe skin, no blur anywhere.' : 'Off — full glassmorphism theme.',
            style: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Swaps wallpaper for flat dark, nav for the notched bar with docked scan button, clauses for the pin timeline, and fines for saffron badges. Applies instantly, survives restart.',
            style: TextStyle(color: GlassTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- DAEMON HOST CARD ---

  Widget _buildDaemonHostCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'INSPECTION DAEMON HOST',
                style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isHealthy == true
                          ? GlassTheme.compliantCyan
                          : _isHealthy == false
                              ? GlassTheme.criticalCrimson
                              : GlassTheme.moderateRiskAmber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isHealthy == true
                                  ? GlassTheme.compliantCyan
                                  : _isHealthy == false
                                      ? GlassTheme.criticalCrimson
                                      : GlassTheme.moderateRiskAmber)
                              .withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isChecking
                        ? 'Pinging...'
                        : _isHealthy == true
                            ? 'ONLINE (CPU)'
                            : 'OFFLINE',
                    style: TextStyle(
                      color: _isHealthy == true ? GlassTheme.compliantCyan : GlassTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'http://localhost:8080',
                hintStyle: TextStyle(color: GlassTheme.textDim, fontSize: 13),
              ),
              onSubmitted: (_) => _testConnection(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildHostChip('USB ADB (localhost)', 'http://localhost:8080'),
              _buildHostChip('LAN WiFi (192.168.1.92)', 'http://192.168.1.92:8080'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'For USB adb testing: adb reverse tcp:8080 tcp:8080',
                  style: TextStyle(color: GlassTheme.textMuted, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _testConnection,
                icon: Icon(CupertinoIcons.bolt_fill, size: 12, color: _acc(GlassTheme.bgNeonCyan)),
                label: const Text(
                  'Connect / Test',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostChip(String label, String url) {
    final isActive = _urlController.text.trim() == url;
    return GestureDetector(
      onTap: () {
        setState(() {
          _urlController.text = url;
        });
        _testConnection();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? _acc(GlassTheme.bgNeonCyan) : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // --- HARDWARE CONCURRENCY CARD ---

  Widget _buildConcurrencyCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HARDWARE CONCURRENCY PROFILE',
            style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Controls multi-threaded batch inspection pooling across host CPU cores.',
            style: TextStyle(color: GlassTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _buildRadioOption('5/6 Workers (~83%)', 'Recommended for desktop & server audit'),
          _buildRadioOption('Full Power (100%)', 'Dedicated server execution'),
          _buildRadioOption('1/2 Workers (50%)', 'Thermal-throttled edge laptops'),
          _buildRadioOption('Single Thread (1.0)', 'Deterministic step-by-step debug'),
        ],
      ),
    );
  }

  // --- MODEL TIER CARD ---

  Widget _buildModelTierCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI VISION MODEL TIER',
                style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.35)),
                ),
                child: Text(
                  _selectedModelTier == EngineModelOption.mobileCompactInt8
                      ? 'NATIVE (COMPACT)'
                      : _selectedModelTier == EngineModelOption.mobileAccurateInt8
                          ? 'NATIVE (ACCURATE)'
                          : 'REMOTE (LAN/WAN)',
                  style: TextStyle(
                    color: _acc(GlassTheme.bgNeonCyan),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select on-device native edge neural network or remote LAN/WAN server backend.',
            style: TextStyle(color: GlassTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Option 1: Smaller / Fast (Mobile Native)
          _buildModelTierOption(
            option: EngineModelOption.mobileCompactInt8,
            title: '1. Mobile Native Fast (Compact INT8 • ~3.1 MB)',
            badge: 'EDGE NATIVE • OFFLINE',
            subtitle: 'Ultra-lightweight MobileNetV3 / PP-OCRv3 INT8 on-device detector & recognizer. Sub-400ms latency, zero data transfer, 100% offline in basement godowns.',
            executionType: 'Device ARM NEON • Zero Network',
          ),

          // Option 2: Bigger / High Accuracy (Mobile Native)
          _buildModelTierOption(
            option: EngineModelOption.mobileAccurateInt8,
            title: '2. Mobile Native High-Accuracy (Accurate INT8 • ~27.3 MB)',
            badge: 'EDGE NATIVE • HIGH RECALL',
            subtitle: 'High-capacity DBNet + SVTR / PP-OCRv4 INT8 model executed natively on phone NPU / NNAPI. Maximum recall on curved bottles and faint dot-matrix dates.',
            executionType: 'Device NPU / NNAPI • Zero Network',
          ),

          // Option 3: Server one (Remote LAN/WAN)
          _buildModelTierOption(
            option: EngineModelOption.remoteServer,
            title: '3. Remote Themis Server (LAN / WAN Daemon)',
            badge: 'REMOTE WORKSTATION • MULTI-CORE',
            subtitle: 'Delegates inference over LAN/WAN Wi-Fi to central Rust backend. Full FP32 precision, multi-worker thread pooling, and high-throughput batch audits.',
            executionType: 'Rust Axum Daemon • LAN / WAN',
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteDisconnectedNotice() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        children: [
          Icon(CupertinoIcons.wifi_slash, size: 20, color: GlassTheme.moderateRiskAmber),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Hardware concurrency profiling is managed on the host daemon. Connect to your LAN/WAN server to view and configure worker allocation.',
              style: TextStyle(color: GlassTheme.textMuted, fontSize: 11.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // --- DIAGNOSTICS CARD ---

  Widget _buildDiagnosticsCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DIAGNOSTICS & TELEMETRY',
                style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Icon(CupertinoIcons.chevron_left_slash_chevron_right, color: _acc(GlassTheme.bgNeonCyan), size: 16),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Live execution traces, ONNX model pipeline logs, HTTP network traces, and clipboard export.',
            style: TextStyle(color: GlassTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevLogsScreen()),
                );
              },
              icon: const Icon(CupertinoIcons.chevron_left_slash_chevron_right, size: 14, color: Colors.black),
              label: const Text(
                'Open Developer Logs Console',
                style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- INSPECTOR PROFILE CARD ---

  Widget _buildInspectorProfileCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x3300F2FE), Color(0x330072FF)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.4)),
            ),
            child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'INSPECTOR ID: #DOCA-2026-894',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Role: Directorate Enforcement Officer',
                  style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11),
                ),
                SizedBox(height: 2),
                Text(
                  'HMAC-SHA256 JWT Authenticated',
                  style: TextStyle(
                    color: GlassTheme.compliantCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String title, String subtitle) {
    final isSelected = _selectedProfile == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedProfile = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              size: 16,
              color: isSelected ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelTierOption({
    required EngineModelOption option,
    required String title,
    required String badge,
    required String subtitle,
    required String executionType,
  }) {
    final isSelected = _selectedModelTier == option;
    return GestureDetector(
      onTap: () => _onModelTierChanged(option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                  size: 18,
                  color: isSelected ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: isSelected ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textMuted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle,
                style: const TextStyle(color: GlassTheme.textMuted, fontSize: 11.5, height: 1.3),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                children: [
                  Icon(
                    option == EngineModelOption.remoteServer
                        ? CupertinoIcons.wifi
                        : Icons.memory,
                    size: 13,
                    color: isSelected ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textDim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    executionType,
                    style: TextStyle(
                      color: isSelected ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textDim,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
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
