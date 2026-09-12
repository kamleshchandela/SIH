//! End-to-end guided session through the C FFI: submit four Yippie halves,
//! finalize, assert validity map + merged session report. Needs the model
//! dir and dataset present; skips gracefully without them (CI-safe).
use std::ffi::{CStr, CString};

fn models_dir() -> Option<String> {
    for c in ["models", "../themis/models", "/home/arch/Projects/backbone/themis/models"] {
        let p = std::path::Path::new(c);
        if p.join("ppocr_det_int8.onnx").exists() {
            return Some(c.to_string());
        }
    }
    None
}

fn dataset_img(name: &str) -> Option<String> {
    for c in [
        format!("../dataset/mine/yippie/halfimage/{name}"),
        format!("../dataset/mine/yippie/fullimage/{name}"),
        format!("/home/arch/Projects/backbone/dataset/mine/yippie/halfimage/{name}"),
        format!("/home/arch/Projects/backbone/dataset/mine/yippie/fullimage/{name}"),
    ] {
        if std::path::Path::new(&c).exists() {
            return Some(c);
        }
    }
    None
}

fn submit(models: &str, step: &str, images_json: &str) -> serde_json::Value {
    let m = CString::new(models).unwrap();
    let t = CString::new("mobile-v3").unwrap();
    let s = CString::new(step).unwrap();
    let j = CString::new(images_json).unwrap();
    let ret = unsafe {
        themis::ffi::themis_guided_step_submit(m.as_ptr(), t.as_ptr(), s.as_ptr(), j.as_ptr())
    };
    assert!(!ret.is_null());
    let out = unsafe { CStr::from_ptr(ret) }.to_str().unwrap().to_string();
    unsafe { themis::ffi::themis_free_string(ret) };
    serde_json::from_str(&out).unwrap()
}

fn finalize() -> serde_json::Value {
    let ret = unsafe { themis::ffi::themis_guided_session_finalize(std::ptr::null()) };
    assert!(!ret.is_null());
    let out = unsafe { CStr::from_ptr(ret) }.to_str().unwrap().to_string();
    unsafe { themis::ffi::themis_free_string(ret) };
    serde_json::from_str(&out).unwrap()
}

#[test]
fn guided_session_end_to_end() {
    let Some(models) = models_dir() else {
        eprintln!("models missing — skipping guided FFI test");
        return;
    };
    // Correct step assignment per the v2 eval baseline field map. Quantity
    // uses the full image: no half carries a readable (non-barcode) net
    // quantity — the barcode-guard validator correctly rejects them all.
    let mapping = [
        ("quantity", "PXL_20260906_162819848.jpg"),
        ("price", "PXL_20260906_162758817.jpg"),
        ("date", "PXL_20260906_162723483.jpg"),
        ("back", "PXL_20260906_162742953.jpg"),
    ];
    let mut imgs = Vec::new();
    for (_, f) in &mapping {
        let Some(p) = dataset_img(f) else {
            eprintln!("dataset image {f} missing — skipping guided FFI test");
            return;
        };
        imgs.push(p);
    }

    for ((step, _), img) in mapping.iter().zip(imgs.iter()) {
        let v = submit(&models, step, &serde_json::to_string(&vec![img]).unwrap());
        assert_eq!(v["error"], serde_json::Value::Null);
        assert_eq!(v["step"], *step, "step echo");
        assert!(v["tokens"].as_u64().unwrap_or(0) > 0, "step {step} extracted tokens");
    }

    // Wrong photo for price must validate false (still cached — resubmit
    // correct capture right after so finalize sees a valid session).
    let wrong = submit(&models, "price", &serde_json::to_string(&vec![&imgs[2]]).unwrap());
    assert_eq!(wrong["valid"], false);
    let fixed = submit(&models, "price", &serde_json::to_string(&vec![&imgs[1]]).unwrap());
    assert_eq!(fixed["valid"], true);

    let rep = finalize();
    assert_eq!(rep["error"], serde_json::Value::Null);
    assert_eq!(rep["capture_mode"], "guided");
    let validity = rep["step_validity"].as_object().unwrap();
    for step in ["quantity", "price", "date", "back"] {
        assert_eq!(validity[step], true, "step {step} valid in session");
    }
    let score = rep["compliance_score_pct"].as_f64().unwrap();
    assert!(score > 0.0, "session scored {score}");
    let fields: Vec<&str> = rep["evaluations"]
        .as_array()
        .unwrap()
        .iter()
        .map(|e| e["field"].as_str().unwrap())
        .collect();
    for f in ["NetQuantity", "MaximumRetailPrice", "ManufactureDate", "ManufacturerDetails"] {
        assert!(fields.contains(&f), "session owns {f}");
    }
}
