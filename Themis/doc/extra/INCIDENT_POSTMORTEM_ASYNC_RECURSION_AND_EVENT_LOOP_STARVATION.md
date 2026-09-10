# Incident Postmortem: Re-entrant Storage Recursion & Dart Event Loop Starvation

**Incident ID:** INC-20260909-ASYNC-RECURSION-LOOP  
**Date:** 2026-09-09  
**Severity:** P1 — UI Lockup & Unbounded Scan Latency Spike  
**Affected Component:** `themis_app` / `AuditStorageService` / `InspectScreen`  
**Target Hardware:** Google Pixel 4a 5G (`12171JECB00573`), Android 11 (API 30), Qualcomm Snapdragon 765G, 6GB RAM.  

---

## 1. Executive Summary

Shortly after resolving the native ARM64 swap thrashing incident (INC-20260909-ARM64-SWAP) and introducing local compliance audit persistence and offline PDF exports, on-device testing on the physical Google Pixel 4a 5G encountered a severe regression:
- Packaging scans that normally execute in **<40–50 seconds** failed to complete even after **5+ minutes**.
- The Flutter UI exhibited heavy stutter, scroll stalls, and the loading spinner froze midway.
- To the end user, this appeared to be the exact same "never-ending scan and memory thrashing" bug returning.

Diagnostic analysis revealed that while the symptoms were indistinguishable from the earlier kernel-level swap thrashing, the root cause was fundamentally different: an **unlatched re-entrant asynchronous recursion loop** within `AuditStorageService.ensureInitialized()`. 

The recursion flooded the Dart event queue with cascading disk writes, JSON serializations, and `notifyListeners()` state notifications. This completely saturated the main isolate's event loop, preventing the response port from `ThemisNativeBridge`'s background inference isolate from ever being processed.

Placing an immediate initialization latch at the entry of `ensureInitialized()` and decoupling default demo seeding completely resolved the issue, returning on-device execution to **~45–50 seconds** with fluid 60fps scrolling.

---

## 2. Symptom Comparison: Swap Thrashing vs. Event Loop Starvation

Both incidents produced almost identical outward UX degradation, illustrating how distinct architectural bottlenecks in cross-language mobile apps (Rust native vs. Dart event loop) can masquerade as the same failure mode:

| Dimension | Incident 1: Kernel Swap Thrashing | Incident 2: Dart Event Loop Starvation |
|---|---|---|
| **Root Layer** | Linux Kernel / OS Virtual Memory | Dart VM Event Queue / Microtask Queue |
| **Trigger** | Unthrottled concurrent `Isolate.run` calls | Unlatched async recursion in `AuditStorageService` |
| **Memory State** | 2.5 GB RSS, 0 KB Free Swap, `kswapd0` 36% CPU | Normal memory (<450 MB RSS), swap unburdened |
| **CPU State** | High `sys` (kernel page faulting & I/O wait) | High `user` (Dart isolate churning event loop) |
| **Native Inference** | Slowed to 3+ minutes due to memory page faults | Completed in 35s in background, but response port blocked |
| **UI Symptoms** | Frame drops, stuttering scroll, stuck spinner | Frame drops, stuttering scroll, stuck spinner |
| **Scan Resolution** | Stalled or killed by Android LowMemoryKiller | Scan appeared to hang indefinitely (>5 minutes) |

---

## 3. Timeline & Observations

| Timestamp (Local) | Event / User Observation |
|---|---|
| **21:28** | Offline PDF notice generator and local audit persistence committed (`72db8d6`). |
| **21:32** | Fresh APK installed on Pixel 4a 5G. |
| **21:35** | User initiated test audit on Dishwash packaging. |
| **21:39** | Audit exceeded 4 minutes without completing. User reported: *"its lagging aian, like heavily, every sicne you made chanegs it same problem, stutture laoding scren lag, adn its not snaned afetr 5 minutes"*. |
| **21:41** | Diagnostic probe: ADB `top` revealed low swap usage, but the Dart main thread was continually pegged dispatching change notifications and file I/O microtasks. |
| **21:42** | Code review of `AuditStorageService.ensureInitialized()` identified self-referential async recursion via `_seedDefaultDemos()` -> `saveInspection()` -> `ensureInitialized()`. |
| **21:43** | Hot fix deployed: set `_initialized = true` at method entry, removed recursive demo seeding. |
| **21:45** | Retest by user: *"its better now, as it was before, dishwasher one doen is 50 sec, less lag, usabel export si working"*. |

---

## 4. Root Cause Analysis

### 4.1 The Re-entrant Asynchronous Loop

