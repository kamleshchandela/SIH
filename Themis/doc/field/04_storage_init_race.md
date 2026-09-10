# 04 — Storage init race: empty history with data on disk

## Symptom

Back out of the app, reopen, Audit Registry shows "No historical audits" —
while `registry_index.json` on disk holds 6 entries (verified via root):

```bash
adb shell "su -c 'cat /data/data/gov.doca.themis.themis_app/app_flutter/themis_audits/registry_index.json'" \
  | python3 -c "import json,sys; print(len(json.load(sys.stdin)), 'entries')"
```

## Root cause

The recursion-incident fix set `_initialized = true` *before* awaiting the
disk read. Concurrent callers (Dossier fetch vs the in-flight init) saw the
latch, returned instantly, and read an empty in-memory index. The persistent
log caught it live on a cold start:

```
[23:36:14.10] DOSSIER Loaded 0 record(s) from local registry
[23:36:14.16] STORAGE AuditStorage initialized with 6 ... record(s).
```

Fetch 0.07s *before* init finished — race won by the reader, every cold start
a coin flip on timing.

## Fix (commit `458e9d7`)

One shared init future instead of a boolean latch:

```dart
Future<void>? _initFuture;
Future<void> ensureInitialized() {
  if (_initialized) return Future.value();
  return _initFuture ??= _initialize();   // all callers await the same load
}
```

`_initialize()` keeps the old body, sets `_initialized = true` in `finally`.
No deadlock path: nothing inside init calls back into save (runtime demo
seeding was already removed in the recursion fix).

Verified on device cold start — ordering inverted, count correct:

```
[23:37:47.06] STORAGE AuditStorage initialized with 6 ... record(s).
[23:37:47.06] DOSSIER Loaded 6 record(s) from local registry (filter: All).
```

General lesson for this codebase: any `initialized` boolean guarding async
setup must hand out a shared future, never a bare latch — a second caller
must wait, not skip.
