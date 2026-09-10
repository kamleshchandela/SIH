# 10 — ARM vs x86 decode divergence: the 28.6% gap (closed)

## Symptom

Same APK logic, same image, same tier: desktop CLI scored the Yippie full
shot **42.9%**, the phone **28.6%**. Audit `INSP-20260910-102139` showed the
two flipped fields: NetQuantity and MaximumRetailPrice both Violation
on-device, Compliant/Warning on desktop.

## Root cause: same model, different silicon numerics

INT8 kernels on ARM (XNNPACK/NEON) vs x86 (AVX) round differently, so the
recognizer decodes the same strip into different token shapes:

| Strip token | Desktop x86 | Phone ARM |
|---|---|---|
| qty label | `NETWEIGHT:` | `NEt WEIgHT:` |
| qty value | `420gBNoBP41G6` | `420gB.No.BP4166` (dot shreds) |
| price | `9000R5.0219` | lost entirely |
| tax | `otall taxes/` | lost entirely |
| consolation | — | `MRPBS.iC.` (MRP-label shred) |
| date | `17JUL26712APR2` | `17JUL26712APR2` (identical) |

The date fix (doc 09) turned out silicon-proof — it matched on both. The
qty boundary and the MRP fragment fallback were tuned to x86 shapes only:
- `420gB.No.BP4166`: the batch tail `[A-Za-z]*\d` choked on the dots.
- No price + no tax token: the fragment fallback never fired, and the old
  else-branch reported a false "missing from all panels" Violation even
  though `MRPBS.iC.` proved the declaration exists.

## Fixes (commit `7b1810d`)

1. Batch tail admits dot shreds: `(?:[A-Za-z.]*\d[A-Za-z0-9.]*)?` —
   `420gB.No.BP4166` → **420 g Compliant**; `420grams` still rejects
   (tail requires a digit).
2. MRP label located but price lost → **Warning** ("label located, price
   numeral unreadable") instead of a false missing-Violation.
3. Phone-variant regression test (`test_vertical_strip_phone_variant`);
   17/17 lib tests green, desktop holds 42.9%.

## Verified on device

Audit `INSP-20260910-105509`: **42.9%**, field-for-field identical to
desktop (Qty✓ Date✓ Rule7✓, Mfr/COO/Care/MRP warnings). On-device split
from the same run: `total=44285ms detect=3151ms recognize=34738ms
probe=0ms merge=6393ms tokens=135` — recognize 78%, as predicted.

## Lesson

Matcher work must be validated against **on-device token streams**, not
just desktop ones — pull `raw_ocr_tokens` from the audit JSON
(`app_flutter/themis_audits/reports/`) whenever phone and desktop scores
diverge. Desktop-shaped fixtures give false confidence; the phone-variant
test exists for exactly this reason.
