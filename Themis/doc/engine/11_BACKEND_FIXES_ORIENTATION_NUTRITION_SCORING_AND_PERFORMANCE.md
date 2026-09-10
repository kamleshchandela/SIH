# 11 — Backend Compliance Fixes: Orientation Rescue, Nutrition Ranking, Scoring & Performance Guards

> **Status:** Implemented (Production Backend Core)  
> **Scope:** all changes in this chapter were made to `themis/` (Rust backend) only.
> No frontend, contract, or API-shape changes. Frontend (`themis_app/`) needed zero
> modifications — it was already rendering correctly; the backend was feeding it bad data.
>
> **Baseline:** release binary built from pre-fix code; verified with
> `--scan-product ... --json` on Maggi (`8901058000269`), Oats (`dataset/mine/oats/`),
> Oreo (`7622201756697`). Rebuilt with `cargo build --release`, re-verified same way.
> `cargo test`: 6/6 pass before and after.

---

## 1. Summary of results

| SKU | Before fix | After fix |
|---|---|---|
| Oats `IMG20260906201853.jpg` + `IMG20260906201830.jpg` (sideways phone photos) | 12.5% `CriticalSevere` (~170 gibberish tokens) | **71.4%, 344 tokens**, both panels auto-rotated 270° (quality 0.90 / 0.78). Manufacturer, Net 460g, Date, Origin, Rule 7 all pass |
| Maggi `8901058000269` (4 panels) | 25.0% `HighRiskMajor`, NetQty false-positive `8.8g` | **42.9% `ModerateRisk`, NetQty `70 g` on `front.jpg`** (matches the doc-06 case-study verdict) |
| Oreo `7622201756697` (4 panels) | correct verdict but binary **timed out past 300 s** mid-fix (see §6) | **42 s, 0 spurious probes, 28.6% `HighRiskMajor`** — Mfg/MRP/Date correctly missing (back crimp absent from evidence, doc-08 doctrine) |

---

## 2. Fix 1 — Orientation rescue: quality-gated 90°/270°/180° probe

**Files:** `themis/src/ocr/pipeline.rs`

### 2.1 Symptom (evidence)

Frontend showed `170 TOKENS DETECTED` on the oats pouch with boxes slicing *across*
text lines and compliance at 12.5% Critical. Image is `4480×2016` landscape with the
pouch physically upright, EXIF orientation unset — text runs vertically. Tokens were
phonetic gibberish (`"wmmmmwem"`, `"iinenranineannna"`), so every Rule 6 regex failed.

### 2.2 Root cause

The old auto-orientation (`pipeline.rs`, pre-fix) rotated 90° **only** when
`height > 1.4 × width` on > 35% of boxes:

```rust
// BEFORE — geometric heuristic only
if regions.len() >= 4 {
    let vertical_boxes = regions.iter()
        .filter(|r| r.height > (r.width as f32 * 1.4) as u32).count();
    if (vertical_boxes as f32 / regions.len() as f32) > 0.35 {
        let rotated_90 = image::imageops::rotate90(img);
        // ... keep if more regions and less vertical ...
    }
}
```

On vertical text DBNet merges adjacent columns into **wide horizontal blobs**, so the
vertical fraction sits near 0 and rotation never fires. A second defect: when it *did*
fire, boxes were kept in **rotated-frame coordinates**, silently misaligning Rule 7
height ratios and every frontend overlay box.

### 2.3 Why this fix (and not the proposed alternatives)

* A dedicated orientation-classifier model (`PP-LCNet_doc_ori`) was rejected: trained
  on flat documents, not cluttered FMCG-on-bedsheet photos; adds download/quantize/
  integration risk before SIH for a problem solvable with existing passes.
* Wiring `ppocr_cls.onnx` was deferred: it is a *line-level 0°/180° flipper* and does
  nothing for 90°/270° page rotation (verified: the model file exists in
  `themis/models/` but has zero call sites — it remains unused by design, not oversight).
* Polygon de-warp and CLAHE were deferred: they help slanted/faint text, not 90°
  gibberish. Linear contrast stretch already exists (`enhance_text_contrast_if_needed`).

### 2.4 What was implemented

`process_image_with_source` was split into a `recognize_regions` helper (noise filter
+ contrast + CTC recognize, unchanged logic) plus an orchestration layer:

1. Full-res upright pass (1280px detect, as before).
2. Quality gate — `ocr_quality()` in `[0, 1]`:

```rust
fn ocr_quality(tokens: &[OcrToken]) -> f32 {
    // ...
    mean_conf * 0.5 + wordlike * 0.3 + (anchor_hits / 3.0).min(1.0) * 0.2
}
```

   `mean_conf` = mean token confidence; `wordlike` = fraction of tokens with ≥ 4
   ASCII letters (rejects single-glyph noise `"S"`, `"7"`); `anchor_hits` = tokens
   containing statutory anchors (`net/mrp/mfg/india/price/care/batch/ssai/…`).
   Sideways gibberish scores ≈ 0.41; clean panels ≈ 0.75–0.90.
3. If regions ≥ 4 **and** score < 0.60, probe 90° → 270° → 180°. Probe *detections*
   run at 640px (`detector.detect_with_target`, §5 — ~3–4× cheaper); crops still come
   from the full-res image; boxes are inverse-mapped to original coordinates
   (`map_bbox_to_original`, exact CW/CCW/180 inverses with bounds clamping).
4. Strict acceptance (learned the hard way, §6): accept only if
   `score > best + 0.15 && score >= 0.65 && tokens >= 50% of upright count`;
   early-stop at 0.75; abort remaining angles if 90° and 270° both score clearly
   worse (upright-but-hard panel: artistic fonts, glare — rotation cannot help).
   Good scans execute exactly one pass — zero added cost.

### 2.5 Verification

Oats log (stderr): `Auto-orientation successful … angle=270 score=0.90 tokens=183`
and `angle=270 score=0.78 tokens=161`. Maggi/Oreo logs: zero probe lines (fast path).

---

## 3. Fix 2 — Net Quantity nutrition ranking (the `8.8g` vs `70g` bug)

**Files:** `themis/src/compliance/rules.rs`

### 3.1 Symptom (evidence)

Live Maggi scan reported `NetQuantity Compliant as 8.8 g` while tokens contained
`70 g`, `70g`, `1x70g`. `8.8g` is a per-serve macro value; the statutory pack size is 70g.

### 3.2 Root cause (two holes, not one)

* Primary path (`RE_NET_QTY` over joined text) takes the **first** regex match in
  reading order — whichever number the line-sort puts first wins, nutrition or not.
* Fallback path (`RE_STANDALONE_QTY` per token) guarded with
  `RE_NUTRITION_IGNORE` on the **single token's own text** — but a bare `"8.8g"`
  token contains no keyword (`"Protein"` sits in the *adjacent* token), so the guard
  never fires. First attempt at a fix (hard veto on nutrition context) over-corrected
  to `NetQuantity VIOLATION … not found` (14.3% Critical) because dense panels
  interleave nutrition rows with the true declaration.

### 3.3 What was implemented (rank, don't veto)

```rust
/// Penalize — not veto — quantity candidates by nutrition keywords nearby.
fn nutrition_penalty(window: &str) -> u32 { /* count of 13 macro keywords, capped at 3 */ }

fn find_net_qty_candidate(combined_text: &str) -> Option<(String, String)> {
    // all RE_NET_QTY matches → lowest 48-char lookbehind penalty → largest value
}
```

* Primary: iterate **all** captures; rank by (penalty asc, value desc). Pack size
  exceeds per-serve macros almost always (70 > 8.8; 1.1 kg > side values).
* Fallback: rank reading-order candidates by (net-adjacent first, penalty asc,
  value desc); a penalized guess is still accepted over a false "missing" violation
  when the anchor was OCR-mangled.
* Deleted the now-unused `RE_NUTRITION_IGNORE` static (replaced by substring
  penalty over the same 13 keywords).

### 3.4 Verification

Maggi: `NetQuantity Compliant: 70 g … [on front.jpg]`. Oats promo pack
`460g(400g+60g Free)` resolves to `460 g` (first/primary match already correct; USP
`(0.25Per g)` matches the existing case-insensitive `per` pattern — no change needed).

---

## 4. Fix 3 — Score denominator excluded exempt clauses

**Files:** `themis/src/compliance/rules.rs` (`evaluate_compliance_with_quality`)

### 4.1 Root cause

```rust
// BEFORE
let score = (compliant_checks / total_checks) * 100.0;   // total_checks includes N/A rows
```

`UnitSalePrice` is `NotApplicable` on every pack < 1 kg/1 L, so **no small pack could
ever exceed 7/8 = 87.5%**, and `Compliant` tier (which keys off zero
violations/warnings, not the score) disagreed with the displayed percentage.

### 4.2 Fix

```rust
// AFTER — exempt clauses neither reward nor punish
let scored_checks = (total_checks - na_count).max(1.0);
let score = (compliant_checks / scored_checks) * 100.0;
```

