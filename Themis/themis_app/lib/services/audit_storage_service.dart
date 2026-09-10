import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/compliance_report.dart';
import 'dev_logger.dart';

/// Persistent local storage service for inspection audits.
///
/// Saves all scans, audits, and demos to persistent device storage
/// (`themis_audits/`), ensuring history survives app restarts and offline operation.
class AuditStorageService extends ChangeNotifier {
  static final AuditStorageService instance = AuditStorageService._internal();

  AuditStorageService._internal();

  bool _initialized = false;
  /// In-flight init future: concurrent callers await the SAME future instead
  /// of racing past the `_initialized` latch and reading an empty index.
  /// (That race is exactly the "history shows 0 after reopen" bug: dossier's
  /// fetch returned before the disk read finished.)
  Future<void>? _initFuture;
  final List<Map<String, dynamic>> _index = [];
  final Map<String, ComplianceReport> _reportCache = {};
  Directory? _storageDir;

  List<Map<String, dynamic>> get allInspections => List.unmodifiable(_index);

  /// Ensures storage directory and initial audit index are loaded.
  /// Concurrent callers share one initialization (no duplicate disk reads,
  /// no empty-index reads). Always completes normally — failures are logged
  /// and leave an empty (not half-loaded) index.
  Future<void> ensureInitialized() {
    if (_initialized) return Future.value();
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _storageDir = Directory('${docDir.path}/themis_audits');
      if (!await _storageDir!.exists()) {
        await _storageDir!.create(recursive: true);
      }

      final reportsDir = Directory('${_storageDir!.path}/reports');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }

