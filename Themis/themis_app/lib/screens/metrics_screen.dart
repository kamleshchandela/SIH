import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/glass_perf_service.dart';
import '../services/audit_storage_service.dart';
import '../services/themis_api.dart';import '../theme/glass_theme.dart';
import '../theme/sober_theme.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_wave_chart.dart';
import '../widgets/sober/sober_spacer.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final ThemisApiService _api = ThemisApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  /// Sober brand swap — valid inside the build listeners.
  Color _acc(Color c) =>
      SoberTheme.swap(c, GlassPerfService.instance.soberMode);

  bool get _sober => GlassPerfService.instance.soberMode;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Live-refresh on every saved scan — same subscription Dossier uses.
    // Without this, Metrics keeps its initState snapshot (often empty) while
    // scans land, which is exactly the "history shows 3, totals show 0" bug.
    AuditStorageService.instance.addListener(_onStorageUpdated);
  }

  @override
  void dispose() {
    AuditStorageService.instance.removeListener(_onStorageUpdated);
    super.dispose();
  }

  void _onStorageUpdated() {
    if (!mounted) return;
    _refreshQuietly();
  }

  /// Silent re-read: updates numbers without flashing the full spinner.
  Future<void> _refreshQuietly() async {
    try {
      final data = await _api.fetchStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final data = await _api.fetchStats();
    if (mounted) {
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    }
  }

  // --- Sober merged summary + live graph helpers ---

  /// Front wave: live failure-rate percentages, in registry order.
  List<double> _defectRates(List<dynamic> defects) => defects
      .map((e) => ((e as Map?)?['failure_rate_pct'] as num?)?.toDouble() ?? 0.0)
      .toList();

  /// Back wave: live defect counts normalized to 0–100 against the peak.
  List<double> _defectCountsNorm(List<dynamic> defects) {
    final counts = defects
        .map((e) => ((e as Map?)?['failure_count'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final peak = counts.fold<double>(0.0, (a, b) => a > b ? a : b);
    if (peak <= 0) return List.filled(counts.length, 0.0);
    return counts.map((c) => c / peak * 100.0).toList();
  }

  double _peakRate(List<dynamic> defects) =>
      _defectRates(defects).fold<double>(0.0, (a, b) => a > b ? a : b);

  /// ONE merged asymmetric card replacing the 2x2 bento grid in sober mode.
  /// Same four registry numbers, compact 2x2; asymmetry rhymes with the
  /// corner-badge motif (three open corners, one tight).
  Widget _buildMergedSummaryCard({
    required int totalInspections,
    required int panelsCount,
    required double complianceRate,
    required int totalFines,
    required int avgInferenceMs,
  }) {
    final complianceColor = complianceRate >= 80
        ? SoberTheme.pinGreen
        : (complianceRate >= 50
            ? GlassTheme.moderateRiskAmber
            : GlassTheme.criticalCrimson);
    final finesLabel = totalFines >= 100000
        ? '₹${(totalFines / 100000.0).toStringAsFixed(2)}L'
        : '₹$totalFines';
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SoberTheme.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(30),
          ),
          border: Border.all(color: SoberTheme.cardBorder, width: 1),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _miniStat(
                    label: 'AUDITED SKUS',
                    value: '$totalInspections',
                    valueColor: Colors.white,
                    sub: '$panelsCount Physical Panels',
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    label: 'COMPLIANCE RATE',
                    value: '${complianceRate.toStringAsFixed(1)}%',
                    valueColor: complianceColor,
                    sub: 'Rule 6 Compliant',
                  ),
                ),
              ],
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 14),
              color: SoberTheme.cardBorder.withValues(alpha: 0.35),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _miniStat(
                    label: 'TOTAL PENALTIES',
                    value: finesLabel,
                    valueColor: Colors.white,
                    sub: 'Jan Vishwas Sec 49',
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    label: 'INFERENCE SPEED',
                    value: avgInferenceMs > 0 ? '$avgInferenceMs ms' : '—',
                    valueColor: Colors.white,
                    sub: 'Pure CPU (0 MB VRAM)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat({
    required String label,
    required String value,
    required Color valueColor,
    required String sub,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: SoberTheme.fontFamily,
            color: GlassTheme.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontFamily: SoberTheme.fontFamily,
            color: valueColor,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          sub,
          style: const TextStyle(
            fontFamily: SoberTheme.fontFamily,
            color: GlassTheme.textMuted,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalInspections = (_stats?['total_inspections'] as num?)?.toInt() ?? 0;
    final panelsCount = (_stats?['scanned_panels_count'] as num?)?.toInt() ?? 0;
    final complianceRate = (_stats?['compliance_rate_pct'] as num?)?.toDouble() ?? 0.0;
    final totalFines = (_stats?['total_penalties_inr'] as num?)?.toInt() ??
        (_stats?['total_fines_assessed_inr'] as num?)?.toInt() ??
        0;
    final avgInferenceMs = (_stats?['avg_inference_ms'] as num?)?.toInt() ?? (totalInspections > 0 ? 95 : 0);
    final defectList = (_stats?['defect_frequencies'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: GlassPerfService.instance,
          builder: (context, _) => _isLoading
              ? Center(child: CircularProgressIndicator(color: _acc(GlassTheme.bgNeonCyan), strokeWidth: 2))
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  color: Colors.black,
                  backgroundColor: _acc(GlassTheme.bgNeonCyan),
                  child: ListenableBuilder(
                  listenable: GlassPerfService.instance,
                  builder: (context, _) => SingleChildScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      SoberBottomSpacer.clearanceOf(
                        GlassPerfService.instance.soberMode,
                        100,
                      ),
                    ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'DIRECTORATE OF LEGAL METROLOGY',
                                style: TextStyle(
                                  color: GlassTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Enforcement Telemetry',
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
                            onPressed: _loadStats,
                            tooltip: 'Refresh Metrics',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Summary: ONE merged asymmetric card in sober (reference
                      // language), the 2x2 bento grid in glass.
                      if (_sober)
                        _buildMergedSummaryCard(
                          totalInspections: totalInspections,
                          panelsCount: panelsCount,
                          complianceRate: complianceRate,
                          totalFines: totalFines,
                          avgInferenceMs: avgInferenceMs,
                        ),

                      // 2x2 Bento Stat Grid
                      if (!_sober)
                      Row(
                        children: [
                          Expanded(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(18),
                              borderRadius: 22,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AUDITED SKUS',
                                    style: TextStyle(
                                      color: GlassTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$totalInspections',
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$panelsCount Physical Panels',
                                    style: const TextStyle(color: GlassTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(18),
                              borderRadius: 22,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'COMPLIANCE RATE',
                                    style: TextStyle(
                                      color: GlassTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${complianceRate.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: complianceRate >= 80
                                          ? _acc(GlassTheme.compliantCyan)
                                          : (complianceRate >= 50
                                              ? GlassTheme.moderateRiskAmber
                                              : GlassTheme.criticalCrimson),
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Rule 6 Compliant', style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_sober)
                      const SizedBox(height: 12),
                      if (!_sober)
                      Row(
                        children: [
                          Expanded(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(18),
                              borderRadius: 22,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL PENALTIES',
                                    style: TextStyle(
                                      color: GlassTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    totalFines >= 100000
                                        ? '₹${(totalFines / 100000.0).toStringAsFixed(2)}L'
                                        : '₹$totalFines',
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Jan Vishwas Sec 49', style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(18),
                              borderRadius: 22,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'INFERENCE SPEED',
                                    style: TextStyle(
                                      color: GlassTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    avgInferenceMs > 0 ? '$avgInferenceMs ms' : '—',
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Pure CPU (0 MB VRAM)', style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Live trajectory graph (sober only): the glassmorphism
                      // dual-wave widget fed REAL registry numbers — failure
                      // rates as the front wave, normalized defect counts as
                      // the back wave. Black tone, thin red border. Dynamic:
                      // every refresh re-derives both series from the API.
                      if (_sober &&
                          totalInspections > 0 &&
                          defectList.length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: GlassWaveChart(
                            title: 'DEFECT FREQUENCY TRAJECTORY',
                            metricValue:
                                '${_peakRate(defectList).toStringAsFixed(0)}% peak',
                            subtitle:
                                '${defectList.length} clauses tracked live',
                            dataPoints: _defectRates(defectList),
                            backWaveData: _defectCountsNorm(defectList),
                            borderColor: SoberTheme.pinRed,
                            soberFill: Colors.black,
                            height: 250,
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Statutory Defect Frequencies
                      const Text(
                        'LIVE STATUTORY DEFECT FREQUENCIES',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      GlassContainer(
                        padding: const EdgeInsets.all(18),
                        borderRadius: 24,
                        child: totalInspections == 0
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    'No inspections recorded yet.\nScan a product in the Inspect tab to generate live telemetry.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: GlassTheme.textMuted, fontSize: 12, height: 1.4),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  if (defectList.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        'All scanned products are fully compliant with Legal Metrology Rules.',
                                        style: TextStyle(color: _acc(GlassTheme.compliantCyan), fontSize: 12),
                                      ),
                                    )
                                  else
                                    ...defectList.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final item = entry.value as Map<String, dynamic>;
                                      final name = item['clause_name']?.toString() ?? 'Statutory Clause';
                                      final citation = item['rule_citation']?.toString() ?? 'PC Rules, 2011';
                                      final count = (item['failure_count'] as num?)?.toInt() ?? 0;
                                      final pct = (item['failure_rate_pct'] as num?)?.toDouble() ?? 0.0;
                                      final fraction = (pct / 100.0).clamp(0.0, 1.0);

                                      return Column(
                                        children: [
                                          if (idx > 0) const SizedBox(height: 14),
                                          _buildDefectRow(
                                            name,
                                            fraction,
                                            citation,
                                            '${pct.toStringAsFixed(0)}% ($count defect${count == 1 ? "" : "s"})',
                                          ),
                                        ],
                                      );
                                    }),
                                ],
                              ),
                      ),

                      const SizedBox(height: 24),

                      // Regulatory Framework Card
                      GlassContainer(
                        padding: const EdgeInsets.all(18),
                        borderRadius: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'ENFORCEMENT STATUTES',
                              style: TextStyle(
                                color: GlassTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Legal Metrology (Packaged Commodities) Rules, 2011',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• GSR 779(E) 2021 Amendments (Unit Sale Price & Country of Origin)\n• Jan Vishwas (Amendment of Provisions) Act, 2023 (Sec 36 & 49 compounding)\n• Schedule II Numeral Height & Laplacian Blur Forensic Admissibility Gate',
                              style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
              ),
              ),
      ),
    );
  }

  Widget _buildDefectRow(String title, double fraction, String clause, String frequency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Text(frequency, style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(
              fraction > 0 ? GlassTheme.criticalCrimson : _acc(GlassTheme.compliantCyan),
            ),
          ),
        ),
      ],
    );
  }
}
