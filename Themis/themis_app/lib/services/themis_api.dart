import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/compliance_report.dart';
import 'audit_storage_service.dart';
import 'dev_logger.dart';
import 'statutory_notice_csv_service.dart';
import 'statutory_notice_pdf_service.dart';
import 'themis_native_bridge.dart';

enum EngineModelOption {
  mobileCompactInt8,
  mobileAccurateInt8,
  remoteServer,
}

class ThemisApiService {
  static final ThemisApiService _instance = ThemisApiService._internal();
  factory ThemisApiService() => _instance;

  String baseUrl = 'http://localhost:8080';
  EngineModelOption _modelOption = EngineModelOption.mobileCompactInt8;
  late final Dio _dio;

  EngineModelOption get modelOption => _modelOption;

  void setModelOption(EngineModelOption option) {
    _modelOption = option;
    DevLogger.instance.info('MODEL', 'AI Vision execution tier switched to: ${option.name}');
  }

  ThemisApiService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 180),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          DevLogger.instance.info('NET', '${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          final info = response.statusCode == 200 ? 'SUCCESS' : 'STATUS ${response.statusCode}';
          DevLogger.instance.success('NET', '$info <- ${response.requestOptions.method} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (err, handler) {
          DevLogger.instance.error(
            'NET',
            '${err.requestOptions.method} ${err.requestOptions.path} ERROR: ${err.message ?? err.toString()}',
          );
          handler.next(err);
        },
      ),
    );

    DevLogger.instance.info('SYSTEM', 'PARAKH API Service initialized with host: $baseUrl');
  }

  void updateBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    DevLogger.instance.info('CONFIG', 'Backend endpoint updated to: $baseUrl');
  }

  Future<bool> checkHealth() async {
    if (_modelOption == EngineModelOption.mobileCompactInt8 ||
        _modelOption == EngineModelOption.mobileAccurateInt8) {
      if (ThemisNativeBridge.instance.isSupportedPlatform) {
        final ok = ThemisNativeBridge.instance.ping();
        if (ok) {
          DevLogger.instance.success('HEALTH', 'Native Rust Engine is READY (On-device)');
        } else {
          DevLogger.instance.warn('HEALTH', 'Native Rust Engine ping failed');
        }
        return ok;
      }
    }

    try {
      DevLogger.instance.info('PING', 'Checking engine health at $baseUrl/api/v1/health...');
      final res = await _dio.get('$baseUrl/api/v1/health');
      final healthy = res.statusCode == 200;
      if (healthy) {
        DevLogger.instance.success('HEALTH', 'PARAKH engine is ONLINE (200 OK)');
      } else {
        DevLogger.instance.warn('HEALTH', 'PARAKH engine returned non-200 status: ${res.statusCode}');
      }
      return healthy;
    } catch (e) {
      DevLogger.instance.error('HEALTH', 'Failed to reach engine at $baseUrl: $e');
      return false;
    }
  }

  Future<ComplianceReport> scanSku({
    required List<String> panelImagePaths,
    String? productName,
  }) async {
    if (_modelOption == EngineModelOption.mobileCompactInt8 ||
        _modelOption == EngineModelOption.mobileAccurateInt8) {
      if (ThemisNativeBridge.instance.isSupportedPlatform) {
        DevLogger.instance.info('SCAN', 'Routing packaging audit directly to On-Device Native Rust FFI (${_modelOption.name})...');
        final report = await ThemisNativeBridge.instance.scanSku(
          panelImagePaths: panelImagePaths,
          productName: productName,
          modelOption: _modelOption,
        );
        await AuditStorageService.instance.saveInspection(report);
        return report;
      }
    }
    DevLogger.instance.info('SCAN', 'Packaging audit started for ${panelImagePaths.length} panel(s)...');
    final formData = FormData();

    if (productName != null && productName.trim().isNotEmpty) {
      formData.fields.add(MapEntry('product_name', productName.trim()));
      DevLogger.instance.info('SCAN', 'Assigned product name: "${productName.trim()}"');
    }

    for (int i = 0; i < panelImagePaths.length; i++) {
      final path = panelImagePaths[i];
      final file = File(path);
      if (await file.exists()) {
        final sizeKb = (await file.length()) / 1024.0;
        final fieldName = i == 0 ? 'front' : 'panel_$i';
        DevLogger.instance.info('FILE', 'Attaching panel $i: ${file.uri.pathSegments.last} (${sizeKb.toStringAsFixed(1)} KB)');
        formData.files.add(
          MapEntry(
            fieldName,
            await MultipartFile.fromFile(path, filename: file.uri.pathSegments.last),
          ),
        );
      } else {
        DevLogger.instance.warn('FILE', 'Panel file does not exist: $path');
      }
    }

    DevLogger.instance.info('ENGINE', 'Sending multipart payload to Rust engine for DBNet + PP-OCRv4 inference...');
    final response = await _dio.post(
      '$baseUrl/api/v1/scan-sku',
      data: formData,
    );

    if (response.statusCode == 200 && response.data != null) {
      final report = ComplianceReport.fromJson(response.data as Map<String, dynamic>);
      await AuditStorageService.instance.saveInspection(report);
      DevLogger.instance.success(
        'AUDIT',
        'Inspection completed! ID: ${report.inspectionId}, Score: ${report.complianceScorePct.toStringAsFixed(1)}%, Tier: ${report.riskTier}',
      );
      return report;
    } else {
      DevLogger.instance.error('ENGINE', 'Inspection failed with status ${response.statusCode}');
      throw Exception('Scan failed with status ${response.statusCode}');
    }
  }

  Future<ComplianceReport> scanSinglePanel(String imagePath) async {
    if (_modelOption == EngineModelOption.mobileCompactInt8 ||
        _modelOption == EngineModelOption.mobileAccurateInt8) {
      if (ThemisNativeBridge.instance.isSupportedPlatform) {
        DevLogger.instance.info('SCAN', 'Routing single panel audit directly to On-Device Native Rust FFI (${_modelOption.name})...');
        final report = await ThemisNativeBridge.instance.scanSinglePanel(
          imagePath: imagePath,
          modelOption: _modelOption,
        );
        await AuditStorageService.instance.saveInspection(report);
        return report;
      }
    }
    DevLogger.instance.info('SCAN', 'Single panel audit started: $imagePath');
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $imagePath');
    }
    final sizeKb = (await file.length()) / 1024.0;
    DevLogger.instance.info('FILE', 'Attaching panel: ${file.uri.pathSegments.last} (${sizeKb.toStringAsFixed(1)} KB)');
    
    final formData = FormData();
    formData.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(imagePath, filename: file.uri.pathSegments.last),
      ),
    );

    DevLogger.instance.info('ENGINE', 'Sending single panel payload to Rust engine...');
    final response = await _dio.post(
      '$baseUrl/api/v1/scan',
      data: formData,
    );

    if (response.statusCode == 200 && response.data != null) {
      final report = ComplianceReport.fromJson(response.data as Map<String, dynamic>);
      await AuditStorageService.instance.saveInspection(report);
      DevLogger.instance.success(
        'AUDIT',
        'Single panel audit completed! ID: ${report.inspectionId}, Score: ${report.complianceScorePct.toStringAsFixed(1)}%, Tier: ${report.riskTier}',
      );
      return report;
    } else {
      DevLogger.instance.error('ENGINE', 'Single panel inspection failed with status ${response.statusCode}');
      throw Exception('Scan single panel failed with status ${response.statusCode}');
    }
  }

  Future<ComplianceReport> scanPath(String filePath) async {
    DevLogger.instance.info('SCAN', 'Scanning server file path: $filePath');
    final response = await _dio.post(
      '$baseUrl/api/v1/scan-path',
      data: {'file_path': filePath},
    );

    if (response.statusCode == 200 && response.data != null) {
      final report = ComplianceReport.fromJson(response.data as Map<String, dynamic>);
      await AuditStorageService.instance.saveInspection(report);
      DevLogger.instance.success(
        'AUDIT',
        'Server file audit completed! ID: ${report.inspectionId}, Score: ${report.complianceScorePct.toStringAsFixed(1)}%, Tier: ${report.riskTier}',
      );
      return report;
    } else {
      DevLogger.instance.error('ENGINE', 'Server file scan failed with status ${response.statusCode}');
      throw Exception('Scan file path failed with status ${response.statusCode}');
    }
  }

  Future<ComplianceReport> scanProductPath(String productDir, {String? productName}) async {
    DevLogger.instance.info('SCAN', 'Scanning server directory SKU: $productDir');
    final payload = <String, dynamic>{'product_dir': productDir};
    if (productName != null && productName.trim().isNotEmpty) {
      payload['product_name'] = productName.trim();
      DevLogger.instance.info('SCAN', 'Assigned product name: "${productName.trim()}"');
    }

    final response = await _dio.post(
      '$baseUrl/api/v1/scan-product-path',
      data: payload,
    );

    if (response.statusCode == 200 && response.data != null) {
      final report = ComplianceReport.fromJson(response.data as Map<String, dynamic>);
      await AuditStorageService.instance.saveInspection(report);
      DevLogger.instance.success(
        'AUDIT',
        'Server SKU folder audit completed! ID: ${report.inspectionId}, Score: ${report.complianceScorePct.toStringAsFixed(1)}%, Tier: ${report.riskTier}',
      );
      return report;
    } else {
      DevLogger.instance.error('ENGINE', 'Server SKU folder scan failed with status ${response.statusCode}');
      throw Exception('Scan product path failed with status ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchStats() async {
    if (_modelOption == EngineModelOption.remoteServer) {
      try {
        final res = await _dio.get('$baseUrl/api/v1/stats');
        if (res.statusCode == 200 && res.data != null && res.data is Map) {
          return Map<String, dynamic>.from(res.data as Map);
        }
      } catch (e) {
        DevLogger.instance.warn('STATS', 'Could not fetch live stats from server: $e');
      }
    }
    return await AuditStorageService.instance.computeStats();
  }

  Future<List<Map<String, dynamic>>> fetchInspections({
    int page = 1,
    int limit = 50,
    String? riskTier,
    String? search,
  }) async {
    // 1. Read persistent local storage (guarantees offline availability)
    final localList = await AuditStorageService.instance.getInspections(
      riskTier: riskTier,
      search: search,
      page: page,
      limit: limit,
    );

    // 2. If remote server is configured, try fetching remote inspections
    if (_modelOption == EngineModelOption.remoteServer) {
      try {
        final query = <String, dynamic>{
          'page': page,
          'limit': limit,
        };
        if (riskTier != null && riskTier != 'All') query['risk_tier'] = riskTier;
        if (search != null && search.isNotEmpty) query['search'] = search;

        final res = await _dio.get('$baseUrl/api/v1/inspections', queryParameters: query);
        if (res.statusCode == 200 && res.data != null) {
          final List<dynamic> raw = res.data is List
              ? res.data as List
              : (res.data is Map && res.data['inspections'] is List)
                  ? res.data['inspections'] as List
                  : [];
          if (raw.isNotEmpty) {
            final remoteList = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            return remoteList;
          }
        }
      } catch (e) {
        DevLogger.instance.info('DOSSIER', 'Remote server unreachable, using persistent local registry.');
      }
    }

    return localList;
  }

  String getEvidenceUrl(String inspectionId, String panelFilename) {
    return '$baseUrl/api/v1/evidence/$inspectionId/$panelFilename';
  }

  Future<Uint8List> getPdfBytes(String inspectionId, {ComplianceReport? report}) async {
    ComplianceReport? r = report ?? await AuditStorageService.instance.getReport(inspectionId);
    if (r != null) {
      return StatutoryNoticePdfService.generate(r);
    }

    if (_modelOption == EngineModelOption.remoteServer) {
      try {
        final res = await _dio.get<List<int>>(
          '$baseUrl/api/v1/inspections/$inspectionId/export/pdf',
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.statusCode == 200 && res.data != null) {
          return Uint8List.fromList(res.data!);
        }
      } catch (e) {
        DevLogger.instance.warn('EXPORT', 'Remote PDF download failed: $e');
      }
    }

    throw Exception('Could not locate audit record $inspectionId for PDF export');
  }

  Future<Uint8List> getCsvBytes(String inspectionId, {ComplianceReport? report}) async {
    ComplianceReport? r = report ?? await AuditStorageService.instance.getReport(inspectionId);
    if (r != null) {
      return StatutoryNoticeCsvService.generate(r);
    }

    if (_modelOption == EngineModelOption.remoteServer) {
      try {
        final res = await _dio.get<List<int>>(
          '$baseUrl/api/v1/inspections/$inspectionId/export/csv',
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.statusCode == 200 && res.data != null) {
          return Uint8List.fromList(res.data!);
        }
      } catch (e) {
        DevLogger.instance.warn('EXPORT', 'Remote CSV download failed: $e');
      }
    }

    throw Exception('Could not locate audit record $inspectionId for CSV export');
  }

  Future<String> downloadPdfNotice(String inspectionId, String targetPath, {ComplianceReport? report}) async {
    DevLogger.instance.info('EXPORT', 'Exporting statutory PDF notice for $inspectionId -> $targetPath');
    final pdfBytes = await getPdfBytes(inspectionId, report: report);
    final file = File(targetPath);
    await file.writeAsBytes(pdfBytes, flush: true);
    DevLogger.instance.success('EXPORT', 'PDF notice written: $targetPath (${pdfBytes.length} bytes)');
    return targetPath;
  }

  Future<String> downloadCsvAudit(String inspectionId, String targetPath, {ComplianceReport? report}) async {
    DevLogger.instance.info('EXPORT', 'Exporting CSV compliance spreadsheet for $inspectionId -> $targetPath');
    final csvBytes = await getCsvBytes(inspectionId, report: report);
    final file = File(targetPath);
    await file.writeAsBytes(csvBytes, flush: true);
    DevLogger.instance.success('EXPORT', 'CSV audit report written: $targetPath (${csvBytes.length} bytes)');
    return targetPath;
  }
}
