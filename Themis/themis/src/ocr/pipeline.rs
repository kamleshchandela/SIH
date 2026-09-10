use anyhow::Result;
use std::path::Path;
use std::sync::Mutex;
use std::time::Instant;
use tracing::{debug, info};

use crate::compliance::types::{BoundingBox, OcrToken};
use super::detector::TextDetector;
use super::recognizer::TextRecognizer;

/// Per-panel `[THEMIS_TIMING]` lines since last drain. eprintln alone never
/// reaches logcat from a cdylib, so the FFI boundary drains this buffer
/// into the JSON payload and the host logs it (DevLogger on Flutter).
static PANEL_TIMINGS: Mutex<Vec<String>> = Mutex::new(Vec::new());

/// Drain collected panel timing lines (clears the buffer).
pub fn drain_panel_timings() -> Vec<String> {
    PANEL_TIMINGS
        .lock()
        .map(|mut g| std::mem::take(&mut *g))
        .unwrap_or_default()
}

pub struct OcrPipeline {
    detector: TextDetector,
    recognizer: TextRecognizer,
}

impl OcrPipeline {
    pub fn new(models_dir: &Path) -> Result<Self> {
        Self::new_with_tier(models_dir, None)
    }

    pub fn new_with_tier(models_dir: &Path, tier: Option<&str>) -> Result<Self> {
        let env_tier = std::env::var("THEMIS_MODEL_TIER").ok();
        let selected_tier = tier.or(env_tier.as_deref()).unwrap_or("auto");

        let det_server_int8 = models_dir.join("ppocr_det_server_int8.onnx");
        let det_server_path = models_dir.join("ppocr_det_server.onnx");
        let det_mobile_int8 = models_dir.join("ppocr_det_int8.onnx");
        let det_mobile_path = models_dir.join("ppocr_det.onnx");

        let det_path = if let Ok(custom) = std::env::var("THEMIS_DET_MODEL") {
            let p = std::path::PathBuf::from(custom);
            info!(path = %p.display(), "Using custom detection model from THEMIS_DET_MODEL");
            p
        } else {
            match selected_tier {
                "server-int8" if det_server_int8.exists() => {
                    info!("Using PP-OCRv4 SERVER INT8 detection model (27.35 MB, high-accuracy quantized)");
                    det_server_int8
                }
                "server" if det_server_path.exists() => {
                    info!("Using PP-OCRv4 SERVER FP32 detection model (108.10 MB, full-precision)");
                    det_server_path
                }
                "mobile-int8" | "mobile-high-recall" | "high-recall" | "mobile-v3" if det_mobile_int8.exists() => {
                    info!("Using PP-OCRv4 MOBILE INT8 detection model (0.76 MB, ultra-lightweight edge)");
                    det_mobile_int8
                }
                "mobile" if det_mobile_path.exists() => {
                    info!("Using PP-OCRv4 MOBILE FP32 detection model (2.32 MB, fast edge)");
                    det_mobile_path
                }
                _ => {
                    // Auto-detection: prioritize Server INT8 (fast & compact server), then Server FP32, then Mobile INT8, then Mobile FP32
                    if det_server_int8.exists() {
                        info!("Auto-selected PP-OCRv4 SERVER INT8 detection model (27.35 MB, high-accuracy quantized)");
                        det_server_int8
                    } else if det_server_path.exists() {
                        info!("Auto-selected PP-OCRv4 SERVER detection model (108.10 MB, high-accuracy)");
                        det_server_path
                    } else if det_mobile_int8.exists() {
                        info!("Auto-selected PP-OCRv4 MOBILE INT8 detection model (0.76 MB, ultra-lightweight edge)");
                        det_mobile_int8
                    } else {
                        info!("Auto-selected PP-OCRv4 MOBILE FP32 detection model (2.32 MB)");
                        det_mobile_path
                    }
                }
            }
        };

        let rec_fp32_path = models_dir.join("en_ppocr_v4_rec.onnx");
        let rec_v4_int8_path = models_dir.join("en_ppocr_v4_rec_int8.onnx");
        let rec_v3_int8_path = models_dir.join("en_ppocr_v3_rec_int8.onnx");

        let rec_path = if let Ok(custom) = std::env::var("THEMIS_REC_MODEL") {
            let p = std::path::PathBuf::from(custom);
            info!(path = %p.display(), "Using custom recognition model from THEMIS_REC_MODEL");
            p
        } else if (selected_tier == "mobile-high-recall" || selected_tier == "high-recall" || selected_tier == "mobile-v3") && rec_v3_int8_path.exists() {
            info!("Using PP-OCRv3 Mobile INT8 HIGH-RECALL recognition model (2.30 MB, proven field champion)");
            rec_v3_int8_path
        } else if selected_tier == "mobile-int8" && rec_v4_int8_path.exists() {
            info!("Using PP-OCRv4 Mobile INT8 recognition model (2.00 MB, fast baseline)");
            rec_v4_int8_path
        } else if rec_v3_int8_path.exists() {
            info!("Auto-selected PP-OCRv3 Mobile INT8 HIGH-RECALL recognition model (2.30 MB, proven field champion)");
            rec_v3_int8_path
        } else if rec_v4_int8_path.exists() {
            info!("Auto-selected PP-OCRv4 Mobile INT8 recognition model (2.00 MB)");
            rec_v4_int8_path
        } else if rec_fp32_path.exists() {
            info!("Using PP-OCRv4 Mobile FP32 recognition model (7.31 MB)");
            rec_fp32_path
        } else {
            rec_v4_int8_path
        };

        let dict_path = models_dir.join("en_dict.txt");

        info!(dir = %models_dir.display(), "Initializing Themis OCR pipeline on CPU...");

        // Detection resolution: 1280 default on every tier. A 960 mobile
        // default was tried and reverted (2026-09-10): desktop Yippie-full
        // lost the vertical-strip recall the merge pass exists for (merge
        // added 0 net tokens) and invented a false "339 l" quantity, while
        // timers showed detection is only ~4% of panel time — the trade
        // was recall for ~3% speedup on the wrong stage. 960 stays
        // available via THEMIS_DET_TARGET for a future A/B once
        // recognition batching lands.

        let detector = TextDetector::new(&det_path)?;
        let recognizer = TextRecognizer::new(&rec_path, &dict_path)?;

        Ok(Self {
            detector,
            recognizer,
        })
    }