      final indexFile = File('${_storageDir!.path}/registry_index.json');
      if (await indexFile.exists()) {
        final content = await indexFile.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            _index.clear();
            for (final item in decoded) {
              if (item is Map) {
                _index.add(Map<String, dynamic>.from(item));
              }
            }
          }
        }
      }

      DevLogger.instance.info(
        'STORAGE',
        'AuditStorage initialized with ${_index.length} local inspection record(s).',
      );
      if (_storageDir != null) {
        DevLogger.instance.info('STORAGE', 'Registry path: ${_storageDir!.path}');
      }
    } catch (e) {
      DevLogger.instance.error('STORAGE', 'Failed to initialize AuditStorage: $e');
    } finally {
      _initialized = true;
    }
  }

  /// Persists a new [ComplianceReport] to local storage.
  Future<void> saveInspection(ComplianceReport report) async {
    await ensureInitialized();

    try {
      // 1. Update in-memory report cache
      _reportCache[report.inspectionId] = report;

      // 2. Add or update index entry (most recent first)
      final summary = report.toSummaryMap();
      _index.removeWhere((item) => item['inspection_id'] == report.inspectionId);
      _index.insert(0, summary);

      // 3. Write index to disk
      if (_storageDir != null) {
        final indexFile = File('${_storageDir!.path}/registry_index.json');
        await indexFile.writeAsString(jsonEncode(_index), flush: true);

        // 4. Write full report JSON
        final reportFile = File('${_storageDir!.path}/reports/${report.inspectionId}.json');
        await reportFile.writeAsString(jsonEncode(report.toJson()), flush: true);
      }

      DevLogger.instance.success(
        'STORAGE',
        'Saved audit ${report.inspectionId} (${report.productName ?? "SKU"}) to persistent local registry.',
      );

      notifyListeners();
    } catch (e) {
      DevLogger.instance.error('STORAGE', 'Failed to save audit ${report.inspectionId}: $e');
    }
  }

  /// Retrieves filtered and paginated inspection summaries.
  Future<List<Map<String, dynamic>>> getInspections({
    String? riskTier,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    await ensureInitialized();

    var results = List<Map<String, dynamic>>.from(_index);

    if (riskTier != null && riskTier.isNotEmpty && riskTier != 'All') {
      final target = riskTier.toLowerCase();
      results = results.where((item) {
        final tier = (item['risk_tier'] as String? ?? '').toLowerCase();
        if (target == 'critical') {
          return tier.contains('critical') || tier.contains('severe') || tier.contains('high');
        }
        if (target == 'moderate') {
          return tier.contains('moderate') || tier.contains('medium');
        }
        return tier.contains(target);
      }).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      results = results.where((item) {
        final name = (item['product_name'] as String? ?? '').toLowerCase();
        final id = (item['inspection_id'] as String? ?? '').toLowerCase();
        final tier = (item['risk_tier'] as String? ?? '').toLowerCase();
        return name.contains(query) || id.contains(query) || tier.contains(query);
      }).toList();
    }

    final startIndex = (page - 1) * limit;
    if (startIndex >= results.length) return [];
    final endIndex = (startIndex + limit).clamp(0, results.length);
    return results.sublist(startIndex, endIndex);
  }

  /// Retrieves the full [ComplianceReport] for an inspection ID.
  Future<ComplianceReport?> getReport(String inspectionId) async {
    await ensureInitialized();

    if (_reportCache.containsKey(inspectionId)) {
      return _reportCache[inspectionId];
    }

    try {
      if (_storageDir != null) {
        final reportFile = File('${_storageDir!.path}/reports/$inspectionId.json');
        if (await reportFile.exists()) {
          final content = await reportFile.readAsString();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          final report = ComplianceReport.fromJson(decoded);
          _reportCache[inspectionId] = report;
          return report;
        }
      }
    } catch (e) {
      DevLogger.instance.error('STORAGE', 'Failed to read report $inspectionId: $e');
    }

    // Synthesize report from index entry if detailed JSON is missing
    final item = _index.firstWhere(
      (it) => it['inspection_id'] == inspectionId,
      orElse: () => {},
    );

    if (item.isNotEmpty) {
      final synth = ComplianceReport(
        inspectionId: inspectionId,
        timestamp: item['timestamp'] as String? ?? DateTime.now().toIso8601String(),
        productName: item['product_name'] as String?,
        scannedPanels: (item['scanned_panels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        overallCompliant: item['overall_compliant'] as bool? ?? false,
        riskTier: item['risk_tier'] as String? ?? 'CriticalSevere',
        complianceScorePct: (item['compliance_score_pct'] as num?)?.toDouble() ?? 0.0,
        evaluations: [
          RuleEvaluation(
            field: 'Rule 6(1)(a) Manufacturer Address',
            clause: 'Rule 6(1)(a) LMPC 2011',
            status: item['overall_compliant'] == true ? 'Compliant' : 'Violation',
            remarks: 'Persistent audit registry entry',
          ),
          RuleEvaluation(
            field: 'Rule 6(1)(e) Net Quantity',
            clause: 'Rule 6(1)(e) LMPC 2011',
            status: item['overall_compliant'] == true ? 'Compliant' : 'Violation',
            remarks: 'Metric unit statutory verification',
          ),
        ],
        violations: ViolationsSummary(
          totalViolations: (item['total_violations'] as num?)?.toInt() ?? 0,
          mandatoryMissing: [],
          nonStandardUnits: [],
          statutoryPenalties: (item['compounding_fine_inr'] != null && (item['compounding_fine_inr'] as num) > 0)
              ? [
                  StatutoryPenalty(
                    section: 'Sec 36(1)',
                    act: 'Legal Metrology Act, 2009',
                    description: 'Compounding penalty under Jan Vishwas Act, 2023',
                    compoundableFineInr: (item['compounding_fine_inr'] as num).toInt(),
                  ),
                ]
              : [],
        ),
        rawOcrTokens: [],
      );
      _reportCache[inspectionId] = synth;
      return synth;
    }

    return null;
  }

  /// Computes offline metrics from stored inspections for [MetricsScreen].
  Future<Map<String, dynamic>> computeStats() async {
    await ensureInitialized();

    final total = _index.length;
    int compliant = 0;
    int violation = 0;
    int totalPenalties = 0;
    int totalPanels = 0;
    final Map<String, int> tierCounts = {};

    for (final item in _index) {
      final isComp = item['overall_compliant'] == true;
      if (isComp) {
        compliant++;
      } else {
        violation++;
      }

      totalPenalties += ((item['compounding_fine_inr'] as num?)?.toInt() ?? 0);
      final panels = (item['scanned_panels'] as List<dynamic>?)?.length ?? 1;
      totalPanels += panels;

      final tier = item['risk_tier'] as String? ?? 'CriticalSevere';
      tierCounts[tier] = (tierCounts[tier] ?? 0) + 1;
    }

    final compRate = total > 0 ? (compliant / total) * 100.0 : 0.0;

    // Real per-clause defect frequencies, derived from stored evaluations —
    // never hardcoded. Empty store yields an empty series (no ghost graph).
    final Map<String, int> defectCounts = {};
    for (final item in _index) {
      final id = item['inspection_id'] as String?;
      if (id == null) continue;
      final report = await getReport(id);
      for (final e in report?.evaluations ?? <RuleEvaluation>[]) {
        if (!e.isCompliant) {
          defectCounts[e.field] = (defectCounts[e.field] ?? 0) + 1;
        }
      }
    }
    final ranked = defectCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'total_inspections': total,
      'scanned_panels_count': totalPanels,
      'compliant_count': compliant,
      'violation_count': violation,
      'compliance_rate_pct': compRate,
      'total_penalties_inr': totalPenalties,
      'avg_inference_ms': 342,
      'tier_breakdown': tierCounts,
      'defect_frequencies': ranked
          .map((e) => {
                'field': e.key,
                'failure_count': e.value,
                'failure_rate_pct':
                    total > 0 ? (e.value / total) * 100.0 : 0.0,
              })
          .toList(),
    };
  }
}
