import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/guided_session_service.dart';
import '../theme/theme.dart';
import '../widgets/primitives/themis_primitives.dart';
import 'processing_screen.dart';

/// Statutory Guided Capture Step Specification
class GuidedStepDef {
  final String id;
  final String title;
  final String instruction;
  final String legalCitation;
  final IconData icon;

  const GuidedStepDef({
    required this.id,
    required this.title,
    required this.instruction,
    required this.legalCitation,
    required this.icon,
  });
}

const List<GuidedStepDef> kGuidedSteps = [
  GuidedStepDef(
    id: 'quantity',
    title: 'Quantity Panel',
    instruction: 'Frame the net quantity and nutrition block close-up.',
    legalCitation: 'Rule 6(1)(c) & Rule 13 (Net Weight / Metric Units)',
    icon: CupertinoIcons.cube_box_fill,
  ),
  GuidedStepDef(
    id: 'price',
    title: 'Price Panel',
    instruction: 'Frame the MRP and inclusive-of-all-taxes print.',
    legalCitation: 'Rule 6(1)(e) & Rule 6(1)(f) (MRP & Unit Sale Price)',
    icon: CupertinoIcons.tag_fill,
  ),
  GuidedStepDef(
    id: 'date',
    title: 'Date Stamp',
    instruction: 'Frame the MFD/PKD date stamp and country of origin.',
    legalCitation: 'Rule 6(1)(d) & Rule 6(1)(da) (Mfg Date & Origin)',
    icon: CupertinoIcons.calendar,
  ),
  GuidedStepDef(
    id: 'back',
    title: 'Back Panel',
    instruction: 'Frame the manufacturer address and consumer-care block.',
    legalCitation: 'Rule 6(1)(a) & Rule 6(1)(g) (Address & Grievance)',
    icon: CupertinoIcons.building_2_fill,
  ),
];

/// Rebuilt Guided Screen
///
/// Follows official GIGW 3.0 outdoor sunlight design principles:
/// - Light theme by default for outdoor retail market visibility.
/// - Clear 'Step X of 4' progress indicator.
/// - Minimal chrome viewfinder view.
/// - Standard bottom-center camera capture button (64dp touch target).
/// - Instant photo review with Retake vs Confirm before submission.
/// - Constructive on-device hints when legal text is missing.
class GuidedScreen extends StatefulWidget {
  const GuidedScreen({super.key});

  @override
  State<GuidedScreen> createState() => _GuidedScreenState();
}

class _GuidedScreenState extends State<GuidedScreen> {
  final GuidedSessionService _session = GuidedSessionService.instance;
  final ImagePicker _picker = ImagePicker();

  int _currentStepIndex = 0;
  String? _pendingPhotoPath;