    /// Process a full RGB packaging image and extract all text tokens with coordinates
    pub fn process_image(&self, img: &image::RgbImage) -> Result<Vec<OcrToken>> {
        self.process_image_with_source(img, None)
    }

    /// Process an image and tag every extracted token with its source panel filename.
    ///
    /// Orientation-robust: after the upright pass, if the OCR quality signal
    /// indicates sideways gibberish (low CTC confidence, no dictionary words),
    /// the panel is retried at 90°/270°/180° and the best orientation wins.
    /// Returned bounding boxes are always mapped back to ORIGINAL image
    /// coordinates so Rule 7 height checks and frontend overlays stay aligned.
    pub fn process_image_with_source(
        &self,
        img: &image::RgbImage,
        source_name: Option<String>,
    ) -> Result<Vec<OcrToken>> {
        let (img_w, img_h) = img.dimensions();
        debug!(w = img_w, h = img_h, "Running text detection...");

        let t_total = Instant::now();
        let t0 = Instant::now();
        let regions = self.detector.detect(img)?;
        let detect_ms = t0.elapsed().as_millis();
        debug!(count = regions.len(), "Text regions detected");
        let t0 = Instant::now();
        let mut best_tokens = self.recognize_regions(img, &regions, source_name.clone())?;
        let recognize_ms = t0.elapsed().as_millis();
        let mut best_score = ocr_quality(&best_tokens);
        let mut best_angle: u16 = 0;
        let mut probe_ms: u128 = 0;
        let t_probe = Instant::now();

        // Geometric hint for logging: mostly-tall boxes suggest a sideways photo.
        // NOTE: this alone cannot trigger rotation — vertical text often merges
        // into wide horizontal blobs in DBNet (e.g. oats pouch), so the
        // recognition-quality fallback below is the real decision maker.
        let vertical_frac = if regions.len() >= 4 {
            regions
                .iter()
                .filter(|r| r.height > (r.width as f32 * 1.4) as u32)
                .count() as f32
                / regions.len() as f32
        } else {
            0.0
        };

        // Retry gate: good scans pay zero extra cost. Require enough regions so
        // blank/blurry panels don't burn extra passes on garbage.
        if regions.len() >= 4 && best_score < 0.60 {
            debug!(score = best_score, vertical_frac, "Low OCR quality — probing rotated orientations...");
            // Probe detections run at 640px (~3-4x cheaper than 1280); boxes are
            // still scaled to original dims, crops come from the full-res image.
            // If both 90° and 270° score clearly worse than upright, the panel is
            // hard-but-upright (artistic fonts, glare) — skip 180° and keep it.
            let mut worse_count = 0;
            for angle in [90u16, 270, 180] {
                let rotated = match angle {
                    90 => image::imageops::rotate90(img),
                    270 => image::imageops::rotate270(img),
                    _ => image::imageops::rotate180(img),
                };
                let rot_regions = match self.detector.detect_with_target(&rotated, 640) {
                    Ok(r) => r,
                    Err(_) => continue,
                };
                if rot_regions.len() < 4 {
                    worse_count += 1;
                    if angle == 270 && worse_count >= 2 {
                        break;
                    }
                    continue;
                }
                let mut toks =
                    self.recognize_regions(&rotated, &rot_regions, source_name.clone())?;
                // Map boxes back to original coordinates.
                for t in toks.iter_mut() {
                    t.bbox = map_bbox_to_original(&t.bbox, angle, img_w, img_h);
                }
                let score = ocr_quality(&toks);
                debug!(angle, score, tokens = toks.len(), "Orientation probe complete");
                // Strict acceptance: rotation must help decisively. Marginal wins
                // on blurry panels are noise and can destroy the few good tokens
                // (e.g. losing the only MRP box). Oats-class failures improve by
                // ~+0.4 (0.41 -> 0.86), so +0.15 with an absolute floor is safe.
                let count_ok =
                    toks.len() >= (best_tokens.len() as f32 * 0.5) as usize;
                if score > best_score + 0.15 && score >= 0.65 && count_ok {
                    best_score = score;
                    best_tokens = toks;
                    best_angle = angle;
                    if score >= 0.75 {
                        break;
                    }
                } else {
                    if score < best_score - 0.05 {
                        worse_count += 1;
                        // Upright-but-hard panel (artistic fonts, glare): both
                        // sideways probes failed — don't waste a 180° pass.
                        if angle == 270 && worse_count >= 2 {
                            break;
                        }
                    }
                }
            }
            if best_angle != 0 {
                info!(
                    angle = best_angle,
                    score = best_score,
                    probe_tokens = best_tokens.len(),
                    "Auto-orientation probe selected angle. Running full-resolution pass on rotated panel..."
                );
                let rotated = match best_angle {
                    90 => image::imageops::rotate90(img),
                    270 => image::imageops::rotate270(img),
                    _ => image::imageops::rotate180(img),
                };
                if let Ok(full_regions) = self.detector.detect_with_target(&rotated, 1280) {
                    if let Ok(mut full_toks) = self.recognize_regions(&rotated, &full_regions, source_name.clone()) {
                        for t in full_toks.iter_mut() {
                            t.bbox = map_bbox_to_original(&t.bbox, best_angle, img_w, img_h);
                        }
                        let full_score = ocr_quality(&full_toks);
                        debug!(full_tokens = full_toks.len(), full_score, "Full-res pass on rotated panel complete");
                        if full_toks.len() > best_tokens.len() {
                            best_tokens = full_toks;
                            best_score = full_score;
                        }
                    }
                }
                info!(
                    angle = best_angle,
                    score = best_score,
                    tokens = best_tokens.len(),
                    "Auto-orientation successful. Using rotated panel for compliance."
                );
            }
            probe_ms = t_probe.elapsed().as_millis();
        }

        // Vertical-print merge pass: upright DBNet is blind to vertical
        // (top-to-bottom) statutory strips — e.g. the Yippie full shot, where
        // NET/MRP/date live in a vertical block and the panel scored exactly
        // 0.0% with 122 good horizontal tokens. Unlike the probe above (which
        // REPLACES on a global win), this MERGES.
        //
        // Direction matters and was verified visually: top-to-bottom print
        // becomes readable horizontal text under rotate270 (CCW); rotate90
        // yields upside-down lines whose garbage decodes pollute the merge
        // (first attempt proved this: 16 reversed-fragment tokens, zero
        // statutory). Mapping uses the 270 branch accordingly.
        //
        // Discovery runs at 1280, not the probe's 640: a 640 discovery
        // downscales statutory small-print (~25px) to ~4px, below the 8px
        // recognition floor. Full-res costs one extra detection, so it is
        // gated to panels whose text fails to reach the side margins:
        // well-covered panels pay nothing.
        let t_merge = Instant::now();
        let mut merge_ms: u128 = 0;
        if best_tokens.len() >= 6 {
            let reach_right = best_tokens
                .iter()
                .map(|t| t.bbox.x.saturating_add(t.bbox.width))
                .max()
                .unwrap_or(0);
            let reach_left = best_tokens
                .iter()
                .map(|t| t.bbox.x)
                .min()
                .unwrap_or(img_w);
            let right_empty = reach_right < (img_w as f32 * 0.80) as u32;
            let left_empty = reach_left > (img_w as f32 * 0.20) as u32;
            if right_empty || left_empty {
                debug!(reach_right, reach_left, img_w, "Side band empty — running rotated full-res discovery...");
                let rotated = image::imageops::rotate270(img);
                // Pinned 1280 regardless of tier default: small vertical
                // print (~25px) must stay well above the recognition floor.
                if let Ok(rot_regions) = self.detector.detect_with_target(&rotated, 1280) {
                    // Keep regions adding coverage: IoU <= 0.25 against every
                    // known box (compared in ORIGINAL coordinates).
                    let mut fresh = Vec::new();
                    for r in &rot_regions {
                        let as_box = BoundingBox {
                            x: r.x,
                            y: r.y,
                            width: r.width,
                            height: r.height,
                        };
                        let mapped = map_bbox_to_original(&as_box, 270, img_w, img_h);
                    if best_tokens
                        .iter()
                        .all(|t| bbox_iou(&mapped, &t.bbox) <= 0.25)
                    {
                        fresh.push(r.clone());
                    }
                }
                if !fresh.is_empty() {
                    if let Ok(mut vtoks) = self.recognize_regions(
                        &rotated,
                        &fresh,
                        source_name.clone(),
                    ) {
                        let before = best_tokens.len();
                        for t in vtoks.iter_mut() {
                            t.bbox = map_bbox_to_original(&t.bbox, 270, img_w, img_h);
                        }
                        // Drop low-confidence merges: rotated-pass
                        // hallucinations must not inject garbage clauses.
                        // Upright tokens are untouched.
                        vtoks.retain(|t| t.confidence >= 0.35);
                        vtoks.retain(|t| {
                            best_tokens
                                .iter()
                                .all(|e| bbox_iou(&t.bbox, &e.bbox) <= 0.25)
                        });
                        let added = vtoks.len();
                        best_tokens.extend(vtoks);
                        debug!(added, before, total = best_tokens.len(), "Vertical-print merge pass complete");
                    }
                }
                }
            }
            merge_ms = t_merge.elapsed().as_millis();
        }

        // eprintln, not tracing: the cdylib has no subscriber on Android, so
        // info!/debug! are silent on-device. This line reaches CLI consoles;
        // on-device it travels via drain_panel_timings() -> FFI JSON ->
        // DevLogger. Grep THEMIS_TIMING either way.
        let line = format!(
            "[THEMIS_TIMING] panel total={}ms detect={}ms recognize={}ms probe={}ms merge={}ms tokens={}",
            t_total.elapsed().as_millis(),
            detect_ms,
            recognize_ms,
            probe_ms,
            merge_ms,
            best_tokens.len()
        );
        eprintln!("{line}");
        if let Ok(mut g) = PANEL_TIMINGS.lock() {
            g.push(line);
        }
        info!(extracted_tokens = best_tokens.len(), "OCR processing complete");
        Ok(best_tokens)
    }

