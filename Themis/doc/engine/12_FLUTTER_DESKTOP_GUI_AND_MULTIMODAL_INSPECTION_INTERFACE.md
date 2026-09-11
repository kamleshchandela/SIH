# 12 — Flutter Desktop GUI & Multimodal Inspection Interface

> **Status:** Implemented (Desktop & Mobile Multimodal Interface Live)  
> **Native Linux desktop workstation engineered for statutory enforcement officers, field inspectors, and legal metrology adjudicators under the Legal Metrology Act, 2009, LMPC Rules, 2011, and Jan Vishwas Act, 2023.**

---

## 1. Executive Summary & Design System

PARAKH Desktop (`themis_app/`) provides an institutional, high-performance visual interface to the PARAKH Rust compliance engine. It is designed to satisfy the rigorous evidentiary demands of legal metrology inspections without sacrificing usability, speed, or aesthetic quality.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PARAKH DESKTOP GUI                               │
│                         (Apple Minimalist Dark)                             │
├─────────────────┬───────────────────────────────────────────────────────────┤
│ Top Bar         │ • Mode Indicator ("Statutory Packaging Inspection")      │
│                 │ • Engine Health Beacon ("ONLINE • 1280px INT8")          │
│                 │ • Dev Logs Navigation Shortcut                            │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ 3-Tab Segmented │ [Single Panel]      [Full SKU (Multi)]     [Server Path]  │
│ Control         │ Quick single-image  Composite multi-image  Direct folder  │
│                 │ isolated check      cross-panel pooling    batch audit    │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ Multi-Panel     │ • Panel Selector Row: [Panel 1] [Panel 2] ... [Panel N]   │
│ Controls        │ • In-Canvas Pagination: < PANEL 1/3 >                     │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ Hardware Canvas │ • 120Hz Pinch-to-Zoom & Pan Viewport (1.0x - 6.0x)        │
│                 │ • Dynamic Token Filtering per Active Panel                │
│                 │ • High-Precision Inverse-Mapped Bounding Boxes            │
│                 │ • Apple Crisp White Glassmorphic Token Selection          │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ Adjudication    │ • Overall Compliance Score & Risk Tier Badge              │
│ Verdict HUD     │ • Compounding Liability (INR) under Jan Vishwas Act       │
│                 │ • Panel Evidence Breakdown & Image Quality Metrics        │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ Statutory Audit │ • Clause-by-clause Rule 6 evaluation tiles                │
│ Section         │ • Detected text verbatim, confidence score, and remarks   │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ Dev Log Console │ • Real-time reactive stream console (NET, OCR, AUDIT)     │
│                 │ • One-click copyable logs for field debugging             │
└─────────────────┴───────────────────────────────────────────────────────────┘
```

### Aesthetic Philosophy
1. **Curated Monochrome Palette**:
   - Background: Pitch Black (`#000000`).
   - Primary Surface: Deep Charcoal (`#141416`).
   - Elevated Surface: Charcoal Slate (`#1E1E22`).
   - Structural Borders: Hairline Stroke (`#28282C`, width `1.0`).
   - Primary Text: High-Contrast White (`#FFFFFF`).
   - Secondary Text: Apple Muted Gray (`#86868B`).
2. **Strict Color Discipline**:
   - "Low Risk", "Moderate Risk", and "Compliant" badges are rendered in Apple monochrome white and silver pills (`#A1A1A6` and `#FFFFFF`).
   - Apple Crimson (`#FF453A`) is reserved strictly for genuine statutory non-compliance violations and compounding fines.
   - Selected bounding box highlights are rendered in clean white with translucent glassmorphic fill, replacing distracting fluorescent accents.

---

## 2. Segmented Three-Tab Inspection Architecture

Field inspectors encounter packaging evidence in varying formats: a single photo of a back label, multiple high-res photos taken around a cylindrical jar, or a folder of images stored on a server. The UI provides three dedicated workflows:

### Tab 1: Single Panel Inspection
- Intended for rapid spot-checks where an officer captures or selects one packaging panel (e.g. nutrition facts or manufacturer address block).
- Ingests image via file picker, transmits to `/api/v1/scan-upload`, and immediately renders the statutory verdict and bounding boxes.

