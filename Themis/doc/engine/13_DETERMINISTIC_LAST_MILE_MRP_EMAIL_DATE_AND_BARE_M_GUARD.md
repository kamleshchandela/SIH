# 13 — Deterministic Last-Mile: Ranked MRP, Stitched Emails, Packing-Date Preference, Determinism & the Bare-m Guard

> **Status:** Implemented (Production Deterministic Compliance Engine Live)  
> **Scope:** `themis/src/compliance/rules.rs`, `themis/src/ocr/detector.rs`,
> `themis/src/ocr/recognizer.rs`. No API, contract, or frontend changes.
> Follows doc 11 (orientation rescue, nutrition ranking, N/A-free scoring) and builds
> on the merged columnar work in `bfc6f8d` (35-char soup tolerance, 2D spatial
> adjacency, truncated-`m` mapping). Verified with `cargo test` (14/14) and live
> `--scan-product --json` runs on Maggi, Oats, Dishwasher.
>
> **Result line:** Oats 100% fully correct on all 8 clauses · Dishwasher 85.7% intact ·
> Maggi 71.4% LowRisk · zero build warnings.

---

## 1. Fix 1 — MRP nearest-to-anchor price selection

### Symptom (evidence)

Oats reported `MaximumRetailPrice Warning | MRP 460` while the label clearly prints
`MRP ₹ 100.00 (incl. of all taxes)`. The engine grabbed the pack weight instead of
the price.

### Root cause

Price detection took the **first regex capture** after the MRP anchor. With the
merged 35-char gap tolerance, `MRPR … 460g …` matches before the real price is ever
considered. No ranking existed between candidates.

### Change (`rules.rs`, MRP block)

All `RE_MRP` captures in the pooled text are now collected with features and ranked —
currency-marked first, then decimal (`100.00` beats bare `460`), then closest to the
first MRP anchor, then largest value:

```rust
// (price_val, text, has_decimal, has_currency, dist_from_anchor)
cands.sort_by(|a, b| {
    (b.3).cmp(&a.3)                    // currency mark wins
        .then_with(|| b.2.cmp(&a.2))   // decimal wins
        .then_with(|| a.4.cmp(&b.4))   // nearer anchor wins
        .then_with(|| b.0.partial_cmp(&a.0).unwrap_or(Equal))
});
```

Two hard exclusions: values outside ₹5–10,000, values equal to the Net Quantity
numeral, and numbers glued to a unit suffix (`460g` — peek the char after the match;
alpha means it is a weight, not a price). The pre-existing spatial fallback (floating
numeral near the MRP box) is untouched and still runs only when the regex path yields
nothing.

### Verification

Oats: `MRP Rs./₹ 100.00 (incl. of all taxes)` Compliant. New unit test
`test_mrp_prefers_decimal_price_over_pack_weight` (`MRPR, 460g, 100.00` → `100.00`).

---

## 2. Fix 2 — Split-email stitching across boxes

### Symptom (evidence)

Maggi `panel_raw_2.jpg` prints `WECARE@IN.NESTLE.COM`, but DBNet splits it into
`"WECARE"` + `"eIN.NESTLECOM"` — the `@` glyph is lost between boxes (read as `e` /
dropped). `RE_EMAIL` requires `@`, so the email was invisible and ConsumerCare sat at
Warning despite a compliant pack.

### Change (`rules.rs`, ConsumerCare block)

Care-keyword-anchored repair pass when the strict email regex finds nothing:

```rust
Regex::new(r"(?i)\b(wecare|customercare|customer\s*care|support|helpdesk|helpline|feedback|care)\s+([a-z0-9][a-z0-9._-]*\.[a-z]{2,}(?:\.[a-z]{2,})?)\b")
```

`WECARE eIN.NESTLECOM` reconstructs to `wecare@ein.nestlecom`, which is shown in
`detected_text`; the bounding box comes from the same two-token window
(`find_first_match` already merges 2–3 adjacent tokens). Anchoring on grievance
keywords keeps false positives near-impossible outside care blocks.

### Verification