    /// Run recognition over detected regions of an already-upright image.
    fn recognize_regions(
        &self,
        img: &image::RgbImage,
        regions: &[super::detector::TextRegion],
        source_name: Option<String>,
    ) -> Result<Vec<OcrToken>> {
        let mut tokens = Vec::new();

        for reg in regions {
            // On-device micro-noise pre-filter:
            // Discard tiny artifacts (cardboard speckles, foil glint, dot-matrix printer noise)
            // Under LMPC Rule 7 & Schedule II, minimum statutory font height is >= 1.0mm (~8px at standard scan).
            if reg.width < 18 || reg.height < 8 {
                continue;
            }
            // Discard extreme vertical noise artifacts (e.g. barcode lines, packaging fold creases)
            if (reg.width as f32 / reg.height as f32) < 0.25 && reg.height < 40 {
                continue;
            }

            // Crop text patch
            let mut crop = image::imageops::crop_imm(img, reg.x, reg.y, reg.width, reg.height).to_image();

            // Adaptive contrast enhancement for faint text (dot-matrix print on metallic foils or yellow backgrounds)
            enhance_text_contrast_if_needed(&mut crop);

            let (text, rec_conf) = self.recognizer.recognize(&crop)?;

            if !text.is_empty() {
                // Calibrated token confidence: geometric mean of detector mask probability and recognizer CTC confidence
                let combined_conf = if rec_conf > 0.0 {
                    (reg.score * rec_conf).sqrt()
                } else {
                    reg.score * 0.5
                };
                let clean_conf = (combined_conf.clamp(0.10, 0.99) * 1000.0).round() / 1000.0;

                tokens.push(OcrToken {
                    text,
                    confidence: clean_conf,
                    bbox: BoundingBox {
                        x: reg.x,
                        y: reg.y,
                        width: reg.width,
                        height: reg.height,
                    },
                    source_image: source_name.clone(),
                });
            }
        }

        Ok(tokens)
    }
}

