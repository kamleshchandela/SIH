import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dev_logger.dart';

/// Helper service to extract bundled demo packaging panel assets
/// to persistent local device storage so on-device OCR and inspection
/// pipelines can execute natively without host file dependencies.
class DemoAssetService {
  DemoAssetService._();
  static final DemoAssetService instance = DemoAssetService._();

  final Map<String, String> _extractedPaths = {};

  /// Ensures a demo asset is unpacked to application storage and returns its absolute path.
  Future<String> ensureDemoAsset(String assetPath, String targetFileName) async {
    if (_extractedPaths.containsKey(targetFileName)) {
      final cached = _extractedPaths[targetFileName]!;
      if (File(cached).existsSync()) return cached;
    }

    try {
      Directory targetDir;
      try {
        final support = await getApplicationSupportDirectory();
        targetDir = Directory('${support.path}/themis_demos');
      } catch (_) {
        final temp = await getTemporaryDirectory();
        targetDir = Directory('${temp.path}/themis_demos');
      }

      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      final targetFile = File('${targetDir.path}/$targetFileName');
      if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
        DevLogger.instance.info('DEMO', 'Unpacking demo asset $assetPath -> ${targetFile.path}...');
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        await targetFile.writeAsBytes(bytes, flush: true);
      }

      _extractedPaths[targetFileName] = targetFile.path;
      return targetFile.path;
    } catch (e) {
      DevLogger.instance.error('DEMO', 'Failed to extract demo asset $assetPath: $e');
      rethrow;
    }
  }

  Future<String> getOatsDemoPath() {
    return ensureDemoAsset('assets/demo/oats_demo.jpg', 'oats_demo.jpg');
  }

  Future<String> getDishwashDemoPath() {
    return ensureDemoAsset('assets/demo/dishwash_demo.jpg', 'dishwash_demo.jpg');
  }

  Future<String> getMaggiDemoPath() {
    return ensureDemoAsset('assets/demo/maggi_demo.jpg', 'maggi_demo.jpg');
  }
}
