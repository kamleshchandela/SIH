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
use std::collections::HashMap;

static GLOBAL_PIPELINE: Mutex<Option<(String, OcrPipeline)>> = Mutex::new(None);

/// Active guided session: one cached capture set per step id. Submit runs
/// inference once per capture; finalize merges without re-running it, so a
/// retake loop costs one step instead of the whole session.
static GUIDED_CACHE: std::sync::LazyLock<Mutex<HashMap<String, CachedGuidedStep>>> =
    std::sync::LazyLock::new(|| Mutex::new(HashMap::new()));

struct CachedGuidedStep {
    step_id: String,
    tokens: Vec<crate::compliance::OcrToken>,
    panel_names: Vec<String>,
    qualities: Vec<crate::compliance::quality::PanelImageQuality>,
}

/// Photo-level inference cache: the same file submitted for two steps (the
/// Yippie weight strip backs quantity AND price AND date) must not burn
/// inference twice. Keyed by content hash; cleared on session reset and
/// finalize so stale captures can never leak across sessions.
static PHOTO_TOKENS: std::sync::LazyLock<
    Mutex<HashMap<u64, (Vec<crate::compliance::OcrToken>, String, crate::compliance::quality::PanelImageQuality)>>,
> = std::sync::LazyLock::new(|| Mutex::new(HashMap::new()));

fn hash_photo_bytes(path: &Path) -> Option<u64> {
    use std::hash::{Hash, Hasher};
    let bytes = std::fs::read(path).ok()?;
    let mut h = std::collections::hash_map::DefaultHasher::new();
    bytes.hash(&mut h);
    Some(h.finish())
}

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
    finalize_report_json(&report, None)
}

/// Serialize a report, injecting drained stage timings plus optional extra
/// top-level keys (all additive; Dart fromJson ignores unknown keys).
fn finalize_report_json(
    report: &crate::compliance::ComplianceReport,
    extra: Option<serde_json::Map<String, serde_json::Value>>,
) -> anyhow::Result<String> {
    let mut value = serde_json::to_value(report)?;
    if let Some(obj) = value.as_object_mut() {
        obj.insert(
            "stage_timings".to_string(),
            serde_json::json!(crate::ocr::pipeline::drain_panel_timings()),
        );
        if let Some(extra) = extra {
            obj.extend(extra);
        }
    }
    Ok(serde_json::to_string(&value)?)
}

