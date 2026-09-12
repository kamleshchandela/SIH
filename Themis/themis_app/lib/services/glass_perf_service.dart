import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Effective glass quality tier after resolving [GlassMode].
/// Every tier keeps live glass — only sigma changes (blur cost scales with
/// sigma²). If a phone can't handle sigma 2, it can't handle the OCR engine
/// either, so there is no fully-static tier anymore.
enum GlassTier {
  premium,
  high,
  balanced,
  lite,
}

/// User-facing glass quality mode. `auto` resolves from device RAM
/// (Lite on ≤4GB / low-RAM devices, Balanced otherwise); manual tiers
/// always override and are persisted across restarts.
enum GlassMode {
  auto,
  premium,
  high,
  balanced,
  lite,
}

/// Adaptive glass quality singleton — same pattern as [WallpaperService].
///
/// Drives [GlassContainer]: every tier keeps live glass, only sigma changes
/// (Premium 12 / High 8 / Balanced 5 / Lite 2). Notifies listeners so tier
/// switches hot-apply, no restart.
class GlassPerfService extends ChangeNotifier {
  static final GlassPerfService instance = GlassPerfService._internal();

  GlassPerfService._internal() {
    _init();
  }

  static const MethodChannel _channel = MethodChannel('gov.doca.themis/perf');

  /// Devices at or below this total RAM auto-resolve to Lite.
  static const int lowRamThresholdMb = 4096;

  GlassMode _mode = GlassMode.auto;
  GlassTier _autoTier = GlassTier.balanced;
  int? _totalMemMb;

  /// Sober (judge-safe) skin: solid dark surfaces, wallpaper off, no blur
  /// anywhere. Independent of the glass tier — persists across restarts and
  /// hot-applies via the same notifyListeners channel. Defaults ON for now
  /// (demo season); flip it off in Engine settings for full glass.
  bool _soberMode = true;

  GlassMode get mode => _mode;
  int? get totalMemMb => _totalMemMb;
  bool get soberMode => _soberMode;

  /// Live-blur sigma enforced per tier, applied everywhere including pills.
  /// Explicit per-card `blur` values are capped (or floored, for Premium)
  /// to this — see GlassContainer.
  static double sigmaForTier(GlassTier tier) => switch (tier) {
        GlassTier.premium => 12.0,
        GlassTier.high => 8.0,
        GlassTier.balanced => 5.0,
        GlassTier.lite => 2.0,
      };

  GlassTier get tier => switch (_mode) {
        GlassMode.premium => GlassTier.premium,
        GlassMode.high => GlassTier.high,
        GlassMode.balanced => GlassTier.balanced,
        GlassMode.lite => GlassTier.lite,
        GlassMode.auto => _autoTier,
      };

  String get tierLabel => switch (tier) {
        GlassTier.premium => 'Premium',
        GlassTier.high => 'High',
        GlassTier.balanced => 'Balanced',
        GlassTier.lite => 'Lite',
      };

  void setMode(GlassMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    _save();
  }

  void setSoberMode(bool value) {
    if (_soberMode == value) return;
    _soberMode = value;
    notifyListeners();
    _save();
  }

  /// Inspector one-shot unlock: demoted one-shot controls stay hidden until
  /// explicitly enabled in Engine settings behind a warning dialog.
  /// Defaults off; persisted with the rest of the shell config.
  bool _oneShotUnlocked = false;
  bool get oneShotUnlocked => _oneShotUnlocked;

  void setOneShotUnlocked(bool value) {
    if (_oneShotUnlocked == value) return;
    _oneShotUnlocked = value;
    notifyListeners();
    _save();
  }

  Future<void> _init() async {
    await _load();
    await _resolveAuto();
  }

  /// Queries total RAM via the `gov.doca.themis/perf` method channel
  /// (MainActivity.ActivityManager). Falls back to Balanced on any failure
  /// (iOS, desktop, channel missing) — never blocks the UI.
  Future<void> _resolveAuto() async {
    try {
      if (!Platform.isAndroid) return;
      final info = await _channel.invokeMapMethod<String, dynamic>('getMemoryInfo');
      if (info != null) {
        final total = (info['totalMemMb'] as num?)?.toInt();
        final lowRam = info['lowRamDevice'] as bool? ?? false;
        _totalMemMb = total;
        if (lowRam || (total != null && total <= lowRamThresholdMb)) {
          _autoTier = GlassTier.lite;
        } else {
          _autoTier = GlassTier.balanced;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[GlassPerf] auto-tier resolve failed, staying Balanced: $e');
    }
  }

  Future<File?> _configFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/themis_glass_config.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    try {
      final file = await _configFile();
      if (file == null) return;
      await file.writeAsString(jsonEncode(
          {'mode': _mode.name, 'sober': _soberMode, 'oneshot': _oneShotUnlocked}));
    } catch (e) {
      debugPrint('[GlassPerf] Could not persist glass mode: $e');
    }
  }

  Future<void> _load() async {
    try {
      final file = await _configFile();
      if (file != null && await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final modeStr = data['mode'] as String? ?? 'auto';
        _mode = GlassMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => GlassMode.auto,
        );
        _soberMode = data['sober'] as bool? ?? true;
        _oneShotUnlocked = data['oneshot'] as bool? ?? false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[GlassPerf] Could not load glass mode: $e');
    }
  }
}
