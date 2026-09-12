use super::types::*;
use regex::Regex;
use std::sync::LazyLock;

// Precompiled regular expressions for LMPC rules with robust whitespace tolerance
// Trailing `(?:[A-Za-z.]*\d[A-Za-z0-9.]*)?\b`: a unit may be glued to an
// UPPERCASE batch/lot run containing digits ("420gBNoBP41G6", phone-side
// "420gB.No.BP4166" with dot shreds) — \b alone fails there since both
// sides are word chars. The optional tail requires a digit inside, so
// plain words ("420grams") still reject. (No lookahead: the regex crate
// doesn't support it.)
pub(crate) static RE_NET_QTY: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:(?:net\s*(?:wt\.?|weight|we[i]?ght|qty\.?|quantity|content[s]?|vol\.?|volume|weicm)?|netwt|netweght|netqty|netquantity|netweight|netweicm|quantity|qty|vol|volume)\s*[:.]?\s*(?:[\s\S]{0,35}?[:.]?\s*)?)(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|ml|l|ltr|ltrs|n|u|units|m)(?:[A-Za-z.]*\d[A-Za-z0-9.]*)?\b").unwrap()
});

pub(crate) static RE_STANDALONE_QTY: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(\d+(?:\.\d+)?)\s*(kg|g|gm|ml|l|ltr|m)(?:[A-Za-z.]*\d[A-Za-z0-9.]*)?\b").unwrap()
});

static RE_ILLEGAL_UNITS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(\d+(?:\.\d+)?)\s*(gms?|gm|ml\.|kgs?\.?|ltrs?\.?)\b").unwrap()
});

pub(crate) static RE_MRP: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:m\.?r\.?p\.?[a-z]{0,3}|mrp\s*[rte]|max(?:imum)?\s*retail\s*price|maxretailprice)\s*[:.]?\s*(?:rs\.?|inr|₹|r|t|e)?\s*(?:[\s\S]{0,60}?[:.]?\s*(?:rs\.?|inr|₹|r|t|e)?\s*)?(\d{1,5}\.\d{2}|\b\d{2,5}\b)|(?:rs\.?|₹)\s*(\d{1,5}(?:\.\d{1,2})?)").unwrap()
});

static RE_TAX_INCL: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:(?:incl[a-z.]*|cinci|indl?|inclusive)\s*(?:of)?[\s\S]{0,120}?all\s*taxes|inclusive\s*of\s*all\s*taxes|incl\.?ofalltaxes|incl\.?alltaxes|inclofalltaxes|indl?\s*(?:of)?[\s\S]{0,120}?all\s*taxes|(?:incl|inclusive)[\s\S]{0,80}?taxes|\ball\s*taxes\b)").unwrap()
});

pub(crate) static RE_MFG_DATE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:mfg\.?|mfd\.?|pkd\.?|packed|manufactured|mfgdate|pkddate|mfdon|mid|mic|mio|pkd[.\s/]*(?:l?use)?(?:by)?|use\s*by)\s*(?:on\s*)?[:.]?\s*(?:date\s*[:.]?)?\s*(\d{1,2}[\s/-]*[A-Za-z]{3,9}\.?[\s/-]*\d{2,4}|(?:\d{1,2}[\s/-]*)?(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|j0l|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?[/-]?\s*\d{2,4}|(?:0[1-9]|1[0-2]|[o0][1-9d]|1[o0-2])\s*[/-]\s*(?:20\d{2}|19\d{2}|\d{2})|(?:0?[1-9]|[12][0-9]|3[01])[./-](?:0?[1-9]|1[0-2])[./-](?:20\d{2}|19\d{2}|\d{2})|(\d{1,2}(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|J0L|AUG|SEP|OCT|NOV|DEC|AP8)\d{2})\d{1,3}(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|J0L|AUG|SEP|OCT|NOV|DEC|AP8)[A-Za-z0-9]*|\d{1,2}(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|J0L|AUG|SEP|OCT|NOV|DEC|AP8)\d{2,4})").unwrap()
});

// Glued-date alternative: MFD and USEBY in one token ("17JUL26712APR2").
// Ordered BEFORE the general run so group 2 captures the 2-digit-year
// first date ("17JUL26", not year 2671). Code reads get(2).or(get(1)).
// (Consumes the tail instead of a lookahead: unsupported by this crate.)
pub(crate) // Dotted day-first dates first: DD.MM.YYYY is the common Indian stamp
// ("22.05.2026") and neither the month-word nor the MM/YYYY alternatives
// accept dots. Year needs 2+ digits so versions ("2.0") and decimals
// ("0.44") can't match; month 01-12 keeps "1.25%"-style values out.
static RE_STANDALONE_DATE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b((?:0?[1-9]|[12][0-9]|3[01])[./-](?:0?[1-9]|1[0-2])[./-](?:20\d{2}|19\d{2}|\d{2})\b|\d{1,2}[\s/-]*(?:jan|feb|mar|apr|may|jun|jul|j0l|aug|sep|oct|nov|dec)[a-z]*\.?[\s/-]*\d{2,4}\b|(\d{1,2}(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|J0L|AUG|SEP|OCT|NOV|DEC|AP8)\d{2})\d{1,3}(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|J0L|AUG|SEP|OCT|NOV|DEC|AP8)[A-Za-z0-9]*|\d{1,2}(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|J0L|AUG|SEP|OCT|NOV|DEC|AP8)\d{2,4}\b|(?:0[1-9]|1[0-2]|[o0][1-9d]|1[o0-2])\s*[/-]\s*(?:20\d{2}|19\d{2}|\d{2})\b)").unwrap()
});

static RE_COUNTRY_ORIGIN: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:country\s*of\s*origin|made\s*in|product\s*of|madeinindia|productofindia)\s*[:.]?\s*([a-zA-Z\s]+)?").unwrap()
});

pub(crate) static RE_EMAIL: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+").unwrap()
});

pub(crate) static RE_PHONE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:^|[^\d+])(?:1800[-\s]?[0-9mMnNoOzZ]{3}[-\s]?[0-9mMnNoOzZ]{3,4}|(?:\+9[0-9]?|0)?\s*[6-9]\d{2,4}[-\s]?\d{2,4}[-\s]?\d{2,4}|\d{3,4}[-\s]\d{6,8})\b").unwrap()
});

pub(crate) static RE_PINCODE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\b[1-9][0-9]{2}\s?[0-9]{3}\b").unwrap()
});

pub(crate) static RE_MFG_KEYWORDS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:mfg|manufactured|marketed|packed|imported|regd\.?\s*office|industrial\s*area|plot\s*no\.?|pvt\.?\s*ltd\.?|private\s*limited|ltd\.?|limited)\s*(?:by|at|for)?|manufacturedby|marketedby|regdoffice|industrialarea|plotno").unwrap()
});

static RE_UNIT_SALE_PRICE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:unit\s*sale\s*price|usp|unitsaleprice)\s*[:.]?\s*(?:rs\.?|₹)?\s*(\d+(?:\.\d{1,2})?)\s*(?:per|/)\s*(?:g|kg|ml|l|unit)").unwrap()
});

/// Byte-safe lookbehind window: `end` must be a char boundary (all call sites
/// pass regex match offsets, which are). Floors the start so multibyte text
/// (₹, accents) can never panic the slice.
fn safe_window(text: &str, end: usize, back: usize) -> &str {
    let s = text.floor_char_boundary(end.saturating_sub(back));
    &text[s..end]
}

/// Runs of 8+ consecutive digits are EAN/GTIN barcodes (or batch serials),
/// never quantity/date/price values. Seen live: "89017251005955 l" reported
/// as a 14-digit net quantity on a close-up half with no better candidate.
static RE_DIGIT_RUN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\d{8,}").unwrap());

/// True when the candidate value (or its host token) is barcode ballast.
pub(crate) fn is_barcode_ballast(val: &str, host: &str) -> bool {
    val.len() >= 8 && val.chars().all(|c| c.is_ascii_digit())
        || RE_DIGIT_RUN.is_match(host)
}

