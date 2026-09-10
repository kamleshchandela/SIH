import 'package:flutter_test/flutter_test.dart';
import 'package:themis_app/services/wallpaper_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WallpaperService Tests', () {
    test('Presets list contains all 12 curated wallpapers', () {
      expect(WallpaperService.presets.length, equals(12));
      for (final preset in WallpaperService.presets) {
        expect(preset.id.isNotEmpty, isTrue);
        expect(preset.name.isNotEmpty, isTrue);
        expect(preset.assetPath.startsWith('assets/wallpapers/'), isTrue);
        expect(preset.tag.isNotEmpty, isTrue);
      }
    });

    test('Mode changes between Mesh and Presets properly and notifies listeners', () {
      final service = WallpaperService.instance;
      int notifications = 0;
      void listener() => notifications++;

      service.addListener(listener);

      // Set Mesh
      service.setMesh();
      expect(service.mode, equals(WallpaperMode.mesh));
      expect(service.isMeshSelected, isTrue);
      expect(service.activeName, equals('Dynamic Fluid Mesh'));
      expect(notifications, greaterThanOrEqualTo(1));

      // Set Preset
      final samplePreset = WallpaperService.presets.first;
      service.setPreset(samplePreset);
      expect(service.mode, equals(WallpaperMode.asset));
      expect(service.isSelected(samplePreset), isTrue);
      expect(service.activePath, equals(samplePreset.assetPath));
      expect(service.activeName, equals(samplePreset.name));

      // Set Custom
      service.setCustom('/fake/path/art.png', customName: 'My Art');
      expect(service.mode, equals(WallpaperMode.custom));
      expect(service.isCustomSelected, isTrue);
      expect(service.activePath, equals('/fake/path/art.png'));
      expect(service.activeName, equals('My Art'));

      // Set Tint
      service.setTintOpacity(0.5);
      expect(service.tintOpacity, equals(0.5));

      service.removeListener(listener);
    });
  });
}
