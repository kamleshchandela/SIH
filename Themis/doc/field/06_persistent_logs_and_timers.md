# 06 — Persistent logs + scan timers

## Ask

1. Durable log section that needs no manual export (survives restarts).
2. Per-scan timing from button tap to final verdict, to evaluate the 40s/image
   complaint with data instead of adjectives.

## Implementation (commit `458e9d7`)

**`DevLogger` auto-appends** every entry to
`<docs>/themis_logs/themis_YYYYMMDD.log`, 512KB rotation (one `.prev`
generation). Write path is fire-and-forget through a single-flight batched
flush — one write per burst, bounded 200-line buffer, all failures swallowed —
so logging can never stall the event loop (hard rule after the async-recursion
postmortem). Read on device:

```bash
adb shell "su -c 'tail -20 /data/data/gov.doca.themis.themis_app/app_flutter/themis_logs/themis_*.log'"
```

**DevLogs screen backfills** file history once per process (lenient parse,
prepended ahead of live entries, deduped by the once-flag). **TIMER tag** added
(`TIMER` color + included in the SCAN filter).

**Scan TIMER marks** (`themis_native_bridge.dart`, plus tap logs in both
Inspect handlers and 3-frame stack traces in their catches):

```
[TIMER] Audit button tapped (5 pooled panels, t=+0ms)
[TIMER] Scan requested: 5 panel(s) (t=+0ms)
[TIMER] Isolate spawned, entering FFI (t=+3ms)
[TIMER] Native FFI returned (t=+132047ms). Deserializing payload...
[TIMER] Report parsed: 28.6% (HighRiskMajor) (t=+132047ms total)
```

Measured on the Yippie 5-panel pooled scan: **132047ms, ~100% inside the Rust
FFI call, ~3ms Dart overhead.** That single line reframes the speed work: no
Dart-side optimization can matter; per-stage Rust timings (load → quality gate
→ detect → recognize → probe? → evaluate, per panel) are the required next
instrumentation before cutting detector input or batching recognition.

**Dossier diagnostics** in the same pass: every history load logs its record
count (`Loaded N record(s)…`, which is what caught doc 04's race live), and
load failures surface a toast + stack trace instead of a silent empty screen.
Storage init logs its registry path.