/// True when text looks like a nutrition facts table (2+ macro keywords).
/// Used by the guided quantity-step validator: a nutrition-only close-up is
/// the right *kind* of photo even when the net-weight print isn't in frame.
pub(crate) fn has_nutrition_table(text: &str) -> bool {
    const KEYS: [&str; 13] = [
        "carbohydrate",
        "sugar",
        "fat",
        "protein",
        "sodium",
        "energy",
        "serve",
        "serving",
        "kcal",
        "kj",
        "cholesterol",
        "saturate",
        "transfat",
    ];
    let low = text.to_lowercase();
    KEYS.iter().filter(|k| low.contains(**k)).count() >= 2
}

/// Count nutrition-table keywords in a context window (capped). Used to
/// penalize — not veto — quantity candidates, since dense panels interleave
/// nutrition rows with the true pack declaration in reading order.
fn nutrition_penalty(window: &str) -> u32 {
    const KEYS: [&str; 13] = [
        "carbohydrate",
        "sugar",
        "fat",
        "protein",
        "sodium",
        "energy",
        "serve",
        "serving",
        "kcal",
        "kj",
        "cholesterol",
        "saturate",
        "transfat",
    ];
    let low = window.to_lowercase();
    KEYS.iter()
        .filter(|k| low.contains(**k))
        .count()
        .min(3) as u32
}

/// Scan all RE_NET_QTY matches and return the best one: lowest nutrition
/// penalty in the 48-char lookbehind, tie-broken toward the largest value
/// (pack size exceeds per-serve macro values like "8.8g" vs "70g").
fn find_net_qty_candidate(combined_text: &str) -> Option<(String, String)> {
    let mut best: Option<(u32, f32, String, String)> = None;
    for caps in RE_NET_QTY.captures_iter(combined_text) {
        let Some(m) = caps.get(0) else { continue };
        let val_str = caps.get(1).map(|m| m.as_str()).unwrap_or("");
        let unit_raw = caps.get(2).map(|m| m.as_str()).unwrap_or("");
        if val_str.is_empty() || unit_raw.is_empty() {
            continue;
        }
        if is_barcode_ballast(val_str, val_str) {
            continue;
        }
        let val_start = caps.get(1).map(|m| m.start()).unwrap_or(m.start());
        let pen = nutrition_penalty(safe_window(combined_text, val_start, 48));
        let val: f32 = val_str.parse().unwrap_or(0.0);
        let mut unit_str = unit_raw.to_lowercase();
        let is_bare_m = unit_str == "m";
        if is_bare_m {
            // Truncated "500m" (curved-bottle clipping) is only credible with a
            // whole-word anchor immediately before the value. Without this,
            // soup-tolerance matches garbage like "nete m … 9 … M" (stray
            // capitals) and reports phantom "9 ml" quantities.
            static RE_BARE_M_ANCHOR: LazyLock<Regex> = LazyLock::new(|| {
                Regex::new(r"(?i)\b(net|quantity|qty|vol|volume)\b\s*[:.]?\s*$").unwrap()
            });
            if !RE_BARE_M_ANCHOR.is_match(safe_window(combined_text, val_start, 20)) {
                continue;
            }
            unit_str = "ml".to_string();
        }
        let replace = match &best {
            None => true,
            Some((bp, bv, _, _)) => pen < *bp || (pen == *bp && val > *bv),
        };
        if replace {
            best = Some((pen, val, val_str.to_string(), unit_str));
        }
    }
    best.map(|(_, _, v, u)| (v, u))
}
pub fn evaluate_compliance(
    tokens: &[OcrToken],
    image_width: u32,
    image_height: u32,
    product_name: Option<String>,
    scanned_panels: Vec<String>,
) -> ComplianceReport {
    evaluate_compliance_with_quality(
        tokens,
        image_width,
        image_height,
        product_name,
        scanned_panels,
        Vec::new(),
    )
}

/// Groups and sorts OCR tokens into natural left-to-right, top-to-bottom reading order.
/// Solves DBNet random contour order and handles same-line tokens with differing vertical heights.
fn sort_tokens_reading_order<'a>(tokens: &[&'a OcrToken]) -> Vec<&'a OcrToken> {
    if tokens.is_empty() {
        return Vec::new();
    }
    let mut sorted = tokens.to_vec();
    sorted.sort_by_key(|t| t.bbox.y);

    let mut lines: Vec<Vec<&'a OcrToken>> = Vec::new();
    for t in sorted {
        let mut placed = false;
        for line in lines.iter_mut().rev() {
            let line_y_min = line.iter().map(|tok| tok.bbox.y).min().unwrap_or(0);
            let line_y_max = line.iter().map(|tok| tok.bbox.y + tok.bbox.height).max().unwrap_or(0);
            let overlap_top = t.bbox.y.max(line_y_min);
            let overlap_bot = (t.bbox.y + t.bbox.height).min(line_y_max);
            if overlap_bot > overlap_top && (overlap_bot - overlap_top) * 4 >= t.bbox.height.max(1) {
                line.push(t);
                placed = true;
                break;
            }
        }
        if !placed {
            lines.push(vec![t]);
        }
    }

    let mut result = Vec::with_capacity(tokens.len());
    for mut line in lines {
        line.sort_by_key(|t| t.bbox.x);
        result.extend(line);
    }
    result
}

