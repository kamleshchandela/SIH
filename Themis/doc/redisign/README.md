# Themis Frontend Redesign — Documentation Index

> **Official engineering documentation for the mobile-first glassmorphic redesign of Themis (`feature/frontend-redesign`).**

---

## Documentation Index

| Chapter | Document | Description |
|---|---|---|
| **01** | [**Redesign Vision & Glassmorphic Architecture**](file:///home/arch/Projects/backbone/doc/redisign/01_REDESIGN_VISION_AND_GLASSMORPHISM_ARCHITECTURE.md) | Architectural specifications of the soft white-blue-purple glassmorphic ecosystem, `GlassContainer`, `FluidBackground`, `GlassBottomBar`, and the Dynamic Wallpaper Engine. |
| **02** | [**Bug Fixes, Performance & Android Diagnostics**](file:///home/arch/Projects/backbone/doc/redisign/02_BUG_FIXES_PERFORMANCE_AND_ANDROID_DIAGNOSTICS.md) | Exhaustive root cause analysis and resolutions for the Snapdragon 765G CPU choke (BUG-01), Android 11 gallery crash (BUG-02), release network socket block (BUG-03), and frosted blur legibility (BUG-04). |
| **03** | [**Experimental Status, Architecture & Deployment Guide**](file:///home/arch/Projects/backbone/doc/redisign/03_EXPERIMENTAL_STATUS_AND_DEPLOYMENT_GUIDE.md) | Branch lifecycle, rationale for centralizing ONNX inference in the Rust backend, AI model tier selection (Mobile INT8 vs Server INT8/FP32), and step-by-step USB/WiFi field deployment guide. |
| **04** | [**Glass Retest — Small-Sigma Blur, iPhone Discovery & Adaptive Quality**](file:///home/arch/Projects/backbone/doc/redisign/04_SMALL_SIGMA_RETEST_IPHONE_LIQUID_GLASS_AND_ADAPTIVE_QUALITY.md) | BUG-01 retest (10fps→35fps+ via sigma 24→8), proof old iPhones lag on Liquid Glass too + Apple's mitigations, shipped fix table, list-tile next step, adaptive quality switch proposal. |

---

## Quick Reference: Key Engineering Metrics

| Metric | Previous State | Current Redesign State |
|---|---|---|
| **Scroll fps (Inspect, Pixel 4a 5G)** | ~10fps (sigma-24 blur on ~30 cards) | **35fps+ (sigma-8 live glass)** |
| **Tab switch latency** | ~2s behind | instant |
| **Idle CPU Utilization (Phone)** | 35% - 55% (continuous CPU churn) | **0% - 1%** (settled, static wallpaper) |
| **Android SurfaceFlinger CPU** | 19.4% - 30.0% | **0.3% - 0.4%** |
| **Wallpaper Asset Bundle Size** | 97.0 MB (71MB single image) | **5.2 MB** (all 12 presets under 800 KB each) |
| **Card Blur Diffusion** | 0.0 (unblurred clear glass) | **20.0 sigma** (soft frosted diffusion, high legibility) |
| **Photo Attachment Reliability** | Crashed on certain Android 11 gallery viewers | **100% crash-proof** via Native Android SAF picker |
| **Default Model Tier** | Server INT8 (27.3 MB) | **Mobile INT8 (2.7 MB)** with quick Server toggle |
| **Network Connectivity** | Blocked with SocketException in release mode | **Seamless REST API** via USB reverse (`localhost:8080`) & LAN WiFi |

---

## Quick Start Commands

```bash
# 1. Forward port for USB inspection
adb reverse tcp:8080 tcp:8080

# 2. Build release APK
export ANDROID_HOME=/home/arch/Android/Sdk
export ANDROID_SDK_ROOT=/home/arch/Android/Sdk
cd /home/arch/Projects/backbone/themis_app
flutter build apk --release

# 3. Install & launch on connected Android phone
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n gov.doca.themis.themis_app/.MainActivity
```
