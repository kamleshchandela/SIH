import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/glass_perf_service.dart';
import '../services/guided_session_service.dart';
import '../theme/glass_theme.dart';
import '../theme/sober_theme.dart';
import '../widgets/clause_tile.dart';
import '../widgets/glass/glass_container.dart';

/// One forced capture step of a guided session.
class GuidedStepDef {
  final String id;
  final String title;
  final String instruction;
  final IconData icon;

  const GuidedStepDef({
    required this.id,
    required this.title,
    required this.instruction,
    required this.icon,
  });
}

const List<GuidedStepDef> kGuidedSteps = [
  GuidedStepDef(
    id: 'quantity',
    title: 'Quantity panel',
    instruction: 'Frame the net quantity + nutrition block close-up.',
    icon: CupertinoIcons.cube_box_fill,
  ),
  GuidedStepDef(
    id: 'price',
    title: 'Price panel',
    instruction: 'Frame the MRP + inclusive-of-all-taxes print.',
    icon: CupertinoIcons.tag_fill,
  ),
  GuidedStepDef(
    id: 'date',
    title: 'Date stamp',
    instruction: 'Frame the MFD/PKD + origin print.',
    icon: CupertinoIcons.calendar,
  ),
  GuidedStepDef(
    id: 'back',
    title: 'Back panel',
    instruction: 'Frame the manufacturer address + consumer-care block.',
    icon: CupertinoIcons.building_2_fill,
  ),
];

/// Forced 4-step guided capture. Back-safe: session state lives in
/// GuidedSessionService, so leaving mid-verification never loses work —
/// return here to finish. The stop button abandons the session outright.
class GuidedScreen extends StatelessWidget {
  const GuidedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [GlassPerfService.instance, GuidedSessionService.instance]),
      builder: (context, _) {
        final sober = GlassPerfService.instance.soberMode;
        final session = GuidedSessionService.instance;
        return Scaffold(
          backgroundColor: sober ? SoberTheme.pageBg : Colors.transparent,
          appBar: AppBar(
            title: const Text('Guided inspection'),
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: 'Force-stop session',
                icon: const Icon(CupertinoIcons.stop_circle),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Stop inspection?'),
                      content: const Text(
                          'Abandons all captured steps. This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Keep going'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await GuidedSessionService.instance.stop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session stopped')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          body: session.sessionReport != null
              ? _SummaryView(sober: sober)
              : _StepperView(sober: sober),
        );
      },
    );
  }
}

class _StepperView extends StatelessWidget {
  final bool sober;
  const _StepperView({required this.sober});

  @override
  Widget build(BuildContext context) {
    final session = GuidedSessionService.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Row(
            children: [
              Icon(CupertinoIcons.viewfinder,
                  color: sober ? SoberTheme.accent : GlassTheme.compliantCyan),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Photograph each declaration close-up. You can leave mid-scan — verification continues.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < kGuidedSteps.length; i++)
          _StepCard(index: i, def: kGuidedSteps[i], sober: sober),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: session.canFinalize
                ? () async {
                    final ok = await session.finalize();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Verify or skip every step first (${session.decidedCount}/4 decided)')),
                      );
                    }
                  }
                : null,
            child: session.finalizing
                ? const SizedBox.square(
                    dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Finish inspection (${session.decidedCount}/4)'),
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final GuidedStepDef def;
  final bool sober;
  const _StepCard({required this.index, required this.def, required this.sober});

  Future<void> _capture(BuildContext context, ImageSource source,
      {bool multi = false}) async {
    final session = GuidedSessionService.instance;
    if (session.busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifying another step — please wait')),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      if (multi) {
        final picked = await picker.pickMultiImage();
        if (picked.isEmpty) return;
        await session.addPhotos(def.id, picked.map((e) => e.path).toList());
      } else {
        final picked = await picker.pickImage(source: source);
        if (picked == null) return;
        await session.addPhotos(def.id, [picked.path]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = GuidedSessionService.instance;
    final ui = session.steps[def.id]!;
    final Color stateColor;
    final String stateLabel;
    switch (ui.status) {
      case GuidedStepStatus.valid:
        stateColor = sober ? SoberTheme.pinGreen : GlassTheme.compliantCyan;
        stateLabel = 'Verified${ui.tokens > 0 ? ' · ${ui.tokens} tokens' : ''}';
        break;
      case GuidedStepStatus.invalid:
        stateColor = sober ? SoberTheme.pinRed : GlassTheme.criticalCrimson;
        stateLabel = 'Wrong photo — retake';
        break;
      case GuidedStepStatus.verifying:
        stateColor = sober ? SoberTheme.pinAmber : GlassTheme.moderateRiskAmber;
        stateLabel = 'Verifying… (safe to leave)';
        break;
      case GuidedStepStatus.skipped:
        stateColor = GlassTheme.textMuted;
        stateLabel = 'Skipped (scores zero)';
        break;
      case GuidedStepStatus.idle:
        stateColor = GlassTheme.textMuted;
        stateLabel = ui.photos.isEmpty ? 'No photo yet' : '${ui.photos.length} photo(s)';
        break;
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(def.icon, color: stateColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${index + 1}/4 · ${def.title}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(def.instruction,
                        style: TextStyle(color: GlassTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(stateLabel,
              style: TextStyle(
                  color: stateColor, fontSize: 12.5, fontWeight: FontWeight.w600)),
          if (ui.status == GuidedStepStatus.invalid && ui.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(ui.hint, style: TextStyle(color: stateColor, fontSize: 12)),
            ),
          if (ui.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ui.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(ui.photos[i]),
                      width: 64, height: 64, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: session.busy ? null : () => _capture(context, ImageSource.camera),
                icon: const Icon(CupertinoIcons.camera, size: 16),
                label: Text(ui.photos.isEmpty ? 'Capture' : 'Retake'),
              ),
              OutlinedButton.icon(
                onPressed:
                    session.busy ? null : () => _capture(context, ImageSource.gallery, multi: true),
                icon: const Icon(CupertinoIcons.photo, size: 16),
                label: const Text('Gallery'),
              ),
              if (ui.status == GuidedStepStatus.invalid)
                OutlinedButton.icon(
                  onPressed: session.busy ? null : () => session.retake(def.id),
                  icon: const Icon(CupertinoIcons.refresh, size: 16),
                  label: const Text('Clear'),
                ),
              TextButton(
                onPressed: session.busy ? null : () => session.toggleSkip(def.id),
                child: Text(ui.status == GuidedStepStatus.skipped ? 'Unskip' : 'Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final bool sober;
  const _SummaryView({required this.sober});

  @override
  Widget build(BuildContext context) {
    final session = GuidedSessionService.instance;
    final report = session.sessionReport!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(18),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${report.complianceScorePct.toStringAsFixed(1)}% · ${report.riskTier}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (sober ? SoberTheme.accent : GlassTheme.compliantCyan)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(report.captureMode.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in kGuidedSteps)
                    Chip(
                      label: Text(
                          '${s.id}: ${session.validity[s.id] == true ? 'verified' : 'skipped'}',
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final e in report.evaluations) ClauseTile(evaluation: e),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              GuidedSessionService.instance.resetForNew();
              Navigator.of(context).pop();
            },
            child: const Text('Done — saved to dossier'),
          ),
        ),
      ],
    );
  }
}