Maggi ConsumerCare Warning → Compliant (`…confirmed (wecare@ein.nestlecom)`),
Maggi overall 57.1% → 71.4% LowRisk. New unit test
`test_split_email_stitched_across_boxes`.

---

## 3. Fix 3 — Unified packing-date preference (MFD over Use-by)

### Symptom (evidence)

Oats reported ManufactureDate `15JUN 2027` — the **Use-by** date — while `MFD 15JUN
2026` was printed on the same panel.

### Root cause (interaction of two commits)

The merged `RE_MFG_DATE` added `use\s*by` as a date anchor (needed: dishwasher's only
parseable date is `Use by: 07/28`), and date detection took the **first** match of
anchored-then-standalone in reading order. First-hit-wins silently preferred expiry
over packing.

### Change (`rules.rs`, date block)

One ranking pass over **all** anchored and standalone candidates:

```rust
let rank = (is_expiry as u32) * 2 + (!is_packing as u32);   // packing 0 … expiry 3
// tie → earliest position
```

Context windows (28 chars): packing = `mfd|mfg|pkd|packed|manufact|lot|batch`;
expiry = `use by|useby|expir|best before`. Standalone values duplicating the selected
anchored date are skipped. The `use by` anchor is kept (dishwasher depends on it) but
demoted below any packing-context date.

### Verification

Oats: `ManufactureDate Compliant | 15JUN 2026`. Dishwasher still `07/28` — correct
behavior there, because its `Mfd…08/26` is OCR-mangled to `QX26` (see §6: training
target). New unit test `test_packing_date_preferred_over_use_by`. The merged
`test_truncated_quantity_unit_with_anchor` still passes unmodified.

---

## 4. Fix 4 — Deterministic mode for reproducible evals

### Symptom (evidence)

Identical Maggi input produced 168 vs 201 tokens across runs — parallel ONNX
reductions reorder floats, moving marginal boxes across the 0.15 detection threshold
and changing verdicts between runs.

### Change (`detector.rs`, `recognizer.rs`)

`THEMIS_DETERMINISTIC=1` forces single-threaded sessions for bit-stable inference:

```rust
.unwrap_or_else(|| {
    if std::env::var("THEMIS_DETERMINISTIC").is_ok() { return 1; }
    std::thread::available_parallelism().map(|n| (n.get() / 2).clamp(2, 6)).unwrap_or(4)
});
```

Default stays fast/multithreaded (interactive scans, frontend); batch keeps its
`THEMIS_INTRA_THREADS=1` override. Deterministic mode is for benchmarks and the
labeled eval set (§7), not daily use.

---

## 5. Fix 5 — Phantom `9 ml`: whole-word anchors for bare-`m`

### Symptom (evidence — caught live during verification)

After the Merge, oats flipped from true `460 g` to phantom `9 ml`. Forensics: the OCR
fragment `nete m` (misread splinter) + soup tolerance + a bare `9` + stray capital
`M` combined into a quantity that exists nowhere on the pack. No `9 ml` token exists
in the token list — the regex *synthesized* it across three unrelated fragments.

### Root cause (two substring holes)

1. Primary path mapped bare `m/M` → `ml` unconditionally.
2. Both paths tested anchors by **substring** (`contains("net")`), so `nete`
   qualified as a quantity anchor.

### Change (`rules.rs`, both quantity paths)

* Primary: bare-`m` candidates additionally require a whole-word anchor
  (`\b(net|quantity|qty|vol|volume)\b` + optional colon) within 20 chars before the
  value; otherwise skipped. Full units (`g/kg/ml`) keep soup tolerance (dishwasher's
  cross-column `Quantity: … 500m` still resolves).
* Fallback guard upgraded from substring list to `RE_ANCHOR_WORD`
  (`\b(net|quantity|qty|vol|volume|content)\b`) — `nete` no longer qualifies while
  real `Quantity:` still does (full word listed first; `\bquant\b` alone would miss
  it — documented trap, avoided).

### Verification

