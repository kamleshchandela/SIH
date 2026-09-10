pub mod csv;
pub mod pdf;

pub use csv::generate_inspection_csv;
pub use pdf::generate_statutory_notice_pdf;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compliance::types::{ComplianceReport, DeclarationField, RiskTier, StatutoryPenalty, ViolationSummary};

    fn sample_report() -> ComplianceReport {
        ComplianceReport {
            inspection_id: "INSP-TEST-001".to_string(),
            timestamp: "2026-09-06T12:00:00Z".to_string(),
            product_name: Some("Test SKU".to_string()),
            scanned_panels: vec!["front.jpg".to_string(), "back.jpg".to_string()],
            overall_compliant: false,
            compliance_score_pct: 60.0,
            risk_tier: RiskTier::HighRiskMajor,
            evaluations: vec![crate::compliance::RequirementEvaluation {
                field: DeclarationField::NetQuantity,
                legal_clause: "Rule 6(1)(c)".to_string(),
                status: crate::compliance::Status::Violation,
                detected_text: None,
                confidence: 0.0,
                source_panel: Some("front.jpg".to_string()),
                bbox: None,
                remarks: "Missing declaration".to_string(),
            }],
            violations: ViolationSummary {
                total_violations: 1,
                mandatory_missing: vec![DeclarationField::NetQuantity],
                non_standard_units: vec![],
                statutory_penalties: vec![StatutoryPenalty {
                    section: "Section 36(1)".to_string(),
                    act: "Legal Metrology Act, 2009".to_string(),
                    description: "Missing Net Quantity Declaration".to_string(),
                    compoundable_fine_inr: 50000,
                }],
            },
            panel_qualities: vec![],
            tamper_analysis: None,
            raw_ocr_tokens: vec![],
        }
    }

    #[test]
    fn test_csv_export_format() {
        let report = sample_report();
        let csv = generate_inspection_csv(&report);
        assert!(csv.contains("Inspection ID,Timestamp,Product SKU"));
        assert!(csv.contains("INSP-TEST-001"));
        assert!(csv.contains("Test SKU"));
        assert!(csv.contains("HIGH RISK (MAJOR)"));
    }

    #[test]
    fn test_pdf_export_format() {
        let report = sample_report();
        let pdf = generate_statutory_notice_pdf(&report);
        // Valid PDF magic header
        assert!(pdf.starts_with(b"%PDF-1.4\n"));
        // Valid PDF EOF
        assert!(pdf.ends_with(b"%%EOF\n"));
        // Check content size is substantial
        assert!(pdf.len() > 1000);
    }
}
