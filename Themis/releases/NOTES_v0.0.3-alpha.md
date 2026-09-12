# Themis v0.0.3-alpha — guided 4-step capture is the primary flow

On-device build (Rust `libthemis.so` + INT8 ONNX, zero server dependency).
Tested on Pixel 4a 5G / Snapdragon 765G / Android 11.

## New in this release

- **Guided 4-step inspection (new primary flow).** Quantity → Price →
  Date → Back-panel close-ups, each verified on-device before acceptance
  (wrong photo = retake prompt with a hint, never a silent fail). Skip is
  allowed but scores the part zero and labels it not-inspected. Sessions
  merge into one report (`capture_mode: guided`); oats session verified
  at 71.4% on-device.
- **One-shot demoted behind a lock.** SCAN/FILES/MULTI/SAMPLE shortcuts,
  the glass action grid, and the one-shot tabs stay hidden until
  Engine → Inspector quick scan is enabled behind a warning dialog
  (persisted, reversible). Guided is the only flow a casual user sees.
- **Back-safe sessions.** Verification continues if you leave mid-scan;
  return to finish. Force-stop button in the AppBar abandons a session.
- **No double scanning.** Same photo reused across steps hits a
  content-hash cache (measured 11–21ms vs full inference).
- **Dotted dates + shred tolerance.** DD.MM.YYYY stamps
  (`22.05.2026` packing date wins over USEBY), I-dropped labels
  (`NETWEGHT`), MRP shred labels; month allowlist stops invented
  years; barcode runs (8+ digits) never count as quantities.
- **PDF rule table fixed.** Columns rendered off-page in both renderers
  (relative-`Td` bug) — now absolute positioning with full
  Rule 6(1)(x) references and Found values per row.

## Known limitations

- Full-pack one-shot ~34–46s on SD765G, ~78% in unbatched recognition —
  crop batching is next (`doc/field/ROADMAP.md`).
- Below-cliff captures (e.g. T-dropped labels + substituted units in one
  token) stay rejected by design — remedy is a steadier close-up.
- MRP without a readable label stays Warning; verify on pack.

## Install

Sideload `themis-v0.0.3-alpha.apk` (173MB, arm64-v8a, Android 11+).
No server, no account, no network needed — models ship inside the APK.
`sha256: cf31657976f91944…` (full: verify after download).