/// Evaluates pooled OCR tokens and panel image quality against Legal Metrology Rules, 2011 & Rule 7 Schedule II
pub fn evaluate_compliance_with_quality(
    tokens: &[OcrToken],
    _image_width: u32,
    image_height: u32,
    product_name: Option<String>,
    scanned_panels: Vec<String>,
    panel_qualities: Vec<super::quality::PanelImageQuality>,
) -> ComplianceReport {
    // Segregate tokens by panel so that text from distinct panels (e.g. nutrition table
    // from panel 1 and MRP declaration from panel 2) is NEVER interleaved by raw y-coordinates.
    let mut panels_map: std::collections::HashMap<Option<String>, Vec<&OcrToken>> = std::collections::HashMap::new();
    let mut panel_order: Vec<Option<String>> = Vec::new();
    for t in tokens {
        if !panels_map.contains_key(&t.source_image) {
            panel_order.push(t.source_image.clone());
        }
        panels_map.entry(t.source_image.clone()).or_default().push(t);
    }

    let mut sorted_all: Vec<&OcrToken> = Vec::new();
    let mut panel_text_blocks = Vec::new();
    let mut column_text_blocks = Vec::new();

    for panel_key in &panel_order {
        if let Some(panel_tokens) = panels_map.get(panel_key) {
            let sorted_panel = sort_tokens_reading_order(panel_tokens);
            let panel_str = sorted_panel
                .iter()
                .map(|t| t.text.as_str())
                .collect::<Vec<_>>()
                .join(" ");
            panel_text_blocks.push(panel_str);

            // Multi-column layout linearization per panel
            if panel_tokens.len() >= 6 {
                let min_x = panel_tokens.iter().map(|t| t.bbox.x).min().unwrap_or(0);
                let max_x = panel_tokens.iter().map(|t| t.bbox.x + t.bbox.width).max().unwrap_or(0);
                let width_span = max_x.saturating_sub(min_x);
                if width_span > 800 {
                    let mid_x = min_x + width_span / 2;
                    let mut left_col: Vec<&OcrToken> = Vec::new();
                    let mut right_col: Vec<&OcrToken> = Vec::new();
                    for t in panel_tokens {
                        let center_x = t.bbox.x + t.bbox.width / 2;
                        if center_x < mid_x {
                            left_col.push(t);
        } else {
                            right_col.push(t);
                        }
                    }
                    let sorted_left = sort_tokens_reading_order(&left_col);
                    let sorted_right = sort_tokens_reading_order(&right_col);
                    let left_str = sorted_left.iter().map(|t| t.text.as_str()).collect::<Vec<_>>().join(" ");
                    let right_str = sorted_right.iter().map(|t| t.text.as_str()).collect::<Vec<_>>().join(" ");
                    column_text_blocks.push(left_str);
                    column_text_blocks.push(right_str);
                }
            }

            sorted_all.extend(sorted_panel);
        }
    }

    let global_text = panel_text_blocks.join(" \n ");
    let combined_text = if !column_text_blocks.is_empty() {
        format!("{} \n {}", global_text, column_text_blocks.join(" \n "))
    } else {
        global_text
    };

    let mut evaluations = Vec::new();
    let mut violations_count = 0;
    let mut missing_fields = Vec::new();
    let mut non_standard_units = Vec::new();
    let mut statutory_penalties = Vec::new();

    // 1. Rule 6(1)(a): Manufacturer / Packer / Importer Details
    let has_mfg_keyword = RE_MFG_KEYWORDS.is_match(&combined_text);
    let has_pin = RE_PINCODE.is_match(&combined_text);
    let (mfg_bbox, mfg_panel, mfg_conf) = find_first_match(tokens, &RE_MFG_KEYWORDS);

    if has_mfg_keyword && has_pin {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ManufacturerDetails,
            legal_clause: DeclarationField::ManufacturerDetails.legal_clause().to_string(),
            status: Status::Compliant,
            detected_text: Some("Manufacturer identity and postal PIN detected".to_string()),
            confidence: mfg_conf.unwrap_or(0.90),
            bbox: mfg_bbox.clone(),
            source_panel: mfg_panel.clone(),
            remarks: "Complies with Rule 6(1)(a): Complete address and postal PIN code identified.".to_string(),
        });
    } else if has_mfg_keyword || has_pin {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ManufacturerDetails,
            legal_clause: DeclarationField::ManufacturerDetails.legal_clause().to_string(),
            status: Status::Warning,
            detected_text: Some("Partial manufacturer declaration".to_string()),
            confidence: mfg_conf.map(|c| (c * 0.85).clamp(0.1, 0.99)).unwrap_or(0.70),
            bbox: mfg_bbox.clone(),
            source_panel: mfg_panel.clone(),
            remarks: "Incomplete address or missing postal PIN code under Rule 6(1)(a).".to_string(),
        });
    } else {
        violations_count += 1;
        missing_fields.push(DeclarationField::ManufacturerDetails);
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ManufacturerDetails,
            legal_clause: DeclarationField::ManufacturerDetails.legal_clause().to_string(),
            status: Status::Violation,
            detected_text: None,
            confidence: 0.0,
            bbox: None,
            source_panel: None,
            remarks: "VIOLATION: Name and address of manufacturer/packer missing entirely.".to_string(),
        });
    }

    // 2. Rule 6(1)(c) & Rule 13: Net Quantity and Standard Units
    let mut net_qty_val: Option<f32> = None;
    let mut net_qty_unit: Option<String> = None;
    let mut detected_qty: Option<(String, String)> = None;
    let mut qty_bbox: Option<BoundingBox> = None;
    let mut qty_panel: Option<String> = None;
    let mut qty_conf: Option<f32> = None;

    if let Some((val_str, unit_str)) = find_net_qty_candidate(&combined_text) {
        detected_qty = Some((val_str.clone(), unit_str.clone()));
        let (bb, sp, qc) = find_first_match(tokens, &RE_NET_QTY);
        qty_bbox = bb;
        qty_panel = sp;
        qty_conf = qc;
        if qty_bbox.is_none() {
            for t in tokens {
                if t.text.contains(val_str.as_str()) || (!unit_str.is_empty() && t.text.to_lowercase().contains(&unit_str)) {
                    qty_bbox = Some(t.bbox.clone());
                    qty_panel = t.source_image.clone();
                    qty_conf = Some(t.confidence);
                    break;
                }
            }
        }
    } else {
        // Standalone pack volume/weight fallback (no "net" anchor in text).
        // Rank candidates across reading order: net-adjacent first, then lowest
        // nutrition penalty, then largest value (pack size beats per-serve
        // macros). Never veto outright — a penalized guess beats a false
        // "missing" violation when the anchor was simply OCR-mangled.
        let mut best: Option<(bool, u32, f32, String, String, usize)> = None;
        for (idx, t) in sorted_all.iter().enumerate() {
            let caps = match RE_STANDALONE_QTY.captures(&t.text) {
                Some(c) => c,
                None => continue,
            };
            let lo = idx.saturating_sub(4);
            let hi = (idx + 5).min(sorted_all.len());
            let context = sorted_all[lo..hi]
                .iter()
                .map(|x| x.text.as_str())
                .collect::<Vec<_>>()
                .join(" ");
            let val_str = caps.get(1).map(|m| m.as_str()).unwrap_or("");
            let unit_raw = caps.get(2).map(|m| m.as_str()).unwrap_or("");
            if is_barcode_ballast(val_str, &t.text) {
                continue;
            }
            let mut unit_str = unit_raw.to_lowercase();
            if unit_str == "m" {
                unit_str = "ml".to_string();
            }
            // Whole-word anchors only: substring matching lets OCR fragments
            // like "nete m" pose as quantity anchors (phantom "9 ml" bug).
            static RE_ANCHOR_WORD: LazyLock<Regex> = LazyLock::new(|| {
                Regex::new(r"(?i)\b(net|quantity|qty|vol|volume|content)\b").unwrap()
            });
            let has_net = RE_ANCHOR_WORD.is_match(&context);
            // If unit was truncated 'm', require a net/quantity/volume anchor in context
            if unit_raw.eq_ignore_ascii_case("m") && !has_net {
                continue;
            }
            let pen = nutrition_penalty(&context);
            let val: f32 = val_str.parse().unwrap_or(0.0);
            let replace = match &best {
                None => true,
                Some((bh, bp, bv, _, _, _)) => {
                    (has_net && !bh)
                        || (has_net == *bh && (pen < *bp || (pen == *bp && val > *bv)))
                }
            };
            if replace {
                best = Some((has_net, pen, val, val_str.to_string(), unit_str.to_string(), idx));
            }
        }
        if let Some((_, _, _, val_str, unit_str, idx)) = best {
            let t = sorted_all[idx];
            detected_qty = Some((val_str, unit_str));
            qty_bbox = Some(t.bbox.clone());
            qty_panel = t.source_image.clone();
            qty_conf = Some(t.confidence);
        }

        if detected_qty.is_none() {
            // Spatial 2D adjacency fallback for rotated or columnar packaging:
            // Checks if a quantity/volume anchor and a quantity number are geometrically aligned
            for t_anchor in sorted_all.iter() {
                let text_low = t_anchor.text.to_lowercase();
                if text_low.contains("quantity") || text_low.contains("qty") || text_low.contains("net") || text_low.contains("vol") {
                    for t_val in sorted_all.iter() {
                        let dx = (t_val.bbox.x as i32 - t_anchor.bbox.x as i32).abs();
                        let dy = (t_val.bbox.y as i32 - t_anchor.bbox.y as i32).abs();
                        // Either vertically aligned (same column) or horizontally aligned (same row)
                        if (dx < 140 && dy < 800) || (dy < 80 && dx < 600) {
                            if let Some(caps) = RE_STANDALONE_QTY.captures(&t_val.text) {
                                let v = caps.get(1).map(|m| m.as_str()).unwrap_or("");
                                if is_barcode_ballast(v, &t_val.text) {
                                    continue;
                                }
                                let u_raw = caps.get(2).map(|m| m.as_str()).unwrap_or("");
                                let u = if u_raw.eq_ignore_ascii_case("m") { "ml" } else { u_raw };
                                detected_qty = Some((v.to_string(), u.to_string()));
                                qty_bbox = Some(t_val.bbox.clone());
                                qty_panel = t_val.source_image.clone();
                                qty_conf = Some(t_val.confidence);
                                break;
                            }
                        }
                    }
                    if detected_qty.is_some() {
                        break;
                    }
                }
            }
        }
    }

    if let Some((ref val_str, ref unit_str)) = detected_qty {
        net_qty_val = val_str.parse().ok();
        net_qty_unit = Some(unit_str.to_lowercase());

        let declared_qty_str = format!("{val_str} {unit_str}");
        let is_illegal_unit = RE_ILLEGAL_UNITS.is_match(&declared_qty_str);
        let standard_units = ["g", "kg", "ml", "l", "ltr", "n", "u", "units"];
        let is_standard = standard_units.contains(&unit_str.to_lowercase().as_str());
        let assigned_conf = qty_conf.unwrap_or(0.92);

        if is_illegal_unit || !is_standard {
            violations_count += 1;
            non_standard_units.push(unit_str.to_string());
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::NetQuantity,
                legal_clause: DeclarationField::NetQuantity.legal_clause().to_string(),
                status: Status::Violation,
                detected_text: Some(format!("{val_str} {unit_str}")),
                confidence: assigned_conf,
                bbox: qty_bbox.clone(),
                source_panel: qty_panel.clone(),
                remarks: format!("VIOLATION under Rule 13: Non-standard unit '{unit_str}'. Law permits only SI symbols (g, kg, ml, l)."),
            });
        } else {
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::NetQuantity,
                legal_clause: DeclarationField::NetQuantity.legal_clause().to_string(),
                status: Status::Compliant,
                detected_text: Some(format!("{val_str} {unit_str}")),
                confidence: assigned_conf,
                bbox: qty_bbox.clone(),
                source_panel: qty_panel.clone(),
                remarks: format!("Compliant: Net quantity declared as {val_str} {unit_str} using standard metric symbol."),
            });
        }
    } else {
        violations_count += 1;
        missing_fields.push(DeclarationField::NetQuantity);
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::NetQuantity,
            legal_clause: DeclarationField::NetQuantity.legal_clause().to_string(),
            status: Status::Violation,
            detected_text: None,
            confidence: 0.0,
            bbox: None,
            source_panel: None,
            remarks: "VIOLATION under Rule 6(1)(c): Net quantity declaration not found across scanned panels.".to_string(),
        });
    }

    // 3. Rule 6(1)(e): Maximum Retail Price (MRP) and Tax clause
    let (mut mrp_bbox, mut mrp_panel, mrp_conf) = find_first_match(tokens, &RE_MRP);
    if mrp_bbox.is_none() {
        for t in tokens {
            if t.text.to_lowercase().contains("mrp") {
                mrp_bbox = Some(t.bbox.clone());
                mrp_panel = t.source_image.clone();
                break;
            }
        }
    }
    let mut detected_price: Option<String> = None;
    // True when the price came from the label-less fragment fallback below:
    // a lead, not proof — the Compliant branch must downgrade to Warning.
    let mut mrp_frag_unlabelled = false;

    // Ranked MRP candidates: decimal prices beat bare integers (100.00 over the
    // 460 in "460g"), currency-marked beats unmarked, nearer the MRP anchor wins.
    // Previously the first regex capture won, grabbing pack weights ("MRP 460").
    {
        // Byte offset of the first MRP anchor for proximity ranking.
        let anchor_pos = RE_MRP
            .find_iter(&combined_text)
            .map(|m| m.start())
            .min()
            .unwrap_or(0);
        // (price_val, text, has_decimal, has_currency, nut_pen, dist_from_anchor)
        let mut cands: Vec<(f32, String, bool, bool, u32, usize)> = Vec::new();
        let push_cand = |val: f32, text: String, pos: usize, cands: &mut Vec<(f32, String, bool, bool, u32, usize)>| {
            if !(5.0..=10000.0).contains(&val) {
                return;
            }
            if let Some((ref q_val, _)) = detected_qty {
                if let Ok(q_f) = q_val.parse::<f32>() {
                    if (val - q_f).abs() < 0.01 {
                        return; // Exclude net quantity numeral
                    }
                }
            }
            // Skip numbers glued to a unit suffix ("460g"): peek after match.
            let after = combined_text[pos..].chars().nth(text.len());
            if matches!(after, Some(c) if c.is_ascii_alphabetic()) {
                return;
            }
            // Skip numerals in manufacturing/packing date or unit sale price context ("Pkd. 15 JUN 2026", "USP Rs. 0.22/g")
            let win_start = safe_window(&combined_text, pos, 35);
            let before = win_start.to_lowercase();
            if before.contains("pkd")
                || before.contains("mfd")
                || before.contains("mfg")
                || before.contains("packed")
                || before.contains("date")
                || before.contains("exp")
                || before.contains("use by")
                || before.contains("unit sale")
                || before.contains("usp")
            {
                return;
            }
            let after_snippet = combined_text[pos..].chars().take(20).collect::<String>().to_lowercase();
            static RE_DATE_TRAILER: LazyLock<Regex> = LazyLock::new(|| {
                Regex::new(r"(?i)^\d+[\s/-]*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)").unwrap()
            });
            if RE_DATE_TRAILER.is_match(&after_snippet) {
                return;
            }

            let has_currency =
                before.contains('₹') || before.contains("rs") || before.contains("inr");
            let has_decimal = text.contains('.');
            let nut_pen = nutrition_penalty(win_start);
            let dist = pos.saturating_sub(anchor_pos);
            cands.push((val, text, has_decimal, has_currency, nut_pen, dist));
        };

        for caps in RE_MRP.captures_iter(&combined_text) {
            for g in [1, 2] {
                if let Some(m) = caps.get(g) {
                    let txt = m.as_str().to_string();
                    if let Ok(val) = txt.parse::<f32>() {
                        push_cand(val, txt, m.start(), &mut cands);
                    }
                    break;
                }
            }
        }
        cands.sort_by(|a, b| {
            a.4.cmp(&b.4) // lowest nutrition penalty wins (0 beats >0)
                .then_with(|| b.3.cmp(&a.3)) // currency mark wins
                .then_with(|| b.2.cmp(&a.2)) // decimal wins
                .then_with(|| a.5.cmp(&b.5)) // nearer anchor wins
                .then_with(|| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal))
        });
        if let Some((_, txt, _, _, _, _)) = cands.into_iter().next() {
            detected_price = Some(txt);
        }
    }

    // Spatial proximity fallback: find floating price numeral adjacent to MRP anchor
    if detected_price.is_none() {
        if let Some(ref m_bb) = mrp_bbox {
            static RE_FLOAT_PRICE: LazyLock<Regex> = LazyLock::new(|| {
                Regex::new(r"^\b(\d{1,4}(?:\.\d{1,2})?)\b$").unwrap()
            });
            let mut spatial_cands: Vec<(f32, String, bool, i64)> = Vec::new();
            for t in tokens {
                if t.source_image == mrp_panel {
                    let dy = (t.bbox.y as i64 - m_bb.y as i64).abs();
                    let dx = (t.bbox.x as i64 - m_bb.x as i64).abs();
                    if (dx.max(dy) <= 650 && dx.min(dy) <= 220) || (dx <= 700 && dy <= 300) {
                        if let Some(caps) = RE_FLOAT_PRICE.captures(t.text.trim()) {
                            if let Some(m) = caps.get(1) {
                                let p = m.as_str();
                                if let Ok(val) = p.parse::<f32>() {
                                    if let Some((ref q_val, _)) = detected_qty {
                                        if let Ok(q_f) = q_val.parse::<f32>() {
                                            if (val - q_f).abs() < 0.01 {
                                                continue; // Exclude net quantity numeral
                                            }
                                        }
                                    }
                                    if (5.0..=10000.0).contains(&val) {
                                        let dist_sq = dx * dx + dy * dy;
                                        let has_decimal = p.contains('.');
                                        spatial_cands.push((val, p.to_string(), has_decimal, dist_sq));
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Prefer decimal prices (100.00 over 10 or 460), then closest spatial distance
            spatial_cands.sort_by(|a, b| {
                b.2.cmp(&a.2) // decimal wins
                    .then_with(|| a.3.cmp(&b.3)) // closer distance wins
                    .then_with(|| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal))
            });
            if let Some((_, p, _, _)) = spatial_cands.into_iter().next() {
                detected_price = Some(p);
            }
        }
    }

    // Label-less MRP fragment fallback (vertical-strip packs): a price-like
    // token near a tax declaration, e.g. "9000R5.0219" beside "otall taxes/"
    // where the MRP label itself never survived OCR. Warning only — without
    // a label this is a lead, not proof. Guards mirror push_cand (qty/date
    // exclusion) plus mandatory tax-token proximity and a non-empty
    // fragmentation trailer (bare integers stay out).
    if detected_price.is_none() {
        static RE_PRICE_FRAG: LazyLock<Regex> = LazyLock::new(|| {
            Regex::new(r"^(\d{2,5}(?:\.\d{1,2})?)([A-Za-z].*)?$").unwrap()
        });
        static RE_DATE_TRAILER: LazyLock<Regex> = LazyLock::new(|| {
            Regex::new(r"(?i)^\d+[\s/-]*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)").unwrap()
        });
        // Tax proximity in CHARACTER space (combined_text), not token-index
        // space: reading-order sort interleaves vertical-strip tokens with
        // body text, so index adjacency is meaningless on these packs.
        for t in sorted_all.iter() {
            let text = t.text.trim();
            let caps = match RE_PRICE_FRAG.captures(text) {
                Some(c) => c,
                None => continue,
            };
            let num = caps.get(1).map(|m| m.as_str()).unwrap_or("");
            let trailer = caps.get(2).map(|m| m.as_str()).unwrap_or("");
            // Bare integers are handled by other paths; fragments only.
            if trailer.is_empty() && !num.contains('.') {
                continue;
            }
            let val: f32 = match num.parse() {
                Ok(v) => v,
                Err(_) => continue,
            };
            if !(5.0..=10000.0).contains(&val) {
                continue;
            }
            if let Some((ref q_val, _)) = detected_qty {
                if let Ok(q_f) = q_val.parse::<f32>() {
                    if (val - q_f).abs() < 0.01 {
                        continue; // Exclude net quantity numeral
                    }
                }
            }
            if RE_DATE_TRAILER.is_match(text) || RE_STANDALONE_DATE.is_match(text) {
                continue; // Date fragment, not price
            }
            let pos = combined_text.find(text).unwrap_or(usize::MAX);
            if pos == usize::MAX {
                continue;
            }
            let lo = combined_text.floor_char_boundary(pos.saturating_sub(150));
            let hi = combined_text
                .floor_char_boundary((pos + text.len() + 150).min(combined_text.len()));
            if !combined_text[lo..hi].to_lowercase().contains("tax") {
                continue;
            }
            {
                let before = safe_window(&combined_text, pos, 35).to_lowercase();
                if before.contains("pkd")
                    || before.contains("mfd")
                    || before.contains("mfg")
                    || before.contains("packed")
                    || before.contains("date")
                    || before.contains("exp")
                    || before.contains("use by")
                    || before.contains("unit sale")
                    || before.contains("usp")
                {
                    continue;
                }
            }
            detected_price = Some(num.to_string());
            mrp_bbox = Some(t.bbox.clone());
            mrp_panel = t.source_image.clone();
            mrp_frag_unlabelled = true;
            break;
        }
    }

    if let Some(price) = detected_price {
        let has_tax_clause = RE_TAX_INCL.is_match(&combined_text)
            || tokens.iter().any(|t| {
                let l = t.text.to_lowercase();
                l.contains("all taxes") || (l.contains("tax") && (l.contains("incl") || l.contains("indl") || l.contains("cinci")))
            })
            || (tokens.iter().any(|t| {
                let l = t.text.to_lowercase();
                l.contains("incl") || l.contains("indl") || l.contains("inclusive") || l.contains("cinci")
            }) && tokens.iter().any(|t| {
                t.text.to_lowercase().contains("tax")
            }));
        let base_conf = mrp_conf.unwrap_or(0.90);

        if has_tax_clause && !mrp_frag_unlabelled {
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::MaximumRetailPrice,
                legal_clause: DeclarationField::MaximumRetailPrice.legal_clause().to_string(),
                status: Status::Compliant,
                detected_text: Some(format!("MRP Rs./₹ {price} (incl. of all taxes)")),
                confidence: base_conf,
                bbox: mrp_bbox.clone(),
                source_panel: mrp_panel.clone(),
                remarks: "Complies with Rule 6(1)(e): Retail sale price clearly stated inclusive of all taxes.".to_string(),
            });
        } else if mrp_frag_unlabelled {
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::MaximumRetailPrice,
                legal_clause: DeclarationField::MaximumRetailPrice.legal_clause().to_string(),
                status: Status::Warning,
                detected_text: Some(format!("MRP {price} (label unreadable — price fragment near tax declaration)")),
                confidence: (base_conf * 0.70).clamp(0.10, 0.99),
                bbox: mrp_bbox.clone(),
                source_panel: mrp_panel.clone(),
                remarks: "WARNING: Price fragment found beside the tax declaration but the MRP label itself was not readable — verify on pack.".to_string(),
            });
        } else {
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::MaximumRetailPrice,
                legal_clause: DeclarationField::MaximumRetailPrice.legal_clause().to_string(),
                status: Status::Warning,
                detected_text: Some(format!("MRP {price}")),
                confidence: (base_conf * 0.90).clamp(0.10, 0.99),
                bbox: mrp_bbox.clone(),
                source_panel: mrp_panel.clone(),
                remarks: "WARNING: Price detected but 'inclusive of all taxes' clause was not explicitly confirmed.".to_string(),
            });
        }
    } else if mrp_bbox.is_some() {
        // MRP label located (e.g. phone-side "MRPBS.iC.") but no price
        // numeral survived near it. "Missing from all panels" would be
        // false — the declaration is there, its value isn't.
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::MaximumRetailPrice,
            legal_clause: DeclarationField::MaximumRetailPrice.legal_clause().to_string(),
            status: Status::Warning,
            detected_text: Some("MRP label located, price numeral unreadable".to_string()),
            confidence: 0.60,
            bbox: mrp_bbox.clone(),
            source_panel: mrp_panel.clone(),
            remarks: "WARNING: MRP declaration located but the price numeral was not readable — verify on pack.".to_string(),
        });
    } else {
        violations_count += 1;
        missing_fields.push(DeclarationField::MaximumRetailPrice);
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::MaximumRetailPrice,
            legal_clause: DeclarationField::MaximumRetailPrice.legal_clause().to_string(),
            status: Status::Violation,
            detected_text: None,
            confidence: 0.0,
            bbox: None,
            source_panel: None,
            remarks: "VIOLATION under Rule 6(1)(e): Maximum Retail Price (MRP) missing from all panels.".to_string(),
        });
    }

    // 4. Rule 6(1)(d): Month & Year of Manufacture / Packing
    // Unified date ranking across anchored AND standalone matches: packing
    // context (MFD/MFG/PKD/Lot/Batch) beats expiry context (Use-by/Exp), then
    // earliest position. Previously the first regex hit won, reporting
    // "Use by 2027" as the packing date while "MFD 2026" sat later in text.
    let (mut date_bbox, mut date_panel, mut date_conf) = find_first_match(tokens, &RE_MFG_DATE);
    let detected_date: Option<String>;

    {
        // (rank, pos, text); lower rank wins.
        let mut best: Option<(u32, usize, String)> = None;
        let consider = |val: &str, pos: usize, best: &mut Option<(u32, usize, String)>| {
            let ctx = safe_window(&combined_text, pos, 48).to_lowercase();
            let is_expiry = ctx.contains("use by")
                || ctx.contains("useby")
                || ctx.contains("expir")
                || ctx.contains("best before")
                || ctx.contains("bestbefore");
            let is_packing = ctx.contains("mfd")
                || ctx.contains("mfg")
                || ctx.contains("pkd")
                || ctx.contains("packed")
                || ctx.contains("manufact")
                || ctx.contains("lot")
                || ctx.contains("batch")
                || ctx.contains("mic")
                || ctx.contains("mio")
                || ctx.contains("mid");
            let rank = (is_expiry as u32) * 2 + (!is_packing as u32);
            let replace = match best {
                None => true,
                Some((br, bp, _)) => rank < *br || (rank == *br && pos < *bp),
            };
            if replace {
                *best = Some((rank, pos, val.to_string()));
            }
        };
        for caps in RE_MFG_DATE.captures_iter(&combined_text) {
            // Group 2 = glued-date prefix ("17JUL26" out of "17JUL26712APR2");
            // absent for every other alternative, hence the fallback.
            if let Some(m) = caps.get(2).or_else(|| caps.get(1)) {
                consider(m.as_str(), m.start(), &mut best);
            }
        }
        // Standalone dates only fill gaps the anchored pass missed: skip any
        // value already selected to avoid double-counting the same print.
        let taken = best.as_ref().map(|(_, _, s)| s.clone()).unwrap_or_default();
        for caps in RE_STANDALONE_DATE.captures_iter(&combined_text) {
            if let Some(m) = caps.get(2).or_else(|| caps.get(1)) {
                if !taken.is_empty() && (m.as_str() == taken || taken.contains(m.as_str())) {
                    continue;
                }
                consider(m.as_str(), m.start(), &mut best);
            }
        }
        detected_date = best.map(|(_, _, s)| s);
    }

    if date_bbox.is_none() {
        let (s_bbox, s_panel, s_conf) = find_first_match(tokens, &RE_STANDALONE_DATE);
        if s_bbox.is_some() {
            date_bbox = s_bbox;
            date_panel = s_panel;
            date_conf = s_conf;
        } else if let Some(ref ds) = detected_date {
            if let Some(t) = tokens.iter().find(|tok| tok.text.contains(ds.as_str()) || ds.contains(tok.text.as_str())) {
                date_bbox = Some(t.bbox.clone());
                date_panel = t.source_image.clone();
                date_conf = Some(t.confidence);
            }
        }
    }

    if let Some(date_str) = detected_date {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ManufactureDate,
            legal_clause: DeclarationField::ManufactureDate.legal_clause().to_string(),
            status: Status::Compliant,
            detected_text: Some(date_str.clone()),
            confidence: date_conf.unwrap_or(0.88),
            bbox: date_bbox,
            source_panel: date_panel,
            remarks: format!("Complies with Rule 6(1)(d): Packing date found as {date_str}."),
        });
    } else {
        violations_count += 1;
        missing_fields.push(DeclarationField::ManufactureDate);
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ManufactureDate,
            legal_clause: DeclarationField::ManufactureDate.legal_clause().to_string(),
            status: Status::Violation,
            detected_text: None,
            confidence: 0.0,
            bbox: None,
            source_panel: None,
            remarks: "VIOLATION under Rule 6(1)(d): Month and year of manufacture/packing missing.".to_string(),
        });
    }

    // 5. Rule 6(1)(da): Country of Origin (2021 Amendment)
    let (coo_bbox, coo_panel, coo_conf) = find_first_match(tokens, &RE_COUNTRY_ORIGIN);

    if let Some(caps) = RE_COUNTRY_ORIGIN.captures(&combined_text) {
        let country = caps.get(1).map(|m| m.as_str().trim()).unwrap_or("India");
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::CountryOfOrigin,
            legal_clause: DeclarationField::CountryOfOrigin.legal_clause().to_string(),
            status: Status::Compliant,
            detected_text: Some(country.to_string()),
            confidence: coo_conf.unwrap_or(0.88),
            bbox: coo_bbox,
            source_panel: coo_panel,
            remarks: format!("Complies with Rule 6(1)(da): Country of Origin declared ({country})."),
        });
    } else if combined_text.to_lowercase().contains("india") || combined_text.to_lowercase().contains("madeinindia") {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::CountryOfOrigin,
            legal_clause: DeclarationField::CountryOfOrigin.legal_clause().to_string(),
            status: Status::Compliant,
            detected_text: Some("India".to_string()),
            confidence: coo_conf.unwrap_or(0.82),
            bbox: coo_bbox,
            source_panel: coo_panel,
            remarks: "Complies: Country of Origin identified (India).".to_string(),
        });
    } else if has_pin && has_mfg_keyword {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::CountryOfOrigin,
            legal_clause: DeclarationField::CountryOfOrigin.legal_clause().to_string(),
            status: Status::Compliant,
            detected_text: Some("India (Domestic Manufacturer Address)".to_string()),
            confidence: 0.88,
            bbox: mfg_bbox.clone(),
            source_panel: mfg_panel.clone(),
            remarks: "Complies with Rule 6(1)(da): Domestic origin established via verified Indian manufacturing premises & postal PIN.".to_string(),
        });
    } else {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::CountryOfOrigin,
            legal_clause: DeclarationField::CountryOfOrigin.legal_clause().to_string(),
            status: Status::Warning,
            detected_text: None,
            confidence: 0.0,
            bbox: None,
            source_panel: None,
            remarks: "Country of Origin not explicitly stated (Mandated under 2021 Amendment).".to_string(),
        });
    }

    // 6. Rule 6(1)(g): Consumer Care / Grievance Redressal
    let mut has_email = RE_EMAIL.is_match(&combined_text);
    let has_phone = RE_PHONE.is_match(&combined_text);
    let (mut care_bbox, mut care_panel, mut care_conf) = find_first_match(tokens, &RE_EMAIL);
    let mut stitched_email: Option<String> = None;

    // Repair OCR-split emails: "WECARE eIN.NESTLECOM" (the @ glyph read as 'e'
    // or dropped between boxes). Care-keyword anchored, so false positives are
    // near-impossible outside grievance blocks.
    if !has_email {
        static RE_SPLIT_EMAIL: LazyLock<Regex> = LazyLock::new(|| {
            Regex::new(r"(?i)\b(wecare|customercare|customer\s*care|support|helpdesk|helpline|feedback|care|email|e-mail|mail|contact)\s+([a-z0-9][a-z0-9._-]*\.[a-z]{2,}(?:\.[a-z]{2,})?)\b").unwrap()
        });
        if let Some(caps) = RE_SPLIT_EMAIL.captures(&combined_text) {
            // Reconstruct "WECARE eIN.NESTLECOM" -> "wecare@ein.nestlecom".
            let local = caps.get(1).map(|m| m.as_str()).unwrap_or("care");
            let domain = caps.get(2).map(|m| m.as_str()).unwrap_or("");
            if !domain.is_empty() {
                has_email = true;
                stitched_email = Some(format!(
                    "{}@{}",
                    local.to_lowercase().replace(' ', ""),
                    domain.to_lowercase()
                ));
                let (bb, sp, cf) = find_first_match(tokens, &RE_SPLIT_EMAIL);
                care_bbox = bb;
                care_panel = sp;
                care_conf = cf;
            }
        }
    }

    if has_email && has_phone {
        let contact_note = stitched_email
            .map(|e| format!("Both telephone and email grievance channels confirmed ({e})"))
            .unwrap_or_else(|| {
                "Both telephone and email grievance channels confirmed".to_string()
            });
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ConsumerCare,
            legal_clause: DeclarationField::ConsumerCare.legal_clause().to_string(),
            status: Status::Compliant,
            detected_text: Some(contact_note),
            confidence: care_conf.unwrap_or(0.94),
            bbox: care_bbox,
            source_panel: care_panel,
            remarks: "Complies with Rule 6(1)(g): Complete consumer grievance mechanism available.".to_string(),
        });
    } else if has_email || has_phone {
        let (phone_bbox, phone_panel, phone_conf) = find_first_match(tokens, &RE_PHONE);
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ConsumerCare,
            legal_clause: DeclarationField::ConsumerCare.legal_clause().to_string(),
            status: Status::Warning,
            detected_text: Some("Partial consumer care details (missing either phone or email)".to_string()),
            confidence: phone_conf.or(care_conf).map(|c| (c * 0.85).clamp(0.1, 0.99)).unwrap_or(0.75),
            bbox: phone_bbox.or(care_bbox),
            source_panel: phone_panel.or(care_panel),
            remarks: "Rule 6(1)(g) mandates both telephone number and email address for consumer grievances.".to_string(),
        });
    } else {
        violations_count += 1;
        missing_fields.push(DeclarationField::ConsumerCare);
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::ConsumerCare,
            legal_clause: DeclarationField::ConsumerCare.legal_clause().to_string(),
            status: Status::Violation,
            detected_text: None,
            confidence: 0.0,
            bbox: None,
            source_panel: None,
            remarks: "VIOLATION under Rule 6(1)(g): Consumer care telephone/email details missing across all panels.".to_string(),
        });
    }

    // 7. Rule 6(1)(f): Unit Sale Price (Mandatory if >= 1kg or >= 1L)
    let is_large_pack = match (net_qty_val, net_qty_unit.as_deref()) {
        (Some(v), Some("kg")) if v >= 1.0 => true,
        (Some(v), Some("l") | Some("ltr") | Some("ltrs")) if v >= 1.0 => true,
        (Some(v), Some("g")) if v >= 1000.0 => true,
        (Some(v), Some("ml")) if v >= 1000.0 => true,
        _ => false,
    };

    if is_large_pack {
        let has_usp = RE_UNIT_SALE_PRICE.is_match(&combined_text);
        let (usp_bbox, usp_panel, usp_conf) = find_first_match(tokens, &RE_UNIT_SALE_PRICE);
        if has_usp {
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::UnitSalePrice,
                legal_clause: DeclarationField::UnitSalePrice.legal_clause().to_string(),
                status: Status::Compliant,
                detected_text: Some("Unit Sale Price declared".to_string()),
                confidence: usp_conf.unwrap_or(0.88),
                bbox: usp_bbox,
                source_panel: usp_panel,
                remarks: "Complies with Rule 6(1)(f): Unit sale price declared for bulk packaging (>= 1kg/1L).".to_string(),
            });
        } else {
            violations_count += 1;
            missing_fields.push(DeclarationField::UnitSalePrice);
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::UnitSalePrice,
                legal_clause: DeclarationField::UnitSalePrice.legal_clause().to_string(),
                status: Status::Violation,
                detected_text: None,
                confidence: 0.0,
                bbox: None,
                source_panel: None,
                remarks: "VIOLATION under Rule 6(1)(f) (2021 Amendment): Package exceeds 1kg/1L, but Unit Sale Price (USP) is missing.".to_string(),
            });
        }
    } else {
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::UnitSalePrice,
            legal_clause: DeclarationField::UnitSalePrice.legal_clause().to_string(),
            status: Status::NotApplicable,
            detected_text: None,
            confidence: 1.0,
            bbox: None,
            source_panel: None,
            remarks: "Exempt from Rule 6(1)(f): Unit sale price not mandatory for pack sizes below 1kg / 1L.".to_string(),
        });
    }

    // 8. Rule 7 & Schedule II: Minimum Height of Numerals & Letters
    let primary_numeral_bbox = qty_bbox.as_ref().or(mrp_bbox.as_ref());
    let primary_panel = qty_panel.as_ref().or(mrp_panel.as_ref());

    if let Some(bbox) = primary_numeral_bbox {
        // True font height is the transverse dimension across the text box
        let font_height = bbox.width.min(bbox.height);
        let panel_dim = if image_height > 0 { image_height } else { 1000 };
        let ratio = font_height as f32 / panel_dim as f32;

        if ratio < 0.005 || font_height < 10 {
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::Rule7NumeralHeight,
                legal_clause: DeclarationField::Rule7NumeralHeight.legal_clause().to_string(),
                status: Status::Warning,
                detected_text: Some(format!("Numeral font height: {}px ({:.2}% of panel)", font_height, ratio * 100.0)),
                confidence: 0.85,
                bbox: Some(bbox.clone()),
                source_panel: primary_panel.cloned(),
                remarks: "WARNING under Rule 7 / Schedule II: Declared numeral height is below recommended visibility threshold (< 0.5% of packaging height). High risk of consumer illegibility.".to_string(),
            });
        } else {
            evaluations.push(RequirementEvaluation {
                field: DeclarationField::Rule7NumeralHeight,
                legal_clause: DeclarationField::Rule7NumeralHeight.legal_clause().to_string(),
                status: Status::Compliant,
                detected_text: Some(format!("Numeral font height: {}px ({:.2}% of panel)", font_height, ratio * 100.0)),
                confidence: 0.95,
                bbox: Some(bbox.clone()),
                source_panel: primary_panel.cloned(),
                remarks: "Complies with Rule 7 & Schedule II: Numeral and letter height conforms to statutory visibility thresholds.".to_string(),
            });
        }
    } else {
        violations_count += 1;
        missing_fields.push(DeclarationField::Rule7NumeralHeight);
        evaluations.push(RequirementEvaluation {
            field: DeclarationField::Rule7NumeralHeight,
            legal_clause: DeclarationField::Rule7NumeralHeight.legal_clause().to_string(),
            status: Status::Violation,
            detected_text: None,
            confidence: 0.0,
            bbox: None,
            source_panel: None,
            remarks: "VIOLATION under Rule 7: Cannot verify statutory numeral height because mandatory declarations (Net Quantity / MRP) are absent.".to_string(),
        });
    }

    // 9. Jan Vishwas Act Compounding Assessment
    if violations_count > 0 {
        statutory_penalties.push(StatutoryPenalty {
            section: "Section 36(1) read with Section 49".to_string(),
            act: "Legal Metrology Act, 2009 (amended by Jan Vishwas Act, 2023)".to_string(),
            description: format!("{violations_count} non-compliant declarations detected under Legal Metrology (Packaged Commodities) Rules, 2011."),
            compoundable_fine_inr: (violations_count as u64) * 25_000,
        });
    }

    // Exempt (NotApplicable) clauses — e.g. USP on packs < 1kg/1L — must not
    // penalize the score. Previously total included the N/A row, capping every
    // small pack at 7/8 = 87.5% so 100% was unreachable.
    let total_checks = evaluations.len() as f32;
    let na_count = evaluations
        .iter()
        .filter(|e| e.status == Status::NotApplicable)
        .count() as f32;
    let scored_checks = (total_checks - na_count).max(1.0);
    let compliant_checks = evaluations.iter().filter(|e| e.status == Status::Compliant).count() as f32;
    let score = (compliant_checks / scored_checks) * 100.0;

    let warnings_count = evaluations.iter().filter(|e| e.status == Status::Warning).count();

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

    let overall_compliant = violations_count == 0 && warnings_count == 0;

    ComplianceReport {
        inspection_id: format!("INSP-{}", chrono::Utc::now().format("%Y%m%d-%H%M%S")),
        timestamp: chrono::Utc::now().to_rfc3339(),
        product_name,
        scanned_panels,
        overall_compliant,
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
        capture_mode: "one-shot".to_string(),
        raw_ocr_tokens: tokens.to_vec(),
    }
}

