use super::types::{BoundingBox, TamperAnalysis};
use image::RgbImage;

/// Forensic visual tamper detector that analyzes packaging panels for physical
/// secondary adhesive stickers, altered price labels, and dual-MRP violations.
///
/// Implements high-throughput CPU-vectorized boundary gradient discontinuity
/// and substrate luminance inconsistency analysis directly on the in-memory RGB patch.
pub fn analyze_packaging_tampering(
    img: &RgbImage,
    mrp_bbox: Option<&BoundingBox>,
) -> Option<TamperAnalysis> {
    let bbox = mrp_bbox?;
    let (img_w, img_h) = img.dimensions();
    if img_w < 20 || img_h < 20 {
        return None;
    }

    // Expand ROI by 25% margin to capture physical adhesive paper boundary & drop shadow
    let margin_x = (bbox.width as f32 * 0.25).max(10.0).min(60.0) as u32;
    let margin_y = (bbox.height as f32 * 0.25).max(10.0).min(50.0) as u32;

    let roi_x = bbox.x.saturating_sub(margin_x);
    let roi_y = bbox.y.saturating_sub(margin_y);
    let roi_w = (bbox.width + 2 * margin_x).min(img_w.saturating_sub(roi_x)).max(20);
    let roi_h = (bbox.height + 2 * margin_y).min(img_h.saturating_sub(roi_y)).max(15);

    if roi_x + roi_w > img_w || roi_y + roi_h > img_h || roi_w < 20 || roi_h < 15 {
        return None;
    }

    // Extract cropped sub-image in memory
    let patch = image::imageops::crop_imm(img, roi_x, roi_y, roi_w, roi_h).to_image();
    let (pw, ph) = patch.dimensions();

    // Convert patch to grayscale luminance array
    let mut gray = vec![0u8; (pw * ph) as usize];
    for y in 0..ph {
        for x in 0..pw {
            let p = patch.get_pixel(x, y);
            let lum = (0.299 * p[0] as f32 + 0.587 * p[1] as f32 + 0.114 * p[2] as f32).round() as u8;
            gray[(y * pw + x) as usize] = lum;
        }
    }

    // 1. Boundary Perimeter Gradient Discontinuity (Sobel operator)
    // Physical stickers exhibit strong horizontal and vertical gradient lines along their perimeter
    let border_zone_x = (pw as f32 * 0.15).max(3.0) as u32;
    let border_zone_y = (ph as f32 * 0.18).max(3.0) as u32;

    let mut perimeter_edge_count = 0u32;
    let mut perimeter_pixel_count = 0u32;
    let mut core_lum_sum = 0u64;
    let mut core_pixel_count = 0u32;
    let mut outer_lum_sum = 0u64;
    let mut outer_pixel_count = 0u32;

    for y in 1..(ph - 1) {
        let row_up = ((y - 1) * pw) as usize;
        let row_cur = (y * pw) as usize;
        let row_down = ((y + 1) * pw) as usize;

        for x in 1..(pw - 1) {
            let xu = x as usize;
            let is_perimeter = x < border_zone_x || x >= (pw - border_zone_x) || y < border_zone_y || y >= (ph - border_zone_y);

            let p_val = gray[row_cur + xu] as u64;
            if is_perimeter {
                outer_lum_sum += p_val;
                outer_pixel_count += 1;

                // Sobel 3x3 Gradient Magnitude
                let gx = (gray[row_down + xu + 1] as i32 + 2 * gray[row_cur + xu + 1] as i32 + gray[row_up + xu + 1] as i32)
                    - (gray[row_down + xu - 1] as i32 + 2 * gray[row_cur + xu - 1] as i32 + gray[row_up + xu - 1] as i32);
                let gy = (gray[row_down + xu - 1] as i32 + 2 * gray[row_down + xu] as i32 + gray[row_down + xu + 1] as i32)
                    - (gray[row_up + xu - 1] as i32 + 2 * gray[row_up + xu] as i32 + gray[row_up + xu + 1] as i32);

                let mag = ((gx * gx + gy * gy) as f32).sqrt();
                // Adhesive sticker edge gradient threshold
                if mag > 65.0 {
                    perimeter_edge_count += 1;
                }
                perimeter_pixel_count += 1;
            } else {
                core_lum_sum += p_val;
                core_pixel_count += 1;
            }
        }
    }

    // Metric 1: Perimeter edge density along sticker margin
    let edge_density = if perimeter_pixel_count > 0 {
        perimeter_edge_count as f32 / perimeter_pixel_count as f32
    } else {
        0.0
    };

    // Metric 2: Substrate Luminance Jump (Sticker paper vs carton packaging background)
    let core_mean = if core_pixel_count > 0 {
        core_lum_sum as f32 / core_pixel_count as f32
    } else {
        128.0
    };
    let outer_mean = if outer_pixel_count > 0 {
        outer_lum_sum as f32 / outer_pixel_count as f32
    } else {
        128.0
    };

    let contrast_inconsistency = ((core_mean - outer_mean).abs() / 255.0).clamp(0.0, 1.0);

    // Multi-factor forensic confidence scoring:
    // A secondary sticker creates a physical paper substrate step (contrast jump > 0.06).
    // If substrate luminance is uniform (< 0.06), perimeter edges arise from adjacent printed text
    // lines or dot-matrix dots, not a secondary adhesive sticker.
    let attenuated_edge_density = if contrast_inconsistency < 0.06 {
        edge_density * (contrast_inconsistency / 0.06)
    } else {
        edge_density
    };

    let raw_score = (attenuated_edge_density * 2.8) + (contrast_inconsistency * 1.8);
    let confidence = (1.0 / (1.0 + (-5.0 * (raw_score - 0.42)).exp())).clamp(0.05, 0.98);

    let detected = confidence >= 0.70;
    let rounded_conf = (confidence * 100.0).round() / 100.0;

    let description = if detected {
        format!(
            "Forensic Tampering Alert ({:.0}% Confidence): Secondary adhesive sticker detected over pre-printed MRP. Physical label boundary & substrate contrast mismatch flagged under Section 18 read with Section 36(1).",
            rounded_conf * 100.0
        )
    } else {
        format!(
            "Authentic Direct Print ({:.0}% Confidence): Continuous substrate texture and uniform surface reflectance detected without secondary sticker boundaries.",
            (1.0 - rounded_conf) * 100.0
        )
    };

    Some(TamperAnalysis {
        detected,
        confidence: rounded_conf,
        tamper_type: if detected {
            "SecondaryAdhesiveStickerOverMRP".to_string()
        } else {
            "AuthenticPackagingSubstrate".to_string()
        },
        description,
        roi_bbox: Some(BoundingBox {
            x: roi_x,
            y: roi_y,
            width: roi_w,
            height: roi_h,
        }),
        edge_density: (edge_density * 1000.0).round() / 1000.0,
        contrast_inconsistency: (contrast_inconsistency * 1000.0).round() / 1000.0,
    })
}

/// Applies forensic visual tamper analysis verdict to the ComplianceReport
/// If tampering is confirmed, raises statutory penalty under Section 18/36(1) and escalates risk tier.
pub fn apply_tamper_analysis(
    report: &mut super::types::ComplianceReport,
    analysis: TamperAnalysis,
) {
    if analysis.detected {
        report.overall_compliant = false;
        report.risk_tier = super::types::RiskTier::CriticalSevere;
        report.violations.total_violations += 1;
        report.violations.statutory_penalties.push(super::types::StatutoryPenalty {
            section: "Section 18 read with Section 36(1)".to_string(),
            act: "Legal Metrology Act, 2009 (Dual-MRP Prohibition)".to_string(),
            description: "Forensic Physical Tampering: Secondary adhesive sticker detected over pre-printed Maximum Retail Price (Dual-MRP violation).".to_string(),
            compoundable_fine_inr: 25_000,
        });
    }
    report.tamper_analysis = Some(analysis);
}