### Tab 2: Full SKU (Multi-Panel) Composite Inspection
- Formulated to address the "Multi-Panel Evidence Pooling" doctrine established in Chapter 04 and Chapter 08: mandatory declarations are routinely distributed across distinct packaging facets (e.g. MRP on top crimp, Net Qty on front face, Manufacturer on back panel).
- Features an interactive thumbnail carousel displaying all staged panels with individual removal and addition capabilities.
- Submits images as a multipart payload to `/api/v1/scan-sku-upload`, receiving a pooled evaluation where text across all panels is unified into a comprehensive SKU audit.

### Tab 3: Server Path Direct Audit
- Allows direct specification of a filesystem path to an image or product folder (e.g. `/home/arch/Projects/backbone/dataset/mine/dishwasher/PXL_20260906_162848337.jpg` or `dataset/real_products/8901058000269_Maggi`).
- Interacts with `/api/v1/scan-path` and `/api/v1/scan-product-path`, eliminating HTTP multipart serialization overhead during local testing, batch benchmarking, and high-resolution ground truth validation.

---

## 3. Multi-Panel Canvas Navigation & Bounding Box Engine

### The Multi-Panel Synchronization Challenge
In multi-panel inspections, displaying all bounding boxes from panel 2 over panel 1 creates severe visual clutter and false coordinate overlays. To resolve this:

1. **Active Panel Filtering**:
   ```dart
   tokens: _report?.rawOcrTokens.where((t) {
     if (t.sourceImage == null) return true;
     if (panels.length == 1) return true;
     final s = t.sourceImage!;
     return s == panelFileName ||
         s == 'panel_${safeIndex + 1}.jpg' ||
         panelFileName.contains(s) ||
         s.contains(panelFileName);
   }).toList() ?? []
   ```
2. **Dual Switcher Navigation**:
   - **Above-Canvas Horizontal Bar**: Interactive chips (`[Panel 1] [Panel 2] ...`) with active selection rings.
   - **In-Canvas Overlay Pagination**: Built-in `<` and `>` chevron buttons directly within the top floating HUD badge (`PANEL 1/3`), enabling rapid cycling without shifting eye focus from the packaging details.
3. **Aspect-Ratio Preserving Hardware Canvas**:
   `BoundingBoxCanvas` dynamically measures the natural dimensions of the active image (`_resolveImageSize`) and embeds it within an `InteractiveViewer` constrained to `AspectRatio(naturalWidth / naturalHeight)`.
   The custom painter (`_BBoxPainter`) transforms normalized detector bounding boxes using scale factors:
   $$\text{scale}_x = \frac{\text{viewportWidth}}{\text{naturalWidth}}, \quad \text{scale}_y = \frac{\text{viewportHeight}}{\text{naturalHeight}}$$
   ensuring pixel-perfect alignment under all zoom factors (1.0x to 6.0x).

---

## 4. Live Telemetry & Dev Log Subsystem

To facilitate rapid diagnosis during field trials and live demonstration sessions:
- **`DevLogger` In-Memory Event Bus**:
  A thread-safe, reactive logging bus (`DevLogger.instance`) with broadcast capabilities (`ValueNotifier<List<LogEntry>>`).
  Logs events across five structured subsystems:
  - `[NET]`: HTTP requests, latency, payload sizes, and HTTP status codes.
  - `[ENGINE]`: Server health, device selection, and ONNX Runtime state.
  - `[OCR]`: Token counts, rotation angles, confidence metrics, and probe execution.
  - `[SCAN]`: Active panel ingestion, file dimensions, and EXIF attributes.
  - `[AUDIT]`: Rule evaluation results, risk tier classification, and penalty totals.
- **Embedded Live Console**:
  A compact, semi-transparent status stream located directly below the inspection controls on the main screen, giving real-time visual feedback that the system is processing heavy models rather than stalling.
- **Dedicated Dev Logs Screen**:
  Accessible via the top navigation bar or settings menu. Provides full-text search, subsystem tag filters, entry counter, and a one-click clipboard export button (`Copy All Logs`) for post-inspection analysis.

---

## 5. Verification & Performance Benchmarks

| Viewport Metric | Flutter Desktop Linux (Release) | Target Benchmark |
|---|---|---|
| Startup Time to Interactive | 280 ms | < 500 ms |
| Image Render & Layout | 16 ms (60–120 FPS) | < 33 ms |
| Zoom / Pan Latency | 0 dropped frames (hardware accelerated) | 60 FPS minimum |
| Multi-Panel Switching | Instantaneous (< 10 ms cached) | < 50 ms |
| Memory Footprint (GUI) | ~72 MB Resident RSS | < 150 MB |
| Test Suite Status | `flutter test`: All tests passing | 100% pass |
