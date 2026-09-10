use crate::compliance::types::ComplianceReport;

/// Generates an RFC 4180 compliant CSV inspection audit trail
pub fn generate_inspection_csv(report: &ComplianceReport) -> String {
    let mut out = String::new();

    // CSV Header
    out.push_str("Inspection ID,Timestamp,Product SKU,Field,Legal Clause,Status,Detected Text,Confidence %,Source Panel,Bounding Box,Remarks\n");

    for eval in &report.evaluations {
        let field_str = format!("{:?}", eval.field);
        let legal_clause = escape_csv(&eval.legal_clause);
        let status_str = match eval.status {
            crate::compliance::Status::Compliant => "COMPLIANT",
            crate::compliance::Status::Violation => "VIOLATION",
            crate::compliance::Status::Warning => "WARNING",
            crate::compliance::Status::NotApplicable => "NOT_APPLICABLE",
        };
        let detected = escape_csv(eval.detected_text.as_deref().unwrap_or("N/A"));
        let conf_pct = format!("{:.1}%", eval.confidence * 100.0);
        let panel = escape_csv(eval.source_panel.as_deref().unwrap_or("N/A"));
        let bbox_str = if let Some(ref bb) = eval.bbox {
            format!("\"({}, {}) {}x{}\"", bb.x, bb.y, bb.width, bb.height)
        } else {
            "\"N/A\"".to_string()
        };
        let remarks = escape_csv(&eval.remarks);

        out.push_str(&format!(
            "{},{},{},{},{},{},{},{},{},{},{}\n",
            escape_csv(&report.inspection_id),
            escape_csv(&report.timestamp),
            escape_csv(report.product_name.as_deref().unwrap_or("Unknown")),
            escape_csv(&field_str),
            legal_clause,
            status_str,
            detected,
            conf_pct,
            panel,
            bbox_str,
            remarks
        ));
    }

    // Append Statutory Summary Section
    out.push_str("\n--- STATUTORY AUDIT SUMMARY ---\n");
    out.push_str(&format!("Overall Status,{}\n", if report.overall_compliant { "COMPLIANT" } else { "VIOLATION DETECTED" }));
    out.push_str(&format!("Statutory Risk Tier,{}\n", report.risk_tier.label()));
    out.push_str(&format!("Compliance Score,{:.1}%\n", report.compliance_score_pct));
    out.push_str(&format!("Total Violations,{}\n", report.violations.total_violations));

    let total_compounding: u64 = report
        .violations
        .statutory_penalties
        .iter()
        .map(|p| p.compoundable_fine_inr)
        .sum();
    out.push_str(&format!("Total Jan Vishwas Compounding Fine INR,₹{}\n", total_compounding));

    // Append Panel Quality Sharpness Diagnostics
    if !report.panel_qualities.is_empty() {
        out.push_str("\n--- PANEL SHARPNESS DIAGNOSTICS (LAPLACIAN VARIANCE) ---\n");
        out.push_str("Panel Name,Resolution,Laplacian Edge Variance,Capture Quality,Assessment\n");
        for q in &report.panel_qualities {
            out.push_str(&format!(
                "{},{}x{},{:.1},{},{}\n",
                escape_csv(&q.panel_name),
                q.width,
                q.height,
                q.laplacian_variance,
                if q.is_blurry { "BLURRY" } else { "SHARP" },
                escape_csv(&q.assessment)
            ));
        }
    }

    out
}

fn escape_csv(val: &str) -> String {
    if val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r') {
        format!("\"{}\"", val.replace('"', "\"\""))
    } else {
        val.to_string()
    }
}
