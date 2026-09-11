# PARAKH GUI — Legal Metrology Inspection Desktop Client

> **Native Linux desktop inspection workstation engineered for statutory enforcement officers and legal metrology auditors under the Legal Metrology Act, 2009, LMPC Rules, 2011, and Jan Vishwas Act, 2023.**

---

## 1. Architectural Philosophy & Aesthetics

PARAKH GUI follows a strict **Apple Minimalist Monochrome Design System**:
- **Palette**: Pitch black background (`#000000`), deep charcoal card surfaces (`#141416`), elevated panels (`#1E1E22`), and subtle border delineation (`#28282C`).
- **Typography**: Clean, sans-serif typography (`Inter` / Apple system font) with clear hierarchy, high legibility, and monospaced code elements.
- **Color Discipline**: Monochrome silver/white (`#A1A1A6` and `#FFFFFF`) used for all standard status beacons ("Low Risk", "Moderate Risk", "Compliant"), while Apple Crimson (`#FF453A`) is reserved strictly for statutory violations and compounding fines.
- **Bento Grid Layout**: High information density structured in modular bento cards (`BentoCard`) with smooth corner radii and subtle hairline borders.

---

## 2. Core Features & Capabilities

### Three-Tab Segmented Inspection Workflow
1. **Single Panel Tab**:
   - Quick drag-and-drop or file selection for isolated packaging labels (e.g. back panel with nutrition and manufacturer declaration).
   - Instant single-image evaluation against all Rule 6 clauses.
2. **Full SKU (Multi) Tab**:
   - Multi-image upload for composite packaging dossiers (front, back, left, right, top, bottom).
   - Interactive thumbnail carousel with individual panel removal and addition.
   - Unified multi-panel token pooling: text across all panels is evaluated collectively to establish complete SKU compliance.
3. **Server Path Tab**:
   - Fast direct audit of local server directories or files without uploading over HTTP.
   - Ideal for batch operations, ground truth verification, and high-throughput automated inspections.

### Multi-Panel Canvas & Preview Controls
- **Panel Selector Bar**: An interactive switcher bar (`[Panel 1] [Panel 2] ...`) appears above the viewport for multi-image dossiers.
- **In-Canvas Pagination**: Direct `<` and `>` chevron controls embedded in the canvas header badge (`PANEL 1/2`, `PANEL 2/2`) allow seamless panel navigation without shifting scroll focus.
- **Interactive 120Hz Zoom/Pan Canvas**: Hardware-accelerated interactive canvas supporting mouse wheel and touchpad pinch-to-zoom (up to 6.0x) with high-precision bounding box rendering.
- **Filtered Token Highlighting**: Bounding boxes and tokens automatically synchronize with the active panel being previewed.
- **Clean Selection**: Tapping or clicking any bounding box highlights the token in Apple crisp white with translucent glassmorphic fill.

### Live Telemetry & Dev Logging Subsystem
- **In-View Mini Console**: Collapsible real-time dev log console on the inspect screen showing backend network events, OCR stages, and evaluation progress.
- **Full-Screen Dev Logs Viewer**: Dedicated screen accessible from the top navigation bar with search filtering, severity badge filters, and one-click clipboard export.

---

## 3. Running & Building

### Prerequisites
- Flutter SDK (≥ 3.24) with Linux desktop support enabled:
  ```bash
  flutter config --enable-linux-desktop
  ```
- Clang, CMake, and GTK3 development libraries:
  ```bash
  sudo pacman -S clang cmake ninja pkg-config gtk3
  ```

### Development Mode
```bash
flutter run -d linux
```

### Production Release Build
```bash
flutter build linux --release
```
The compiled self-contained bundle will be located at:
```bash
./build/linux/x64/release/bundle/themis_app
```

---

## 4. Directory Structure

```
themis_app/
├── lib/
│   ├── main.dart                   # Application entrypoint & navigation shell
│   ├── models/
│   │   └── compliance_report.dart  # Strongly typed models mirroring Rust backend schema
│   ├── screens/
│   │   ├── inspect_screen.dart     # Primary inspection screen (3 tabs, canvas, results)
│   │   ├── dossier_screen.dart     # Historical inspection dossiers & filtering
│   │   ├── metrics_screen.dart     # Real-time compliance statistics & compliance rates
│   │   ├── engine_screen.dart      # Engine health, ONNX status & system settings
│   │   └── dev_logs_screen.dart    # Full-screen developer log viewer with search & copy
│   ├── services/
│   │   ├── themis_api.dart         # REST client communicating with backend (Axum)
│   │   └── dev_logger.dart         # In-memory reactive logging bus with stream broadcast
│   ├── theme/
│   │   └── app_theme.dart          # Apple minimalist monochrome color palette & ThemeData
│   └── widgets/
│       ├── bento_card.dart         # Modular card container with hairline borders
│       ├── bounding_box_canvas.dart# Zoomable 120Hz canvas with overlay bbox painter
│       ├── clause_tile.dart        # Individual statutory clause evaluation tile
│       └── risk_tier_badge.dart    # Severity tier badge pill (monochrome / crimson)
└── pubspec.yaml                    # Flutter dependencies (cupertino_icons, http, etc.)
```
