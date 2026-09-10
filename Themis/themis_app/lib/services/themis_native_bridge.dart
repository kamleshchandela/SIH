import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/compliance_report.dart';
import 'dev_logger.dart';
import 'themis_api.dart';

// Native C function typedefs
typedef _ThemisPingC = Int32 Function();
typedef _ThemisPingDart = int Function();

typedef _ThemisScanSkuC = Pointer<Utf8> Function(
  Pointer<Utf8> modelsDir,
  Pointer<Utf8> tier,
  Pointer<Utf8> imagesJson,
  Pointer<Utf8> productName,
);
typedef _ThemisScanSkuDart = Pointer<Utf8> Function(
  Pointer<Utf8> modelsDir,
  Pointer<Utf8> tier,
  Pointer<Utf8> imagesJson,
  Pointer<Utf8> productName,
);

typedef _ThemisFreeStringC = Void Function(Pointer<Utf8> ptr);
typedef _ThemisFreeStringDart = void Function(Pointer<Utf8> ptr);

/// High-performance FFI bridge to the native embedded Rust compliance engine (`libthemis.so`).
/// Executes DBNet text detection, PP-OCR text recognition, and Legal Metrology Rule 7 evaluations
/// on-device with zero Dart garbage collection pauses or thread stalls.
class ThemisNativeBridge {
  static final ThemisNativeBridge _instance = ThemisNativeBridge._internal();
  static ThemisNativeBridge get instance => _instance;

  ThemisNativeBridge._internal();

  DynamicLibrary? _cachedLib;
  String? _resolvedLibPath;
  String? _resolvedModelsDir;
  bool _initialized = false;

  /// Returns true if the native `libthemis` dynamic library is accessible on this platform.
  bool get isSupportedPlatform =>
      Platform.isAndroid || Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  /// Resolve the dynamic library path across desktop and mobile environments.
  String _resolveLibraryPath() {
    if (_resolvedLibPath != null) return _resolvedLibPath!;

    final envPath = Platform.environment['THEMIS_LIB_PATH'];
    if (envPath != null && File(envPath).existsSync()) {
      _resolvedLibPath = envPath;
      return envPath;
    }

    if (Platform.isAndroid) {
      _resolvedLibPath = 'libthemis.so';
      return 'libthemis.so';
    }

    if (Platform.isLinux) {
      final candidates = [
        '${Directory.current.path}/../themis/target/release/libthemis.so',
        '${Directory.current.path}/themis/target/release/libthemis.so',
        '/home/arch/Projects/backbone/themis/target/release/libthemis.so',
        'libthemis.so',
      ];
      for (final p in candidates) {
        if (File(p).existsSync()) {
          _resolvedLibPath = p;
          return p;
        }
      }
      _resolvedLibPath = 'libthemis.so';
      return 'libthemis.so';
    }

    if (Platform.isMacOS) {
      _resolvedLibPath = 'libthemis.dylib';
      return 'libthemis.dylib';
    }

    if (Platform.isWindows) {
      _resolvedLibPath = 'themis.dll';
      return 'themis.dll';
    }

    _resolvedLibPath = 'libthemis.so';
    return 'libthemis.so';
  }

  /// Open or retrieve cached DynamicLibrary
  DynamicLibrary _loadLibrary() {
    if (_cachedLib != null) return _cachedLib!;
    final path = _resolveLibraryPath();
    DevLogger.instance.info('NATIVE', 'Opening native shared library: $path');
    try {
      if (Platform.isAndroid) {
        try {
          DynamicLibrary.open('libc++_shared.so');
        } catch (e) {
          DevLogger.instance.warn('NATIVE', 'Pre-loading libc++_shared.so notice: $e');
        }
      }
      _cachedLib = DynamicLibrary.open(path);
      return _cachedLib!;
    } catch (e) {
      DevLogger.instance.error('NATIVE', 'Failed to load native library "$path": $e');
      rethrow;
    }
  }

  /// Check whether the native engine responds to ping (returns 1).
  bool ping() {
    try {
      final lib = _loadLibrary();
      final pingFn = lib.lookupFunction<_ThemisPingC, _ThemisPingDart>('themis_ping');
      final res = pingFn();
      final ok = res == 1;
      if (ok) {
        DevLogger.instance.success('NATIVE', 'Embedded Rust engine ping verified (1 OK)');
      }
      return ok;
    } catch (e) {
      DevLogger.instance.warn('NATIVE', 'Native ping probe failed: $e');
      return false;
    }
  }