Oats back to `460 g`; dishwasher still `500 ml` (85.7% intact). New unit test
`test_bare_m_without_word_anchor_is_rejected`.

---

## 6. Already fixed — do not revisit

Deterministic layer, verified live (docs 11 + `bfc6f8d` + this chapter):

| Item | Status |
|---|---|
| 90°/270°/180° orientation rescue (quality-gated probe, boxes mapped home) | Oats 12.5% → 100% |
| Nutrition-vs-pack ranking (`8.8g` → `70 g`) | Maggi holds across merges |
| N/A-free scoring (exempt USP no longer caps small packs at 87.5%) | Live |
| Columnar binding + 2D spatial adjacency + truncated-`m` with anchor guard | Dishwasher 85.7% |
| Threading model (dynamic single-scan, `=1` batch, deterministic flag) | Live |
| Logs → stderr, clean `--json` pipes; batch/CLI scoring parity | Live |

## 7. What future training SHOULD target (and only this)

Train **iff** the labeled eval set (step 2 of the training plan) indicts the
recognizer. In-scope classes — all *character-level misreads on correctly detected
boxes*, unfixable in regex:

1. **CIJ dot-matrix digits** (`08/26` → `QX26`, `Q826`): needs synthetic dot-matrix
   augmentation + rec-head fine-tune. Blocks dishwasher's true MFD.
2. **`₹` glyph** (→ `R`/`T`): currency-symbol augmentation; every MRP match pays tax
   for this (pun intended — tax-clause detection degrades to Warning).
3. **Calligraphic brand scripts** (Cadbury → `Ondboury`): real-crop fine-tune; low
   priority (brand names carry no statutory weight per doc 08).
4. **Truncated edge glyphs** (`500ml` → `500m` on curved boundaries): crop-jitter
   augmentation at box edges.
5. **Run-to-run threshold variance**: fixed seeds + deterministic eval protocol first;
   training cannot fix nondeterminism.

Recipe when green-lit: freeze backbone, fine-tune recognition head only, 12 h on the
RTX 4070M (8 GiB → batched/low-res), packaging-heavy mixed with general English to
avoid catastrophic forgetting.

## 8. What training should NOT target

* Orientation, ranking, anchor selection, scoring, thresholds — solved
  deterministically above; training cannot improve decisions that are already exact.
* Missing-panel verdicts (Oreo's absent crimp, Maggi's cap-stamped MRP/date) — evidence
  gaps, not model gaps. The frontend capture flow (multi-angle gusset guidance) owns
  these, plus the `THEMIS_DETERMINISTIC=1` eval protocol owns measurement.

## 9. Benchmarks (post-change, release binary)

| SKU | Score | Verdict |
|---|---|---|
| Oats (2 sideways panels) | 100.0% | Compliant — all 8 clauses correct |
| Dishwasher (curved, 2-column) | 85.7% | LowRiskMinor — only MRP Warning (fragment `07`) |
| Maggi (4 panels) | 71.4% | LowRiskMinor — only Date Violation (crimp absent from photos) |
| Oreo (4 panels, no back seal) | 28.6% | HighRiskMajor — Mfg/MRP/Date correctly missing |

`cargo test`: 14/14 pass (5 new: nutrition, MRP-decimal, email-stitch, date-rank,
char-boundary, bare-m). Zero build warnings.

## 10. File manifest of this change set

```
themis/src/compliance/rules.rs   # ranked MRP candidates + unit-glued exclusion;
                                 #   RE_SPLIT_EMAIL stitch + reconstructed address;
                                 #   unified anchored/standalone date ranking;
                                 #   safe_window() byte-safe lookbehinds;
                                 #   bare-m word-anchor guard (primary + fallback);
                                 #   5 new unit tests
themis/src/ocr/detector.rs       # THEMIS_DETERMINISTIC=1 single-thread override
themis/src/ocr/recognizer.rs     # THEMIS_DETERMINISTIC=1 single-thread override
doc/engine/13_DETERMINISTIC_LAST_MILE_MRP_EMAIL_DATE_AND_BARE_M_GUARD.md  # this file
```