/// OCR quality signal in [0, 1]: mean CTC confidence blended with dictionary
/// word rate and statutory anchor hits. Sideways gibberish scores < 0.5;
/// clean upright panels score > 0.7.
fn ocr_quality(tokens: &[OcrToken]) -> f32 {
    if tokens.is_empty() {
        return 0.0;
    }
    let n = tokens.len() as f32;
    let mean_conf: f32 = tokens.iter().map(|t| t.confidence).sum::<f32>() / n;
    let wordlike = tokens
        .iter()
        .filter(|t| {
            t.text
                .chars()
                .filter(|c| c.is_ascii_alphabetic())
                .count()
                >= 4
        })
        .count() as f32
        / n;
    let anchor_hits = tokens
        .iter()
        .filter(|t| {
            let l = t.text.to_lowercase();
            l.contains("net")
                || l.contains("mrp")
                || l.contains("mfg")
                || l.contains("mfd")
                || l.contains("pkd")
                || l.contains("india")
                || l.contains("price")
                || l.contains("market")
                || l.contains("manufact")
                || l.contains("care")
                || l.contains("batch")
                || l.contains("ssai")
                || l.contains("weight")
                || l.contains("quantity")
                || l.contains("tax")
        })
        .count() as f32;
    mean_conf * 0.5 + wordlike * 0.3 + (anchor_hits / 3.0).min(1.0) * 0.2
}

