//! Guided capture sessions: four forced close-up steps whose per-step
//! evaluations merge into one session report (see doc/field/11).
//!
//! Each step runs the full evaluator on its own capture(s); the merge takes
//! each field from its owning step, marks skipped steps NotApplicable
//! (excluded from the score denominator, never violations), and flags
//! cross-step contradictions. Validators reuse the matcher regexes — a
//! capture that fails validation is the *wrong photo*, not a bad pack.

use super::quality::PanelImageQuality;
use super::rules::{
    evaluate_compliance_with_quality, has_nutrition_table, is_barcode_ballast,
    RE_EMAIL, RE_MFG_DATE, RE_MFG_KEYWORDS, RE_MRP, RE_NET_QTY, RE_PHONE,
    RE_PINCODE, RE_STANDALONE_DATE, RE_STANDALONE_QTY,
};
use super::types::*;

/// One of the four forced capture steps.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GuidedStep {
    Quantity,
    Price,
    Date,
    BackPanel,
}

impl GuidedStep {
    pub fn from_id(id: &str) -> Option<Self> {
        match id.to_lowercase().as_str() {
            "quantity" | "qty" | "netqty" => Some(Self::Quantity),
            "price" | "mrp" => Some(Self::Price),
            "date" | "mfg" | "mfd" => Some(Self::Date),
            "back" | "backpanel" | "address" | "care" => Some(Self::BackPanel),
            _ => None,
        }
    }

    pub fn id(&self) -> &'static str {
        match self {
            Self::Quantity => "quantity",
            Self::Price => "price",
            Self::Date => "date",
            Self::BackPanel => "back",
        }
    }

    /// Fields this step owns in the session merge.
    pub fn owned_fields(&self) -> &'static [DeclarationField] {
        match self {
            Self::Quantity => &[
                DeclarationField::NetQuantity,
                DeclarationField::Rule7NumeralHeight,
                DeclarationField::NutritionalInfo,
            ],
            Self::Price => &[
                DeclarationField::MaximumRetailPrice,
                DeclarationField::UnitSalePrice,
            ],
            Self::Date => &[
                DeclarationField::ManufactureDate,
                DeclarationField::CountryOfOrigin,
            ],
            Self::BackPanel => &[
                DeclarationField::ManufacturerDetails,
                DeclarationField::ConsumerCare,
            ],
        }
    }
}

/// Validator: does this capture look like the step it claims? Failure means
/// "retake the photo", never a pack violation.
pub fn validate_step_capture(step: GuidedStep, tokens: &[OcrToken]) -> bool {
    let text = tokens
        .iter()
        .map(|t| t.text.as_str())
        .collect::<Vec<_>>()
        .join(" ");
    match step {
        GuidedStep::Quantity => {
            // Same barcode honesty as the evaluator: a barcode-shaped
            // "quantity" must not validate the photo. A nutrition table
            // alone also validates (it owns NutritionalInfo) even when the
            // weight print sits outside the frame — the merge then judges
            // the quantity honestly instead of rejecting the photo.
            has_nutrition_table(&text)
                || RE_NET_QTY.captures_iter(&text).any(|c| {
                    let v = c.get(1).map(|m| m.as_str()).unwrap_or("");
                    !is_barcode_ballast(v, v)
                }) || tokens.iter().any(|t| {
                    RE_STANDALONE_QTY.captures(&t.text).is_some_and(|c| {
                        let v = c.get(1).map(|m| m.as_str()).unwrap_or("");
                        !is_barcode_ballast(v, &t.text)
                    })
                })
        }
        GuidedStep::Price => {
            RE_MRP.is_match(&text)
                || (text.to_lowercase().contains("tax")
                    && tokens.iter().any(|t| {
                        t.text.chars().filter(|c| c.is_ascii_digit()).count() >= 2
                    }))
        }
        GuidedStep::Date => {
            RE_MFG_DATE.is_match(&text) || RE_STANDALONE_DATE.is_match(&text)
        }
        GuidedStep::BackPanel => {
            RE_MFG_KEYWORDS.is_match(&text)
                || RE_PINCODE.is_match(&text)
                || RE_EMAIL.is_match(&text)
                || RE_PHONE.is_match(&text)
                || {
                    let low = text.to_lowercase();
                    ["consumer care", "grievance", "feedback", "write to"]
                        .iter()
                        .any(|k| low.contains(k))
                }
        }
    }
}

