import 'package:flutter/foundation.dart';

import '../models/compliance_report.dart';
import 'dev_logger.dart';
import 'themis_api.dart';

/// Per-step UI state for a guided session.
enum GuidedStepStatus { idle, verifying, valid, invalid, skipped }

class GuidedStepState {
  final List<String> photos = [];
  GuidedStepStatus status = GuidedStepStatus.idle;
  int tokens = 0;
  String hint = '';
}

/// Singleton session state for guided capture. Outlives GuidedScreen: the
/// user can press back mid-verification, explore the app, and return — the
/// in-flight isolate keeps running and the result lands here (generation
/// guard drops stale completions after a force-stop).
class GuidedSessionService extends ChangeNotifier {
  static final GuidedSessionService instance = GuidedSessionService._internal();
  GuidedSessionService._internal();

  final ThemisApiService _api = ThemisApiService();

  final Map<String, GuidedStepState> steps = {
    'quantity': GuidedStepState(),
    'price': GuidedStepState(),
    'date': GuidedStepState(),
    'back': GuidedStepState(),
  };

  int _generation = 0;
  bool _finalizing = false;
  bool get finalizing => _finalizing;

  ComplianceReport? sessionReport;
  Map<String, dynamic> validity = {};

  /// True while any verification or finalize is in flight: the bridge
  /// serializes native scans, so no other submit may start.
  bool get busy =>
      _finalizing || steps.values.any((u) => u.status == GuidedStepStatus.verifying);

  bool get canFinalize =>
      !busy &&
      steps.values.every((u) =>
          u.status == GuidedStepStatus.valid || u.status == GuidedStepStatus.skipped);

  int get decidedCount => steps.values
      .where((u) =>
          u.status == GuidedStepStatus.valid || u.status == GuidedStepStatus.skipped)
      .length;

  /// Append captures to a step and verify. Safe to call and walk away from:
  /// late results are dropped if a stop happened meanwhile.
  Future<void> addPhotos(String stepId, List<String> paths) async {
    final ui = steps[stepId];
    if (ui == null || paths.isEmpty) return;
    if (busy) return;
    ui.photos.addAll(paths);
    if (ui.status == GuidedStepStatus.skipped) ui.status = GuidedStepStatus.idle;
    await submitStep(stepId);
  }

  Future<void> submitStep(String stepId) async {
    final ui = steps[stepId];
    if (ui == null || ui.photos.isEmpty || busy) return;
    final gen = _generation;
    ui.status = GuidedStepStatus.verifying;
    ui.hint = '';
    notifyListeners();
    try {
      final res = await _api.submitGuidedStep(stepId: stepId, imagePaths: ui.photos);
      if (gen != _generation) return; // Stopped meanwhile: drop.
      ui.tokens = (res['tokens'] as num? ?? 0).toInt();
      ui.hint = (res['hint'] as String? ?? '').trim();
      ui.status = (res['valid'] == true) ? GuidedStepStatus.valid : GuidedStepStatus.invalid;
    } catch (e, st) {
      if (gen != _generation) return;
      DevLogger.instance.error('GUIDED', 'Step $stepId submit failed: $e');
      DevLogger.instance.error('STACK', st.toString().split('\n').take(3).join(' | '));
      ui.status = GuidedStepStatus.idle;
      ui.hint = e.toString();
    }
    notifyListeners();
  }

  void retake(String stepId) {
    if (busy) return;
    final ui = steps[stepId];
    if (ui == null) return;
    ui
      ..photos.clear()
      ..tokens = 0
      ..hint = ''
      ..status = GuidedStepStatus.idle;
    notifyListeners();
  }

  void toggleSkip(String stepId) {
    if (busy) return;
    final ui = steps[stepId];
    if (ui == null) return;
    if (ui.status == GuidedStepStatus.skipped) {
      ui.status = ui.photos.isEmpty ? GuidedStepStatus.idle : GuidedStepStatus.invalid;
      notifyListeners();
      if (ui.photos.isNotEmpty) submitStep(stepId);
    } else {
      ui.status = GuidedStepStatus.skipped;
      notifyListeners();
    }
  }

  Future<bool> finalize() async {
    if (!canFinalize) return false;
    final gen = _generation;
    _finalizing = true;
    notifyListeners();
    try {
      final res = await _api.finalizeGuidedSession();
      if (gen != _generation) return false;
      sessionReport = res.report;
      validity = res.validity;
      return true;
    } catch (e, st) {
      if (gen != _generation) return false;
      DevLogger.instance.error('GUIDED', 'Finalize failed: $e');
      DevLogger.instance.error('STACK', st.toString().split('\n').take(3).join(' | '));
      return false;
    } finally {
      if (gen == _generation) {
        _finalizing = false;
        notifyListeners();
      }
    }
  }

  /// Force-stop: abandon in-flight work, clear the native cache, reset all
  /// steps. Late isolate results are dropped by the generation guard.
  Future<void> stop() async {
    _generation++;
    _finalizing = false;
    for (final ui in steps.values) {
      ui
        ..photos.clear()
        ..tokens = 0
        ..hint = ''
        ..status = GuidedStepStatus.idle;
    }
    sessionReport = null;
    validity = {};
    notifyListeners();
    try {
      await _api.resetGuidedSession();
    } catch (_) {}
    DevLogger.instance.warn('GUIDED', 'Session force-stopped by user.');
  }

  /// Fresh session after a completed one (keeps the singleton alive).
  void resetForNew() {
    _generation++;
    _finalizing = false;
    for (final ui in steps.values) {
      ui
        ..photos.clear()
        ..tokens = 0
        ..hint = ''
        ..status = GuidedStepStatus.idle;
    }
    sessionReport = null;
    validity = {};
    notifyListeners();
    _api.resetGuidedSession().catchError((_) {});
  }
}
