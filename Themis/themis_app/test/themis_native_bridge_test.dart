import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:themis_app/services/themis_api.dart';
import 'package:themis_app/services/themis_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemisNativeBridge (Path A Native FFI)', () {
    test('Native platform support flag is true on host', () {
      expect(ThemisNativeBridge.instance.isSupportedPlatform, isTrue);
    });

    test('themis_ping() returns true via FFI', () {
      final pingOk = ThemisNativeBridge.instance.ping();
      expect(pingOk, isTrue);
    });

    test('Models directory resolution detects local models', () async {
      final modelsDir = await ThemisNativeBridge.instance.ensureModelsReady();
      expect(Directory(modelsDir).existsSync(), isTrue);
      expect(File('$modelsDir/ppocr_det_int8.onnx').existsSync(), isTrue);
      expect(File('$modelsDir/en_ppocr_v3_rec_int8.onnx').existsSync(), isTrue);
    });

    test('themis_scan_sku executes in background isolate and parses ComplianceReport', () async {
      final sampleImagePath = '/home/arch/Projects/backbone/dataset/real_products/3948764042911_thums_up/front.jpg';
      if (!File(sampleImagePath).existsSync()) {
        // Skip if running in environment without sample image
        return;
      }

      final report = await ThemisNativeBridge.instance.scanSku(
        panelImagePaths: [sampleImagePath],
        productName: 'Thums Up 750ml PET',
        modelOption: EngineModelOption.mobileCompactInt8,
      );

      expect(report.inspectionId.isNotEmpty, isTrue);
      expect(report.complianceScorePct, isNotNull);
      expect(report.evaluations.isNotEmpty, isTrue);
      expect(report.rawOcrTokens.isNotEmpty, isTrue);
      expect(report.scannedPanels.contains('front.jpg'), isTrue);
    });

    test('ThemisApiService checkHealth() uses native ping when in mobile compact mode', () async {
      final api = ThemisApiService();
      api.setModelOption(EngineModelOption.mobileCompactInt8);
      final healthy = await api.checkHealth();
      expect(healthy, isTrue);
    });
  });
}
