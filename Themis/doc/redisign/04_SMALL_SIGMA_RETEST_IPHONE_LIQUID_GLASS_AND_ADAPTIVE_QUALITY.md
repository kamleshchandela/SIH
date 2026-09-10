# Chapter 04: Glass Retest — Small-Sigma Blur, the iPhone Discovery & Adaptive Quality

> **Follow-up to BUG-01. The "0% idle" fix was real but incomplete: scrolling stayed at ~10fps with 2s tab lag. This chapter records the retest, the key discovery that old iPhones lag on Liquid Glass too (and how Apple copes), and the small-sigma + adaptive-quality solution now shipped in `themis_app`.**

---

## 1. Retest Timeline (Pixel 4a 5G, Snapdragon 765G / Adreno 620, release APK)

| Stage | GlassContainer default | Scroll fps | Tab switch | Idle CPU (app) |
|---|---|---|---|---|
| Baseline (Ch.02 claim) | `blur: 24`, all cards live | ~10fps | ~2s behind | 24–28% churning* |
| Static-fill experiment | `enableBlur: false` (cards), blur kept on nav only | ~30fps | fast | 0–1% |
| **Shipped (this chapter)** | **`enableBlur: true, blur: 8` on widgets; bottom bar static translucent** | **35fps+** | fast | **0–1%** |

\* The Ch.02 "0% idle" telemetry was captured in a settled static state; on-device retest with `top -b` showed 24–28% sustained churn (fresh-install shader warmup + mesh/animation suspects investigated — no `Timer`/polling/animation remains in static-wallpaper mode; verified by grep).

### Why sigma 8 instead of 24

Gaussian blur tap count scales with **sigma²**. Dropping sigma 24 → 8 cuts kernel samples to roughly **1/9th per pixel per pass**, while still reading as frosted glass over the dark wallpaper. That single constant change (plus the untouched `RepaintBoundary` isolation) took us from 30fps/static to **35fps+/live glass** — i.e. the premium look came back *with* a speedup, because per-card cost collapsed ~9×.

### Files changed

- `lib/widgets/glass/glass_container.dart` — default `blur: 8.0, enableBlur: true`; static frosted gradient fallback when `enableBlur: false`; `RepaintBoundary` around every card surface.
- `lib/widgets/glass/glass_bottom_bar.dart` — `enableBlur: false` (bar is on screen every frame; static translucency, zero per-frame cost).
- `lib/widgets/glass/glass_wave_chart.dart` — `MaskFilter.blur(8)` halo → layered alpha circles; `RepaintBoundary` + `isComplex` on the chart canvas.
- `lib/widgets/glass/glass_circular_gauge.dart` — `MaskFilter.blur(6)` glow → wide translucent stroke; `RepaintBoundary` around the tween painter.
- `lib/widgets/glass/fluid_background.dart` — wallpaper `cacheWidth: 1080`, `filterQuality.low`, `gaplessPlayback` (was full-res decode re-sampled under every blur).
- `lib/main.dart` — `RepaintBoundary` around the tab `IndexedStack`.
- Field fix (not code): `adb reverse tcp:8080 tcp:8080` had been wiped — phone's `localhost:8080` went nowhere (`health ERROR` in log strip). Re-established; backend was healthy throughout.

---

## 2. The iPhone Discovery: Old iPhones Lag on Liquid Glass Too

Premise we started with: *"iPhone 12 runs full-UI iOS 26 Liquid Glass without lag — why can't we?"* **That premise is false.** Web research (Sep 2025 – Jun 2026) shows:

- **iPhone 11/12/13/SE owners report jitter, stutter, slow app-open and battery drain on iOS 26** (BGR, MacObserver, Macworld, Apple Support Communities, Reddit r/iOS). iOS 26 needed **10 patches** post-launch; Macworld (May 2026) measured **Notification Center open ≈ 15W / 40% GPU vs 8W / 20% with transparency off** — "as much as playing a 3D game."
- **Controlled benchmark** (reactnative.live, Apr 2026, iPhone 13/14 Pro/SE-class): Liquid Glass vs legacy translucency → **GPU +13pp (45%→58%), frame time 7.8ms→11.2ms, touch latency +26ms (58→84ms), +40–90MB memory** for multi-backdrop views.
- **Apple's own mitigations prove the cost is real:** iOS 26.1 added a **"Tinted" (reduced) Liquid Glass mode**, plus Reduce Transparency / Reduce Motion fallbacks; **older chips capped at 60Hz** (full 120Hz only on A18 Pro + ProMotion); **effect disabled entirely on weak iPads** (A14 and earlier). A viral "Frosted Glass instead of Liquid" accessibility workaround on iPhone 13 removed stutter — i.e. users independently re-discovered *our* static-fill experiment.
- **Why Apple still does it better** (and what we copied):
  1. **Silicon:** A14+ GPUs are ~2–3× the Adreno 620 with tile-based deferred rendering designed for compositing; Flutter pays Vulkan/Impeller overhead per `BackdropFilter` saveLayer.
  2. **Cached backdrops:** Core Animation caches static backgrounds and only re-samples on content motion ("static backgrounds get cached; scrolling forces recalculation"). → Our mirror: `RepaintBoundary` on every card (= `CALayer.shouldRasterize`), wallpaper decode hints.
  3. **Shared sampling buffer:** SwiftUI `GlassEffectContainer` allocates **one GPU texture for a group** of elements instead of per-element passes. → Our mirror: one live-blur budget concentrated on hero widgets; lists and the always-on nav bar go static.
  4. **Official guidance we now follow verbatim:** *"replace dynamic blurs with static pre-baked images on constrained devices," "smaller blur radii drastically reduce shader work," "avoid glass inside fast-scrolling lists," "pre-render blurred backgrounds during idle."*

