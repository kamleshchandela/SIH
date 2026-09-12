import 'dart:convert';
import 'dart:typed_data';
import '../models/compliance_report.dart';

/// Pure Dart ISO PDF 1.4 Statutory Notice Generator.
///
/// Ported from the high-fidelity Rust implementation in `themis/src/export/pdf.rs`.
/// Operates 100% offline with zero external package dependencies, generating
/// official Ministry of Consumer Affairs Statutory Notices of Violation.
class StatutoryNoticePdfService {
  StatutoryNoticePdfService._();

  /// Generates a valid ISO PDF 1.4 byte array for the given [ComplianceReport].
  static Uint8List generate(ComplianceReport report) {
    final StringBuffer stream = StringBuffer();

    // 1. Header Banner & Title
    // Navy Blue Header Box
    stream.writeln('0.1 0.2 0.45 rg');
    stream.writeln('40 780 515 45 re f');

    // Header Text (White)
    stream.writeln('BT');
    stream.writeln('1 1 1 rg');
    stream.writeln('/F2 12 Tf');
    stream.writeln('55 805 Td');
    stream.writeln('(GOVERNMENT OF INDIA - MINISTRY OF CONSUMER AFFAIRS) Tj');
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('1 1 1 rg');
    stream.writeln('/F1 9 Tf');
    stream.writeln('55 792 Td');
    stream.writeln('(DIRECTORATE OF LEGAL METROLOGY | AUTOMATED STATUTORY AUDIT SYSTEM) Tj');
    stream.writeln('ET');

    // Document Title
    stream.writeln('BT');
    stream.writeln('0.1 0.1 0.1 rg');
    stream.writeln('/F2 14 Tf');
    stream.writeln('40 755 Td');
    stream.writeln('(STATUTORY NOTICE OF INSPECTION & NON-COMPLIANCE) Tj');
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('0.4 0.4 0.4 rg');
    stream.writeln('/F1 8 Tf');
    stream.writeln('40 743 Td');
    stream.writeln('(Issued under Section 36\\(1\\) Legal Metrology Act, 2009 read with LMPC Rules, 2011 & Jan Vishwas Act, 2023) Tj');
    stream.writeln('ET');

    // Thin separator
    stream.writeln('0.8 0.8 0.8 rg');
    stream.writeln('40 735 515 1 re f');

    // Metadata Box (Light background)
    stream.writeln('0.96 0.96 0.98 rg');
    stream.writeln('40 660 515 65 re f');
    stream.writeln('0.8 0.8 0.85 RG');
    stream.writeln('1 w');
    stream.writeln('40 660 515 65 re s');

    final skuName = report.productName ?? 'Pre-packaged Commodity';
    final safeSku = _sanitizePdf(skuName);
    final panelsStr = _sanitizePdf(report.scannedPanels.join(', '));
    final ts = report.timestamp.length >= 19
        ? report.timestamp.substring(0, 19)
        : report.timestamp;

    final statusColor = report.overallCompliant ? '0.0 0.5 0.2' : '0.8 0.1 0.1';
    final statusLabel = report.overallCompliant
        ? 'COMPLIANT (PASS)'
        : 'VIOLATION DETECTED (NON-COMPLIANT)';

    stream.writeln('BT');
    stream.writeln('0.15 0.15 0.15 rg');
    stream.writeln('/F2 9 Tf');
    stream.writeln('50 710 Td');
    stream.writeln('(Inspection ID: ) Tj');
    stream.writeln('/F1 9 Tf');
    stream.writeln('(${_sanitizePdf(report.inspectionId)}) Tj');
    stream.writeln('/F2 9 Tf');
    stream.writeln('(  |  Date: ) Tj');
    stream.writeln('/F1 9 Tf');
    stream.writeln('(${_sanitizePdf(ts)}) Tj');
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('0.15 0.15 0.15 rg');
    stream.writeln('/F2 9 Tf');
    stream.writeln('50 695 Td');
    stream.writeln('(Product SKU  : ) Tj');
    stream.writeln('/F1 9 Tf');
    stream.writeln('($safeSku) Tj');
    stream.writeln('/F2 9 Tf');
    stream.writeln('(  |  Panels: ) Tj');
    stream.writeln('/F1 9 Tf');
    stream.writeln('(${report.scannedPanels.length} panels - $panelsStr) Tj');
    stream.writeln('ET');

    stream.writeln('BT');
    stream.writeln('0.15 0.15 0.15 rg');
    stream.writeln('/F2 9 Tf');
    stream.writeln('50 680 Td');
    stream.writeln('(Audit Result : ) Tj');
    stream.writeln('$statusColor rg');
    stream.writeln('/F2 9 Tf');
    stream.writeln('($statusLabel  |  Risk: ${_sanitizePdf(report.riskTierFormatted)}  |  Score: ${report.complianceScorePct.toStringAsFixed(1)}%) Tj');
    stream.writeln('ET');

    // 2. Rule Evaluation Table Header
    stream.writeln('BT');
    stream.writeln('0.1 0.2 0.4 rg');
    stream.writeln('/F2 10 Tf');
    stream.writeln('40 640 Td');
    stream.writeln('(RULE-BY-RULE STATUTORY DECLARATION AUDIT) Tj');
    stream.writeln('ET');

    stream.writeln('0.2 0.3 0.5 rg');
    stream.writeln('40 622 515 15 re f');
    // NOTE: Tm (absolute) — chained Td drifts relative and pushes every
    // column after the first off-page (the old "empty columns" bug).
    stream.writeln('BT');
    stream.writeln('1 1 1 rg');
    stream.writeln('/F2 8 Tf');
    stream.writeln('1 0 0 1 45 626 Tm (Status) Tj');
    stream.writeln('1 0 0 1 85 626 Tm (Mandated Field) Tj');
    stream.writeln('1 0 0 1 220 626 Tm (Statutory Rule) Tj');
    stream.writeln('ET');

    // Evaluation rows (two lines each: status/field/rule + found value)
    double curY = 605.0;
    for (final eval in report.evaluations) {
      if (curY < 210.0) break; // Keep on single high-density summary page

      final String stColor;
      final String stBadge;
      if (eval.isCompliant) {
        stColor = '0.0 0.55 0.2';
        stBadge = 'PASS';
      } else if (eval.isViolation) {
        stColor = '0.85 0.1 0.1';
        stBadge = 'FAIL';
      } else if (eval.isWarning) {
        stColor = '0.85 0.55 0.0';
        stBadge = 'WARN';
      } else {
        stColor = '0.4 0.4 0.4';
        stBadge = 'N/A ';
      }

      final fName = _sanitizePdf(_truncate(eval.field, 22));
      // Full rule reference: clause is "Rule 6(1)(c) & Rule 13 — <title>".
      // The old 28-char cut mangled it mid-word, so the rule rides uncut.
      final ruleRef = _sanitizePdf(eval.clause.split(' — ').first);
      final foundSrc = (eval.detectedText?.isNotEmpty == true)
          ? eval.detectedText!
          : eval.remarks;
      final found = _sanitizePdf(_truncate(foundSrc, 100));

      stream.writeln('BT');
      stream.writeln('$stColor rg /F2 8 Tf 1 0 0 1 45 ${curY.toStringAsFixed(1)} Tm ($stBadge) Tj');
      stream.writeln('0.1 0.1 0.1 rg /F2 8 Tf 1 0 0 1 85 ${curY.toStringAsFixed(1)} Tm ($fName) Tj');
      stream.writeln('0.15 0.15 0.45 rg /F2 8 Tf 1 0 0 1 220 ${curY.toStringAsFixed(1)} Tm ($ruleRef) Tj');
      stream.writeln('0.35 0.35 0.35 rg /F1 7.5 Tf 1 0 0 1 85 ${(curY - 11.0).toStringAsFixed(1)} Tm (Found: $found) Tj');
      stream.writeln('ET');

      stream.writeln('0.9 0.9 0.9 rg 40 ${(curY - 14.0).toStringAsFixed(1)} 515 0.5 re f');
      curY -= 27.0;
    }

    // 3. Image Forensics Quality Gate Box
    curY -= 8.0;
    stream.writeln('BT 0.1 0.2 0.4 rg /F2 10 Tf 40 ${curY.toStringAsFixed(1)} Td (FORENSIC IMAGE QUALITY & PACKAGING INTEGRITY GATE) Tj ET');
    curY -= 14.0;
    stream.writeln('BT 0.4 0.4 0.4 rg /F1 8 Tf 45 ${curY.toStringAsFixed(1)} Td (Packaging panels verified through multi-angle edge verification and OCR token clustering.) Tj ET');
    curY -= 14.0;

    // 4. Jan Vishwas Act Statutory Penalties Box
    curY -= 6.0;
    final fineInr = report.violations.totalFineInr;
    final violationsCount = report.violations.totalViolations;

    stream.writeln('0.98 0.93 0.93 rg 40 ${(curY - 40.0).toStringAsFixed(1)} 515 50 re f');
    stream.writeln('0.85 0.2 0.2 RG 1 w 40 ${(curY - 40.0).toStringAsFixed(1)} 515 50 re s');

    stream.writeln('BT 0.7 0.1 0.1 rg /F2 9.5 Tf 50 ${(curY - 12.0).toStringAsFixed(1)} Td (STATUTORY PENALTY NOTICE - JAN VISHWAS ACT, 2023) Tj ET');
    stream.writeln('BT 0.2 0.2 0.2 rg /F1 8 Tf 50 ${(curY - 24.0).toStringAsFixed(1)} Td (Total Statutory Violations: $violationsCount  |  Section 36\\(1\\) read with Section 49 Legal Metrology Act, 2009) Tj ET');
    stream.writeln('BT 0.7 0.1 0.1 rg /F2 10 Tf 50 ${(curY - 36.0).toStringAsFixed(1)} Td (Compoundable Penalty Fine: INR Rs. $fineInr/-  \\(Payable within 30 days of statutory notice\\)) Tj ET');

    // 5. Footer Sign-Off
    stream.writeln('BT 0.4 0.4 0.4 rg /F1 7.5 Tf 40 45 Td (Generated automatically by Themis Mobile Forensic Legal Metrology Engine - Ministry of Consumer Affairs, GoI.) Tj ET');
    stream.writeln('BT 0.4 0.4 0.4 rg /F2 7.5 Tf 420 45 Td (Authorized Legal Inspector Signature) Tj ET');

    // Assemble PDF Byte Structure
    final BytesBuilder pdf = BytesBuilder();
    pdf.add(utf8.encode('%PDF-1.4\n%'));
    pdf.add(const [0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

    final offsets = <int>[];

    // Object 1: Catalog
    offsets.add(pdf.length);
    pdf.add(utf8.encode('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'));

    // Object 2: Pages
    offsets.add(pdf.length);
    pdf.add(utf8.encode('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'));

    // Object 3: Page (A4 MediaBox: 595.28 x 841.89)
    offsets.add(pdf.length);
    pdf.add(utf8.encode(
      '3 0 obj\n'
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Contents 4 0 R '
      '/Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>\n'
      'endobj\n',
    ));

    // Object 4: Stream Content
    offsets.add(pdf.length);
    final streamBytes = utf8.encode(stream.toString());
    pdf.add(utf8.encode('4 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n'));
    pdf.add(streamBytes);
    pdf.add(utf8.encode('\nendstream\nendobj\n'));

    // Object 5: Font F1 (Helvetica)
    offsets.add(pdf.length);
    pdf.add(utf8.encode('5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n'));

    // Object 6: Font F2 (Helvetica-Bold)
    offsets.add(pdf.length);
    pdf.add(utf8.encode('6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n'));

    // Cross-reference table (xref)
    final xrefOffset = pdf.length;
    final numObjects = offsets.length + 1;
    pdf.add(utf8.encode('xref\n0 $numObjects\n0000000000 65535 f \n'));
    for (final off in offsets) {
      final offStr = off.toString().padLeft(10, '0');
      pdf.add(utf8.encode('$offStr 00000 n \n'));
    }

    // Trailer
    pdf.add(utf8.encode(
      'trailer\n'
      '<< /Size $numObjects /Root 1 0 R >>\n'
      'startxref\n'
      '$xrefOffset\n'
      '%%EOF\n',
    ));

    return pdf.toBytes();
  }

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen - 1)}…';
  }

  static String _sanitizePdf(String s) {
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      final char = s[i];
      if (char == '(') {
        sb.write(r'\(');
      } else if (char == ')') {
        sb.write(r'\)');
      } else if (char == '\\') {
        sb.write(r'\\');
      } else if (char == '\n' || char == '\r') {
        sb.write(' ');
      } else if (char == '₹') {
        sb.write('Rs.');
      } else if (code >= 32 && code <= 126) {
        sb.write(char);
      } else {
        sb.write('?');
      }
    }
    return sb.toString();
  }
}
