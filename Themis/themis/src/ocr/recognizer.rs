use anyhow::{Context, Result};
use ndarray::Array4;
use ort::session::builder::GraphOptimizationLevel;
use ort::session::Session;
use ort::value::TensorRef;
use std::path::Path;
use std::sync::Mutex;
use tracing::info;

/// PP-OCRv4 text recognizer using ONNX Runtime (CPU multi-threaded)
pub struct TextRecognizer {
    session: Mutex<Session>,
    charset: Vec<char>,
}

impl TextRecognizer {
    pub fn new(model_path: &Path, dict_path: &Path) -> Result<Self> {
        info!(path = %model_path.display(), "Loading PP-OCRv4 recognition model on CPU...");

        // Concurrency default mirrors detector.rs; batch overrides via env.
        // THEMIS_DETERMINISTIC=1 forces single-threaded reproducible inference.
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
            .map_err(|e| anyhow::anyhow!("Failed to load OCR rec model: {e}"))?;

        // Load character dictionary
        let mut charset: Vec<char> = std::fs::read_to_string(dict_path)
            .map(|content| {
                content
                    .lines()
                    .filter(|l| !l.is_empty())
                    .map(|l| l.chars().next().unwrap_or(' '))
                    .collect()
            })
            .unwrap_or_else(|_| {
                // Fallback standard vocabulary
                "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()-_=+[]{}|;:'\",.<>/?₹ "
                    .chars()
                    .collect()
            });


        // PaddleOCR en_PP-OCRv4_rec has 97 CTC output classes:
        // class 0: CTC blank
        // classes 1..95: characters in en_dict.txt
        // class 96: ' ' (space character appended by use_space_char=true)
        // Ensure charset has at least 96 entries so class 96 (index 95) is not dropped
        if charset.len() < 96 {
            charset.resize(96, ' ');
        }

        info!(dict_size = charset.len(), "PP-OCRv4 character dictionary loaded");

        Ok(Self {
            session: Mutex::new(session),
            charset,
        })
    }

    /// Run recognition on a cropped image patch, returning decoded text and mean character confidence
    pub fn recognize(&self, crop: &image::RgbImage) -> Result<(String, f32)> {
        let (crop_w, crop_h) = crop.dimensions();
        if crop_w == 0 || crop_h == 0 {
            return Ok((String::new(), 0.0));
        }

        // PP-OCRv4 standard height is 48, width scales with aspect ratio (clamped to min 64, max 1920)
        let target_h = 48u32;
        let aspect = crop_w as f32 / crop_h as f32;
        let target_w = ((target_h as f32 * aspect).round() as u32).clamp(64, 1920);

        let resized = image::imageops::resize(
            crop,
            target_w,
            target_h,
            image::imageops::FilterType::Triangle,
        );

        // NCHW tensor: [1, 3, 48, target_w]
        let mut arr = Array4::<f32>::zeros((1, 3, target_h as usize, target_w as usize));
        for y in 0..target_h as usize {
            for x in 0..target_w as usize {
                let pixel = resized.get_pixel(x as u32, y as u32);
                // Normalize: (val / 255.0 - 0.5) / 0.5
                arr[[0, 0, y, x]] = (pixel[0] as f32 / 255.0 - 0.5) / 0.5;
                arr[[0, 1, y, x]] = (pixel[1] as f32 / 255.0 - 0.5) / 0.5;
                arr[[0, 2, y, x]] = (pixel[2] as f32 / 255.0 - 0.5) / 0.5;
            }
        }

        let input_tensor = TensorRef::from_array_view(&arr).context("OCR rec input tensor")?;
        let mut sess = self.session.lock().map_err(|_| anyhow::anyhow!("Session poisoned"))?;
        let outputs = sess.run(ort::inputs![input_tensor]).context("OCR rec inference failed")?;
        let (shape, data) = outputs[0].try_extract_tensor::<f32>().context("Extract rec output")?;

        let seq_len = if shape.len() == 3 {
            shape[1] as usize
        } else if shape.len() == 2 {
            shape[0] as usize
        } else {
            return Ok((String::new(), 0.0));
        };

        let num_classes = if shape.len() == 3 {
            shape[2] as usize
        } else {
            shape[1] as usize
        };

        // CTC greedy decode: collapse repeats and ignore blank index 0
        let mut decoded = String::new();
        let mut char_probs = Vec::new();
        let mut prev = usize::MAX;

        for t in 0..seq_len {
            let offset = t * num_classes;
            let mut best_class = 0;
            let mut best_prob = data[offset];
            for c in 1..num_classes {
                if data[offset + c] > best_prob {
                    best_prob = data[offset + c];
                    best_class = c;
                }
            }

            if best_class != 0 && best_class != prev {
                let char_idx = best_class - 1;
                if char_idx < self.charset.len() {
                    decoded.push(self.charset[char_idx]);
                    char_probs.push(best_prob);
                }
            }
            prev = best_class;
        }

        let mean_conf = if !char_probs.is_empty() {
            char_probs.iter().sum::<f32>() / (char_probs.len() as f32)
        } else {
            0.0
        };
        let clean_conf = (mean_conf.clamp(0.10, 0.99) * 1000.0).round() / 1000.0;

        Ok((decoded.trim().to_string(), clean_conf))
    }
}