  /// Ensure models directory is prepared on disk.
  /// On desktop, uses existing repository `models/` directory if present.
  /// On mobile devices, unpacks bundled assets from `assets/models/` to persistent app storage.
  Future<String> ensureModelsReady() async {
    if (_resolvedModelsDir != null && Directory(_resolvedModelsDir!).existsSync()) {
      return _resolvedModelsDir!;
    }

    final envModels = Platform.environment['THEMIS_MODELS_DIR'];
    if (envModels != null && Directory(envModels).existsSync()) {
      _resolvedModelsDir = envModels;
      return envModels;
    }

    // Check project workspace model locations for desktop development
    final localCandidates = [
      '/home/arch/Projects/backbone/themis/models',
      '${Directory.current.path}/../themis/models',
      '${Directory.current.path}/themis/models',
      '${Directory.current.path}/models',
    ];

    for (final dirPath in localCandidates) {
      final dir = Directory(dirPath);
      if (dir.existsSync() &&
          File('$dirPath/ppocr_det_int8.onnx').existsSync() &&
          File('$dirPath/en_ppocr_v3_rec_int8.onnx').existsSync()) {
        _resolvedModelsDir = dirPath;
        DevLogger.instance.info('NATIVE', 'Found local models directory: $dirPath');
        return dirPath;
      }
    }

    // On mobile devices or standalone installs, extract from bundled Flutter assets
    Directory targetDir;
    try {
      final appSupport = await getApplicationSupportDirectory();
      targetDir = Directory('${appSupport.path}/themis_models');
    } catch (_) {
      final temp = await getTemporaryDirectory();
      targetDir = Directory('${temp.path}/themis_models');
    }

    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final assets = [
      'assets/models/ppocr_det_int8.onnx',
      'assets/models/en_ppocr_v3_rec_int8.onnx',
      'assets/models/en_ppocr_v4_rec_int8.onnx',
      'assets/models/en_dict.txt',
    ];

    for (final assetPath in assets) {
      final fileName = assetPath.split('/').last;
      final targetFile = File('${targetDir.path}/$fileName');
      if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
        try {
          DevLogger.instance.info('NATIVE', 'Extracting asset $fileName -> ${targetFile.path}');
          final byteData = await rootBundle.load(assetPath);
          final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
          await targetFile.writeAsBytes(bytes, flush: true);
        } catch (e) {
          DevLogger.instance.warn('NATIVE', 'Asset $assetPath not available to extract: $e');
        }
      }
    }

