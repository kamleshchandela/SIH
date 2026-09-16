import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/audit_storage_service.dart';
import '../theme/theme.dart';
import '../widgets/primitives/themis_primitives.dart';
import 'guided_screen.dart';
import 'inspect_screen.dart';

/// Themis Home Screen
///
/// Default primary landing view for Legal Metrology enforcement officers.
/// Built in Sunlight Light Theme for high-visibility outdoor retail market use.
class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuditStorageService _storage = AuditStorageService.instance;

  @override
  void initState() {
    super.initState();
    _storage.addListener(_onStorageUpdated);
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageUpdated);
    super.dispose();
  }

  void _onStorageUpdated() {
    if (mounted) setState(() {});
  }

  void _startGuidedScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuidedScreen(),
      ),
    );
  }

  void _startSpotCheck() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: InspectScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspections = _storage.allInspections;
    final totalScans = inspections.length;
    final totalViolations = inspections.where((item) {
      final tier = (item['risk_tier'] as String?)?.toLowerCase() ?? '';
      return tier.contains('critical') || tier.contains('high') || tier.contains('violation');
    }).length;

    // Compounding fines aggregate
    int totalFines = 0;
    for (final item in inspections) {
      final fines = item['compoundable_fines_inr'];
      if (fines is int) {
        totalFines += fines;
      } else if (fines is num) {
        totalFines += fines.toInt();
      }
    }

    final recentInspections = inspections.take(3).toList();

    return Theme(
      data: ThemisTheme.sunlightTheme,
      child: Scaffold(
        backgroundColor: ThemisTheme.sunlightBg,
        appBar: ThemisAppBar(
          title: 'THEMIS',
          subtitle: 'Directorate of Legal Metrology',
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.bell, size: 20, color: ThemisTheme.sunlightTextSecondary),
              tooltip: 'Advisories',
              onPressed: () {},
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: ThemisTheme.space16,
              vertical: ThemisTheme.space20,
            ),
            children: [
              // 1. Officer Shift & Session Greeting Banner
              Container(
                padding: const EdgeInsets.all(ThemisTheme.space16),
                decoration: BoxDecoration(
                  color: ThemisTheme.sunlightSurface,
                  borderRadius: BorderRadius.circular(ThemisTheme.radius8),
                  border: Border.all(color: ThemisTheme.sunlightBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ThemisTheme.amberTint,
                        borderRadius: BorderRadius.circular(ThemisTheme.radius8),
                        border: Border.all(color: ThemisTheme.amberPrimary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_badge_plus_fill,
                        color: ThemisTheme.amberPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: ThemisTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enforcement Officer on Duty',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ThemisTheme.amberPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: ThemisTheme.space2),
                          const Text(
                            'Retail Compliance Audit Session',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ThemisTheme.sunlightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: ThemisTheme.space2),
                          Text(
                            'Legal Metrology (Packaged Commodities) Rules, 2011',
                            style: TextStyle(
                              fontSize: 12,
                              color: ThemisTheme.sunlightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: ThemisTheme.space16),

              // 2. Today's Stat Summary — 4 Compact Metric Cards (2x2 Grid)
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Total Audits',
                      value: '$totalScans',
                      subtitle: totalScans == 0 ? 'No scans today' : 'Recorded in dossier',
                      icon: CupertinoIcons.cube_box,
                      accentColor: ThemisTheme.sunlightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: ThemisTheme.space12),
                  Expanded(
                    child: MetricCard(
                      label: 'Violations',
                      value: '$totalViolations',
                      subtitle: 'Sec 36(1) notices',
                      icon: CupertinoIcons.exclamationmark_octagon,
                      accentColor: totalViolations > 0 ? ThemisTheme.statusViolation : ThemisTheme.statusCompliant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ThemisTheme.space12),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Fines Assessed',
                      value: totalFines > 0 ? '₹${(totalFines / 1000).toStringAsFixed(1)}k' : '₹0',
                      subtitle: 'Jan Vishwas compounding',
                      icon: CupertinoIcons.money_dollar_circle,
                      accentColor: totalFines > 0 ? ThemisTheme.amberPrimary : ThemisTheme.sunlightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: ThemisTheme.space12),
                  Expanded(
                    child: MetricCard(
                      label: 'Active Engine',
                      value: 'INT8 Edge',
                      subtitle: '0 MB VRAM offline',
                      icon: CupertinoIcons.bolt_fill,
                      accentColor: ThemisTheme.statusCompliant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: ThemisTheme.space24),

              // 3. Large Primary CTA: START GUIDED SCAN (56dp+ height)
              ThemisButton(
                label: 'START GUIDED SCAN (4 STEPS)',
                leadingIcon: CupertinoIcons.viewfinder_circle_fill,
                isPrimaryCTA: true,
                onPressed: _startGuidedScan,
              ),

              const SizedBox(height: ThemisTheme.space12),

              // Secondary Action: Quick Spot Check
              ThemisButton(
                label: 'Single-Panel Quick Spot Check',
                leadingIcon: CupertinoIcons.camera_fill,
                variant: ThemisButtonVariant.secondaryOutline,
                onPressed: _startSpotCheck,
              ),

              const SizedBox(height: ThemisTheme.space24),

              // 4. Recent Audited Commodities Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT FIELD AUDITS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ThemisTheme.sunlightTextMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (inspections.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        widget.onNavigateTab?.call(1); // Jump to Dossier tab
                      },
                      child: const Text(
                        'View All →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ThemisTheme.amberPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: ThemisTheme.space8),

              if (recentInspections.isEmpty) ...[
                SectionCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: ThemisTheme.space24),
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.doc_text_search,
                          size: 40,
                          color: ThemisTheme.sunlightTextMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: ThemisTheme.space12),
                        const Text(
                          'No Inspections Recorded Yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ThemisTheme.sunlightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: ThemisTheme.space4),
                        Text(
                          'Tap "START GUIDED SCAN" above to inspect a product packaging label.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: ThemisTheme.sunlightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...recentInspections.map((item) {
                  final name = (item['product_name'] as String?)?.trim();
                  final title = (name != null && name.isNotEmpty) ? name : 'Packaged Commodity ${item['id'] ?? ''}';
                  final tierStr = (item['risk_tier'] as String?) ?? 'Compliant';
                  final score = item['score_percentage'];
                  final scoreStr = score != null ? '${(score as num).toStringAsFixed(0)}%' : '--';
                  final timestamp = (item['timestamp'] as String?) ?? '';
                  final timeSnippet = timestamp.length >= 16 ? timestamp.substring(11, 16) : '';

                  StatutoryStatus status;
                  if (tierStr.toLowerCase().contains('compliant')) {
                    status = StatutoryStatus.compliant;
                  } else if (tierStr.toLowerCase().contains('warning') || tierStr.toLowerCase().contains('low')) {
                    status = StatutoryStatus.warning;
                  } else {
                    status = StatutoryStatus.violation;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: ThemisTheme.space8),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ThemisTheme.space16,
                        vertical: ThemisTheme.space12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: ThemisTheme.sunlightSurfaceElevated,
                              borderRadius: BorderRadius.circular(ThemisTheme.radius8),
                              border: Border.all(color: ThemisTheme.sunlightBorder),
                            ),
                            child: const Icon(
                              CupertinoIcons.cube_box,
                              size: 20,
                              color: ThemisTheme.sunlightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: ThemisTheme.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: ThemisTheme.sunlightTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: ThemisTheme.space2),
                                Text(
                                  'Score: $scoreStr ${timeSnippet.isNotEmpty ? "• $timeSnippet" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ThemisTheme.sunlightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatutoryBadge(
                            status: status,
                            customLabel: tierStr.toUpperCase(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
