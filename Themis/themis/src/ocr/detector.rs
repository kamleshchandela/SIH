use anyhow::{Context, Result};
use ndarray::Array4;
use ort::session::builder::GraphOptimizationLevel;
use ort::session::Session;
use ort::value::TensorRef;
use std::path::Path;
use std::sync::Mutex;
use tracing::info;

pub struct TextDetector {
    session: Mutex<Session>,
    target_size: u32,
    threshold: f32,
}

#[derive(Debug, Clone)]
pub struct TextRegion {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
    pub score: f32,
}

impl TextDetector {
    pub fn new(model_path: &Path) -> Result<Self> {
        info!(path = %model_path.display(), "Loading PP-OCR DBNet detection model on CPU...");

        // Concurrency default: multi-threaded sessions for fast single scans.
        // Batch mode sets THEMIS_INTRA_THREADS=1 (see batch.rs) so W pipelines
        // saturate W cores without oversubscription.
        // THEMIS_DETERMINISTIC=1 forces single-threaded execution for
        // reproducible evals/benchmarks (parallel reductions reorder floats).
        let intra_threads: usize = std::env::var("THEMIS_INTRA_THREADS")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or_else(|| {
                if std::env::var("THEMIS_DETERMINISTIC").is_ok() {
                    return 1;
                }
                std::thread::available_parallelism()
                    .map(|n| (n.get() / 2).clamp(2, 6))
                    .unwrap_or(4)
            });

        let session = Session::builder()
            .map_err(|e| anyhow::anyhow!("Failed to create ONNX session builder: {e}"))?
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .map_err(|e| anyhow::anyhow!("Failed to set optimization level: {e}"))?
            .with_intra_threads(intra_threads)
            .map_err(|e| anyhow::anyhow!("Failed to set intra-op threads: {e}"))?
            .commit_from_file(model_path)
            .map_err(|e| anyhow::anyhow!("Failed to load OCR det model: {e}"))?;

        // Detection long-side target: 1280 default (server/desktop recall).
        // Mobile tiers run 960 — set via THEMIS_DET_TARGET by the pipeline —
        // ~44% fewer pixels than 1280 while small print stays ~2x above the
        // 8px recognition floor. 720p was rejected: 25px statutory print
        // would land near ~14px, too close to the floor after DBNet
        // downsampling. Explicit THEMIS_DET_TARGET always wins.
        let target_size: u32 = std::env::var("THEMIS_DET_TARGET")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(1280);

        Ok(Self {
            session: Mutex::new(session),
            target_size,
            threshold: 0.15,
        })
    }

    /// Detect text regions in an image. Returns bounding boxes scaled to original image dimensions.
    pub fn detect(&self, img: &image::RgbImage) -> Result<Vec<TextRegion>> {
        self.detect_with_target(img, self.target_size)
    }

    /// Detect with an explicit input target (long side, px). Orientation probes
    /// use a small target (e.g. 640) for ~3-4x cheaper detection; boxes are
    /// still scaled back to original image dimensions.
    pub fn detect_with_target(
        &self,
        img: &image::RgbImage,
        target_size: u32,
    ) -> Result<Vec<TextRegion>> {
        let (orig_w, orig_h) = img.dimensions();
        if orig_w == 0 || orig_h == 0 {
            return Ok(Vec::new());
        }

        // Resize to multiple of 32 (standard DBNet constraint)
        // Server model handles larger inputs well — use 1280 target with 1920 max
        let scale = target_size as f32 / (orig_w.max(orig_h) as f32);
        let resize_w = (((orig_w as f32 * scale) / 32.0).ceil() as u32 * 32).clamp(32, 1920);
        let resize_h = (((orig_h as f32 * scale) / 32.0).ceil() as u32 * 32).clamp(32, 1920);

        let resized = image::imageops::resize(
            img,
            resize_w,
            resize_h,
            image::imageops::FilterType::Triangle,
        );

        // Normalize: (val / 255.0 - mean) / std (ImageNet mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        let mean = [0.485f32, 0.456, 0.406];
        let std = [0.229f32, 0.224, 0.225];

        let mut arr = Array4::<f32>::zeros((1, 3, resize_h as usize, resize_w as usize));
        for y in 0..resize_h as usize {
            for x in 0..resize_w as usize {
                let p = resized.get_pixel(x as u32, y as u32);
                arr[[0, 0, y, x]] = ((p[0] as f32 / 255.0) - mean[0]) / std[0];
                arr[[0, 1, y, x]] = ((p[1] as f32 / 255.0) - mean[1]) / std[1];
                arr[[0, 2, y, x]] = ((p[2] as f32 / 255.0) - mean[2]) / std[2];
            }
        }

        let input_tensor = TensorRef::from_array_view(&arr).context("OCR det input tensor")?;
        let mut sess = self.session.lock().map_err(|_| anyhow::anyhow!("Session poisoned"))?;
        let outputs = sess.run(ort::inputs![input_tensor]).context("OCR det inference failed")?;
        let (shape, prob_map) = outputs[0].try_extract_tensor::<f32>().context("Extract det output")?;

        let map_h = shape[2] as usize;
        let map_w = shape[3] as usize;

        // Binarize probability map and segment text boxes using connected components
        let mut binary = vec![false; map_h * map_w];
        for i in 0..(map_h * map_w) {
            if prob_map[i] > self.threshold {
                binary[i] = true;
            }
        }

        let regions = extract_connected_components(&prob_map, &binary, map_w, map_h, orig_w, orig_h);
        Ok(regions)
    }
}

