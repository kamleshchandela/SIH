# Field investigations — on-device bug saga (2026-09-09/10)

Device under test: Pixel 4a 5G (`12171JECB00573`), Snapdragon 765G, Android 11,
Magisk root available (`adb root` works, `su -c` usable).

Every claim below was verified by reading bytes, not by reasoning. Commands are
given so any finding can be reproduced exactly.

| # | File | Question | One-line verdict |
|---|---|---|---|
| 1 | `01_yippie_multisku_score_gap.md` | Phone multi-SKU scores 28.6%, CLI scores 62.5% — who is at fault? | Neither engine nor models: ARM/x86 recognizer float noise flips ~6 borderline chars, brittle single-token matchers flip 3 clauses. |
| 2 | `02_exif_ffi_loader_fix.md` | Portrait phone photos fed sideways to the detector? | Yes in code (`ffi.rs` used raw `image::open`), fixed to the shared EXIF loader — but the auto-probe had already been rescuing orientation, so it was hygiene, not the score driver. |
| 3 | `03_metrics_stale_snapshot.md` | History shows 3 audits, totals show 0 — sometimes? | `MetricsScreen` never subscribed to storage; init snapshot went stale. Plus hardcoded defect rates drew a ghost graph. |
| 4 | `04_storage_init_race.md` | History empty after back-out + reopen, data intact on disk? | The recursion-fix latch let readers race past init and read an empty index. Shared init future; verified 6/6 on cold start. |
| 5 | `05_apk_stale_native_lib.md` | Fix verified in source but phone behavior unchanged? | APK kept packaging a stale `libthemis.so` through every rebuild trick short of input-byte change. Verify `sha256sum` of the `.so` inside the APK before every on-device verdict. |
| 6 | `06_persistent_logs_and_timers.md` | No durable logs, no per-stage timings? | `DevLogger` auto-appends to a rotating file; scan path logs `TIMER` marks (tap → isolate → FFI return → parse). Measured: 132047ms, ~100% inside Rust FFI. |
| 7 | `07_dashboard_history_photos.md` | Blank history cards, wall of "P" in Recently Scanned? | Cards never received an image source; people row removed outright; cards resolve demo-asset → panel-file → gradient. |
| 8 | `08_full_image_zero_vertical_blindness.md` | Full pack shot scores 0% on phone? | Detector blind to the vertical statutory strip on all tiers/platforms — phone exonerated; overlay proof in `assets/`. |
| 9 | `09_vertical_merge_fix.md` | Fix for the above? | Merge-only rotated full-res pass (correct CCW direction after a failed CW attempt), gate design; desktop 122→133, phone 0%→14%. Plus a documented false alarm: a claimed 90° mapping bug that the round-trip test disproved and was reverted. |
| 10 | `10_arm_decode_divergence.md` | Phone scores below desktop on the same image? | ARM INT8 decodes the strip into different token shapes (dot shreds, lost price/tax); matchers hardened against both, phone-variant regression test; 28.6%→42.9%, field-identical to desktop. |

Evidence pool (inputs, all pulled from the phone, all hashed):

- `/storage/emulated/0/temp/bug01/` — Metrics-0-vs-history-3 screenshots
- `/storage/emulated/0/temp/bug02/` — misplaced-box screenshots + pooled-audit log
- `/storage/emulated/0/temp/bug03/` — post-fix 29% retest log
- `/storage/emulated/0/Audiobooks/mine/yippie/halfimage/` — the 5 phone input files
- PC mirror: `dataset/mine/yippie/{fullimage,halfimage}/`
- On-device registry (root): `/data/data/gov.doca.themis.themis_app/app_flutter/themis_audits/`
- On-device logs (root): `/data/data/gov.doca.themis.themis_app/app_flutter/themis_logs/themis_YYYYMMDD.log`

Commits (all on `main`): `36514ef` metrics/static defects, `02bd47b` dashboard
photos, `458e9d7` EXIF loader + init race + persistent timed logs.