fn find_first_match(tokens: &[OcrToken], re: &Regex) -> (Option<BoundingBox>, Option<String>, Option<f32>) {
    // 1. Check single tokens
    for t in tokens {
        if re.is_match(&t.text) {
            return (Some(t.bbox.clone()), t.source_image.clone(), Some(t.confidence));
        }
    }

    // 2. Check 2 adjacent tokens on the same panel
    if tokens.len() >= 2 {
        for i in 0..(tokens.len() - 1) {
            if tokens[i].source_image == tokens[i + 1].source_image {
                let pair = format!("{} {}", tokens[i].text, tokens[i + 1].text);
                if re.is_match(&pair) {
                    let min_x = tokens[i].bbox.x.min(tokens[i + 1].bbox.x);
                    let min_y = tokens[i].bbox.y.min(tokens[i + 1].bbox.y);
                    let max_x = (tokens[i].bbox.x + tokens[i].bbox.width).max(tokens[i + 1].bbox.x + tokens[i + 1].bbox.width);
                    let max_y = (tokens[i].bbox.y + tokens[i].bbox.height).max(tokens[i + 1].bbox.y + tokens[i + 1].bbox.height);
                    let avg_conf = (tokens[i].confidence + tokens[i + 1].confidence) / 2.0;
                    return (
                        Some(BoundingBox {
                            x: min_x,
                            y: min_y,
                            width: max_x - min_x,
                            height: max_y - min_y,
                        }),
                        tokens[i].source_image.clone(),
                        Some((avg_conf * 1000.0).round() / 1000.0),
                    );
                }
            }
        }
    }

    // 3. Check 3 adjacent tokens on the same panel
    if tokens.len() >= 3 {
        for i in 0..(tokens.len() - 2) {
            if tokens[i].source_image == tokens[i + 1].source_image && tokens[i].source_image == tokens[i + 2].source_image {
                let triple = format!("{} {} {}", tokens[i].text, tokens[i + 1].text, tokens[i + 2].text);
                if re.is_match(&triple) {
                    let min_x = tokens[i].bbox.x.min(tokens[i + 1].bbox.x).min(tokens[i + 2].bbox.x);
                    let min_y = tokens[i].bbox.y.min(tokens[i + 1].bbox.y).min(tokens[i + 2].bbox.y);
                    let max_x = (tokens[i].bbox.x + tokens[i].bbox.width)
                        .max(tokens[i + 1].bbox.x + tokens[i + 1].bbox.width)
                        .max(tokens[i + 2].bbox.x + tokens[i + 2].bbox.width);
                    let max_y = (tokens[i].bbox.y + tokens[i].bbox.height)
                        .max(tokens[i + 1].bbox.y + tokens[i + 1].bbox.height)
                        .max(tokens[i + 2].bbox.y + tokens[i + 2].bbox.height);
                    let avg_conf = (tokens[i].confidence + tokens[i + 1].confidence + tokens[i + 2].confidence) / 3.0;
                    return (
                        Some(BoundingBox {
                            x: min_x,
                            y: min_y,
                            width: max_x - min_x,
                            height: max_y - min_y,
                        }),
                        tokens[i].source_image.clone(),
                        Some((avg_conf * 1000.0).round() / 1000.0),
                    );
                }
            }
        }
    }

    (None, None, None)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_truncated_quantity_unit_with_anchor() {
        let tokens = vec![
            OcrToken {
                text: "Net".to_string(),
                confidence: 0.99,
                bbox: BoundingBox { x: 1457, y: 2359, width: 73, height: 126 },
                source_image: Some("panel.jpg".to_string()),
            },
            OcrToken {
                text: "Quantity:".to_string(),
                confidence: 0.99,
                bbox: BoundingBox { x: 1430, y: 2520, width: 88, height: 347 },
                source_image: Some("panel.jpg".to_string()),
            },
            OcrToken {
                text: "500m".to_string(),
                confidence: 0.99,
                bbox: BoundingBox { x: 1415, y: 3134, width: 82, height: 261 },
                source_image: Some("panel.jpg".to_string()),
            },
        ];

        let report = evaluate_compliance(&tokens, 3024, 4032, None, vec!["panel.jpg".to_string()]);
        let net_qty_eval = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::NetQuantity)
            .expect("NetQuantity evaluation should exist");

        assert_eq!(net_qty_eval.status, Status::Compliant);
        assert_eq!(net_qty_eval.detected_text.as_deref(), Some("500 ml"));
    }

    fn tok(text: &str, x: u32, y: u32) -> OcrToken {
        OcrToken {
            text: text.to_string(),
            confidence: 0.95,
            bbox: BoundingBox { x, y, width: 120, height: 40 },
            source_image: Some("panel.jpg".to_string()),
        }
    }

    #[test]
    fn test_nutrition_macro_does_not_beat_pack_size() {
        // "8.8g" protein must not shadow the "70 g" statutory pack size.
        let tokens = vec![
            tok("Protein", 0, 0),
            tok("8.8g", 150, 0),
            tok("Net", 0, 100),
            tok("Qty:", 100, 100),
            tok("70", 200, 100),
            tok("g", 280, 100),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);
        let eval = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::NetQuantity)
            .unwrap();
        assert_eq!(eval.status, Status::Compliant);
        assert_eq!(eval.detected_text.as_deref(), Some("70 g"));
    }

    #[test]
    fn test_mrp_prefers_decimal_price_over_pack_weight() {
        // Regression: "MRPR ... 460g ... 100.00" reported "MRP 460".
        let tokens = vec![
            tok("MRPR", 0, 0),
            tok("460g", 150, 0),
            tok("100.00", 0, 100),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);
        let eval = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::MaximumRetailPrice)
            .unwrap();
        assert_eq!(eval.detected_text.as_deref(), Some("MRP 100.00"));
    }

    #[test]
    fn test_split_email_stitched_across_boxes() {
        // "WECARE" + "eIN.NESTLECOM" (@ glyph lost between boxes).
        let tokens = vec![
            tok("WECARE", 0, 0),
            tok("eIN.NESTLECOM", 150, 0),
            tok("1800-123-4567", 0, 100),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);
        let eval = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::ConsumerCare)
            .unwrap();
        assert_eq!(eval.status, Status::Compliant);
        assert!(eval
            .detected_text
            .as_deref()
            .unwrap()
            .contains("wecare@ein.nestlecom"));
    }

    #[test]
    fn test_packing_date_preferred_over_use_by() {
        let tokens = vec![
            tok("Use", 0, 0),
            tok("by", 80, 0),
            tok("15", 160, 0),
            tok("JUN", 230, 0),
            tok("2027", 320, 0),
            tok("Lot", 0, 100),
            tok("KB06", 80, 100),
            tok("15", 160, 100),
            tok("JUN", 230, 100),
            tok("2026", 320, 100),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);
        let eval = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::ManufactureDate)
            .unwrap();
        assert_eq!(eval.status, Status::Compliant);
        assert!(eval.detected_text.as_deref().unwrap().contains("2026"));
    }

    #[test]
    fn test_mfd_on_with_preposition_and_dot_matrix() {
        let tokens = vec![
            tok("Batch", 0, 0),
            tok("No.:", 80, 0),
            tok("BMSR.093", 160, 0),
            tok("Mfd", 0, 50),
            tok("on:", 60, 50),
            tok("08/26", 120, 50),
            tok("Use", 0, 100),
            tok("by:", 60, 100),
            tok("07/28", 120, 100),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);
        let eval = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::ManufactureDate)
            .unwrap();
        assert_eq!(eval.status, Status::Compliant);
        assert_eq!(eval.detected_text.as_deref(), Some("08/26"));
    }

    #[test]
    fn test_safe_window_never_splits_multibyte() {
        assert_eq!(safe_window("a₹b", 4, 2), "₹");
        assert_eq!(safe_window("Net Qty: 70g", 12, 48), "Net Qty: 70g");
    }

    #[test]
    fn test_bare_m_without_word_anchor_is_rejected() {
        // Regression (oats): OCR fragment "nete m … 9 … M" must not combine
        // into phantom "9 ml" via soup-tolerance + bare-m mapping.
        let tokens = vec![
            tok("Mano", 0, 0),
            tok("nete", 80, 0),
            tok("m", 160, 0),
            tok("9", 240, 0),
            tok("M", 300, 0),
            tok("Net", 0, 100),
            tok("Qty.:", 100, 100),
            tok("460g", 200, 100),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);
        let eval = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::NetQuantity)
            .unwrap();
        assert_eq!(eval.status, Status::Compliant);
        assert_eq!(eval.detected_text.as_deref(), Some("460 g"));
    }

    #[test]
    fn test_vertical_strip_fragments() {
        // Yippie full-shot statutory strip: label/value glued across tokens,
        // MFD+USEBY glued into one token, MRP label lost entirely. Filler
        // tokens interleave in reading order (as body text does on real
        // packs), so index proximity is useless — the fallback must key on
        // character-space distance. Regression: the first version used
        // token-index proximity and missed on the real 133-token stream.
        let tokens = vec![
            tok("3", 0, 0),
            tok("bodycopyone", 500, 30),
            tok("NETWEIGHT:", 0, 60),
            tok("bodycopytwo", 500, 90),
            tok("I", 0, 120),
            tok("bodycopythree", 500, 150),
            tok("420gBNoBP41G6", 0, 180),
            tok("bodycopyfour", 500, 210),
            tok("9000R5.0219", 0, 240),
            tok("bodycopyfive", 500, 270),
            tok("otall taxes/", 0, 300),
            tok("bodycopysix", 500, 330),
            tok("17JUL26712APR2", 0, 360),
            tok("bodycopyseven", 500, 390),
            tok("(Rs.per9)", 0, 420),
            tok("bodycopyeight", 500, 450),
            tok("PKD/USEBY:", 0, 480),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);

        let qty = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::NetQuantity)
            .unwrap();
        assert_eq!(qty.status, Status::Compliant);
        assert_eq!(qty.detected_text.as_deref(), Some("420 g"));

        let date = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::ManufactureDate)
            .unwrap();
        assert_eq!(date.detected_text.as_deref(), Some("17JUL26"));

        let mrp = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::MaximumRetailPrice)
            .unwrap();
        // No label survived: Warning lead, never Compliant, never missing.
        assert_eq!(mrp.status, Status::Warning);
        assert!(mrp.detected_text.as_deref().unwrap().contains("9000"));
    }

    #[test]
    fn test_vertical_strip_phone_variant() {
        // Same strip as decoded on-device (ARM INT8): dot shreds, spaced
        // label, MRP label shred present but price and tax tokens lost.
        let tokens = vec![
            tok("NEt WEIgHT:", 0, 60),
            tok("420gB.No.BP4166", 0, 180),
            tok("MRPBS.iC.", 0, 240),
            tok("17JUL26712APR2", 0, 360),
            tok("Rs.pergy", 0, 420),
            tok("PKD./USEBY:", 0, 480),
        ];
        let report = evaluate_compliance(&tokens, 1000, 1000, None, vec!["panel.jpg".to_string()]);

        let qty = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::NetQuantity)
            .unwrap();
        assert_eq!(qty.status, Status::Compliant);
        assert_eq!(qty.detected_text.as_deref(), Some("420 g"));

        let date = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::ManufactureDate)
            .unwrap();
        assert_eq!(date.detected_text.as_deref(), Some("17JUL26"));

        let mrp = report
            .evaluations
            .iter()
            .find(|e| e.field == DeclarationField::MaximumRetailPrice)
            .unwrap();
        // Label located, price lost: Warning, not "missing" Violation.
        assert_eq!(mrp.status, Status::Warning);
    }
}