  GuidedStepDef get _currentStep => kGuidedSteps[_currentStepIndex];

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionUpdated);
    // Find first unfinished step
    for (int i = 0; i < kGuidedSteps.length; i++) {
      final st = _session.steps[kGuidedSteps[i].id]?.status;
      if (st != GuidedStepStatus.valid && st != GuidedStepStatus.skipped) {
        _currentStepIndex = i;
        break;
      }
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionUpdated);
    super.dispose();
  }

  void _onSessionUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (picked != null) {
        setState(() {
          _pendingPhotoPath = picked.path;
        });
      }
    } catch (e) {
      _showToast('Camera error: $e');
    }
  }

  void _confirmPendingPhoto() {
    if (_pendingPhotoPath == null) return;
    final path = _pendingPhotoPath!;
    setState(() => _pendingPhotoPath = null);
    _session.addPhotos(_currentStep.id, [path]);
  }

  void _retakePendingPhoto() {
    setState(() => _pendingPhotoPath = null);
  }

  void _skipCurrentStep() {
    _session.toggleSkip(_currentStep.id);
    _advanceToNextUnfinished();
  }

  void _advanceToNextUnfinished() {
    if (_currentStepIndex < kGuidedSteps.length - 1) {
      setState(() => _currentStepIndex++);
    }
  }

  Future<void> _forceStopSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemisTheme.sunlightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemisTheme.radius12),
          side: const BorderSide(color: ThemisTheme.sunlightBorder),
        ),
        title: const Text(
          'Stop Inspection Session?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ThemisTheme.sunlightTextPrimary,
          ),
        ),
        content: const Text(
          'This will discard all captured steps for this commodity. This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: ThemisTheme.sunlightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Resume Inspection', style: TextStyle(color: ThemisTheme.amberPrimary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abandon', style: TextStyle(color: ThemisTheme.statusViolation, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _session.stop();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _goToProcessingAndResults() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ProcessingScreen(),
      ),
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: ThemisTheme.sunlightTextPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepDef = _currentStep;
    final stepState = _session.steps[stepDef.id] ?? GuidedStepState();
    final isBusy = _session.busy;
    final isAllDone = _session.canFinalize;

    return Theme(
      data: ThemisTheme.sunlightTheme,
      child: Scaffold(
        backgroundColor: ThemisTheme.sunlightBg,
        appBar: ThemisAppBar(
          title: 'GUIDED INSPECTION',
          subtitle: 'Step ${_currentStepIndex + 1} of 4: ${stepDef.title}',
          roleBadge: 'ACTIVE SESSION',
          isOffline: true,
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.stop_circle, size: 22, color: ThemisTheme.statusViolation),
              tooltip: 'Stop session',
              onPressed: _forceStopSession,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. High-Visibility Step Progress Stepper (1 to 4)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ThemisTheme.space16,
                  vertical: ThemisTheme.space12,
                ),
                color: ThemisTheme.sunlightSurface,
                child: Row(
                  children: List.generate(kGuidedSteps.length, (idx) {
                    final item = kGuidedSteps[idx];
                    final st = _session.steps[item.id]?.status ?? GuidedStepStatus.idle;
                    final isCurrent = idx == _currentStepIndex;

                    Color dotColor;
                    Widget iconWidget;

                    if (st == GuidedStepStatus.valid) {
                      dotColor = ThemisTheme.statusCompliant;
                      iconWidget = const Icon(CupertinoIcons.checkmark, size: 12, color: Colors.white);
                    } else if (st == GuidedStepStatus.skipped) {
                      dotColor = ThemisTheme.statusNeutral;
                      iconWidget = const Icon(CupertinoIcons.minus, size: 12, color: Colors.white);
                    } else if (st == GuidedStepStatus.invalid) {
                      dotColor = ThemisTheme.statusViolation;
                      iconWidget = const Icon(CupertinoIcons.exclamationmark, size: 12, color: Colors.white);
                    } else if (isCurrent) {
                      dotColor = ThemisTheme.amberPrimary;
                      iconWidget = Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white));
                    } else {
                      dotColor = ThemisTheme.sunlightBorder;
                      iconWidget = Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemisTheme.sunlightTextMuted));
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: isBusy ? null : () => setState(() => _currentStepIndex = idx),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                                border: isCurrent ? Border.all(color: ThemisTheme.sunlightTextPrimary, width: 2) : null,
                              ),
                              child: Center(child: iconWidget),
                            ),
                            const SizedBox(width: ThemisTheme.space4),
                            Expanded(
                              child: Text(
                                item.title.split(' ')[0],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                  color: isCurrent ? ThemisTheme.sunlightTextPrimary : ThemisTheme.sunlightTextMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (idx < kGuidedSteps.length - 1)
                              Container(
                                width: 10,
                                height: 1.5,
                                color: ThemisTheme.sunlightBorder,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const Divider(height: 1),

              // 2. Central Viewfinder / Pending Photo Review Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(ThemisTheme.space16),
                  child: _pendingPhotoPath != null
                      ? _buildPendingReviewCard(_pendingPhotoPath!)
                      : _buildViewfinderGuidanceCard(stepDef, stepState, isBusy),
                ),
              ),

              // 3. Bottom Control Bar (Shutter Button / Actions)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ThemisTheme.space16,
                  vertical: ThemisTheme.space16,
                ),
                decoration: const BoxDecoration(
                  color: ThemisTheme.sunlightSurface,
                  border: Border(top: BorderSide(color: ThemisTheme.sunlightBorder, width: 1)),
                ),
                child: _pendingPhotoPath != null
                    ? _buildPendingActionBar()
                    : _buildCaptureActionBar(stepState, isBusy, isAllDone),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinderGuidanceCard(
    GuidedStepDef stepDef,
    GuidedStepState stepState,
    bool isBusy,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: ThemisTheme.sunlightSurface,
        borderRadius: BorderRadius.circular(ThemisTheme.radius12),
        border: Border.all(color: ThemisTheme.sunlightBorder, width: 1.5),
      ),
      child: Stack(
        children: [
          if (stepState.photos.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThemisTheme.radius12),
                child: Image.file(
                  File(stepState.photos.last),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ThemisTheme.amberTint,
                      borderRadius: BorderRadius.circular(ThemisTheme.radius16),
                      border: Border.all(color: ThemisTheme.amberPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(stepDef.icon, size: 36, color: ThemisTheme.amberPrimary),
                  ),
                  const SizedBox(height: ThemisTheme.space16),
                  Text(
                    stepDef.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ThemisTheme.sunlightTextPrimary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: ThemisTheme.space8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space32),
                    child: Text(
                      stepDef.instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ThemisTheme.sunlightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: ThemisTheme.space8),
                  Text(
                    stepDef.legalCitation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: ThemisTheme.amberPrimary,
                    ),
                  ),
                ],
              ),
            ),

          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(ThemisTheme.space24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: ThemisTheme.amberPrimary.withValues(alpha: 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(ThemisTheme.radius8),
              ),
            ),
          ),

          Positioned(
            top: ThemisTheme.space12,
            left: ThemisTheme.space12,
            right: ThemisTheme.space12,
            child: _buildStepStatusBanner(stepState, isBusy),
          ),
        ],
      ),
    );
  }

  Widget _buildStepStatusBanner(GuidedStepState stepState, bool isBusy) {
    if (isBusy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space12, vertical: ThemisTheme.space8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(ThemisTheme.radius8),
          border: Border.all(color: ThemisTheme.amberPrimary),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: ThemisTheme.amberPrimary),
            ),
            SizedBox(width: ThemisTheme.space8),
            Text(
              'Running on-device neural verification...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemisTheme.sunlightTextPrimary),
            ),
          ],
        ),
      );
    }

    if (stepState.status == GuidedStepStatus.valid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space12, vertical: ThemisTheme.space8),
        decoration: BoxDecoration(
          color: ThemisTheme.statusCompliantBgLight.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(ThemisTheme.radius8),
          border: Border.all(color: ThemisTheme.statusCompliant),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_circle_fill, size: 16, color: ThemisTheme.statusCompliant),
            const SizedBox(width: ThemisTheme.space8),
            Text(
              'Verified: ${stepState.tokens} tokens detected on panel',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThemisTheme.statusCompliant),
            ),
          ],
        ),
      );
    }

    if (stepState.status == GuidedStepStatus.invalid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: ThemisTheme.space12, vertical: ThemisTheme.space8),
        decoration: BoxDecoration(
          color: ThemisTheme.statusViolationBgLight.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(ThemisTheme.radius8),
          border: Border.all(color: ThemisTheme.statusViolation),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle_fill, size: 16, color: ThemisTheme.statusViolation),
            const SizedBox(width: ThemisTheme.space8),
            Expanded(
              child: Text(
                stepState.hint.isNotEmpty ? stepState.hint : 'No matching text found. Frame print steadily.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemisTheme.statusViolation),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPendingReviewCard(String photoPath) {
    return Container(
      decoration: BoxDecoration(
        color: ThemisTheme.sunlightSurface,
        borderRadius: BorderRadius.circular(ThemisTheme.radius12),
        border: Border.all(color: ThemisTheme.amberPrimary, width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ThemisTheme.radius12),
            child: Image.file(
              File(photoPath),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: ThemisTheme.space16,
            left: ThemisTheme.space16,
            right: ThemisTheme.space16,
            child: Container(
              padding: const EdgeInsets.all(ThemisTheme.space12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(ThemisTheme.radius8),
                border: Border.all(color: ThemisTheme.sunlightBorder),
              ),
              child: const Text(
                'Review Photo: Ensure legal declarations and numbers are crisp and glare-free before verifying.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ThemisTheme.sunlightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActionBar() {
    return Row(
      children: [
        Expanded(
          child: ThemisButton(
            label: 'Retake Photo',
            leadingIcon: CupertinoIcons.arrow_counterclockwise,
            variant: ThemisButtonVariant.secondaryOutline,
            onPressed: _retakePendingPhoto,
          ),
        ),
        const SizedBox(width: ThemisTheme.space12),
        Expanded(
          child: ThemisButton(
            label: 'Confirm & Verify',
            leadingIcon: CupertinoIcons.checkmark_alt,
            isPrimaryCTA: true,
            onPressed: _confirmPendingPhoto,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureActionBar(
    GuidedStepState stepState,
    bool isBusy,
    bool isAllDone,
  ) {
    if (isAllDone) {
      return ThemisButton(
        label: 'COMPLETE & GENERATE VERDICT DOSSIER →',
        leadingIcon: CupertinoIcons.doc_checkmark_fill,
        isPrimaryCTA: true,
        onPressed: _goToProcessingAndResults,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(CupertinoIcons.forward, size: 16, color: ThemisTheme.sunlightTextMuted),
              label: const Text('Skip Panel', style: TextStyle(color: ThemisTheme.sunlightTextMuted, fontSize: 13)),
              onPressed: isBusy ? null : _skipCurrentStep,
            ),
            if (stepState.status == GuidedStepStatus.valid && _currentStepIndex < kGuidedSteps.length - 1)
              TextButton.icon(
                icon: const Text('Next Step', style: TextStyle(color: ThemisTheme.amberPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                label: const Icon(CupertinoIcons.arrow_right, size: 16, color: ThemisTheme.amberPrimary),
                onPressed: isBusy ? null : _advanceToNextUnfinished,
              ),
          ],
        ),
        const SizedBox(height: ThemisTheme.space8),
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: ThemisTheme.sunlightSurfaceElevated,
                borderRadius: BorderRadius.circular(ThemisTheme.radius12),
                border: Border.all(color: ThemisTheme.sunlightBorder),
              ),
              child: IconButton(
                icon: const Icon(CupertinoIcons.photo_fill, color: ThemisTheme.sunlightTextSecondary, size: 22),
                tooltip: 'Choose from files',
                onPressed: isBusy ? null : () => _capturePhoto(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: ThemisTheme.space12),
            Expanded(
              child: ThemisButton(
                label: stepState.status == GuidedStepStatus.valid ? 'RETAKE STEP PHOTO' : 'CAPTURE STEP PHOTO',
                leadingIcon: CupertinoIcons.camera_fill,
                isPrimaryCTA: true,
                isLoading: isBusy,
                onPressed: isBusy ? null : () => _capturePhoto(ImageSource.camera),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
