import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:themis_app/models/compliance_report.dart';
import 'package:themis_app/services/statutory_notice_csv_service.dart';
import 'package:themis_app/services/statutory_notice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleReport = ComplianceReport(
    inspectionId: 'TEST-INSP-2026-001',
    timestamp: '2026-09-09T20:00:00Z',
    productName: 'SaveMore Dishwash 500ml',
    scannedPanels: ['assets/demo/dishwash_demo.jpg'],
    overallCompliant: false,
    riskTier: 'ModerateRisk',
    complianceScorePct: 75.0,
    evaluations: [
      RuleEvaluation(
        field: 'Rule 6(1)(a) Manufacturer',
        clause: 'Rule 6(1)(a) LMPC 2011',
        status: 'Compliant',
        remarks: 'Valid manufacturer address',
      ),
      RuleEvaluation(
        field: 'Rule 6(1)(c) Consumer Care',
        clause: 'Rule 6(1)(c) LMPC 2011',
        status: 'Violation',
        remarks: 'Email missing',
      ),
    ],
    violations: ViolationsSummary(
      totalViolations: 1,
      mandatoryMissing: ['Consumer care email'],
      nonStandardUnits: [],
      statutoryPenalties: [
        StatutoryPenalty(
          section: 'Sec 36(1)',
          act: 'Legal Metrology Act, 2009',
          description: 'Non-declaration under Jan Vishwas Act',
          compoundableFineInr: 25000,
        ),
      ],
    ),
    rawOcrTokens: [],
  );

  group('StatutoryNoticePdfService (ISO PDF 1.4 Offline Generator)', () {
    test('Generates valid ISO PDF 1.4 byte structure', () {
      final pdfBytes = StatutoryNoticePdfService.generate(sampleReport);
      expect(pdfBytes.isNotEmpty, isTrue);

      final pdfStr = latin1.decode(pdfBytes);
      // Valid PDF 1.4 magic header
      expect(pdfStr.startsWith('%PDF-1.4'), isTrue);
      // Document structure
      expect(pdfStr.contains('/Type /Catalog'), isTrue);
      expect(pdfStr.contains('/Type /Pages'), isTrue);
      expect(pdfStr.contains('/Type /Page'), isTrue);
      expect(pdfStr.contains('/Font'), isTrue);
      expect(pdfStr.contains('xref'), isTrue);
      expect(pdfStr.contains('trailer'), isTrue);
      expect(pdfStr.contains('startxref'), isTrue);
      expect(pdfStr.endsWith('%%EOF\n'), isTrue);
    });

    test('Encodes official statutory ministry declarations in stream', () {
      final pdfBytes = StatutoryNoticePdfService.generate(sampleReport);
      final pdfStr = latin1.decode(pdfBytes);

      expect(pdfStr.contains('GOVERNMENT OF INDIA - MINISTRY OF CONSUMER AFFAIRS'), isTrue);
      expect(pdfStr.contains('DIRECTORATE OF LEGAL METROLOGY'), isTrue);
      expect(pdfStr.contains('STATUTORY NOTICE OF INSPECTION'), isTrue);
      expect(pdfStr.contains('TEST-INSP-2026-001'), isTrue);
      expect(pdfStr.contains('SaveMore Dishwash 500ml'), isTrue);
      expect(pdfStr.contains('Rs. 25000'), isTrue);
    });
  });

  group('StatutoryNoticeCsvService (Tabular Compliance Audit Exporter)', () {
    test('Generates compliant CSV rows with header', () {
      final csvBytes = StatutoryNoticeCsvService.generate(sampleReport);
      expect(csvBytes.isNotEmpty, isTrue);

      final csvStr = utf8.decode(csvBytes);
      expect(csvStr.contains('Inspection ID,Timestamp,Product Name'), isTrue);
      expect(csvStr.contains('TEST-INSP-2026-001'), isTrue);
      expect(csvStr.contains('SaveMore Dishwash 500ml'), isTrue);
      expect(csvStr.contains('Rule 6(1)(a) Manufacturer'), isTrue);
      expect(csvStr.contains('Rule 6(1)(c) Consumer Care'), isTrue);
    });
  });
}
