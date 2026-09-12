# 11 — Guided capture: the scan button is a 4-step flow (branch `guided-capture`)

## Decision

One-shot stays as engine capability (batch/API/CLI/Inspector-quick-scan)
but is **demoted out of the primary phone flow**. The scan button runs a
forced 4-step guided capture. Rationale (doc 10 discussion): optional
guided modes are dead modes; validators, not hidden buttons, are what make
"force" real; panel-attribution and small-print-recall bug classes
structurally can't occur in the primary flow anymore.

## The 4 parts (covers 10 of 11 fields; GenericName rides free)

| Step | Capture | Fields judged | Legal |
|---|---|---|---|
| 1 Quantity | net qty + nutrition close-up | NetQuantity, Rule7NumeralHeight (+NutritionalInfo) | 6(1)(c), Rule 7/13 |
| 2 Price | MRP + tax + USP area | MaximumRetailPrice, UnitSalePrice | 6(1)(e), 6(1)(f) |
| 3 Date | date stamp area | ManufactureDate, CountryOfOrigin | 6(1)(d), 6(1)(da) |
| 4 Back panel | address + care block | ManufacturerDetails, ConsumerCare | 6(1)(a), 6(1)(g) |

Each step accepts 1+ photos (multi-photo affordance inside the step; the
Yippie-5-halves SKU workflow becomes "4 steps, some with 2 photos").

## Per-step validators (retake enforcement)

A capture is accepted for its step only if the step's anchor matcher fires
on it, else the UI demands a retake. Validators reuse existing matchers:

- Step 1: `RE_NET_QTY` or `RE_STANDALONE_QTY` hits.
- Step 2: `RE_MRP` label hit, or price-fragment-near-tax (Warning-grade).
- Step 3: `RE_MFG_DATE` or `RE_STANDALONE_DATE` hits.
- Step 4: `RE_MFG_KEYWORDS` (+PIN for full pass) or care anchor hits.

Validator failure ≠ field violation: it means "wrong photo", not "bad
pack". The distinction matters for the report (below) and for tone
("Retake: no date found in this photo" vs "VIOLATION").

## Per-part states (three, not two)

- **Pass** — validator accepted AND field evaluation Compliant.
- **Fail** — validator accepted, field evaluation Violation (or Warning
  where the part demands Compliant — per-part bar is Compliant, no
  partial credit inside a forced step).
- **NotInspected** — user skipped the step. Scores 0 for the part AND is
  labeled as skipped, never as violated. An all-skipped session is an
  empty report, not a failed pack.

## Session report merge (engine)

Each step runs the full evaluator on its close-up capture(s); the session
merge picks, per field, the evaluation from its owning step and recomputes
the header (score = compliant parts / inspected parts; skipped parts
excluded from the denominator but listed). Report header records
`capture_mode: "guided"` vs `"one-shot"` so origin is always auditable.
Cross-step contradictions (e.g. two different net quantities) surface as a
session-level Warning — same pack photographed twice differently is
itself a signal.

## UI contract (sober-first)

Stepper 1/4→4/4, per-step capture literally labels the evidence photo by
construction (no bbox panel-matching needed in guided mode). Retake/skip
per step, session summary screen reusing the sober dashboard cards.
Inspector-quick-scan toggle lives in advanced settings, two taps away.

## Tolerance cliff (field lesson, 2026-09-11)

ARM decoded one strip as `NEIWEGHT:` + `420c` (T dropped from NET, g→c).
That is beyond honest matcher tolerance: accepting it would also accept
enormous garbage elsewhere (a `c` unit alternative would phantom-match
vitamin C / °C constantly). Rule: tolerance covers *shred classes*
(I-drops, dot inserts, case splits), never *letter substitutions that
collide with other vocabulary*. Such captures stay rejected with a
framing hint — the validator working as designed, not a bug.

1. Rust: `evaluate_guided_session(step_evals) -> session report` + unit
   tests with synthetic strip tokens (doc 09/10 fixtures).
2. FFI: step entry point (scan images tagged with step id, validate +
   evaluate per step, return step report JSON).
3. Flutter: stepper UI + validators wiring + session summary.
4. Desktop CLI parity flag for the harness; phone verification via adb.
