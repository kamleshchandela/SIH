use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use tracing::{error, info};

use crate::compliance::quality::analyze_panel_quality;
use crate::compliance::rules::evaluate_compliance_with_quality;
use crate::compliance::tamper::{analyze_packaging_tampering, apply_tamper_analysis};
use crate::compliance::DeclarationField;
use crate::ocr::pipeline::OcrPipeline;

static GLOBAL_PIPELINE: Mutex<Option<(String, OcrPipeline)>> = Mutex::new(None);

#[unsafe(no_mangle)]
pub extern "C" fn themis_ping() -> i32 {
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn themis_scan_sku(
    models_dir: *const c_char,
    tier: *const c_char,
    images_json: *const c_char,
    product_name: *const c_char,
) -> *mut c_char {
    let result = std::panic::catch_unwind(|| {
        inner_scan_sku(models_dir, tier, images_json, product_name)
    });

    match result {
        Ok(Ok(json)) => CString::new(json).unwrap_or_default().into_raw(),
        Ok(Err(err)) => {
            error!("themis_scan_sku error: {err}");
            let err_json = serde_json::json!({
                "error": true,
                "message": err.to_string(),
            });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
        Err(_) => {
            error!("themis_scan_sku panic caught");
            let err_json = serde_json::json!({
                "error": true,
                "message": "Internal engine error during native scan",
            });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn themis_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

fn inner_scan_sku(
    models_dir_ptr: *const c_char,
    tier_ptr: *const c_char,
    images_json_ptr: *const c_char,
    product_name_ptr: *const c_char,
) -> anyhow::Result<String> {
    if models_dir_ptr.is_null() || images_json_ptr.is_null() {
        anyhow::bail!("Null pointer passed to themis_scan_sku");
    }

    let models_dir_str = unsafe { CStr::from_ptr(models_dir_ptr) }.to_str()?;
    let models_dir = Path::new(models_dir_str);

    let tier_str = if tier_ptr.is_null() {
        "mobile-v3"
    } else {
        unsafe { CStr::from_ptr(tier_ptr) }.to_str().unwrap_or("mobile-v3")
    };

    let images_json_str = unsafe { CStr::from_ptr(images_json_ptr) }.to_str()?;
    let image_paths: Vec<String> = serde_json::from_str(images_json_str)?;

    let product_name = if product_name_ptr.is_null() {
        None
    } else {
        let s = unsafe { CStr::from_ptr(product_name_ptr) }.to_str()?;
        if s.trim().is_empty() {
            None
        } else {
            Some(s.to_string())
        }
    };

    if image_paths.is_empty() {
        anyhow::bail!("No image paths provided for scan");
    }

    info!(
        models_dir = %models_dir.display(),
        tier = tier_str,
        panels = image_paths.len(),
        "Native embedded themis_scan_sku invoked"
    );

    let mut guard = GLOBAL_PIPELINE.lock().map_err(|_| anyhow::anyhow!("Pipeline mutex lock poisoned"))?;
    let cache_key = format!("{}:{}", models_dir.display(), tier_str);

    if guard.is_none() || guard.as_ref().map(|(k, _)| k != &cache_key).unwrap_or(false) {
        info!("Initializing and caching native OcrPipeline for {}", cache_key);
        let p = OcrPipeline::new_with_tier(models_dir, Some(tier_str))?;
        *guard = Some((cache_key, p));
    }

    let (_, pipeline) = guard.as_ref().unwrap();

    let mut pooled_tokens = Vec::new();
    let mut panel_qualities = Vec::new();
    let mut scanned_panel_names = Vec::new();
    let mut max_w = 0;
    let mut max_h = 0;

    // Drop any stale timing lines from a previous errored scan; this run's
    // panels append fresh ones below.
    let _ = crate::ocr::pipeline::drain_panel_timings();

    for path_str in &image_paths {
        let path = PathBuf::from(path_str);
        if !path.exists() {
            anyhow::bail!("Image file does not exist: {}", path.display());
        }
        let fname = path.file_name().unwrap_or_default().to_string_lossy().to_string();
        scanned_panel_names.push(fname.clone());

        // EXIF-normalized load — same loader CLI/server/batch use. Raw
        // image::open ignores EXIF orientation, so portrait phone photos
        // (orientation 6) were fed to the detector sideways: garbage boxes,
        // garbage text, deterministic ~28% pooled scores.
        let rgb = crate::ocr::load_image_from_path(&path)?;
        let (w, h) = rgb.dimensions();
        max_w = max_w.max(w);
        max_h = max_h.max(h);

        let quality = analyze_panel_quality(&fname, &rgb);
        panel_qualities.push(quality);

        let tokens = pipeline.process_image_with_source(&rgb, Some(fname))?;
        pooled_tokens.extend(tokens);
    }

    let mut report = evaluate_compliance_with_quality(
        &pooled_tokens,
        max_w,
        max_h,
        product_name,
        scanned_panel_names,
        panel_qualities,
    );

    // On-device forensic tamper check (mirrors scan_sku_upload panel
    // matching): run on the MRP panel's own image, never a pooled
    // stranger's. Skip unattributed rather than risk a false verdict.
    // Advisory only until physical-sticker photos validate the thresholds.
    let mrp_eval = report
        .evaluations
        .iter()
        .find(|e| e.field == DeclarationField::MaximumRetailPrice);
    let mrp_bbox = mrp_eval.and_then(|e| e.bbox.as_ref());
    let mrp_panel_name = mrp_eval.and_then(|e| e.source_panel.as_deref());
    if let Some(panel_name) = mrp_panel_name {
        if let Some(path) = image_paths.iter().find(|p| {
            Path::new(p)
                .file_name()
                .map(|n| {
                    let n = n.to_string_lossy();
                    n.eq_ignore_ascii_case(panel_name)
                        || n.contains(panel_name)
                        || panel_name.contains(n.as_ref())
                })
                .unwrap_or(false)
        }) {
            if let Ok(img) = crate::ocr::load_image_from_path(Path::new(path)) {
                if let Some(analysis) = analyze_packaging_tampering(&img, mrp_bbox) {
                    apply_tamper_analysis(&mut report, analysis);
                }
            }
        }
    }

    // Hand per-panel Rust stage timings to the host log: the cdylib has no
    // tracing subscriber on Android, so pipeline timing lines travel inside
    // the payload under a key the Dart model ignores (additive, safe).
    let mut value = serde_json::to_value(&report)?;
    if let Some(obj) = value.as_object_mut() {
        obj.insert(
            "stage_timings".to_string(),
            serde_json::json!(crate::ocr::pipeline::drain_panel_timings()),
        );
    }

    let json = serde_json::to_string(&value)?;
    Ok(json)
}