Bottom line: **nobody gets full-UI live blur for free on 2020 silicon — Apple pays it in watts and fallback modes.** Our sigma-8 + static-list strategy is the same trade, made explicit and user-switchable (see §4).

---

## 3. Remaining Known Cost: The Clause-Result List ("static fill for list tiles")

After an audit, `InspectScreen` renders **8–14 `ClauseTile`s in a `SliverList`**, each currently a live `BackdropFilter (sigma 8)`. Scrolling through results is therefore the heaviest screen left: ~10 simultaneous blurs vs ~5 on the input form. Hero cards (gauge, wave chart, viewport, action grid) are few and mostly static on screen — cheap.

**Next step (not yet applied): "static fill for list tiles only"** = pass `enableBlur: false` in exactly two places — `ClauseTile`'s `GlassContainer` and the Metrics/Dossier stat cards — while hero widgets keep live sigma-8 blur. Expected: results-scroll approaches input-form fps; visual difference is negligible because list tiles are small and text-dense (the static slate gradient was tuned for legibility over busy wallpapers). One-line change per call site; no architecture change.

---

## 4. Adaptive Glass Quality Switch (Low-End Devices) — SHIPPED

Four tiers, **all live glass** — only sigma changes (cost scales with sigma²). Rationale, per field testing: if a phone can't handle sigma 2 it can't handle the OCR engine either, so there is no fully-static tier. The always-on bottom bar stays static translucent (pinned opt-out) since it would tax every frame.

| Tier | Sigma everywhere | Target |
|---|---|---|
| **Premium** | 12 | Flagships & desktop Linux |
| **High** | 8 | Smooth on most field phones (ex-Balanced) |
| **Balanced** | 5 | The everyday sweet spot, auto-default |
| **Lite** | 2 | Max fps & battery for low-end devices |

- **UI:** `GLASS QUALITY` card in `EngineScreen` §1B (Auto / Premium / Balanced / Lite radio options, same pattern as Model Tier). Badge shows active tier + total RAM (e.g. `Balanced • 5.3GB`).
- **Mechanism:** `lib/services/glass_perf_service.dart` (`GlassPerfService`, `ChangeNotifier` singleton, persisted in `themis_glass_config.json`); `GlassContainer.enableBlur` is now nullable — null follows the tier (Premium floors sigma to 12, all other tiers cap to the tier sigma), explicit true/false always wins (bottom bar pins false, sample pill pins true). Tier switches hot-apply via `ListenableBuilder`, no restart. No device names in UI copy.
- **Auto-default:** `MainActivity` exposes `ActivityManager.MemoryInfo` over `gov.doca.themis/perf` channel (no new plugin dependency); ≤4GB or low-RAM flag → Lite, else Balanced. Channel failure (iOS/desktop) → Balanced. Verified on the 5.5GB test device (→ Balanced).
- **Remaining open question:** should Lite also force static wallpaper (kills the mesh 60fps loop — the biggest battery win)? Currently blur-only.

---

## 5. Quick Reference (Updated Engineering Metrics)

| Metric | Ch.02 State | Current State |
|---|---|---|
| Scroll fps (Inspect, Pixel 4a 5G) | ~10fps (sigma-24 blur on ~30 cards) | **35fps+ (sigma-8 live glass)** |
| Tab switch latency | ~2s behind | instant |
| Idle CPU (app) | 24–28% observed (claim 0%) | **0–1%** |
| Card blur sigma | 24.0 | **Tier-capped: 12 / 8 / 5 / 2** (Premium/High/Balanced/Lite) |
| Bottom nav blur | 20.0 live | static translucent (always-on surface) |
| Chart/gauge glows | `MaskFilter` saveLayer | alpha-layered (zero saveLayer) |
| Wallpaper decode | full-res | 1080px + low filter quality |
| Backend reachability | `adb reverse` wiped (health ERROR) | reverse re-established + documented |

---

## 6. Correction: "The Adreno 620 Was Always Capable; The Compositor Path Wasn't"

The original §2 draft framed Apple silicon as "~2–3× the Adreno 620" and implied old phones can't do full-UI glass. Field debate + benchmark data forced a correction:

- **Peak gap is real but workload-dependent:** 3DMark Wild Life Extreme scores the 765G at **446 vs A14 at 2229** (~5×), while raw throughput is 480 vs 654 GFLOPS (~1.4×). Single-number comparisons mislead.
- **Sustained gap is far smaller — iPhones throttle too:** stability figures show the **765G holding 99% vs A14 dropping to 86%** under sustained load. Thin phones with no vapor chamber universally shed performance (2-hour PUBG sessions throttle iPhones exactly like Androids). The A14's own GPU uplift over the A13 was <8% (Apple's own estimate).
- **Games prove the silicon was never the blocker:** titles like Where Winds Meet render console-grade real-time 3D on 7-year-old phones at 24–30fps. But games do it in **one** fullscreen pass at adaptive resolution with a 33ms budget (their fps badges visibly dip 30→24 under load — quality scaling in action). Our old UI did **~30 stacked full-resolution offscreen Gaussian passes per frame** with a 16.7ms budget plus touch latency. No GPU on earth — Apple or otherwise — survives that; an RTX would crawl too.
- **Where Apple actually wins:** driver/pipeline integration (one Metal path Apple owns end-to-end vs Adreno/Mali/PowerVR × uneven Vulkan drivers × young Impeller), server-side compositor caching, and per-device QA tuning — not magic silicon.
- **Our 4-tier switch is game-style quality scaling** for a two-person team: same philosophy as a game's adaptive resolution, applied to UI blur sigma.

**Corrected thesis: the Adreno 620 was always capable; the compositor path wasn't. Apple wins on driver/pipeline integration and per-device tuning, not magic silicon — and even they throttle.**
