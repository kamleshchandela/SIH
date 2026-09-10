# 01 — Yippie multi-SKU score gap: phone 28.6% vs CLI 62.5%

## Symptom

Same 5 half-panel Yippie images, same `mobile-v3` tier, same model bytes:

- Phone (pooled multi-SKU, on-device FFI): **28.57143% HighRiskMajor**, three runs
  in a row, bit-identical (`INSP-20260909-164030/164328/175204`).
- CLI (`themis --scan-product dataset/mine/yippie/halfimage --model-tier
  mobile-v3 --json`): **62.5% ModerateRisk** (`INSP-20260909-170335`), 252 tokens.

Full set (halves + full image, CLI default tier): **71.42857% LowRiskMinor**
(MRP→Warning on dot-matrix "90.00", Care→Warning, USP correctly NotApplicable
at 420 g). The halves genuinely lack MRP/USP — both live on the full panel
(verified visually: `MRP Rs. 90.00 (Rs. 0.21/g)`, `NET WEIGHT: 420 g`).

Reproduce the CLI side:

```bash
./themis/target/release/themis \
  --scan-product dataset/mine/yippie/halfimage \
  --model-tier mobile-v3 --json > /tmp/opencode/yippie_mobilev3.json
python3 -c "
import json; d = json.load(open('/tmp/opencode/yippie_mobilev3.json'))
print(d['compliance_score_pct'], d['risk_tier'], len(d['raw_ocr_tokens']))"
```

## Dead theories (with kill evidence)

1. **Stale/different on-device models.** Killed by hash:
   ```bash
   sha256sum themis/models/*.onnx themis_app/assets/models/*
   # det_int8 741768df…, v3-rec e9aca062…, v4-rec 48c8b56b…, dict 5662df9d… — identical
   ```
2. **Different input bytes.** Killed by hash — the phone files are bit-identical
   to the PC dataset:
   ```bash
   adb shell "su -c 'find /storage/emulated/0 /data/media -name PXL_20260906_162752285.jpg'"
   adb pull /storage/emulated/0/Audiobooks/mine/yippie/halfimage/<f> /tmp/opencode/phone_panel.jpg
   sha256sum /tmp/opencode/phone_panel.jpg dataset/mine/yippie/halfimage/<f>
   # 3c0a892bf7defffa == 3c0a892bf7defffa
   ```
3. **EXIF-sideways detector input** (all 5 files are 4032×3024, EXIF orientation
   6). Plausible and fixed (doc 02) — but the post-fix retest still scored
   28.6%, so it was not the driver. Decisive counter-evidence below.

## Decisive experiment: token-level diff phone vs CLI

Phone report pulled via root and compared token-by-token:

```bash
adb shell "su -c 'cat /data/data/gov.doca.themis.themis_app/app_flutter/themis_audits/reports/INSP-20260909-175204.json'" > /tmp/opencode/phone_report.json
```

Result: **bounding boxes pixel-identical** (`x:1293 y:255 w:387 h:57` on both),
per-panel counts 95/95, 89/89, 39/40, 20/22, 9/10. Detection is
byte-equivalent across platforms. Only recognized *text* differs, on ~6
borderline tokens:

| Panel token | CLI (x86_64) | Phone (ARM64) | Clause flipped |
|---|---|---|---|
| first word | `ingredients` | `Angredients` | — (noise) |
| date frag | `0.12-11` → parsed 12-11, Compliant | absent entirely | ManufactureDate C→V |
| barcode | `89017251005955l` (phantom `l` = liters!) → matched | `89017251005955` (cleaner, no unit) → miss | NetQuantity C→V |
| care line | `ltccares@itc.n 1800425444444.` → Warning | `4caresan180045444` (`@` lost) → miss | ConsumerCare W→V |
| USP | Violation (from the phantom liters!) | NotApplicable (correct at 420 g) | — |

## Verdict

ARM NEON vs x86 float rounding in the identical INT8 recognizer flips
borderline char argmaxes; three single-token-dependent matchers flip with them.
Uncomfortable corollary: CLI's 62.5% is partly *lucky* (barcode-as-quantity, a
date fragment), the phone's 28.6% partly *honest* (clean barcode correctly
rejected, USP correctly N/A). Neither number is meaningful on halves alone.

Required fixes (all `themis/src/compliance/rules.rs` domain):
- Care matcher must not require `@`: `care` substring + digit run ≥ 8
  (`4caresan180045444` must match).
- Date parsing needs fragment tolerance beyond the `mid/mic/mio` widening.
- Quantity matcher must not accept bare GTIN digits as a quantity with a
  phantom unit — and full-panel coverage (MRP/USP/date/care live there) is
  what actually moves halves 62.5% toward the full-set 71.4%+.
