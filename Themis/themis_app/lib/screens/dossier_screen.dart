import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/audit_storage_service.dart';
import '../services/dev_logger.dart';
import '../services/themis_api.dart';
import '../theme/theme.dart';
import '../widgets/primitives/themis_primitives.dart';

/// Historical Dossiers & Inspection Records Screen
///
/// Built strictly for the Sunlight Light Theme for high-visibility field operations.
/// Allows officers to:
/// - Search past inspections by product name, SKU, or inspection ID.
/// - Filter by statutory severity (All, Critical, Moderate, Compliant).
/// - Inspect full statutory details and penalty compound breakdown.
/// - Export offline ISO PDF 1.4 notices and audit CSVs via system SAF picker.
class DossierScreen extends StatefulWidget {
  final FocusNode? searchFocusNode;
  const DossierScreen({super.key, this.searchFocusNode});

  @override
  State<DossierScreen> createState() => _DossierScreenState();
}

class _DossierScreenState extends State<DossierScreen> {
  final ThemisApiService _api = ThemisApiService();
  final TextEditingController _searchController = TextEditingController();
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.searchFocusNode ?? (_internalFocusNode ??= FocusNode());

  List<Map<String, dynamic>> _inspections = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    AuditStorageService.instance.addListener(_onStorageUpdated);
    _fetchHistory();
  }

  void _onStorageUpdated() {
    if (mounted) _fetchHistory();
  }

  @override
  void dispose() {
    AuditStorageService.instance.removeListener(_onStorageUpdated);
    _searchController.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    DevLogger.instance.info('DOSSIER', 'Fetching historical audits (Filter: $_selectedFilter)...');
    try {
      final results = await _api.fetchInspections(
        riskTier: _selectedFilter == 'All' ? null : _selectedFilter,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      DevLogger.instance.info(
        'DOSSIER',
        'Loaded ${results.length} record(s) from local registry (filter: $_selectedFilter).',
      );
      if (mounted) {
        setState(() {
          _inspections = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      DevLogger.instance.warn('DOSSIER', 'Error fetching inspection history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadPdf(String inspectionId) async {
    try {
      final bytes = await _api.getPdfBytes(inspectionId);
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Statutory Notice PDF',
        fileName: 'Notice_$inspectionId.pdf',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        mimeType: 'application/pdf',
      );

      if (uri == null) return;
      _showToast('Notice PDF saved successfully');
    } catch (e) {
      _showToast('PDF Export failed: $e');
    }
  }

  Future<void> _downloadCsv(String inspectionId) async {
    try {
      final bytes = await _api.getCsvBytes(inspectionId);
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Compliance CSV',
        fileName: 'Audit_$inspectionId.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        mimeType: 'text/csv',
      );

      if (uri == null) return;
      _showToast('Audit CSV saved successfully');
    } catch (e) {
      _showToast('CSV Export failed: $e');
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemisTheme.sunlightTextPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemisTheme.radius8)),
      ),
    );
  }

  StatutoryStatus _parseStatus(String tier) {
    final t = tier.toLowerCase();
    if (t.contains('compliant')) return StatutoryStatus.compliant;
    if (t.contains('warning') || t.contains('moderate') || t.contains('advisory') || t.contains('low')) {
      return StatutoryStatus.warning;
    }
    return StatutoryStatus.violation;
  }

  void _showDetailsModal(Map<String, dynamic> item) {
    final id = item['inspection_id'] as String? ?? '';
    final name = item['product_name'] as String? ?? 'Pre-packaged Commodity';
    final risk = item['risk_tier'] as String? ?? 'CriticalSevere';
    final fine = item['compounding_fine_inr'] ?? 0;
    final score = (item['compliance_score_pct'] as num?)?.toDouble() ?? 0.0;
    final panels = (item['scanned_panels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final violations = item['total_violations'] ?? 0;
    final createdAt = item['created_at'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemisTheme.sunlightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ThemisTheme.radius16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            ThemisTheme.space20,
            ThemisTheme.space16,
            ThemisTheme.space20,
            ThemisTheme.space32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemisTheme.sunlightBorderStrong,
                    borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                  ),
                ),
              ),
              const SizedBox(height: ThemisTheme.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatutoryBadge(
                    status: _parseStatus(risk),
                    customLabel: risk.toUpperCase(),
                  ),
                  Text(
                    'Score: ${score.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: score >= 80
                          ? ThemisTheme.statusCompliant
                          : (score >= 50 ? ThemisTheme.statusWarning : ThemisTheme.statusViolation),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ThemisTheme.space12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ThemisTheme.sunlightTextPrimary,
                ),
              ),
              const SizedBox(height: ThemisTheme.space4),
              Text(
                'ID: $id',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: ThemisTheme.sunlightTextSecondary,
                ),
              ),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: ThemisTheme.space2),
                Text(
                  'Timestamp: $createdAt',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ThemisTheme.sunlightTextMuted,
                  ),
                ),
              ],
              const SizedBox(height: ThemisTheme.space16),

              // Violation & Fine breakdown card
              Container(
                padding: const EdgeInsets.all(ThemisTheme.space16),
                decoration: BoxDecoration(
                  color: ThemisTheme.sunlightBg,
                  borderRadius: BorderRadius.circular(ThemisTheme.radius12),
                  border: Border.all(color: ThemisTheme.sunlightBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Defects Identified:',
                          style: TextStyle(
                            fontSize: 13,
                            color: ThemisTheme.sunlightTextSecondary,
                          ),
                        ),
                        Text(
                          '$violations statutory omissions',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ThemisTheme.sunlightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ThemisTheme.space8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Compounding Penalty:',
                          style: TextStyle(
                            fontSize: 13,
                            color: ThemisTheme.sunlightTextSecondary,
                          ),
                        ),
                        Text(
                          'Rs. $fine INR',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ThemisTheme.amberHover,
                          ),
                        ),
                      ],
                    ),
                    if (panels.isNotEmpty) ...[
                      const SizedBox(height: ThemisTheme.space12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: panels.map((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ThemisTheme.sunlightSurface,
                                borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                                border: Border.all(color: ThemisTheme.sunlightBorder),
                              ),
                              child: Text(
                                p.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ThemisTheme.sunlightTextSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: ThemisTheme.space20),

              ThemisButton(
                label: 'Download Statutory Notice (PDF)',
                leadingIcon: CupertinoIcons.doc_text_fill,
                variant: ThemisButtonVariant.primaryAmber,
                isPrimaryCTA: true,
                onPressed: () {
                  Navigator.pop(context);
                  _downloadPdf(id);
                },
              ),
              const SizedBox(height: ThemisTheme.space8),
              ThemisButton(
                label: 'Export Inspection Audit (CSV)',
                leadingIcon: CupertinoIcons.table,
                variant: ThemisButtonVariant.secondaryOutline,
                onPressed: () {
                  Navigator.pop(context);
                  _downloadCsv(id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemisTheme.sunlightBg,
      appBar: ThemisAppBar(
        title: 'AUDIT DOSSIER',
        subtitle: 'Directorate of Legal Metrology - Inspection History',
        isDark: false,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ThemisTheme.amberPrimary),
                  )
                : const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: ThemisTheme.sunlightTextSecondary),
            onPressed: _fetchHistory,
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===============================================================
          // 1. Search Bar
          // ===============================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ThemisTheme.space16,
              ThemisTheme.space12,
              ThemisTheme.space16,
              ThemisTheme.space8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space12),
              decoration: BoxDecoration(
                color: ThemisTheme.sunlightSurface,
                borderRadius: BorderRadius.circular(ThemisTheme.radius12),
                border: Border.all(color: ThemisTheme.sunlightBorder),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _effectiveFocusNode,
                onSubmitted: (_) => _fetchHistory(),
                style: const TextStyle(
                  fontSize: 14,
                  color: ThemisTheme.sunlightTextPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: const Icon(CupertinoIcons.search, size: 18, color: ThemisTheme.amberPrimary),
                  hintText: 'Search product, commodity or inspection ID...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: ThemisTheme.sunlightTextMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: ThemisTheme.sunlightTextMuted),
                          onPressed: () {
                            _searchController.clear();
                            _fetchHistory();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // ===============================================================
          // 2. Filter Chips Row
          // ===============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space16, vertical: ThemisTheme.space4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['All', 'CriticalSevere', 'ModerateRisk', 'Compliant'].map((tier) {
                  final isSelected = _selectedFilter == tier;
                  final label = tier == 'CriticalSevere'
                      ? 'Critical'
                      : tier == 'ModerateRisk'
                          ? 'Moderate'
                          : tier;

                  return Padding(
                    padding: const EdgeInsets.only(right: ThemisTheme.space8),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedFilter = tier);
                        _fetchHistory();
                      },
                      borderRadius: BorderRadius.circular(ThemisTheme.radius16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? ThemisTheme.amberPrimary : ThemisTheme.sunlightSurface,
                          borderRadius: BorderRadius.circular(ThemisTheme.radius16),
                          border: Border.all(
                            color: isSelected ? ThemisTheme.amberPrimary : ThemisTheme.sunlightBorder,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : ThemisTheme.sunlightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: ThemisTheme.space8),

          // ===============================================================
          // 3. Inspection History List
          // ===============================================================
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: ThemisTheme.amberPrimary),
                  )
                : _inspections.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(ThemisTheme.space32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: ThemisTheme.amberTint,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.doc_text_search,
                                  size: 32,
                                  color: ThemisTheme.amberPrimary,
                                ),
                              ),
                              const SizedBox(height: ThemisTheme.space16),
                              const Text(
                                'No Historical Dossiers Found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ThemisTheme.sunlightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: ThemisTheme.space8),
                              const Text(
                                'Completed multi-panel inspections and statutory notices will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ThemisTheme.sunlightTextSecondary,
                                ),
                              ),
                              if (_selectedFilter != 'All' || _searchController.text.isNotEmpty) ...[
                                const SizedBox(height: ThemisTheme.space16),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'All';
                                      _searchController.clear();
                                    });
                                    _fetchHistory();
                                  },
                                  child: const Text('Reset Search & Filters'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: ThemisTheme.space16,
                          vertical: ThemisTheme.space8,
                        ),
                        itemCount: _inspections.length,
                        itemBuilder: (context, index) {
                          final item = _inspections[index];
                          final id = item['inspection_id'] as String? ?? '';
                          final name = item['product_name'] as String? ?? 'Pre-packaged Commodity';
                          final risk = item['risk_tier'] as String? ?? 'CriticalSevere';
                          final fine = item['compounding_fine_inr'] ?? 0;
                          final score = (item['compliance_score_pct'] as num?)?.toDouble() ?? 0.0;
                          final panels = (item['scanned_panels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: ThemisTheme.space12),
                            decoration: BoxDecoration(
                              color: ThemisTheme.sunlightSurface,
                              borderRadius: BorderRadius.circular(ThemisTheme.radius12),
                              border: Border.all(color: ThemisTheme.sunlightBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => _showDetailsModal(item),
                              borderRadius: BorderRadius.circular(ThemisTheme.radius12),
                              child: Padding(
                                padding: const EdgeInsets.all(ThemisTheme.space16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        StatutoryBadge(
                                          status: _parseStatus(risk),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: (score >= 80
                                                    ? ThemisTheme.statusCompliant
                                                    : (score >= 50
                                                        ? ThemisTheme.statusWarning
                                                        : ThemisTheme.statusViolation))
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                                          ),
                                          child: Text(
                                            'Score: ${score.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: score >= 80
                                                  ? ThemisTheme.statusCompliant
                                                  : (score >= 50
                                                      ? ThemisTheme.statusWarning
                                                      : ThemisTheme.statusViolation),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: ThemisTheme.space8),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: ThemisTheme.sunlightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: ThemisTheme.space4),
                                    Text(
                                      'ID: $id',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: ThemisTheme.sunlightTextMuted,
                                      ),
                                    ),
                                    if (panels.isNotEmpty) ...[
                                      const SizedBox(height: ThemisTheme.space8),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: panels.map((p) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ThemisTheme.sunlightBg,
                                              borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                                              border: Border.all(color: ThemisTheme.sunlightBorder),
                                            ),
                                            child: Text(
                                              p.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: ThemisTheme.sunlightTextSecondary,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    const SizedBox(height: ThemisTheme.space12),
                                    const Divider(height: 1, color: ThemisTheme.sunlightBorder),
                                    const SizedBox(height: ThemisTheme.space8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Compounding: Rs. $fine INR',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: ThemisTheme.amberHover,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                CupertinoIcons.arrow_down_doc_fill,
                                                size: 16,
                                                color: ThemisTheme.amberPrimary,
                                              ),
                                              tooltip: 'Download PDF Notice',
                                              onPressed: () => _downloadPdf(id),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            ),
                                            const SizedBox(width: ThemisTheme.space4),
                                            const Text(
                                              'Details',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: ThemisTheme.amberPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              CupertinoIcons.chevron_right,
                                              size: 12,
                                              color: ThemisTheme.amberPrimary,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
