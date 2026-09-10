# 02 — EXIF-blind FFI loader (fixed hygiene, not the score driver)

## Finding

All 5 Yippie files are stored 4032×3024 with EXIF orientation 6:

```bash
python3 -c "
from PIL import Image
im = Image.open('dataset/mine/yippie/halfimage/PXL_20260906_162723483.jpg')
print(im.size, im.getexif().get(274))"   # (4032, 3024) 6
```

Every image entry point in the codebase normalizes this
(`ocr::load_image_from_path`, used by CLI `main.rs:239`, server
`api/routes.rs`, batch) — **except** the mobile FFI entry, added later in the
native port:

```rust
// themis/src/ffi.rs  (before)
let dyn_img = image::open(&path)?;   // ignores EXIF
let rgb = dyn_img.to_rgb8();
```

## Fix (commit `458e9d7`)

```rust
// EXIF-normalized load — same loader CLI/server/batch use.
let rgb = crate::ocr::load_image_from_path(&path)?;
```

Verified: `cargo check -p themis --lib` clean (11.64s); NDK
`cargo ndk -t arm64-v8a -P 30 -o …/jniLibs build --release --lib` (9.76s).

## Why it was not the score driver

The pipeline's auto-orientation probe (rotate 90/270/180, best wins, boxes
mapped back — `ocr/pipeline.rs`) was already rescuing orientation: phone vs
CLI boxes came out pixel-identical (doc 01). The post-fix on-device retest
still scored 28.6%. Keep the fix (correctness + likely fewer probe cycles =
faster scans), but the score gap belongs to doc 01's matcher analysis.
