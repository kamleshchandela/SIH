import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/audit_storage_service.dart';
import '../services/dev_logger.dart';
import '../services/glass_perf_service.dart';
import '../services/themis_api.dart';
import '../theme/glass_theme.dart';
import '../theme/sober_theme.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/risk_tier_badge.dart';
import '../widgets/sober/sober_badge.dart';
import '../widgets/sober/sober_spacer.dart';
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

  /// Sober brand swap — valid inside the build listener below.
  Color _acc(Color c) =>
      SoberTheme.swap(c, GlassPerfService.instance.soberMode);

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
      // Count line: proves what the registry actually returned (diagnoses
      // "history visible, then empty" reports without guessing).
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
    } catch (e, st) {
      DevLogger.instance.error('DOSSIER', 'History load failed: $e');
      DevLogger.instance.error('STACK', st.toString().split('\n').take(3).join(' | '));
      if (mounted) {
        setState(() {
          _inspections = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load audit history: $e',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            backgroundColor: const Color(0xFF1E1B4B),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

      if (uri == null) {
        return; // User canceled the picker
      }

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

      if (uri == null) {
        return; // User canceled the picker
      }

      _showToast('Audit CSV saved successfully');
    } catch (e) {
      _showToast('CSV Export failed: $e');
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: const Color(0xFF1E1B4B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
      backgroundColor: const Color(0xF20B0C1E),
      barrierColor: Colors.black.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RiskTierBadge(riskTier: risk),
                  Text(
                    'Score: ${score.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: score >= 80
                          ? _acc(GlassTheme.compliantCyan)
                          : (score >= 50 ? GlassTheme.moderateRiskAmber : GlassTheme.criticalCrimson),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: $id',
                style: const TextStyle(color: GlassTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
              ),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Timestamp: $createdAt',
                  style: const TextStyle(color: GlassTheme.textMuted, fontSize: 10),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Violations:', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
                        Text(
                          '$violations statutory defects',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Sober: saffron fee badge. Glass: existing fine row.
                    // Modal builds fresh on open, so a direct read is enough.
                    if (GlassPerfService.instance.soberMode)
                      Row(
                        children: [
                          SoberBadge(
                            amount: '₹$fine',
                            caption: 'Compounding fine • INR',
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Compounding Fine:', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
                          Text(
                            '₹$fine INR',
                            style: const TextStyle(
                              color: GlassTheme.criticalCrimson,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    if (panels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Panels Audited:', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
                          Text(
                            '${panels.length} panel(s)',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadPdf(id);
                      },
                      icon: const Icon(CupertinoIcons.doc_fill, size: 14, color: Colors.black),
                      label: const Text(
                        'Export PDF Notice',
                        style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadCsv(id);
                      },
                      icon: const Icon(CupertinoIcons.table, size: 14, color: Colors.white),
                      label: const Text(
                        'Export CSV Audit',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        // Rebuilds on sober toggle (hot-apply); _fetchHistory only runs on
        // init/filter/search, so this never refetches.
        child: ListenableBuilder(
          listenable: GlassPerfService.instance,
          builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'THEMIS // HISTORICAL DOSSIERS',
                        style: TextStyle(
                          color: GlassTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Audit Registry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.arrow_clockwise, color: _acc(GlassTheme.bgNeonCyan), size: 18),
                    onPressed: _fetchHistory,
                    tooltip: 'Refresh History',
                  ),
                ],
              ),
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _effectiveFocusNode,
                  onSubmitted: (_) => _fetchHistory(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(CupertinoIcons.search, size: 16, color: _acc(GlassTheme.bgNeonCyan)),
                    hintText: 'Search by Product Name or Inspection ID...',
                    hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 13),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(CupertinoIcons.clear_circled_solid, size: 14, color: GlassTheme.textMuted),
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

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: ['All', 'CriticalSevere', 'ModerateRisk', 'Compliant'].map((tier) {
                    final isSelected = _selectedFilter == tier;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedFilter = tier);
                        _fetchHistory();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          tier == 'CriticalSevere'
                              ? 'Critical'
                              : tier == 'ModerateRisk'
                                  ? 'Moderate'
                                  : tier,
                          style: TextStyle(
                            color: isSelected ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textSecondary,
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Inspections List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _acc(GlassTheme.bgNeonCyan), strokeWidth: 2))
                  : _inspections.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(CupertinoIcons.doc_text_search, size: 36, color: GlassTheme.textMuted),
                              SizedBox(height: 12),
                              Text('No historical audits recorded', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13)),
                              SizedBox(height: 4),
                              Text('Perform an audit in the Inspect tab to persist records.', style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchHistory,
                          color: Colors.black,
                          backgroundColor: _acc(GlassTheme.bgNeonCyan),
                          child: ListenableBuilder(
                            listenable: GlassPerfService.instance,
                            builder: (context, _) => ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                20,
                                6,
                                20,
                                SoberBottomSpacer.clearanceOf(
                                  GlassPerfService.instance.soberMode,
                                  90,
                                ),
                              ),
                            itemCount: _inspections.length,
                            itemBuilder: (context, index) {
                              final item = _inspections[index];
                              final id = item['inspection_id'] as String? ?? '';
                              final name = item['product_name'] as String? ?? 'Pre-packaged Commodity';
                              final risk = item['risk_tier'] as String? ?? 'CriticalSevere';
                              final fine = item['compounding_fine_inr'] ?? 0;
                              final score = (item['compliance_score_pct'] as num?)?.toDouble() ?? 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: () => _showDetailsModal(item),
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(16),
                                    borderRadius: 22,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            RiskTierBadge(riskTier: risk),
                                            Text(
                                              'Score: ${score.toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                color: score >= 80
                                                    ? _acc(GlassTheme.compliantCyan)
                                                    : (score >= 50 ? GlassTheme.moderateRiskAmber : GlassTheme.criticalCrimson),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          name,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          id,
                                          style: const TextStyle(color: GlassTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                                        ),
                                        const SizedBox(height: 12),
                                        Divider(color: Colors.white.withValues(alpha: 0.08)),
                                        const SizedBox(height: 8),
                                        ListenableBuilder(
                                          listenable: GlassPerfService.instance,
                                          builder: (context, _) {
                                            // Sober: saffron fee badge. Glass:
                                            // existing fine row. Card shell
                                            // re-skins via GlassContainer.
                                            if (GlassPerfService.instance.soberMode) {
                                              return Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  SoberBadge(
                                                    amount: '₹$fine',
                                                    caption: 'Compounding fine',
                                                  ),
                                                  const Row(
                                                    children: [
                                                      Text(
                                                        'View Dossier',
                                                        style: TextStyle(color: Color(0xFFE8762B), fontSize: 11, fontWeight: FontWeight.w700),
                                                      ),
                                                      SizedBox(width: 4),
                                                      Icon(CupertinoIcons.chevron_right, size: 10, color: Color(0xFFE8762B)),
                                                    ],
                                                  ),
                                                ],
                                              );
                                            }
                                            return Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Fine: ₹$fine INR',
                                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                                ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'View Dossier',
                                                        style: TextStyle(color: _acc(GlassTheme.bgNeonCyan), fontSize: 11, fontWeight: FontWeight.w700),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(CupertinoIcons.chevron_right, size: 10, color: _acc(GlassTheme.bgNeonCyan)),
                                                    ],
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
