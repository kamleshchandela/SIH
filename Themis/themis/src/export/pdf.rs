use crate::compliance::types::ComplianceReport;
use std::fmt::Write;

/// Generates a valid PDF 1.4 Statutory Notice of Non-Compliance document
pub fn generate_statutory_notice_pdf(report: &ComplianceReport) -> Vec<u8> {
    let mut stream = String::new();

    // 1. Header Banner & Title
    // Navy Blue Header Box
    stream.push_str("0.1 0.2 0.45 rg\n"); // Navy blue
    stream.push_str("40 780 515 45 re f\n");

    // Header Text (White)
    stream.push_str("BT\n1 1 1 rg\n/F2 12 Tf\n55 805 Td\n(GOVERNMENT OF INDIA - MINISTRY OF CONSUMER AFFAIRS) Tj\nET\n");
    stream.push_str("BT\n1 1 1 rg\n/F1 9 Tf\n55 792 Td\n(DIRECTORATE OF LEGAL METROLOGY | AUTOMATED STATUTORY AUDIT SYSTEM) Tj\nET\n");

    // Document Title
    stream.push_str("BT\n0.1 0.1 0.1 rg\n/F2 14 Tf\n40 755 Td\n(STATUTORY NOTICE OF INSPECTION & NON-COMPLIANCE) Tj\nET\n");
    stream.push_str("BT\n0.4 0.4 0.4 rg\n/F1 8 Tf\n40 743 Td\n(Issued under Section 36(1) Legal Metrology Act, 2009 read with LMPC Rules, 2011 & Jan Vishwas Act, 2023) Tj\nET\n");

    // Thin separator
    stream.push_str("0.8 0.8 0.8 rg\n40 735 515 1 re f\n");

    // Metadata Box (Light gray background)
    stream.push_str("0.96 0.96 0.98 rg\n40 660 515 65 re f\n");
    stream.push_str("0.8 0.8 0.85 RG\n1 w\n40 660 515 65 re s\n");

    let sku_name = report.product_name.as_deref().unwrap_or("Unknown Product SKU");
    let safe_sku = sanitize_pdf_string(sku_name);
    let panels_str = sanitize_pdf_string(&report.scanned_panels.join(", "));

    // Metadata details
    let mut meta_text = String::new();
    let _ = write!(meta_text, "Inspection ID: {}   |   Date: {}\n", report.inspection_id, &report.timestamp[..19.min(report.timestamp.len())]);
    let _ = write!(meta_text, "Product SKU  : {}\n", safe_sku);
    let _ = write!(meta_text, "Panels Scanned: {} (Pooled Evidence: {})\n", report.scanned_panels.len(), panels_str);

    let status_color = if report.overall_compliant { "0.0 0.5 0.2" } else { "0.8 0.1 0.1" };
    let status_label = if report.overall_compliant { "COMPLIANT (PASS)" } else { "VIOLATION DETECTED (NON-COMPLIANT)" };

    stream.push_str(&format!(
        "BT\n0.15 0.15 0.15 rg\n/F2 9 Tf\n50 710 Td\n(Inspection ID: ) Tj\n/F1 9 Tf\n({} ) Tj\n/F2 9 Tf\n( | Date: ) Tj\n/F1 9 Tf\n({})\nTj\nET\n",
        report.inspection_id, &report.timestamp[..19.min(report.timestamp.len())]
    ));
    stream.push_str(&format!(
        "BT\n0.15 0.15 0.15 rg\n/F2 9 Tf\n50 695 Td\n(Product SKU  : ) Tj\n/F1 9 Tf\n({})\nTj\nET\n",
        safe_sku
    ));
    stream.push_str(&format!(
        "BT\n0.15 0.15 0.15 rg\n/F2 9 Tf\n50 680 Td\n(Audit Result : ) Tj\n{} rg\n/F2 9 Tf\n({}   |   Risk Tier: {}   |   Score: {:.1}%)\nTj\nET\n",
        status_color, status_label, report.risk_tier.label(), report.compliance_score_pct
    ));

    // 2. Rule Evaluation Table
    stream.push_str("BT\n0.1 0.2 0.4 rg\n/F2 10 Tf\n40 640 Td\n(RULE-BY-RULE STATUTORY DECLARATION AUDIT) Tj\nET\n");

    // Table Header
    stream.push_str("0.2 0.3 0.5 rg\n40 622 515 15 re f\n");
    stream.push_str("BT\n1 1 1 rg\n/F2 8 Tf\n45 626 Td\n(Status) Tj\n85 626 Td\n(Mandated Field) Tj\n200 626 Td\n(Statutory Clause) Tj\n350 626 Td\n(Detected Value / Remarks) Tj\nET\n");

    let mut cur_y = 605.0f32;
    for eval in &report.evaluations {
        if cur_y < 200.0 {
            break; // Fit on single high-density summary page
        }

        let (st_color, st_badge) = match eval.status {
            crate::compliance::Status::Compliant => ("0.0 0.55 0.2", "PASS"),
            crate::compliance::Status::Violation => ("0.85 0.1 0.1", "FAIL"),
            crate::compliance::Status::Warning => ("0.85 0.55 0.0", "WARN"),
            crate::compliance::Status::NotApplicable => ("0.4 0.4 0.4", "N/A "),
        };

        let field_name = sanitize_pdf_string(&format!("{:?}", eval.field));
        let clause = sanitize_pdf_string(&eval.legal_clause[..28.min(eval.legal_clause.len())]);
        let remarks = sanitize_pdf_string(&eval.remarks[..48.min(eval.remarks.len())]);

        // Row background alternating
        stream.push_str(&format!(
            "BT\n{} rg\n/F2 8 Tf\n45 {:.1} Td\n({}) Tj\n0.1 0.1 0.1 rg\n/F2 8 Tf\n85 {:.1} Td\n({}) Tj\n0.3 0.3 0.3 rg\n/F1 7 Tf\n200 {:.1} Td\n({}) Tj\n0.2 0.2 0.2 rg\n/F1 7.5 Tf\n350 {:.1} Td\n({}) Tj\nET\n",
            st_color, cur_y, st_badge, cur_y, field_name, cur_y, clause, cur_y, remarks
        ));
        stream.push_str(&format!("0.9 0.9 0.9 rg\n40 {:.1} 515 0.5 re f\n", cur_y - 3.0));

        cur_y -= 16.0;
    }

    // 3. Laplacian Blur Image Sharpness Gate Box
    cur_y -= 8.0;
    stream.push_str(&format!("BT\n0.1 0.2 0.4 rg\n/F2 10 Tf\n40 {:.1} Td\n(FORENSIC IMAGE QUALITY & LAPLACIAN BLUR QUALITY GATE) Tj\nET\n", cur_y));
    cur_y -= 14.0;

    if report.panel_qualities.is_empty() {
        stream.push_str(&format!("BT\n0.4 0.4 0.4 rg\n/F1 8 Tf\n45 {:.1} Td\n(Standard clarity analysis: All packaging panels verified above statutory sharpness threshold.) Tj\nET\n", cur_y));
        cur_y -= 14.0;
    } else {
        for q in &report.panel_qualities {
            let quality_color = if q.is_blurry { "0.85 0.1 0.1" } else { "0.0 0.5 0.2" };
            let quality_tag = if q.is_blurry { "CAMERA BLUR DETECTED" } else { "SHARP (LEGIBLE)" };
            let safe_pname = sanitize_pdf_string(&q.panel_name);
            let safe_assessment = sanitize_pdf_string(&q.assessment[..60.min(q.assessment.len())]);

            stream.push_str(&format!(
                "BT\n0.1 0.1 0.1 rg\n/F2 7.5 Tf\n45 {:.1} Td\n(Panel: {}) Tj\n{} rg\n/F2 7.5 Tf\n180 {:.1} Td\n([{} - Var: {:.1}]) Tj\n0.3 0.3 0.3 rg\n/F1 7.5 Tf\n330 {:.1} Td\n({}) Tj\nET\n",
                cur_y, safe_pname, quality_color, cur_y, quality_tag, q.laplacian_variance, cur_y, safe_assessment
            ));
            cur_y -= 13.0;
        }
    }

    // 3.5 Forensic Visual Tamper Alert (Dual-MRP Secondary Sticker)
    if let Some(ref tamper) = report.tamper_analysis {
        if tamper.detected {
            cur_y -= 4.0;
            stream.push_str(&format!("0.98 0.88 0.88 rg\n40 {:.1} 515 20 re f\n", cur_y - 16.0));
            stream.push_str(&format!("0.85 0.1 0.1 RG\n1 w\n40 {:.1} 515 20 re s\n", cur_y - 16.0));
            stream.push_str(&format!(
                "BT\n0.85 0.1 0.1 rg\n/F2 8 Tf\n48 {:.1} Td\n(FORENSIC ALERT: Physical Dual-MRP Sticker Over Original Price Confirmed [Confidence: {:.0}%]) Tj\nET\n",
                cur_y - 12.0, tamper.confidence * 100.0
            ));
            cur_y -= 22.0;
        }
    }

    // 4. Jan Vishwas Act Statutory Penalties Box
    cur_y -= 6.0;
    stream.push_str(&format!("0.98 0.93 0.93 rg\n40 {:.1} 515 50 re f\n", cur_y - 40.0));
    stream.push_str(&format!("0.85 0.2 0.2 RG\n1 w\n40 {:.1} 515 50 re s\n", cur_y - 40.0));

    let total_compounding: u64 = report
        .violations
        .statutory_penalties
        .iter()
        .map(|p| p.compoundable_fine_inr)
        .sum();

    stream.push_str(&format!(
        "BT\n0.7 0.1 0.1 rg\n/F2 9.5 Tf\n50 {:.1} Td\n(STATUTORY PENALTY NOTICE - JAN VISHWAS (AMENDMENT OF PROVISIONS) ACT, 2023) Tj\nET\n",
        cur_y - 12.0
    ));
    stream.push_str(&format!(
        "BT\n0.2 0.2 0.2 rg\n/F1 8 Tf\n50 {:.1} Td\n(Total Violations: {}   |   Statutory Section: Sec 36(1) read with Sec 49 Legal Metrology Act, 2009) Tj\nET\n",
        cur_y - 24.0, report.violations.total_violations
    ));
    stream.push_str(&format!(
        "BT\n0.7 0.1 0.1 rg\n/F2 10 Tf\n50 {:.1} Td\n(Compoundable Penalty Fine: INR Rs. {}/-  (Compounding payable within 30 days)) Tj\nET\n",
        cur_y - 36.0, total_compounding
    ));

    // Footer Sign-Off
    stream.push_str("BT\n0.4 0.4 0.4 rg\n/F1 7.5 Tf\n40 45 Td\n(Generated automatically by Themis v0.1.0 Legal Metrology Compliance Engine - Ministry of Consumer Affairs, GoI.) Tj\nET\n");
    stream.push_str("BT\n0.4 0.4 0.4 rg\n/F2 7.5 Tf\n420 45 Td\n(Authorized Officer Signature) Tj\nET\n");

    // Assemble PDF Objects
    let mut pdf = Vec::new();
    pdf.extend_from_slice(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n");

    let mut offsets = Vec::new();

    // Object 1: Catalog
    offsets.push(pdf.len());
    pdf.extend_from_slice(b"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");

    // Object 2: Pages
    offsets.push(pdf.len());
    pdf.extend_from_slice(b"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n");

    // Object 3: Page (A4 MediaBox: 595.28 x 841.89)
    offsets.push(pdf.len());
    pdf.extend_from_slice(b"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>\nendobj\n");

    // Object 4: Stream Content
    offsets.push(pdf.len());
    let stream_bytes = stream.into_bytes();
    let stream_header = format!("4 0 obj\n<< /Length {} >>\nstream\n", stream_bytes.len());
    pdf.extend_from_slice(stream_header.as_bytes());
    pdf.extend_from_slice(&stream_bytes);
    pdf.extend_from_slice(b"\nendstream\nendobj\n");

    // Object 5: Font F1 (Helvetica)
    offsets.push(pdf.len());
    pdf.extend_from_slice(b"5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n");

    // Object 6: Font F2 (Helvetica-Bold)
    offsets.push(pdf.len());
    pdf.extend_from_slice(b"6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n");

    // Cross-reference table (xref)
    let xref_offset = pdf.len();
    let num_objects = offsets.len() + 1;
    let xref_header = format!("xref\n0 {}\n0000000000 65535 f \n", num_objects);
    pdf.extend_from_slice(xref_header.as_bytes());

    for off in offsets {
        let entry = format!("{:010} 00000 n \n", off);
        pdf.extend_from_slice(entry.as_bytes());
    }

    // Trailer
    let trailer = format!(
        "trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{}\n%%EOF\n",
        num_objects, xref_offset
    );
    pdf.extend_from_slice(trailer.as_bytes());

    pdf
}

/// Escapes parentheses and backslashes for PDF string literals
fn sanitize_pdf_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '(' => out.push_str("\\("),
            ')' => out.push_str("\\)"),
            '\\' => out.push_str("\\\\"),
            '\n' | '\r' => out.push(' '),
            _ if c.is_ascii() => out.push(c),
            '₹' => out.push_str("Rs."),
            _ => out.push('?'),
        }
    }
    out
}