/// Map a bounding box from a clockwise-rotated image back to original image
/// coordinates (orig_w × orig_h). Inverse of imageops::rotate90/180/270.
fn map_bbox_to_original(
    bbox: &BoundingBox,
    angle_cw: u16,
    orig_w: u32,
    orig_h: u32,
) -> BoundingBox {
    let (x, y, w, h) = (bbox.x, bbox.y, bbox.width, bbox.height);
    let (nx, ny, nw, nh) = match angle_cw {
        // CW: dest (u,v) = (H-1-y, x); inverse of a (u,v,w,h) box is
        // orig (v, H-u-w) with swapped sides.
        90 => (
            y.min(orig_w.saturating_sub(1)),
            orig_h.saturating_sub(x.saturating_add(w).min(orig_h)),
            h.min(orig_w),
            w.min(orig_h),
        ),
        270 => (
            orig_w.saturating_sub(y.saturating_add(h).min(orig_w)),
            x.min(orig_h.saturating_sub(1)),
            h.min(orig_w),
            w.min(orig_h),
        ),
        _ => (
            orig_w.saturating_sub(x.saturating_add(w).min(orig_w)),
            orig_h.saturating_sub(y.saturating_add(h).min(orig_h)),
            w.min(orig_w),
            h.min(orig_h),
        ),
    };
    // Clamp box inside original bounds.
    let cx = nx.min(orig_w.saturating_sub(1));
    let cy = ny.min(orig_h.saturating_sub(1));
    BoundingBox {
        x: cx,
        y: cy,
        width: nw.min(orig_w.saturating_sub(cx)),
        height: nh.min(orig_h.saturating_sub(cy)),
    }
}

