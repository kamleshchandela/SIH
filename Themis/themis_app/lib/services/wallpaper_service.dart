import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum WallpaperMode {
  mesh,
  asset,
  custom,
}

class WallpaperPreset {
  final String id;
  final String name;
  final String assetPath;
  final String tag;

  const WallpaperPreset({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.tag,
  });
}

class WallpaperService extends ChangeNotifier {
  static final WallpaperService instance = WallpaperService._internal();

  WallpaperService._internal() {
    _loadPersistedWallpaper();
  }

  static const List<WallpaperPreset> presets = [
    WallpaperPreset(
      id: 'circlecrystal',
      name: 'Circle Crystal',
      assetPath: 'assets/wallpapers/circlecrystal.png',
      tag: 'Orbital Sphere',
    ),
    WallpaperPreset(
      id: 'frostedblue',
      name: 'Frosted Cyan',
      assetPath: 'assets/wallpapers/frostedblue.png',
      tag: 'Fluid Azure',
    ),
    WallpaperPreset(
      id: 'cleancrystal',
      name: 'Clean Crystal',
      assetPath: 'assets/wallpapers/cleancrystal.png',
      tag: 'Geometric Prism',
    ),
    WallpaperPreset(
      id: 'frostedcrystalsunset',
      name: 'Sunset Crystal',
      assetPath: 'assets/wallpapers/frostedcrystalsunset.png',
      tag: 'Warm Violet Aura',
    ),
    WallpaperPreset(
      id: 'frostedglass',
      name: 'Frosted Glass',
      assetPath: 'assets/wallpapers/frostedglass.png',
      tag: 'Matte Diffusion',
    ),
    WallpaperPreset(
      id: 'frostedcrystal',
      name: 'Frosted Crystal',
      assetPath: 'assets/wallpapers/frostedcrystal.png',
      tag: 'Ice Dispersion',
    ),
    WallpaperPreset(
      id: 'frostedice',
      name: 'Frosted Ice',
      assetPath: 'assets/wallpapers/frostedice.png',
      tag: 'Nordic Frost',
    ),
    WallpaperPreset(
      id: 'halfcrystal',
      name: 'Half Crystal',
      assetPath: 'assets/wallpapers/halfcrystal.png',
      tag: 'Specular Facets',
    ),
    WallpaperPreset(
      id: 'leavesbehindglassdark',
      name: 'Leaves Behind Glass',
      assetPath: 'assets/wallpapers/leavesbehindglassdark.png',
      tag: 'Botanical Depth',
    ),
    WallpaperPreset(
      id: 'iphone12',
      name: 'iOS Fluid Wave',
      assetPath: 'assets/wallpapers/iphone12-wallpaper.png',
      tag: 'Curved Ribbon',
    ),
    WallpaperPreset(
      id: 'samsungs5',
      name: 'Geometric Mesh',
      assetPath: 'assets/wallpapers/samsungs5_wallpaper.png',
      tag: 'Polygon Shards',
    ),
    WallpaperPreset(
      id: 'crystalbehindgassmonochrome',
      name: 'Monochrome Crystal',
      assetPath: 'assets/wallpapers/crystalbehindgassmonochrome.png',
      tag: 'Deep Caustics',
    ),
  ];

  WallpaperMode _mode = WallpaperMode.asset;
  String _activePath = 'assets/wallpapers/frostedglass.png';
  String _activeName = 'Frosted Glass';
  double _tintOpacity = 0.32;

  WallpaperMode get mode => _mode;
  String get activePath => _activePath;
  String get activeName => _activeName;
  double get tintOpacity => _tintOpacity;

  bool isSelected(WallpaperPreset preset) {
    return _mode == WallpaperMode.asset && _activePath == preset.assetPath;
  }

  bool get isMeshSelected => _mode == WallpaperMode.mesh;
  bool get isCustomSelected => _mode == WallpaperMode.custom;

  void setMesh() {
    _mode = WallpaperMode.mesh;
    _activePath = '';
    _activeName = 'Dynamic Fluid Mesh';
    notifyListeners();
    _savePersistedWallpaper();
  }

  void setPreset(WallpaperPreset preset) {
    _mode = WallpaperMode.asset;
    _activePath = preset.assetPath;
    _activeName = preset.name;
    notifyListeners();
    _savePersistedWallpaper();
  }

  void setCustom(String filePath, {String? customName}) {
    _mode = WallpaperMode.custom;
    _activePath = filePath;
    _activeName = customName ?? 'Custom Attached Image';
    notifyListeners();
    _savePersistedWallpaper();
  }

  void setTintOpacity(double opacity) {
    _tintOpacity = opacity.clamp(0.0, 0.8);
    notifyListeners();
    _savePersistedWallpaper();
  }

  /// Android Native SAF Document Picker / Desktop File Browser
  Future<bool> pickCustomWallpaper() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (result.isNotEmpty) {
        final rawPath = result.first.path;
        if (rawPath != null && rawPath.isNotEmpty) {
          final originalFile = File(rawPath);
          if (await originalFile.exists()) {
            // Copy to local app documents directory so it stays accessible across sessions
            final docDir = await getApplicationDocumentsDirectory();
            final ext = rawPath.split('.').last;
            final targetPath = '${docDir.path}/active_custom_wallpaper.$ext';
            await originalFile.copy(targetPath);

            final fileName = result.first.name;
            setCustom(targetPath, customName: fileName);
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[WallpaperService] Failed to pick custom wallpaper: $e');
    }
    return false;
  }

  Future<File?> _getConfigFile() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      return File('${docDir.path}/themis_wallpaper_config.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePersistedWallpaper() async {
    try {
      final file = await _getConfigFile();
      if (file == null) return;
      final data = {
        'mode': _mode.name,
        'activePath': _activePath,
        'activeName': _activeName,
        'tintOpacity': _tintOpacity,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[WallpaperService] Could not persist wallpaper state: $e');
    }
  }

  Future<void> _loadPersistedWallpaper() async {
    try {
      final file = await _getConfigFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final modeStr = data['mode'] as String? ?? 'asset';
        _mode = WallpaperMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => WallpaperMode.asset,
        );
        _activePath = data['activePath'] as String? ?? 'assets/wallpapers/frostedglass.png';
        _activeName = data['activeName'] as String? ?? 'Frosted Glass';
        _tintOpacity = (data['tintOpacity'] as num?)?.toDouble() ?? 0.32;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[WallpaperService] Could not load persisted wallpaper: $e');
    }
  }
}
