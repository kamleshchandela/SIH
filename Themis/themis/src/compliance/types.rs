use serde::{Deserialize, Serialize};

/// Standard declaration fields mandated by Rule 6 of LMPC Rules, 2011
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum DeclarationField {
    ManufacturerDetails,
    GenericName,
    NetQuantity,
    ManufactureDate,
    CountryOfOrigin,
    MaximumRetailPrice,
    UnitSalePrice,
    ConsumerCare,
    NutritionalInfo,
    BestBeforeExpiry,
    Rule7NumeralHeight,
}

impl DeclarationField {
    pub fn legal_clause(&self) -> &'static str {
        match self {
            Self::ManufacturerDetails => "Rule 6(1)(a) — Name & complete address of Manufacturer / Packer / Importer",
            Self::GenericName => "Rule 6(1)(b) — Generic or common name of commodity",
            Self::NetQuantity => "Rule 6(1)(c) & Rule 13 — Net quantity in standard SI metric units",
            Self::ManufactureDate => "Rule 6(1)(d) — Month and year of manufacture/packing/import",
            Self::CountryOfOrigin => "Rule 6(1)(da) (2021 Amendment) — Country of origin / Made in declaration",
            Self::MaximumRetailPrice => "Rule 6(1)(e) — MRP inclusive of all taxes with standard currency symbol",
            Self::UnitSalePrice => "Rule 6(1)(f) (2021 Amendment) — Unit Sale Price per g/kg/ml for packs > 1kg/1L",
            Self::ConsumerCare => "Rule 6(1)(g) — Grievance redressal contact (Name, address, phone & email)",
            Self::NutritionalInfo => "FSSAI / LMPC Schedule — Nutritional facts per 100g or per serve",
            Self::BestBeforeExpiry => "Rule 6(1)(d) proviso — Best before / Expiry date for perishables",
            Self::Rule7NumeralHeight => "Rule 7 & Schedule II — Minimum height of numerals and letters based on packaging area",
        }
    }
}

/// Compliance status for a specific declaration
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum Status {
    Compliant,
    Violation,
    Warning,
    NotApplicable,
}

/// Detailed evaluation of a single legal requirement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequirementEvaluation {
    pub field: DeclarationField,
    pub legal_clause: String,
    pub status: Status,
    pub detected_text: Option<String>,
    pub confidence: f32,
    pub bbox: Option<BoundingBox>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_panel: Option<String>,
    pub remarks: String,
}

/// Normalized 2D bounding box
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BoundingBox {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
}

/// Summary of violations and compounding fines under Jan Vishwas Act
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ViolationSummary {
    pub total_violations: usize,
    pub mandatory_missing: Vec<DeclarationField>,
    pub non_standard_units: Vec<String>,
    pub statutory_penalties: Vec<StatutoryPenalty>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatutoryPenalty {
    pub section: String,
    pub act: String,
    pub description: String,
    pub compoundable_fine_inr: u64,
}

/// Statutory risk tier classifying severity of packaging non-compliance
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum RiskTier {
    Compliant,        // 100% Score, 0 violations
    LowRiskMinor,     // Score >= 70%, advisory warnings / minor infractions
    ModerateRisk,     // Score 40% - 69%, 1-2 non-critical violations (e.g. MRP on neck/crimp)
    HighRiskMajor,    // Score 20% - 39%, multiple mandatory clauses missing
    CriticalSevere,   // Score < 20%, unlabelled / gross non-compliance / counterfeit risk
}

impl RiskTier {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Compliant => "COMPLIANT",
            Self::LowRiskMinor => "LOW RISK (MINOR)",
            Self::ModerateRisk => "MODERATE RISK",
            Self::HighRiskMajor => "HIGH RISK (MAJOR)",
            Self::CriticalSevere => "CRITICAL (SEVERE)",
        }
    }

    pub fn color_code(&self) -> &'static str {
        match self {
            Self::Compliant => "\x1b[92m",      // Green
            Self::LowRiskMinor => "\x1b[96m",   // Cyan
            Self::ModerateRisk => "\x1b[93m",   // Yellow
            Self::HighRiskMajor => "\x1b[95m",  // Magenta
            Self::CriticalSevere => "\x1b[91m", // Red
        }
    }
}

/// Complete compliance assessment report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceReport {
    pub inspection_id: String,
    pub timestamp: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub product_name: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub scanned_panels: Vec<String>,
    pub overall_compliant: bool,
    pub risk_tier: RiskTier,
    pub compliance_score_pct: f32,
    pub evaluations: Vec<RequirementEvaluation>,
    pub violations: ViolationSummary,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub panel_qualities: Vec<super::quality::PanelImageQuality>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tamper_analysis: Option<TamperAnalysis>,
    pub raw_ocr_tokens: Vec<OcrToken>,
}

/// Physical forensic visual tampering assessment (Dual-MRP, secondary adhesive stickers)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TamperAnalysis {
    pub detected: bool,
    pub confidence: f32,
    pub tamper_type: String,
    pub description: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub roi_bbox: Option<BoundingBox>,
    pub edge_density: f32,
    pub contrast_inconsistency: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OcrToken {
    pub text: String,
    pub confidence: f32,
    pub bbox: BoundingBox,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_image: Option<String>,
}