/// Retake hint for a rejected capture: tells the user WHAT to frame, not
/// just that the photo was wrong. Shown in place of a bare rejection.
pub fn step_hint(step: GuidedStep, tokens: &[OcrToken]) -> &'static str {
    let text = tokens
        .iter()
        .map(|t| t.text.as_str())
        .collect::<Vec<_>>()
        .join(" ");
    match step {
        GuidedStep::Quantity => {
            if has_nutrition_table(&text) {
                "Nutrition table seen — now also frame the NET WEIGHT print"
            } else if tokens.is_empty() {
                "No text found — move closer and hold steady"
            } else {
                "No net quantity found — frame the NET WEIGHT print"
            }
        }
        GuidedStep::Price => {
            if text.to_lowercase().contains("tax") {
                "Tax print seen — now also frame the MRP price"
            } else if tokens.is_empty() {
                "No text found — move closer and hold steady"
            } else {
                "No price found — frame the MRP print"
            }
        }
        GuidedStep::Date => {
            if tokens.is_empty() {
                "No text found — move closer and hold steady"
            } else {
                "No date found — frame the MFD/PKD stamp"
            }
        }
        GuidedStep::BackPanel => {
            if tokens.is_empty() {
                "No text found — move closer and hold steady"
            } else {
                "No address found — frame the manufacturer / care block"
            }
        }
    }
}

/// One step's input to a session: captures, or a skip.
pub struct GuidedStepInput {
    pub step: GuidedStep,
    pub tokens: Vec<OcrToken>,
    pub panel_names: Vec<String>,
    pub skipped: bool,
}

