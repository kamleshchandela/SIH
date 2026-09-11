# 08 — Statutory Reports: CSV & PDF Generation Pipeline

> **Technical specification for the generation, digital authentication, and export of statutory inspection artifacts (RFC 4180 CSV Audit Logs & Official Directorate Legal Metrology Notices in PDF) within PARAKH Mobile.**

---

## 1. Statutory Artifact Overview

Under the **Legal Metrology Act, 2009**, read with the **Legal Metrology (Packaged Commodities) Rules, 2011** and the **Jan Vishwas (Amendment of Provisions) Act, 2023**, field enforcement inspections must produce tamper-evident, auditable documentation that can be submitted as electronic evidence under **Section 65B of the Indian Evidence Act, 1872**.

PARAKH Mobile generates two primary statutory artifacts immediately upon completion of an audit:
1. **Statutory CSV Audit Spreadsheet** (`statutory_audit_<INSPECTION_ID>.csv`): An RFC 4180-compliant tabular dataset recording every individual packaging declaration evaluation, source panel image, matched OCR token, and legal remarks.
2. **Official Statutory Notice / Certificate of Compliance (PDF)** (`statutory_notice_<INSPECTION_ID>.pdf`): A print-ready, officially formatted legal show-cause notice issued under Section 36(1) with government headers, statutory compounding schedule, and digital authentication seal.

---

## 2. In-App Statutory Legal Notice (PDF) Generation

### 2.1 Architecture & Flow

```
+--------------------------------------------------------------------------------+
|                        Statutory Compliance Report JSON                        |
|        (Inspection ID, Rule Evaluations, Risk Tier, Penalties, Tokens)        |
+--------------------------------------------------------------------------------+
                                       |
                                       v
+--------------------------------------------------------------------------------+
|             HTML Document Synthesizer (app/pdf-viewer.tsx)                     |
|  - Directorate of Legal Metrology Official Typography & Letterhead             |
|  - Mandated Declarations Table (Rule 6, Rule 7, Rule 13)                       |
|  - Compounding Penalty Schedule (Jan Vishwas Act 2023)                         |
|  - Section 65B Digital Certificate & Statutory Seal Block                      |
+--------------------------------------------------------------------------------+
                                       |
                                       v
+--------------------------------------------------------------------------------+
|                   Native PDF Compiler (expo-print)                             |
|          Print.printToFileAsync({ html, base64: false })                       |
|          -> Generates byte-accurate standard A4 PDF document                  |
+--------------------------------------------------------------------------------+
                                       |
                                       v
+--------------------------------------------------------------------------------+
|                 Mobile Sharing & Persistence Layer (expo-sharing)              |
|          Sharing.shareAsync(file.uri, { mimeType: 'application/pdf' })         |
|          -> AirDrop / WhatsApp / Gmail / Bluetooth / Local Storage             |
+--------------------------------------------------------------------------------+
```

### 2.2 Visual Artifact Preview

<div align="center">

<img src="../assets/UI/13_statutory_notice_pdf_document.png" width="360" alt="Official Statutory Notice PDF Document" />

<p><em>Figure 8.1: High-resolution rendering of the official Directorate of Legal Metrology Statutory Notice of Non-Compliance compiled directly on-device.</em></p>

</div>

### 2.3 Legal Framework & Document Sections

1. **Government Header & Division**:
   - `GOVERNMENT OF INDIA`
   - `MINISTRY OF CONSUMER AFFAIRS, FOOD & PUBLIC DISTRIBUTION`
   - `DIRECTORATE OF LEGAL METROLOGY — ENFORCEMENT & STATUTORY INSPECTION DIVISION`
2. **Statutory Notice Title**:
   - `STATUTORY NOTICE OF NON-COMPLIANCE` (for audits with infractions)
   - `CERTIFICATE OF STATUTORY COMPLIANCE` (for 100% compliant audits)
3. **Statutory Reference ID & Audited Panels**:
   - Unique inspection identifier (e.g. `INSP-20260908-165510`)
   - Exact image panels examined (e.g. `1000091598.jpg`, `1000091599.jpg`)
4. **Mandated Declarations Findings Table**:
   - Evaluates Rule 6(1)(a) [Manufacturer Details], Rule 6(1)(b) [Net Quantity], Rule 6(1)(c) [MRP], Rule 6(1)(d) [Manufacture Date], Rule 6(1)(da) [Country of Origin], Rule 6(1)(g) [Consumer Care], Rule 6(1)(f) [Unit Sale Price], and Rule 7 / Schedule II [Numeral & Letter Height].
