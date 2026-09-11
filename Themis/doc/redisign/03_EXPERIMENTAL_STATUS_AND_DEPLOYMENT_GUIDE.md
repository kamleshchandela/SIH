# Chapter 03: Experimental Status, Architecture & Deployment Guide

> **Operational Guidelines, Model Tier Strategy, and Field Deployment Instructions for the Experimental Mobile Redesign.**

---

## 1. Experimental Branch Status

The mobile-first glassmorphic redesign currently resides on the **`feature/frontend-redesign`** branch of [`themis_app`](file:///home/arch/Projects/backbone/themis_app).

### What is Experimental:
1. **Dynamic Backdrop Shaders**: While the static wallpaper mode is completely optimized (0% idle CPU), the Dynamic Fluid Mesh mode uses animated sinusoidal trigonometric offsets. On low-end thermal-throttled GPUs, static wallpaper mode (`frostedglass.png` or presets) is recommended for all-day field battery endurance.
2. **Impeller Vulkan Acceleration**: The app leverages Flutter's Impeller rendering backend with Vulkan on Android 11+ (API 30+). Older devices running Android 10 or below (API 29) fall back to OpenGL ES, where blur sampling costs may differ.
3. **Mobile vs Desktop UI Divergence**: The current mobile layout utilizes a bottom floating capsule navigation bar (`GlassBottomBar`) with touch-optimized target sizes (48px+). Desktop targets (`linux/x64`) compile cleanly with window resizing support, but a dedicated desktop side-rail navigation layout is planned for wide screens.

---

## 2. On-Device Inference vs Backend Engine Architecture

A common question during field deployment is whether the mobile app requires on-device neural network execution (e.g., via `flutter_onnxruntime`).

```
+-------------------------------------------------------------------------+
|                    CLIENT-SERVER SEPARATION OF CONCERNS                 |
|                                                                         |
|  [ ANDROID SMARTPHONE / TABLET ]            [ BACKEND ENGINE (HOST/LAN) ]|
|  +-----------------------------+           +--------------------------+ |
|  | PARAKH Mobile Client (Flutter) |  HTTP POST | PARAKH Rust Engine (Axum) | |
|  | - Camera Capture            | --------> | - Multi-threaded ONNX    | |
|  | - Native SAF Document Picker | (Multipart) - DBNet Text Detection   | |
|  | - Specular Glass UI Cards   |           | - PP-OCRv4 Text Recog    | |
|  | - Telemetry & Audit Reports | <-------- | - Statutory Rule Engine  | |
|  +-----------------------------+  JSON     |   (LMPC 2011, Jan Vishwas)| |
|                                            | - PDF / CSV Exporter     | |
|                                            +--------------------------+ |
+-------------------------------------------------------------------------+
```

### Why Inference is Centralized in the Rust Backend:
1. **Model Weight Bloat**: Bundling full DBNet and PP-OCR models directly into the APK would increase the package size from ~58 MB to over **200 MB**.
2. **Statutory Compliance Rule Complexity**: The PARAKH rule engine comprises over **10,000 lines of deterministic Rust code** implementing:
   - Mandatory LMPC Rule 6 declarations (MRP, Net Qty, Dates, Manufacturer, Customer Care).
   - Area-based statutory font-size ratio verifications (Principal Display Panel math).
   - Jan Vishwas Act (2023) compounding penalty calculations.
   - Cross-panel SKU pooling and evidence photograph management.
   Porting this logic to Dart would introduce maintenance fragmentation and potential regulatory divergence.
3. **Battery & Thermal Conservation**: Offloading DBNet feature map unclustering and CTC beam decoding protects mobile field hardware from battery drain and CPU thermal throttling.

---

## 3. AI Vision Model Tier Strategy & Empirical Battle Test

Following a rigorous multi-dataset battle test across real-world smartphone packaging (`oats`, `dishwasher`, `yippie`), the vision model tiers are categorized below:

| Tier | Bundle Size | Detection Model | Recognition Model | Field Accuracy (Oats / Dishwasher / Yippie) | Recommended Target |
|---|---|---|---|---|---|
| **Mobile High-Recall INT8** *(Champion)* | **~3.06 MB** | `ppocr_det_int8.onnx` (0.76 MB) | `en_ppocr_v3_rec_int8.onnx` (2.30 MB) | **85.7% / 71.4% / 62.5%** | **Recommended Default**: Proven on curved/folded packs (<8 MiB mobile ship budget) |
| **Mobile Ultra-Fast INT8** | **~2.76 MB** | `ppocr_det_int8.onnx` (0.76 MB) | `en_ppocr_v4_rec_int8.onnx` (2.00 MB) | 0.0% / 0.0% / 14.3% | High-contrast flat scans and digital documents |
| **Server INT8** | **~27.35 MB** | `ppocr_det_server_int8.onnx` (27.35 MB) | `en_ppocr_v4_rec_int8.onnx` (2.00 MB) | 0.0% / 0.0% / 14.3% | High-capacity DBNet Server on dedicated GPU/host |
| **Server FP32** | **~113 MB** | `ppocr_det_server.onnx` (108 MB) | `en_ppocr_v4_rec.onnx` (7.6 MB) | Forensic reference | Forensic laboratory and courtroom verification |
| **Auto Tier** | Dynamic | Resolves highest available precision from `themis/models/` | Automatic environment detection |

> [!TIP]
> **Why PP-OCRv3 Rec INT8 (3.06 MB) Won The Battle Test**:
> On rotated smartphone captures and curved cylindrical surfaces (e.g. SaveMore dishwasher bottle), PP-OCRv4 recognizer suffered confidence drops during multi-angle probing, failing the orientation rescue. PP-OCRv3 INT8 maintains robust character activations (>0.79 to 0.87 mean confidence) on distorted packaging crops, extracting up to **252 tokens** and passing statutory Net Quantity and Date checks in 12–37 seconds pure CPU. Both models fit comfortably inside an **< 8 MiB** on-device APK asset bundle.

---

## 4. Field Deployment & Connection Guide

### Option A: USB ADB Reverse Tethering (Recommended for Lab / Direct Inspection)
When the mobile device is connected to the host laptop via USB with USB Debugging enabled:

1. **Verify ADB Connection**:
   ```bash
   adb devices
   ```
2. **Forward Backend Port**:
   ```bash
   adb -s <device_id> reverse tcp:8080 tcp:8080
   ```
   > **Note:** If `adb root` is executed, the adb daemon restarts and wipes reverse rules. Re-run the reverse command immediately.
3. **Connect in App**:
   - In **Settings & Engine**, tap the **`USB ADB (localhost)`** preset chip (`http://localhost:8080`).
   - Tap **Connect / Test**. The indicator will turn glowing cyan with `ONLINE (CPU)`.

---

### Option B: Local WiFi LAN Operation (Untethered Field Audits)
When the mobile device and host server are connected to the same local WiFi network:

1. **Find Host LAN IP**:
   ```bash
   ip -4 -brief addr
   # Example: wlo1 UP 192.168.1.92/24
   ```
2. **Connect in App**:
   - In **Settings & Engine**, tap the **`LAN WiFi (192.168.1.92)`** preset chip.
   - Tap **Connect / Test**.
   - Inspect packaging panels wirelessly without physical cables.

---

## 5. Building & Installing Release APKs

To produce a production-ready, AOT-compiled release build:

```bash
# Set Android SDK environment variables
export ANDROID_HOME=/home/arch/Android/Sdk
export ANDROID_SDK_ROOT=/home/arch/Android/Sdk

cd /home/arch/Projects/backbone/themis_app

# Build Release APK
flutter build apk --release

# Deploy to Connected Device via ADB
adb -s <device_id> install -r build/app/outputs/flutter-apk/app-release.apk

# Launch App
adb -s <device_id> shell am start -n gov.doca.themis.themis_app/.MainActivity
```