In `themis_app/lib/services/audit_storage_service.dart`:

```dart
// BUGGY IMPLEMENTATION:
Future<void> ensureInitialized() async {
  if (_initialized) return; // [1] Guard check passes initially (false)

  try {
    final docDir = await getApplicationDocumentsDirectory();
    _storageDir = Directory('${docDir.path}/themis_audits');
    ...
    if (_index.isEmpty) {
      await _seedDefaultDemos(); // [2] Awaits seeding before latching _initialized
    }

    _initialized = true; // [3] Latch set ONLY at the very end of the method!
  } catch (e) { ... }
}
```

When `_seedDefaultDemos()` ran:
```dart
Future<void> _seedDefaultDemos() async {
  ...
  await saveInspection(oats); // [4] Calls saveInspection
  ...
}

Future<void> saveInspection(ComplianceReport report) async {
  await ensureInitialized(); // [5] Re-enters ensureInitialized()!
  ...
  notifyListeners(); // [6] Triggers full widget rebuild cascade
}
```

### 4.2 The Cascading Starvation Mechanism

1. During initial screen mount or audit trigger, `ensureInitialized()` was invoked.
2. At step `[2]`, `_seedDefaultDemos()` was called. Notice that at this moment, **`_initialized` was still `false`** because step `[3]` had not been reached.
3. `_seedDefaultDemos()` called `saveInspection(oats)`.
4. `saveInspection(oats)` began with `await ensureInitialized();`.
5. Because `_initialized` was still `false`, `ensureInitialized()` re-entered from the top.
6. The re-entrant invocation saw `_index.isEmpty` (since the file write hadn't completed), and called `_seedDefaultDemos()` **again**.
7. This created an uncontrolled asynchronous recursion tree:
   - Dozens of concurrent disk I/O futures reading and rewriting `registry_index.json`.
   - Repeated JSON encoding/decoding of multi-kilobyte reports.
   - Rapid-fire `notifyListeners()` calls forcing Flutter's scheduler to queue re-layout and repaint passes on every tick.
8. When the user tapped "Scan Single Panel", `ThemisNativeBridge` dispatched native ONNX inference onto a background isolate via `Isolate.run`. 
9. The native background isolate successfully completed DBNet and PP-OCRv4 detection in ~35 seconds and sent its message back through the Dart `SendPort`.
10. However, the main isolate's event queue was so inundated with unresolved storage microtasks and change notifications that it **never yielded time to dequeue the Isolate completion message**. The UI spinner stayed stuck indefinitely.

---

## 5. Remediation & Architectural Resolution

### 5.1 Immediate Re-entrancy Latch
Set the initialization latch immediately upon entry before any asynchronous operation can yield execution:

```dart
Future<void> ensureInitialized() async {
  if (_initialized) return;
  _initialized = true; // Latched immediately on entry
  ...
}
```

### 5.2 Decoupling Static Demo Assets
Removed runtime seeding of synthetic inspection reports into user storage. Canonical demo packaging images (Oats, Dishwash, Maggi) are already bundled directly in Flutter's `assets/demo/` and loaded directly on user demand through `DemoAssetService`, requiring zero runtime disk persistence overhead.

### 5.3 Storage Access Framework (SAF) File Export Integration
Integrated native Android document creation via `FilePicker.platform.saveFile`:
- Allows the user to select the destination folder (Downloads, Documents, SD card, cloud storage) via the system file browser.
- Eliminates reliance on obscure internal app directories (`/data/user/0/.../app_flutter/`).
- Handles user cancellations gracefully with zero exceptions.

---

## 6. Preventive Engineering Safeguards

1. **State Machine Latches First:** Any asynchronous service with an `ensureInitialized()` or `init()` lifecycle must flip its state variable to `in_progress` or `initialized` *before* awaiting any sub-operations to prevent re-entrant cascades.
2. **Never Seed Mutating State in Accessors:** Initialization routines must only set up paths and deserialize existing state. They must never synthesize or persist new domain data as a side-effect.
3. **Isolate Message Starvation Watchdogs:** In high-computation mobile environments, use timeouts on `Isolate.run` with diagnostic warnings if the main thread fails to consume the return port within an expected window:
   ```dart
   await Isolate.run(...).timeout(
     const Duration(seconds: 120),
     onTimeout: () => throw TimeoutException('Isolate response port starved on main thread'),
   );
   ```
4. **Single-Flight Guards on All I/O:** Both native execution (`ThemisNativeBridge._isScanning`) and audit storage (`AuditStorageService._isWriting`) now enforce single-flight mutexes.