Warnings still score 0 (strict; no half-credit introduced — a deliberate non-change
pending legal review). Maggi moved 25.0% → 42.9% (3/7) on the combined nutrition +
denominator fixes.

---

## 5. Fix 4 — Performance: threading model, probe budget, batch parity, clean JSON

**Files:** `detector.rs`, `recognizer.rs`, `batch.rs`, `pipeline.rs`, `main.rs`

1. **Threading** (`detector.rs`, `recognizer.rs`): restored dynamic sessions
   `(available_parallelism/2).clamp(2, 6)` for single scans (fast interactive
   latency, ~512% CPU observed), with `THEMIS_INTRA_THREADS` env override.
   `batch.rs` sets it to `"1"` at startup (before workers spawn) so W pipelines
   saturate W cores instead of building W×threads (the doc-07 oversubscription fix,
   now scoped where it belongs instead of globally). A global `intra=1` was tried
   first and regressed single-scan latency ~6× — reverted for that path.
2. **Probe budget** (`pipeline.rs`, `detector.rs`): new
   `detect_with_target(img, target)` (existing `detect` delegates with 1280);
   probes detect at 640px; 180° skipped when 90°+270° both clearly worse.
3. **Batch parity** (`batch.rs`): workers previously called
   `evaluate_compliance(&tokens, 0, 0, …)` — zero dims broke Rule 7 height and
   dropped sharpness diagnostics, making batch scores incomparable with CLI/API.
   Now computes per-panel `max_w/max_h` + `analyze_panel_quality` and calls
   `evaluate_compliance_with_quality`, identical to the CLI path.
4. **Clean JSON** (`main.rs`): tracing subscriber now writes to **stderr**
   (`.with_writer(std::io::stderr)`). Previously logs polluted stdout and every
   `--json` pipe required stripping non-JSON prefixes.

### Intermediate failures worth recording

* Global `intra_threads=1` (tried, reverted for non-batch): correct for batch,
  ~6× slower for single scans.
* Nutrition hard-veto (tried, replaced by ranking): flipped Maggi to false
  `NetQuantity VIOLATION`, 14.3% Critical.
* Lax probe acceptance `+0.05` (tried, tightened to `+0.15` + floor 0.65 + count
  guard): accepted a 270° rotation scoring 0.607 on a blurry Maggi panel and
  **destroyed the only MRP token** (25% → 14.3% with 4 violations).
* Unbounded probes (tried): Oreo's calligraphic front panels (unreadable at *any*
  angle) burned 4 full-res passes each → 300 s+ timeout. Resolved by 640px probes +
  early abort → 42 s total, 0 probes accepted.

---

## 6. Known remaining issues (not fixed here)

1. **MRP price selection:** oats reports `MRP 460` (pack weight grabbed near the MRP
   anchor instead of `₹100.00`). Needs nearest-numeral-to-anchor scoring, not first
   regex capture. Same family as the date artifact `40-41`.
2. **Consumer-care fragmentation:** `1800 / 103 / 947` split across boxes recovers the
   phone via joined text, but `WECARE` + `eIN.NESTLECOM` split at `@` still loses the
   email → persistent `ConsumerCare Warning` on compliant packs. Needs `@`-aware
   token stitching.
3. **OCR run-to-run variance:** 168 vs 201 tokens on identical Maggi input across
   runs (0.15 threshold sensitivity at 1280px). Pre-existing; needs determinism pass
   (fixed seeds / single-thread detect for CLI).
4. **Stale batch export:** `dataset/batch_scan_results.json` (50 SKUs, 43 Critical,
   ₹51.5L) was produced by the old binary/scoring — re-run
   `themis --batch dataset/real_products --profile 5/6` before any demo or judge review.
5. `ppocr_cls.onnx` still unwired (intentional — 0°/180° line flips only; does not
   address page rotation; revisit for upside-down crimp lines).

---

## 7. File manifest of this change set

```
themis/src/ocr/pipeline.rs      # recognize_regions split, ocr_quality(),
                                #   90/270/180 probe loop, map_bbox_to_original()
themis/src/ocr/detector.rs      # detect_with_target(), dynamic intra + env override
themis/src/ocr/recognizer.rs    # dynamic intra + env override
themis/src/compliance/rules.rs  # nutrition_penalty(), find_net_qty_candidate(),
                                #   ranked standalone fallback, N/A-free scoring,
                                #   removed RE_NUTRITION_IGNORE
themis/src/batch.rs             # THEMIS_INTRA_THREADS=1, real dims + qualities
themis/src/main.rs              # logs → stderr
```