/// Connected components labeling to extract bounding boxes from binary mask
fn extract_connected_components(
    prob_map: &[f32],
    binary: &[bool],
    map_w: usize,
    map_h: usize,
    orig_w: u32,
    orig_h: u32,
) -> Vec<TextRegion> {
    let mut visited = vec![false; map_h * map_w];
    let mut boxes = Vec::new();

    let scale_x = orig_w as f32 / map_w as f32;
    let scale_y = orig_h as f32 / map_h as f32;

    for y in 0..map_h {
        for x in 0..map_w {
            let idx = y * map_w + x;
            if binary[idx] && !visited[idx] {
                // BFS to discover connected component bounds
                let mut min_x = x;
                let mut max_x = x;
                let mut min_y = y;
                let mut max_y = y;
                let mut count = 0;
                let mut sum_prob = 0.0f32;

                let mut queue = std::collections::VecDeque::new();
                queue.push_back((x, y));
                visited[idx] = true;

                while let Some((cx, cy)) = queue.pop_front() {
                    let cur_idx = cy * map_w + cx;
                    count += 1;
                    sum_prob += prob_map[cur_idx];
                    min_x = min_x.min(cx);
                    max_x = max_x.max(cx);
                    min_y = min_y.min(cy);
                    max_y = max_y.max(cy);

                    // 4-neighborhood
                    let neighbors = [
                        (cx.wrapping_sub(1), cy),
                        (cx + 1, cy),
                        (cx, cy.wrapping_sub(1)),
                        (cx, cy + 1),
                    ];

                    for &(nx, ny) in &neighbors {
                        if nx < map_w && ny < map_h {
                            let nidx = ny * map_w + nx;
                            if binary[nidx] && !visited[nidx] {
                                visited[nidx] = true;
                                queue.push_back((nx, ny));
                            }
                        }
                    }
                }

                // Discard tiny noise spots
                let w = max_x - min_x + 1;
                let h = max_y - min_y + 1;
                if count >= 16 && w >= 6 && h >= 4 {
                    // Slight padding to avoid cutting off character ascenders/descenders
                    let pad_x = (w as f32 * 0.1).round() as usize;
                    let pad_y = (h as f32 * 0.15).round() as usize;

                    let px1 = min_x.saturating_sub(pad_x);
                    let py1 = min_y.saturating_sub(pad_y);
                    let px2 = (max_x + pad_x).min(map_w - 1);
                    let py2 = (max_y + pad_y).min(map_h - 1);

                    let box_x = (px1 as f32 * scale_x).round() as u32;
                    let box_y = (py1 as f32 * scale_y).round() as u32;
                    let box_w = (((px2 - px1 + 1) as f32) * scale_x).round() as u32;
                    let box_h = (((py2 - py1 + 1) as f32) * scale_y).round() as u32;

                    let mean_prob = if count > 0 { sum_prob / (count as f32) } else { 0.5 };
                    let det_score = (mean_prob.clamp(0.15, 0.99) * 1000.0).round() / 1000.0;

                    boxes.push(TextRegion {
                        x: box_x.min(orig_w.saturating_sub(1)),
                        y: box_y.min(orig_h.saturating_sub(1)),
                        width: box_w.min(orig_w - box_x),
                        height: box_h.min(orig_h - box_y),
                        score: det_score,
                    });
                }
            }
        }
    }

    // Sort top-to-bottom, left-to-right reading order using a strict total order
    boxes.sort_by(|a, b| {
        let line_a = a.y / 16;
        let line_b = b.y / 16;
        line_a.cmp(&line_b).then_with(|| a.x.cmp(&b.x))
    });

    boxes
}