/// Guided session scan: `session_json` is an array of
/// `{"step": "quantity|price|date|back", "images": [paths...], "skipped": bool}`.
/// Each step is validated (wrong photo => validity false, UI must retake)
/// and the session merges per-step evaluations. Returns the session report
/// JSON with an additive `step_validity` map.
#[unsafe(no_mangle)]
pub extern "C" fn themis_guided_session(
    models_dir: *const c_char,
    tier: *const c_char,
    session_json_ptr: *const c_char,
    product_name_ptr: *const c_char,
) -> *mut c_char {
    let result = std::panic::catch_unwind(|| {
        inner_guided_session(models_dir, tier, session_json_ptr, product_name_ptr)
    });

    match result {
        Ok(Ok(json)) => CString::new(json).unwrap_or_default().into_raw(),
        Ok(Err(err)) => {
            error!("themis_guided_session error: {err}");
            let err_json = serde_json::json!({
                "error": true,
                "message": err.to_string(),
            });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
        Err(_) => {
            error!("themis_guided_session panic caught");
            let err_json = serde_json::json!({
                "error": true,
                "message": "Internal engine error during guided session",
            });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
    }
}

#[derive(serde::Deserialize)]
struct GuidedStepSpec {
    step: String,
    #[serde(default)]
    images: Vec<String>,
    #[serde(default)]
    skipped: bool,
}

fn inner_guided_session(
    models_dir_ptr: *const c_char,
    tier_ptr: *const c_char,
    session_json_ptr: *const c_char,
    product_name_ptr: *const c_char,
) -> anyhow::Result<String> {
    use crate::compliance::guided::{
        merge_guided_session, validate_step_capture, GuidedStep, GuidedStepInput,
    };

    if models_dir_ptr.is_null() || session_json_ptr.is_null() {
        anyhow::bail!("Null pointer passed to themis_guided_session");
    }
    let models_dir = Path::new(unsafe { CStr::from_ptr(models_dir_ptr) }.to_str()?);
    let tier_str = if tier_ptr.is_null() {
        "mobile-v3"
    } else {
        unsafe { CStr::from_ptr(tier_ptr) }.to_str().unwrap_or("mobile-v3")
    };
    let session_str = unsafe { CStr::from_ptr(session_json_ptr) }.to_str()?;
    let specs: Vec<GuidedStepSpec> = serde_json::from_str(session_str)?;
    if specs.is_empty() {
        anyhow::bail!("Empty guided session spec");
    }
    let product_name = if product_name_ptr.is_null() {
        None
    } else {
        let s = unsafe { CStr::from_ptr(product_name_ptr) }.to_str()?;
        if s.trim().is_empty() { None } else { Some(s.to_string()) }
    };

    let mut guard = GLOBAL_PIPELINE.lock().map_err(|_| anyhow::anyhow!("Pipeline mutex lock poisoned"))?;
    let cache_key = format!("{}:{}", models_dir.display(), tier_str);
    if guard.is_none() || guard.as_ref().map(|(k, _)| k != &cache_key).unwrap_or(false) {
        let p = OcrPipeline::new_with_tier(models_dir, Some(tier_str))?;
        *guard = Some((cache_key, p));
    }
    let (_, pipeline) = guard.as_ref().unwrap();

    let _ = crate::ocr::pipeline::drain_panel_timings();
    let mut step_inputs = Vec::new();
    let mut validity = serde_json::Map::new();
    let mut panel_qualities = Vec::new();

    for spec in &specs {
        let Some(gstep) = GuidedStep::from_id(&spec.step) else {
            anyhow::bail!("Unknown guided step: {}", spec.step);
        };
        if spec.skipped || spec.images.is_empty() {
            validity.insert(gstep.id().to_string(), serde_json::Value::Bool(false));
            step_inputs.push(GuidedStepInput {
                step: gstep,
                tokens: vec![],
                panel_names: vec![],
                skipped: true,
            });
            continue;
        }
        let mut tokens = Vec::new();
        let mut panel_names = Vec::new();
        for path_str in &spec.images {
            let (mut t, _fname, q) = scan_photo_cached(pipeline, path_str)?;
            tokens.append(&mut t);
            panel_names.push(path_str.clone());
            panel_qualities.push(q);
        }
        // Wrong photo => invalid; still merged (fields will read missing),
        // UI must demand a retake before accepting the session.
        validity.insert(
            gstep.id().to_string(),
            serde_json::Value::Bool(validate_step_capture(gstep, &tokens)),
        );
        step_inputs.push(GuidedStepInput { step: gstep, tokens, panel_names, skipped: false });
    }

    let report = merge_guided_session(product_name, step_inputs, panel_qualities);
    let mut extra = serde_json::Map::new();
    extra.insert("step_validity".to_string(), serde_json::Value::Object(validity));
    finalize_report_json(&report, Some(extra))
}

/// Resolve (and cache) the pipeline for a models dir + tier. Shared by the
/// one-shot and guided entries.
fn pipeline_cache_key(models_dir: &Path, tier_str: &str) -> String {
    format!("{}:{}", models_dir.display(), tier_str)
}

fn ensure_pipeline(models_dir: &Path, tier_str: &str) -> anyhow::Result<()> {
    let mut guard = GLOBAL_PIPELINE
        .lock()
        .map_err(|_| anyhow::anyhow!("Pipeline mutex lock poisoned"))?;
    let cache_key = pipeline_cache_key(models_dir, tier_str);
    if guard.is_none() || guard.as_ref().map(|(k, _)| k != &cache_key).unwrap_or(false) {
        let p = OcrPipeline::new_with_tier(models_dir, Some(tier_str))?;
        *guard = Some((cache_key, p));
    }
    Ok(())
}

/// Scan one photo through load + quality + inference, reusing the
/// session photo cache on content-hash hits. Returns (tokens, fname, quality).
/// Public for the CLI guided loop so desktop and phone share the behavior.
pub fn scan_photo_cached(
    pipeline: &OcrPipeline,
    path_str: &str,
) -> anyhow::Result<(
    Vec<crate::compliance::OcrToken>,
    String,
    crate::compliance::quality::PanelImageQuality,
)> {
    let path = PathBuf::from(path_str);
    if !path.exists() {
        anyhow::bail!("Image file does not exist: {}", path.display());
    }
    if let Some(key) = hash_photo_bytes(&path) {
        if let Ok(cache) = PHOTO_TOKENS.lock() {
            if let Some((tokens, fname, quality)) = cache.get(&key) {
                tracing::info!(photo = %fname, tokens = tokens.len(), "Photo cache hit — skipping re-inference");
                return Ok((tokens.clone(), fname.clone(), quality.clone()));
            }
        }
    }
    let fname = path.file_name().unwrap_or_default().to_string_lossy().to_string();
    let rgb = crate::ocr::load_image_from_path(&path)?;
    let quality = analyze_panel_quality(&fname, &rgb);
    let tokens = pipeline.process_image_with_source(&rgb, Some(fname.clone()))?;
    if let Some(key) = hash_photo_bytes(&path) {
        if let Ok(mut cache) = PHOTO_TOKENS.lock() {
            cache.insert(key, (tokens.clone(), fname.clone(), quality.clone()));
        }
    }
    Ok((tokens, fname, quality))
}
/// Submit one guided step's captures: runs inference once, validates the
/// capture looks like its step, caches tokens for finalize. Returns
/// `{"step": id, "valid": bool, "tokens": n, "hint": str}`. Retakes
/// overwrite the cache. Photos already scanned for another step are reused
/// from the photo cache (no re-inference).
#[unsafe(no_mangle)]
pub extern "C" fn themis_guided_step_submit(
    models_dir: *const c_char,
    tier: *const c_char,
    step_id: *const c_char,
    images_json_ptr: *const c_char,
) -> *mut c_char {
    let result = std::panic::catch_unwind(|| {
        inner_guided_step_submit(models_dir, tier, step_id, images_json_ptr)
    });
    match result {
        Ok(Ok(json)) => CString::new(json).unwrap_or_default().into_raw(),
        Ok(Err(err)) => {
            error!("themis_guided_step_submit error: {err}");
            let err_json = serde_json::json!({ "error": true, "message": err.to_string() });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
        Err(_) => {
            error!("themis_guided_step_submit panic caught");
            let err_json = serde_json::json!({ "error": true, "message": "Internal engine error during guided step" });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
    }
}

fn inner_guided_step_submit(
    models_dir_ptr: *const c_char,
    tier_ptr: *const c_char,
    step_id_ptr: *const c_char,
    images_json_ptr: *const c_char,
) -> anyhow::Result<String> {
    use crate::compliance::guided::{validate_step_capture, step_hint, GuidedStep};

    if models_dir_ptr.is_null() || step_id_ptr.is_null() || images_json_ptr.is_null() {
        anyhow::bail!("Null pointer passed to themis_guided_step_submit");
    }
    let models_dir = Path::new(unsafe { CStr::from_ptr(models_dir_ptr) }.to_str()?);
    let tier_str = if tier_ptr.is_null() {
        "mobile-v3"
    } else {
        unsafe { CStr::from_ptr(tier_ptr) }.to_str().unwrap_or("mobile-v3")
    };
    let step_raw = unsafe { CStr::from_ptr(step_id_ptr) }.to_str()?;
    let Some(gstep) = GuidedStep::from_id(step_raw) else {
        anyhow::bail!("Unknown guided step: {step_raw}");
    };
    let images_str = unsafe { CStr::from_ptr(images_json_ptr) }.to_str()?;
    let image_paths: Vec<String> = serde_json::from_str(images_str)?;
    if image_paths.is_empty() {
        anyhow::bail!("No images provided for guided step");
    }

    ensure_pipeline(models_dir, tier_str)?;
    let _ = crate::ocr::pipeline::drain_panel_timings();

    // Run inference under the pipeline lock, then release before touching
    // the session cache (lock ordering: pipeline before cache, always).
    let (tokens, panel_names, qualities) = {
        let guard = GLOBAL_PIPELINE
            .lock()
            .map_err(|_| anyhow::anyhow!("Pipeline mutex lock poisoned"))?;
        let (_, pipeline) = guard.as_ref().unwrap();
        let mut tokens = Vec::new();
        let mut panel_names = Vec::new();
        let mut qualities = Vec::new();
        for path_str in &image_paths {
            // Same file across steps hits the photo cache: no re-inference.
            let (mut t, fname, q) = scan_photo_cached(pipeline, path_str)?;
            tokens.append(&mut t);
            // Full path, not bare fname: dossier cards resolve File() photos
            // from scanned_panels, and panel matching still works via
            // substring in both directions.
            panel_names.push(path_str.clone());
            qualities.push(q);
        }
        (tokens, panel_names, qualities)
    };

    let valid = validate_step_capture(gstep, &tokens);
    let n = tokens.len();
    let hint = if valid { String::new() } else { step_hint(gstep, &tokens).to_string() };
    GUIDED_CACHE
        .lock()
        .map_err(|_| anyhow::anyhow!("Guided session lock poisoned"))?
        .insert(
            gstep.id().to_string(),
            CachedGuidedStep { step_id: gstep.id().to_string(), tokens, panel_names, qualities },
        );

    Ok(serde_json::json!({ "step": gstep.id(), "valid": valid, "tokens": n, "hint": hint }).to_string())
}

/// Finalize the active guided session: merges cached steps (missing steps
/// count as skipped) without re-running inference. Clears the cache.
#[unsafe(no_mangle)]
pub extern "C" fn themis_guided_session_finalize(
    product_name_ptr: *const c_char,
) -> *mut c_char {
    let result = std::panic::catch_unwind(|| inner_guided_session_finalize(product_name_ptr));
    match result {
        Ok(Ok(json)) => CString::new(json).unwrap_or_default().into_raw(),
        Ok(Err(err)) => {
            error!("themis_guided_session_finalize error: {err}");
            let err_json = serde_json::json!({ "error": true, "message": err.to_string() });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
        Err(_) => {
            error!("themis_guided_session_finalize panic caught");
            let err_json = serde_json::json!({ "error": true, "message": "Internal engine error finalizing guided session" });
            CString::new(err_json.to_string()).unwrap_or_default().into_raw()
        }
    }
}

fn inner_guided_session_finalize(product_name_ptr: *const c_char) -> anyhow::Result<String> {
    use crate::compliance::guided::{merge_guided_session, validate_step_capture, GuidedStep, GuidedStepInput};

    let product_name = if product_name_ptr.is_null() {
        None
    } else {
        let s = unsafe { CStr::from_ptr(product_name_ptr) }.to_str()?;
        if s.trim().is_empty() { None } else { Some(s.to_string()) }
    };

    let mut cache = GUIDED_CACHE
        .lock()
        .map_err(|_| anyhow::anyhow!("Guided session lock poisoned"))?;
    if cache.is_empty() {
        anyhow::bail!("No guided steps submitted");
    }
    let mut steps = Vec::new();
    let mut qualities = Vec::new();
    let mut validity = serde_json::Map::new();
    for id in ["quantity", "price", "date", "back"] {
        if let Some(cached) = cache.remove(id) {
            let gstep = GuidedStep::from_id(id).unwrap();
            let valid = validate_step_capture(gstep, &cached.tokens);
            validity.insert(id.to_string(), serde_json::Value::Bool(valid));
            qualities.extend(cached.qualities.iter().cloned());
            steps.push(GuidedStepInput {
                step: gstep,
                tokens: cached.tokens,
                panel_names: cached.panel_names,
                skipped: false,
            });
        } else {
            let gstep = GuidedStep::from_id(id).unwrap();
            validity.insert(id.to_string(), serde_json::Value::Bool(false));
            steps.push(GuidedStepInput { step: gstep, tokens: vec![], panel_names: vec![], skipped: true });
        }
    }
    drop(cache);

    let report = merge_guided_session(product_name, steps, qualities);
    // Session over: photo cache must not leak captures into the next one.
    if let Ok(mut photos) = PHOTO_TOKENS.lock() {
        photos.clear();
    }
    let mut extra = serde_json::Map::new();
    extra.insert("step_validity".to_string(), serde_json::Value::Object(validity));
    finalize_report_json(&report, Some(extra))
}

/// Discard the active guided session cache (steps and photo tokens).
#[unsafe(no_mangle)]
pub extern "C" fn themis_guided_session_reset() {
    if let Ok(mut cache) = GUIDED_CACHE.lock() {
        cache.clear();
    }
    if let Ok(mut photos) = PHOTO_TOKENS.lock() {
        photos.clear();
    }
}
