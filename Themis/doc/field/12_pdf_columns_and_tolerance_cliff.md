# 12 — PDF empty columns + matcher tolerance cliff (branch `guided-capture`)

Two field findings from the guided rollout, both fixed on this branch.

## A. PDF rule table rendered badges only (both renderers)

Symptom (device screenshot): the RULE-BY-RULE table showed Status badges
(FAIL/PASS/WARN/N/A) with every other column blank — no field, no rule,
no detected value.

Root cause: PDF `Td` text-positioning operators are *relative to the
current text position*, not absolute. Chained `45 y Td … 85 y Td …
200 y Td … 350 y Td` lands columns at x = 45, 130, 330, 680 — everything
past the first column falls off the 595pt page. The bug existed
identically in the Dart phone renderer
(`themis_app/lib/services/statutory_notice_pdf_service.dart`) and the
Rust server renderer (`themis/src/export/pdf.rs`).

Fix (commit `b9c30b9`): absolute `Tm` (`1 0 0 1 x y Tm`) for the table
header, evaluation rows, and quality rows in both renderers. Rows are now
two lines — `[FAIL] NetQuantity | Rule 6(1)(c) & Rule 13` plus
`Found: 420 g` (up to 100 chars) — replacing the old 28-char mangled
clause (`Rule 6(1)(c) & Rule 13 ? Net`) which never named the rule
readably. Dart's `RuleEvaluation` also dropped `detected_text` in
`fromJson`, so the Found line could never populate: added to the model
(parse + serialize). Byte-slice panics on multibyte text (`₹`)
hardened with `floor_char_boundary` in Rust.

## B. Matcher tolerance cliff (engine accuracy boundary)

ARM decoded one strip as `NEIWEGHT:` + `420c` + `17U261APR242`
(T dropped from NET, g→c, month slot unreadable). An earlier capture of
the same strip decoded as `NETWEGHT:` + `40g` — inside tolerance and now
validating. The cliff between them is deliberate, not a gap:

- Tolerance covers *shred classes*: dropped/inserted letters that don't
  collide with other vocabulary (I-drops, dot inserts, case splits),
  and units glued to digit-bearing batch runs.
- It never covers *substitutions into other vocabulary*: a `c` unit
  alternative would phantom-match vitamin C / °C constantly; parsing
  `U26` as a month invents dates (the matcher once read year "61" out
  of `17UUL612APR242` — fixed with the month allowlist, doc 11 round).

Rule of thumb recorded: tolerance that accepts a capture must not
accept garbage elsewhere at scale. Below-cliff captures stay rejected
with a framing hint ("No net quantity found — frame the NET WEIGHT
print"); the remedy is photons (steadier, straighter close-up), not
regex.

## Verification status

- PDF: layout fix reviewed against the PDF spec (`Tm` semantics);
  on-device visual check pending (regenerate any session notice).
- Matchers: 23/23 lib tests green; desktop Yippie full holds 42.9%
  with exact values; phone session at 14.3% on below-cliff captures
  (honest fails, cache-verified zero re-inference).
