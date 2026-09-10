import 'dart:convert';
import 'dart:typed_data';
import '../models/compliance_report.dart';

/// Pure Dart offline CSV Statutory Compliance Audit Exporter.
class StatutoryNoticeCsvService {
  StatutoryNoticeCsvService._();

  /// Generates UTF-8 CSV bytes for the given [ComplianceReport].
  static Uint8List generate(ComplianceReport report) {
    final sb = StringBuffer();

    // CSV Header
    sb.writeln('Inspection ID,Timestamp,Product Name,Overall Compliant,Risk Tier,Compliance Score (%),Total Violations,Compounding Fine (INR),Field,Clause,Status,Remarks');

    final safeId = _csvEscape(report.inspectionId);
    final safeTime = _csvEscape(report.timestamp);
    final safeProduct = _csvEscape(report.productName ?? 'Pre-packaged Commodity');
    final compliant = report.overallCompliant ? 'TRUE' : 'FALSE';
    final riskTier = _csvEscape(report.riskTierFormatted);
    final score = report.complianceScorePct.toStringAsFixed(1);
    final totalViolations = report.violations.totalViolations.toString();
    final fineInr = report.violations.totalFineInr.toString();

    if (report.evaluations.isEmpty) {
      sb.writeln('$safeId,$safeTime,$safeProduct,$compliant,$riskTier,$score,$totalViolations,$fineInr,"N/A","N/A","N/A","No statutory evaluation items"');
    } else {
      for (final eval in report.evaluations) {
        final field = _csvEscape(eval.field);
        final clause = _csvEscape(eval.clause);
        final status = _csvEscape(eval.status.toUpperCase());
        final remarks = _csvEscape(eval.remarks);

        sb.writeln('$safeId,$safeTime,$safeProduct,$compliant,$riskTier,$score,$totalViolations,$fineInr,$field,$clause,$status,$remarks');
      }
    }

    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  static String _csvEscape(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
      final escaped = val.replaceAll('"', '""');
      return '"$escaped"';
    }
    return val;
  }
}