5. **Compounding Schedule & Jan Vishwas Act Liabilities**:
   - Summary of estimated compounding fine payable under Section 36(1) and Section 49.
6. **Digital Evidence Authentication**:
   - Electronic certification under Section 65B of the Indian Evidence Act, 1872.

---

## 3. RFC 4180 Statutory CSV Audit Log Generation

### 3.1 Serialization Logic (`src/utils/formatters.ts`)

The CSV generator escapes double quotes according to RFC 4180 rules:

```typescript
export function generateCsvContent(report: any): string {
  const rows: string[] = [];
  rows.push('Inspection ID,Timestamp,Product SKU,Field,Status,Source Panel,Matched Value,Remarks');

  if (report.evaluations && Array.isArray(report.evaluations)) {
    for (const ev of report.evaluations) {
      const field = `"${ev.field || ''}"`;
      const status = `"${ev.status || ''}"`;
      const panel = `"${ev.source_panel || 'N/A'}"`;
      const matched = `"${(ev.matched_token || 'N/A').replace(/"/g, '""')}"`;
      const remarks = `"${(ev.remarks || '').replace(/"/g, '""')}"`;
      rows.push(
        `"${report.inspection_id}","${report.timestamp}","${(report.product_name || 'N/A').replace(/"/g, '""')}",${field},${status},${panel},${matched},${remarks}`
      );
    }
  }

  rows.push('');
  rows.push('--- STATUTORY AUDIT SUMMARY ---');
  rows.push(`Overall Compliance,"${report.overall_compliant ? 'COMPLIANT (PASS)' : 'STATUTORY VIOLATION (FAIL)'}"`);
  rows.push(`Statutory Risk Tier,"${report.risk_tier || ''}"`);
  rows.push(`Compliance Score,"${(report.compliance_score_pct || 0).toFixed(1)}%"`);
  rows.push(`Total Jan Vishwas Compounding Fine,"INR ${totalFine}"`);

  return rows.join('\n');
}
```

### 3.2 Sample Generated CSV Output

```csv
Inspection ID,Timestamp,Product SKU,Field,Status,Source Panel,Matched Value,Remarks
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","ManufacturerDetails","Compliant","1000091598.jpg","N/A","Complies with Rule 6(1)(a): Complete address and postal PIN code identified."
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","NetQuantity","Compliant","1000091598.jpg","N/A","Compliant: Net quantity declared as 460 g using standard metric symbol."
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","MaximumRetailPrice","Warning","1000091598.jpg","N/A","WARNING: Price detected but 'inclusive of all taxes' clause was not explicitly confirmed."
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","ManufactureDate","Compliant","1000091598.jpg","N/A","Complies with Rule 6(1)(d): Packing date found as 15JUN 2027."
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","CountryOfOrigin","Compliant","1000091598.jpg","N/A","Complies with Rule 6(1)(da): Domestic origin established via verified Indian manufacturing premises & postal PIN."
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","ConsumerCare","Warning","1000091598.jpg","N/A","Rule 6(1)(g) mandates both telephone number and email address for consumer grievances."
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","UnitSalePrice","NotApplicable","N/A","N/A","Exempt from Rule 6(1)(f): Unit sale price not mandatory for pack sizes below 1kg / 1L."
"INSP-20260908-165510","2026-09-08T16:55:10.802432900+00:00","N/A","Rule7NumeralHeight","Compliant","1000091598.jpg","N/A","Complies with Rule 7 & Schedule II: Numeral and letter height conforms to statutory visibility thresholds."

--- STATUTORY AUDIT SUMMARY ---
Overall Compliance,"STATUTORY VIOLATION (FAIL)"
Statutory Risk Tier,"LowRiskMinor"
Compliance Score,"71.4%"
Total Jan Vishwas Compounding Fine,"INR 0"
```

### 3.3 Mobile File System & Native Sharing

1. **File Path**: `${FileSystem.cacheDirectory}statutory_audit_${report.inspection_id}.csv`
2. **File Writing**: `FileSystem.writeAsStringAsync(fileUri, csvString, { encoding: FileSystem.EncodingType.UTF8 })`
3. **Sharing**: `Sharing.shareAsync(fileUri, { mimeType: 'text/csv', dialogTitle: 'Share Audit CSV' })`