/// Merge per-step evaluations into one session report, mirroring the
/// one-shot scoring math (Compliant / scored-checks; N/A excluded).
pub fn merge_guided_session(
    product_name: Option<String>,
    steps: Vec<GuidedStepInput>,
    panel_qualities: Vec<PanelImageQuality>,
) -> ComplianceReport {
    let mut evaluations: Vec<RequirementEvaluation> = Vec::new();
    let mut all_tokens: Vec<OcrToken> = Vec::new();
    let mut scanned_panels: Vec<String> = Vec::new();
    let mut missing_fields: Vec<DeclarationField> = Vec::new();
    let mut non_standard_units: Vec<String> = Vec::new();
    let mut statutory_penalties: Vec<StatutoryPenalty> = Vec::new();
    let mut violations_count: usize = 0;
    // Net quantities claimed by ANY step's full report (not just the owner):
    // a back panel showing a different qty than the quantity step is itself
    // a signal, even though only the owner's evaluation counts for score.
    let mut qty_claims: Vec<String> = Vec::new();

    for input in &steps {
        if input.skipped {
            for f in input.step.owned_fields() {
                evaluations.push(RequirementEvaluation {
                    field: f.clone(),
                    legal_clause: f.legal_clause().to_string(),
                    status: Status::NotApplicable,
                    detected_text: Some(format!(
                        "Step '{}' skipped by user — not inspected",
                        input.step.id()
                    )),
                    confidence: 0.0,
                    bbox: None,
                    source_panel: None,
                    remarks: "Not inspected: user skipped this capture step. Excluded from score.".to_string(),
                });
            }
            continue;
        }
        // Image dims from token extents (close-ups carry no canvas size).
        let w = input
            .tokens
            .iter()
            .map(|t| t.bbox.x.saturating_add(t.bbox.width))
            .max()
            .unwrap_or(1)
            .max(1);
        let h = input
            .tokens
            .iter()
            .map(|t| t.bbox.y.saturating_add(t.bbox.height))
            .max()
            .unwrap_or(1)
            .max(1);
        let rep = evaluate_compliance_with_quality(
            &input.tokens,
            w,
            h,
            product_name.clone(),
            input.panel_names.clone(),
            Vec::new(),
        );
        for e in rep.evaluations {
            if e.field == DeclarationField::NetQuantity && e.status == Status::Compliant {
                if let Some(ref t) = e.detected_text {
                    qty_claims.push(t.clone());
                }
            }
            if input.step.owned_fields().contains(&e.field) {
                if e.status == Status::Violation {
                    violations_count += 1;
                    missing_fields.push(e.field.clone());
                }
                evaluations.push(e);
            }
        }
        non_standard_units.extend(rep.violations.non_standard_units);        // Carry per-step statutory penalties except the per-report Jan
        // Vishwas aggregate (recomputed for the session below).
        statutory_penalties.extend(
            rep.violations
                .statutory_penalties
                .into_iter()
                .filter(|p| p.section != "Section 36(1) read with Section 49"),
        );
        all_tokens.extend(input.tokens.iter().cloned());
        scanned_panels.extend(input.panel_names.iter().cloned());
    }

    // Same photo across steps yields identical tokens: store once.
    {
        let mut seen: std::collections::HashSet<(String, u32, u32, u32, u32, Option<String>)> =
            std::collections::HashSet::new();
        all_tokens.retain(|t| {
            seen.insert((
                t.text.clone(),
                t.bbox.x,
                t.bbox.y,
                t.bbox.width,
                t.bbox.height,
                t.source_image.clone(),
            ))
        });
    }

    // Cross-step contradiction: two steps claiming different net quantities
    // means the "same" pack was framed inconsistently — itself a signal.
    let qty_texts: Vec<String> = qty_claims
        .into_iter()
        .collect::<std::collections::HashSet<_>>()
        .into_iter()
        .collect();
    if qty_texts.len() > 1 {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::NetQuantity,
            legal_clause: DeclarationField::NetQuantity.legal_clause().to_string(),
            status: Status::Warning,
            detected_text: Some(format!("Conflicting quantities across steps: {}", qty_texts.join(" vs "))),            confidence: 0.70,
            bbox: None,
            source_panel: None,
            remarks: "WARNING: guided steps disagree on the declared net quantity — verify the pack carries a single declaration.".to_string(),
        });
    }

    if violations_count > 0 {
        statutory_penalties.push(StatutoryPenalty {
            section: "Section 36(1) read with Section 49".to_string(),
            act: "Legal Metrology Act, 2009 (amended by Jan Vishwas Act, 2023)".to_string(),
            description: format!("{violations_count} non-compliant declarations detected under Legal Metrology (Packaged Commodities) Rules, 2011 (guided session)."),
            compoundable_fine_inr: (violations_count as u64) * 25_000,
        });
    }

    let total_checks = evaluations.len() as f32;
    let na_count = evaluations
        .iter()
        .filter(|e| e.status == Status::NotApplicable)
        .count() as f32;
    let scored_checks = (total_checks - na_count).max(1.0);
    let compliant_checks = evaluations
        .iter()
        .filter(|e| e.status == Status::Compliant)
        .count() as f32;
    let score = (compliant_checks / scored_checks) * 100.0;
    let warnings_count = evaluations
        .iter()
        .filter(|e| e.status == Status::Warning)
        .count();

    let risk_tier = if violations_count == 0 && warnings_count == 0 {
        RiskTier::Compliant
    } else if violations_count == 0 {
        RiskTier::LowRiskMinor
    } else if score >= 70.0 {
        RiskTier::LowRiskMinor
    } else if score >= 40.0 {
        RiskTier::ModerateRisk
    } else if score >= 20.0 {
        RiskTier::HighRiskMajor
    } else {
        RiskTier::CriticalSevere
    };

    ComplianceReport {
        inspection_id: format!("INSP-{}", chrono::Utc::now().format("%Y%m%d-%H%M%S")),
        timestamp: chrono::Utc::now().to_rfc3339(),
        product_name,
        scanned_panels,
        overall_compliant: violations_count == 0 && warnings_count == 0,
        risk_tier,
        compliance_score_pct: score,
        evaluations,
        violations: ViolationSummary {
            total_violations: violations_count,
            mandatory_missing: missing_fields,
            non_standard_units,
            statutory_penalties,
        },
        panel_qualities,
        tamper_analysis: None,
        raw_ocr_tokens: all_tokens,
        capture_mode: "guided".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tok(text: &str, x: u32, y: u32) -> OcrToken {
        OcrToken {
            text: text.to_string(),
            confidence: 0.95,
            bbox: BoundingBox { x, y, width: 120, height: 40 },
            source_image: Some("panel.jpg".to_string()),
        }
    }

    fn step(id: &str, texts: &[&str]) -> GuidedStepInput {
        GuidedStepInput {
            step: GuidedStep::from_id(id).unwrap(),
            tokens: texts
                .iter()
                .enumerate()
                .map(|(i, t)| tok(t, 0, i as u32 * 50))
                .collect(),
            panel_names: vec!["panel.jpg".to_string()],
            skipped: false,
        }
    }

    #[test]
    fn validators_accept_own_kind_reject_others() {
        let qty = vec![tok("NETWEIGHT:", 0, 0), tok("420gBNoBP41G6", 0, 50)];
        let date = vec![tok("17JUL26712APR2", 0, 0), tok("PKD/USEBY:", 0, 50)];
        assert!(validate_step_capture(GuidedStep::Quantity, &qty));
        assert!(validate_step_capture(GuidedStep::Date, &date));
        assert!(!validate_step_capture(GuidedStep::Quantity, &date));
        assert!(!validate_step_capture(GuidedStep::Date, &qty));
        let price = vec![tok("MRP", 0, 0), tok("Rs.", 60, 0), tok("90.00", 120, 0)];
        assert!(validate_step_capture(GuidedStep::Price, &price));
        assert!(!validate_step_capture(GuidedStep::Price, &qty));
    }

    #[test]
    fn nutrition_table_validates_quantity_step() {
        // Nutrition-only close-up (no weight print in frame): right kind of
        // photo for the quantity step — the merge judges the quantity
        // honestly instead of rejecting the capture.
        let nutri = vec![
            tok("Nutritional", 0, 0),
            tok("Protein", 0, 50),
            tok("Energy", 0, 100),
        ];
        assert!(validate_step_capture(GuidedStep::Quantity, &nutri));
        assert_eq!(
            step_hint(GuidedStep::Quantity, &nutri),
            "Nutrition table seen — now also frame the NET WEIGHT print"
        );
        let empty: Vec<OcrToken> = vec![];
        assert!(!validate_step_capture(GuidedStep::Quantity, &empty));
    }

    #[test]
    fn barcode_quantity_validates_nothing() {
        // "89017251005955 l" is barcode ballast: evaluator rejects it, so
        // the validator must too — otherwise the UI accepts a photo whose
        // step can only fail.
        let barcoded = vec![tok("Net", 0, 0), tok("89017251005955 l", 0, 50)];
        assert!(!validate_step_capture(GuidedStep::Quantity, &barcoded));
        let real = vec![tok("Net", 0, 0), tok("420gBNoBP41G6", 0, 50)];
        assert!(validate_step_capture(GuidedStep::Quantity, &real));
    }

    #[test]
    fn misaligned_closeup_shreds() {
        // Desktop decode of a tilted weight-strip close-up: I-dropped label
        // (NETWEGHT), 2-dropped value (40g), J-mangled date (17UUL612APR242).
        // Quantity must still validate (label shred + standalone value);
        // the digit-shredded date must NOT (its year is unrecoverable).
        let toks = vec![
            tok("NETWEGHT:", 0, 0),
            tok("40g", 0, 50),
            tok("MPRSInC", 0, 100),
            tok("Ot a taxes/", 0, 150),
            tok("17UUL612APR242", 0, 200),
            tok("PRDYUSER:", 0, 250),
        ];
        assert!(validate_step_capture(GuidedStep::Quantity, &toks));
        assert!(validate_step_capture(GuidedStep::Price, &toks));
        assert!(!validate_step_capture(GuidedStep::Date, &toks));
    }

    #[test]
    fn dotted_day_first_dates_validate() {
        // Indian DD.MM.YYYY stamps with drifted two-column layout: neither
        // the month-word nor the MM/YYYY alternatives accept dots.
        let toks = vec![
            tok("DATEOE", 0, 0),
            tok("PACKAGING:", 0, 50),
            tok("K17220526", 0, 100),
            tok("USEBY", 0, 150),
            tok("21.01.2027", 0, 200),
            tok("22.05.2026", 0, 250),
        ];
        assert!(validate_step_capture(GuidedStep::Date, &toks));
    }

    #[test]
    fn session_merge_happy_path_and_skip_math() {
        let steps = vec![
            step("quantity", &["Net", "Wt", "420", "g"]),
            step("price", &["MRP", "Rs.", "90.00", "Inclusive", "of", "all", "taxes"]),
            step("date", &["MFD", "17JUL26", "Made", "in", "India"]),
            GuidedStepInput {
                step: GuidedStep::BackPanel,
                tokens: vec![],
                panel_names: vec![],
                skipped: true,
            },
        ];
        let rep = merge_guided_session(None, steps, vec![]);
        assert_eq!(rep.capture_mode, "guided");
        let get = |f: DeclarationField| {
            rep.evaluations.iter().find(|e| e.field == f).unwrap().clone()
        };
        assert_eq!(get(DeclarationField::NetQuantity).status, Status::Compliant);
        assert_eq!(
            get(DeclarationField::NetQuantity).detected_text.as_deref(),
            Some("420 g")
        );
        assert_eq!(
            get(DeclarationField::MaximumRetailPrice).status,
            Status::Compliant
        );
        assert!(get(DeclarationField::ManufactureDate)
            .detected_text
            .as_deref()
            .unwrap()
            .contains("17JUL26"));
        // Skipped back step: listed as N/A, excluded from the denominator.
        let mfr = get(DeclarationField::ManufacturerDetails);
        assert_eq!(mfr.status, Status::NotApplicable);
        assert!(mfr.detected_text.as_deref().unwrap().contains("skipped"));
        let total = rep.evaluations.len() as f32;
        let na = rep
            .evaluations
            .iter()
            .filter(|e| e.status == Status::NotApplicable)
            .count() as f32;
        let compliant = rep
            .evaluations
            .iter()
            .filter(|e| e.status == Status::Compliant)
            .count() as f32;
        assert_eq!(rep.compliance_score_pct, compliant / (total - na) * 100.0);
    }

    #[test]
    fn session_flags_conflicting_quantities() {
        let steps = vec![
            step("quantity", &["Net", "Wt", "420", "g"]),
            step("price", &["MRP", "Rs.", "90.00"]),
            step("date", &["MFD", "17JUL26"]),
            step("back", &["Net", "Wt", "500", "g", "Mfd", "by", "X", "400001"]),
        ];
        let rep = merge_guided_session(None, steps, vec![]);
        assert!(rep.evaluations.iter().any(|e| e.field
            == DeclarationField::NetQuantity
            && e.status == Status::Warning
            && e.remarks.contains("disagree")));
    }
}