    _resolvedModelsDir = targetDir.path;
    return targetDir.path;
  }

  /// Initialize native bridge and preheat library connection.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      DevLogger.instance.info('NATIVE', 'Initializing Themis Native FFI Bridge...');
      final libPath = _resolveLibraryPath();
      final modelsDir = await ensureModelsReady();
      DevLogger.instance.info('NATIVE', 'Library: $libPath | Models: $modelsDir');
      final ok = ping();
      _initialized = ok;
      return ok;
    } catch (e) {
      DevLogger.instance.error('NATIVE', 'Failed to initialize native bridge: $e');
      return false;
    }
  }

  bool _isScanning = false;

  /// Returns true if a native on-device scan isolate is actively executing.
  bool get isScanning => _isScanning;

  /// Execute packaging audit natively on-device in a background isolate.
  /// Enforces a strict single-flight mutex: rejects overlapping scans to prevent
  /// memory duplication and Linux kernel swap thrashing on edge mobile devices.
  Future<ComplianceReport> scanSku({
    required List<String> panelImagePaths,
    String? productName,
    required EngineModelOption modelOption,
  }) async {
    if (_isScanning) {
      DevLogger.instance.warn('NATIVE', 'Scan rejected: another native scan is already running.');
      throw StateError('A compliance audit is already running. Please wait for it to complete.');
    }

    _isScanning = true;
    // TIMER t0 starts at scan request (button tap lands just above this).
    final sw = Stopwatch()..start();
    DevLogger.instance.info(
      'TIMER',
      'Scan requested: ${panelImagePaths.length} panel(s) (t=+0ms)',
    );
    try {
      final modelsDir = await ensureModelsReady();
      final libPath = _resolveLibraryPath();

      // Map UI model option to Rust OcrPipeline tier string
      final tier = (modelOption == EngineModelOption.mobileAccurateInt8)
          ? 'server-int8'
          : 'mobile-v3';

      DevLogger.instance.info(
        'NATIVE',
        'Spawning background isolate for native scan (Tier: $tier, Panels: ${panelImagePaths.length})...',
      );
      DevLogger.instance.info(
        'TIMER',
        'Isolate spawned, entering FFI (t=+${sw.elapsedMilliseconds}ms)',
      );

      // Run native invocation in a separate isolate
      final jsonResponse = await Isolate.run<String>(() {
        return _runNativeScanInIsolate(
          libPath: libPath,
          modelsDir: modelsDir,
          tier: tier,
          panelImagePaths: panelImagePaths,
          productName: productName,
        );
      });

      sw.stop();
      DevLogger.instance.info(
        'TIMER',
        'Native FFI returned (t=+${sw.elapsedMilliseconds}ms). Deserializing payload...',
      );
      DevLogger.instance.info(
        'NATIVE',
        'Native scan completed in ${sw.elapsedMilliseconds}ms. Deserializing payload...',
      );

      final Map<String, dynamic> parsed = jsonDecode(jsonResponse) as Map<String, dynamic>;
      if (parsed['error'] == true) {
        final msg = parsed['message'] as String? ?? 'Native inference error';
        DevLogger.instance.error('NATIVE', 'Native engine returned error: $msg');
        throw Exception('Native engine error: $msg');
      }

      final report = ComplianceReport.fromJson(parsed);
      DevLogger.instance.info(
        'TIMER',
        'Report parsed: ${report.complianceScorePct.toStringAsFixed(1)}% '
        '(${report.riskTier}) (t=+${sw.elapsedMilliseconds}ms total)',
      );
      // Rust stage timings ride inside the payload (see ffi.rs): the cdylib
      // has no log subscriber on Android, so this is how per-panel
      // detect/recognize/probe/merge splits reach the log file.
      final stageTimings = parsed['stage_timings'];
      if (stageTimings is List) {
        for (final t in stageTimings) {
          DevLogger.instance.info('TIMER', t.toString());
        }
      }
      DevLogger.instance.success(
        'NATIVE',
        'Native audit finished: ID ${report.inspectionId}, Score: ${report.complianceScorePct.toStringAsFixed(1)}%, Tier: ${report.riskTier} (${sw.elapsedMilliseconds}ms total)',
      );

      return report;
    } finally {
      _isScanning = false;
    }
  }

  /// Single panel scan convenience method
  Future<ComplianceReport> scanSinglePanel({
    required String imagePath,
    required EngineModelOption modelOption,
  }) {
    return scanSku(
      panelImagePaths: [imagePath],
      productName: null,
      modelOption: modelOption,
    );
  }

  /// Isolate payload execution worker
  static String _runNativeScanInIsolate({
    required String libPath,
    required String modelsDir,
    required String tier,
    required List<String> panelImagePaths,
    required String? productName,
  }) {
    if (Platform.isAndroid) {
      try {
        DynamicLibrary.open('libc++_shared.so');
      } catch (_) {}
    }
    final lib = DynamicLibrary.open(libPath);

    final scanFn = lib.lookupFunction<_ThemisScanSkuC, _ThemisScanSkuDart>('themis_scan_sku');
    final freeFn = lib.lookupFunction<_ThemisFreeStringC, _ThemisFreeStringDart>('themis_free_string');

    final modelsDirPtr = modelsDir.toNativeUtf8();
    final tierPtr = tier.toNativeUtf8();
    final imagesJson = jsonEncode(panelImagePaths);
    final imagesJsonPtr = imagesJson.toNativeUtf8();
    final productNamePtr = (productName != null && productName.trim().isNotEmpty)
        ? productName.trim().toNativeUtf8()
        : nullptr;

    Pointer<Utf8> resultPtr = nullptr;
    try {
      resultPtr = scanFn(modelsDirPtr, tierPtr, imagesJsonPtr, productNamePtr);
      if (resultPtr == nullptr) {
        return jsonEncode({
          'error': true,
          'message': 'Native scan returned a null pointer',
        });
      }
      final resultStr = resultPtr.toDartString();
      return resultStr;
    } finally {
      if (resultPtr != nullptr) {
        freeFn(resultPtr);
      }
      calloc.free(modelsDirPtr);
      calloc.free(tierPtr);
      calloc.free(imagesJsonPtr);
      if (productNamePtr != nullptr) {
        calloc.free(productNamePtr);
      }
    }
  }
}