/// Intersection-over-union for axis-aligned boxes (0.0 when disjoint).
/// Used by the vertical-print merge pass to keep only coverage-adding tokens.
fn bbox_iou(a: &BoundingBox, b: &BoundingBox) -> f32 {
    let ix1 = a.x.max(b.x);
    let iy1 = a.y.max(b.y);
    let ix2 = a.x.saturating_add(a.width).min(b.x.saturating_add(b.width));
    let iy2 = a.y.saturating_add(a.height).min(b.y.saturating_add(b.height));
    if ix2 <= ix1 || iy2 <= iy1 {
        return 0.0;
    }
    let inter = (ix2 - ix1) as f32 * (iy2 - iy1) as f32;
    let union =
        (a.width as f32 * a.height as f32) + (b.width as f32 * b.height as f32) - inter;
    if union <= 0.0 {
        0.0
    } else {
        inter / union
    }
}

/// Dynamically stretch histogram contrast on low-contrast text patches
/// (e.g. dot-matrix expiry dates on metallic foil crimps or faint print on yellow packaging).
fn enhance_text_contrast_if_needed(crop: &mut image::RgbImage) {
    let (w, h) = crop.dimensions();
    if w == 0 || h == 0 {
        return;
    }

    let mut min_luma = 255u8;
    let mut max_luma = 0u8;
    for pixel in crop.pixels() {
        // Fast integer luma approximation: 0.299 R + 0.587 G + 0.114 B
        let luma = ((pixel[0] as u32 * 77 + pixel[1] as u32 * 150 + pixel[2] as u32 * 29) >> 8) as u8;
        if luma < min_luma {
            min_luma = luma;
        }
        if luma > max_luma {
            max_luma = luma;
        }
    }

    let dynamic_range = max_luma.saturating_sub(min_luma);
    // If dynamic range is compressed (low contrast text on foil or reflective packaging)
    if dynamic_range > 15 && dynamic_range < 140 {
        let min_f = min_luma as f32;
        let scale = 255.0 / (dynamic_range as f32);
        for pixel in crop.pixels_mut() {
            for c in 0..3 {
                let val = ((pixel[c] as f32 - min_f) * scale).clamp(0.0, 255.0) as u8;
                pixel[c] = val;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_map_bbox_matches_imageops_rotation() {
        // Original image 100 x 60
        let orig_w = 100u32;
        let orig_h = 60u32;
        let mut img = image::RgbImage::new(orig_w, orig_h);

        // Put a 10x20 marker at (20, 15) in original
        let marker_x = 20u32;
        let marker_y = 15u32;
        let marker_w = 10u32;
        let marker_h = 20u32;
        for y in marker_y..(marker_y + marker_h) {
            for x in marker_x..(marker_x + marker_w) {
                img.put_pixel(x, y, image::Rgb([255, 0, 0]));
            }
        }

        // Test 90 CW
        let rot90 = image::imageops::rotate90(&img);
        // Find bounds of red pixels in rot90
        let mut min_x = u32::MAX;
        let mut max_x = 0;
        let mut min_y = u32::MAX;
        let mut max_y = 0;
        for y in 0..rot90.height() {
            for x in 0..rot90.width() {
                if rot90.get_pixel(x, y)[0] == 255 {
                    min_x = min_x.min(x);
                    max_x = max_x.max(x);
                    min_y = min_y.min(y);
                    max_y = max_y.max(y);
                }
            }
        }
        let rot90_box = BoundingBox {
            x: min_x,
            y: min_y,
            width: max_x - min_x + 1,
            height: max_y - min_y + 1,
        };
        let unmapped90 = map_bbox_to_original(&rot90_box, 90, orig_w, orig_h);
        println!("Orig: ({marker_x}, {marker_y}, {marker_w}, {marker_h})");
        println!("Rot90 box: ({min_x}, {min_y}, {}, {})", rot90_box.width, rot90_box.height);
        println!("Unmapped 90: ({}, {}, {}, {})", unmapped90.x, unmapped90.y, unmapped90.width, unmapped90.height);
        assert_eq!(unmapped90.x, marker_x);
        assert_eq!(unmapped90.y, marker_y);
        assert_eq!(unmapped90.width, marker_w);
        assert_eq!(unmapped90.height, marker_h);

        // Test 270 CW
        let rot270 = image::imageops::rotate270(&img);
        let mut min_x = u32::MAX;
        let mut max_x = 0;
        let mut min_y = u32::MAX;
        let mut max_y = 0;
        for y in 0..rot270.height() {
            for x in 0..rot270.width() {
                if rot270.get_pixel(x, y)[0] == 255 {
                    min_x = min_x.min(x);
                    max_x = max_x.max(x);
                    min_y = min_y.min(y);
                    max_y = max_y.max(y);
                }
            }
        }
        let rot270_box = BoundingBox {
            x: min_x,
            y: min_y,
            width: max_x - min_x + 1,
            height: max_y - min_y + 1,
        };
        let unmapped270 = map_bbox_to_original(&rot270_box, 270, orig_w, orig_h);
        println!("Rot270 box: ({min_x}, {min_y}, {}, {})", rot270_box.width, rot270_box.height);
        println!("Unmapped 270: ({}, {}, {}, {})", unmapped270.x, unmapped270.y, unmapped270.width, unmapped270.height);
        assert_eq!(unmapped270.x, marker_x);
        assert_eq!(unmapped270.y, marker_y);
        assert_eq!(unmapped270.width, marker_w);
        assert_eq!(unmapped270.height, marker_h);
    }
}
