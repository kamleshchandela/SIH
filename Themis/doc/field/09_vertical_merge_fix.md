# 09 — Vertical-print merge: from 0.0% to 14% on full-pack shots

## Problem

Yippie full pack shot: **0.0% CriticalSevere** on phone (twice) and desktop,
122–123 tokens, while the pack is genuinely compliant. Overlay proof
(`assets/yippie_full_detector_boxes.jpg`, doc 08): every horizontal line boxed,
the white statutory strip (NET WEIGHT / MRP / Mfd date) with zero boxes — its
text runs vertically (top-to-bottom).

## Attempt 1 — wrong direction (failed, kept as evidence)

Merged a `rotate90` pass. Added 16 tokens, all reversed garbage (`PEPPEEPRE`,
`HDEMEN`), zero statutory. Visual check of both rotations settled it:

- CCW rotation → strip upside-down (what attempt 1 fed the recognizer).
- CW rotation (`imageops::rotate270`) → strip perfectly readable
  (`NET WEIGHT: 420 g`, `MRP Rs. incl…`, `17JUL26/12APR2`).

Rule of thumb recorded: top-to-bottom print flattens under counter-clockwise
rotation. `image::imageops::rotate90` is clockwise (verified in crate source:
`destination.put_pixel(h0 - y - 1, x, p)` sends top-left to top-right).

## Correction (2026-09-10): the 90° "mapping bug" was not a bug

The original doc claimed `map_bbox_to_original`'s 90° branch used box width
instead of height for the y origin. That claim was wrong and has been
reverted (`a63ca30`). The lib round-trip test
(`test_map_bbox_matches_imageops_rotation`: paint marker → real `imageops`
rotation → map back → compare) failed on the changed code and passes on the
original: for CW `dest(u,v) = (H-1-y, x)`, the inverse y origin is
`orig_h − (x + w)`, exactly what the original code computed. Lesson recorded:
run `cargo test --lib` before declaring geometry fixes; a green round-trip
test outranks hand derivation. The 270° branch used by the merge below was
always correct and is untouched by this correction.

## Final design (`themis/src/ocr/pipeline.rs`, commit `193190d`)

MERGE, never replace — upright tokens are untouched:

1. **Gate (free):** if tokens ≥ 6 and text fails to reach side margins
   (`reach_right < 0.80W` or `reach_left > 0.20W`), well-covered panels pay
   nothing. Yippie full: reach_right = 2286 < 2419 → fires.
2. **Discovery at full 1280**, not the probe's 640: a 640 pass downscales
   ~25px statutory print to ~4px, below the 8px recognition floor (proven:
   640 added 9 tokens, zero statutory).
3. **Dedupe + floor:** IoU ≤ 0.25 vs every known box (original coords),
   confidence ≥ 0.35 on merged tokens only — rotated hallucinations cannot
   inject garbage clauses.

## Measured results

| Run | Tokens | Score | Notes |
|---|---|---|---|
| Desktop, pre-fix | 122 | 0.0% | strip invisible |
| Desktop, rotate90 attempt | 138 (+16 garbage) | 0.0% | wrong direction, documented above |
| Desktop, rotate270 final | 133 (+11) | 0.0% | `NETWEIGHT:`, `420gBNoBP41G6`, `17JUL26712APR2`, `PKD/USEBY:` captured — matchers still miss (doc 01 follow-ups: 35-char label window, `\b` in glued dates, MRP label hunt) |
| **Phone, final build** | **135** | **14%** | first non-zero full-shot score; arch-noise flips one clause vs desktop |
| Phone, post-revert rebuild (`89970281`, corrected 90° mapping) | UI: 135 tokens | 14.3% | `themis_20260910.log`: single-panel FFI 56031ms total, report `INSP-20260910-044416`; score unchanged by the revert — merge path unaffected as predicted |
| Phone, same build second run (warm, models cached) | — | 14.3% | FFI 34583ms total (`INSP-20260910-051841`); registry persisted 1→2 records. First-run 56s vs warm 35s: cold model-load + one-time asset extraction explain the gap |

## Generalization note (the actual hope)

The gate keys on *coverage shape*, not on Yippie specifics: any panel whose
text avoids a side margin gets one rotated full-res pass. Normal close-ups
span full width → zero extra cost. Cost on firing panels ≈ one extra
detection; quantify via the TIMER marks (doc 06) before tuning the 0.80/0.20
margins against field captures.
