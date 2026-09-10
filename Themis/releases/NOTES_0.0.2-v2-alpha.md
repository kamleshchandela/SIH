# Themis v2-alpha — strip fragments resolved, phone matches desktop

Second alpha of the on-device build (Rust `libthemis.so` + INT8 ONNX, zero
server dependency). Tested on Pixel 4a 5G / Snapdragon 765G / Android 11.

## This release fixes (new since v1)

- **Vertical-strip fragments resolve in matchers.** `NETWEIGHT:`→`420g`
  across token gaps and batch-code glue, glued MFD+USEBY (`17JUL26712APR2`
  → `17JUL26`), label-less MRP price fragments near tax declarations
  (Warning, never Compliant without a label). Yippie full shot:
  **0% → 42.9% on device, field-identical to desktop.**
- **ARM decode divergence closed.** Phone INT8 decodes the strip into
  different token shapes than x86 (dot shreds, lost price/tax tokens);
  matchers now tolerate both, with a phone-variant regression test.
  Details: `doc/field/10_arm_decode_divergence.md`.
- **Forensic tamper check on-device.** `tamper.rs` wired into the FFI scan
  with panel matching (was: server routes only). Advisory thresholds.
- **Stage timings in the log file.** Per-panel
  `[THEMIS_TIMING] total/detect/recognize/probe/merge/tokens` rides the
  FFI payload into DevLogger. Measured Yippie full on SD765G:
  `total=44285ms recognize=34738ms (78%) merge=6393ms detect=3151ms`.
- **Vertical statutory print reads** (v1). Merge-only rotated full-res
  pass: 122 → 133 tokens, 0% → 14% then → 42.9% with the matcher fixes.
  Details: `doc/field/08`, `doc/field/09` (including a documented false
  alarm: a claimed 90° mapping fix the round-trip test disproved).
- **EXIF-blind native loader, durable history, live metrics, durable
  diagnostics** (v1 — see prior notes).

## Known limitations (this alpha)

- Full-pack scan ~34–46s on SD765G, ~78% in unbatched recognition —
  crop batching is the next speed lever (see `doc/field/ROADMAP.md`).
- MRP without a readable label stays Warning by design; verify on pack.
- Sober judge-safe UI is default; glass theme one toggle away in Engine.

## Install

Sideload `themis-0.0.2-v2-alpha.apk` (172MB, arm64-v8a, Android 11+).
No server, no account, no network needed — models ship inside the APK.
`sha256: e77a57a548845fd5…` (full: verify after download).
