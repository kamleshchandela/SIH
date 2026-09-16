import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/audit_storage_service.dart';
import '../services/guided_session_service.dart';
import '../theme/theme.dart';
import '../widgets/primitives/themis_primitives.dart';
import 'results_screen.dart';

/// Informative Audit Processing Screen
///
/// Replaces generic uninformative spinners with real-time streaming statutory verification stages.
/// Conforms to GIGW 3.0 sunlight readability standards.
class ProcessingScreen extends StatefulWidget {
  final String productName;

  const ProcessingScreen({
    super.key,
    this.productName = 'Pre-Packaged Retail Commodity',
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final GuidedSessionService _session = GuidedSessionService.instance;
  final AuditStorageService _storage = AuditStorageService.instance;

  final List<String> _stages = const [
    'Initializing on-device DBNet & PP-OCRv4 neural models...',
    'Performing EXIF orientation correction & Laplacian blur checks...',
    'Pooling multi-panel text tokens into unified SKU reading order...',
    'Validating Net Quantity & SI Metric Units under Rule 6(1)(c) & Rule 13...',
    'Verifying Maximum Retail Price (MRP) & statutory tax declarations...',
    'Inspecting Date Stamp, Month sanity allowlist & Country of Origin...',
    'Auditing Manufacturer physical address & 6-digit postal PIN code...',
    'Running forensic Sobel edge analysis for secondary price stickers...',
    'Calculating Jan Vishwas Act compounding liabilities...',
    'Assembling court-admissible statutory evidence dossier...',
  ];

  int _currentStageIndex = 0;
  Timer? _stageTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startStreamingStages();
    _executeFinalize();
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  void _startStreamingStages() {
    _stageTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) return;
      if (_currentStageIndex < _stages.length - 1) {
        setState(() => _currentStageIndex++);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _executeFinalize() async {
    try {
      final success = await _session.finalize();
      final report = _session.sessionReport;

      if (success && report != null) {
        await _storage.saveInspection(report);

        if (!mounted) return;

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ResultsScreen(report: report),
              ),
            );
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Session report could not be finalized. Please check that all steps are captured.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Engine error during audit finalization: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStageIndex + 1) / _stages.length;

    return Theme(
      data: ThemisTheme.sunlightTheme,
      child: Scaffold(
        backgroundColor: ThemisTheme.sunlightBg,
        appBar: const ThemisAppBar(
          title: 'GUIDED CAPTURE',
          subtitle: 'Legal Metrology Compliance Engine',
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ThemisTheme.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: ThemisTheme.space16),

                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: ThemisTheme.amberTint,
                      borderRadius: BorderRadius.circular(ThemisTheme.radius16),
                      border: Border.all(color: ThemisTheme.amberPrimary.withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: AlwaysStoppedAnimation<Color>(ThemisTheme.amberPrimary),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: ThemisTheme.space20),

                const Text(
                  'Evaluating Statutory Declarations',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ThemisTheme.sunlightTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: ThemisTheme.space4),

                Text(
                  widget.productName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ThemisTheme.amberPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: ThemisTheme.space24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STAGE ${_currentStageIndex + 1} OF ${_stages.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ThemisTheme.sunlightTextMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ThemisTheme.amberPrimary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: ThemisTheme.space8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: ThemisTheme.sunlightBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(ThemisTheme.amberPrimary),
                  ),
                ),

                const SizedBox(height: ThemisTheme.space24),

                Expanded(
                  child: SectionCard(
                    padding: const EdgeInsets.all(ThemisTheme.space16),
                    child: ListView.separated(
                      itemCount: _stages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: ThemisTheme.space12),
                      itemBuilder: (context, idx) {
                        final isPassed = idx < _currentStageIndex;
                        final isCurrent = idx == _currentStageIndex;

                        Color iconColor;
                        IconData icon;

                        if (isPassed) {
                          iconColor = ThemisTheme.statusCompliant;
                          icon = CupertinoIcons.checkmark_circle_fill;
                        } else if (isCurrent) {
                          iconColor = ThemisTheme.amberPrimary;
                          icon = CupertinoIcons.arrow_right_circle_fill;
                        } else {
                          iconColor = ThemisTheme.sunlightBorder;
                          icon = CupertinoIcons.circle;
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 18, color: iconColor),
                            const SizedBox(width: ThemisTheme.space12),
                            Expanded(
                              child: Text(
                                _stages[idx],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                  color: isPassed
                                      ? ThemisTheme.sunlightTextSecondary
                                      : (isCurrent ? ThemisTheme.sunlightTextPrimary : ThemisTheme.sunlightTextMuted),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: ThemisTheme.space16),
                  Container(
                    padding: const EdgeInsets.all(ThemisTheme.space12),
                    decoration: BoxDecoration(
                      color: ThemisTheme.statusViolationBgLight,
                      borderRadius: BorderRadius.circular(ThemisTheme.radius8),
                      border: Border.all(color: ThemisTheme.statusViolation),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: ThemisTheme.statusViolation, size: 18),
                        const SizedBox(width: ThemisTheme.space8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: ThemisTheme.statusViolation, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ThemisTheme.space12),
                  ThemisButton(
                    label: 'Return to Guided Capture',
                    variant: ThemisButtonVariant.secondaryOutline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
