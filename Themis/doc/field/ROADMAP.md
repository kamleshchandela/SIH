# Roadmap — deferred work with context (2026-09-10)

Items intentionally NOT done yet: each is time-consuming or risky, with the
reason and the re-entry point recorded so none gets lost.

## 1. `rules.rs` matcher hardening (highest ROI, do first when time allows)

Characters are captured; regexes drop them. Three surgical gaps from
`doc/field/01` + `09` follow-ups:
- `RE_NET_QTY`: bridge `NETWEIGHT:` label → `420g…` value across token gap
  (35-char window doesn't span it; check `RE_STANDALONE_QTY` fallback first).
- `RE_MFG_DATE`: `17JUL26712APR2` — trailing `\b` can't match inside the
  glued MFD+USEBY run; needs segmentation or dropped trailing boundary.
- `RE_MRP`: no clean MRP label token survives (`otall taxes/` fragment
  only); value fragment `9000R5.0219` needs label-hunt or fragment-tolerant
  value match. This is what moves the Yippie full shot 14% → 50%+.

## 2. Recognition batching (the real speed lever)

`[THEMIS_TIMING]` on desktop (Yippie full, mobile-v3): total 7241ms =
detect 313ms + recognize 5473ms + probe 0ms + merge 1455ms. Recognition is
~75% — detector downscaling (960 experiment) saves ~1s on-device at most
and costs recall (see §5). Next: batch crop inference, then re-measure via
`THEMIS_TIMING` (logcat on device: `adb logcat | grep THEMIS_TIMING`).

## 3. Wire tamper into FFI

`tamper.rs` is merged but server-routes-only; the phone build gets none of
it. ROI math is already panel-relative, so the port is small: call
`analyze_packaging_tampering` in `ffi.rs::inner_scan_sku` with the MRP
bbox/panel, same pattern as `scan_sku_upload`. Keep the synthetic-tuning
caveat from the PR review (cap at advisory until physical-sticker photos
validate).

## 4. Local eval harness (93+ images)

Score every capture, doc/field style: per-image tokens/score/time table.
Demo credibility at district level AND the labeled set future training
needs. Re-entry: `scripts/` + `doc/field/` conventions already established.

## 5. Detector resolution note (960 experiment, 2026-09-10)

Tried mobile-tier 960px default (`THEMIS_DET_TARGET`, tier-gated in
`new_with_tier`, merge/probe-full-res pinned 1280). Desktop Yippie full at
960: 122 tokens, merge fired but added 0 net, and a false `339 l`
NetQuantity flipped the score to a lucky 37.5%. Timers showed detection is
only ~4% of panel time — not the bottleneck. Decision: **main path stays
1280**; 960 remains available via `THEMIS_DET_TARGET=960` env for later
A/B once recognition batching lands. Rationale for 960-over-720 if
revisited: 25px statutory print → ~19px at 960 (safe), ~14px at 720
(too near the 8px floor post-DBNet-downsampling).

## 6. Model training on local everyday products (post-district)

- Recognition is NOT the bottleneck (phone/desktop agree on ~133 tokens;
  misses are layout/rules/resolution). Custom recognizer = marginal gain.
- True cost: hundreds–thousands of labeled crops, GPU fine-tune loop,
  INT8 re-quant, Adreno re-validation, overfit risk on a small local set.
- Exception: if eval (§4) shows *detection* systematically missing local
  print styles (dot-matrix dates, foil MRP), a **detector-only** fine-tune
  is the targeted move. Detection is the weaker link, not recognition.
- Now: collect + label everyday-product captures (photo + known-correct
  verdict). That set is the district demo story AND the training asset.
