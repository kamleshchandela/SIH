# 07 — File Manifest & Engineering Changelog

> **Complete absolute path manifest of all codebase files, accompanied by an in-depth chronological engineering changelog detailing the iterative development of PARAKH Mobile.**

---

## 1. Complete File Manifest

Every file in `my-app` has a strictly defined, non-redundant operational responsibility:

```
my-app/
├── app/
│   ├── (tabs)/
│   │   ├── _layout.tsx           # Bottom Tab Bar (Dashboard, Scan, Audits, Settings)
│   │   ├── index.tsx             # Dashboard: Live Engine Telemetry & Compliance Metrics
│   │   ├── scan.tsx              # Multi-Modal Packaging Scanner (Single, SKU Strip, Path)
│   │   ├── inspections.tsx       # Historical Inspection Repository (Search & Filter)
│   │   └── settings.tsx          # Officer Profile & Dynamic Network Controls
│   ├── _layout.tsx               # Root Stack Navigator & Theme Configuration
│   ├── login.tsx                 # Officer Login & Role Guard (Admin / Inspector)
│   ├── result.tsx                # Comprehensive Inspection Audit Report
│   ├── csv-viewer.tsx            # In-App CSV Audit Spreadsheet Table & Native Share
│   ├── pdf-viewer.tsx            # In-App Directorate Show-Cause Notice & Native Share
│   └── evidence.tsx              # High-Resolution Packaging Photo Viewer
│
├── src/
│   ├── context/
│   │   └── AuthContext.tsx       # Auto-Detecting Wi-Fi IP & JWT Auth State Provider
│   ├── services/
│   │   └── api.ts                # All 12/12 PARAKH REST API Endpoints & File Downloader
│   ├── types/
│   │   └── themis.ts             # Complete TypeScript Interfaces Matching Rust Structs
│   └── utils/
│       └── formatters.ts         # Currency (₹), RFC 4180 CSV Generator, Risk Tiers, Dates
│
├── .env                          # Active Engine Base URL Configuration
├── .env.example                  # Environment Configuration Template
├── app.json                      # Expo Project Configuration & Scheme
├── package.json                  # Dependencies & Execution Scripts
└── tsconfig.json                 # TypeScript 5.9 Compiler Configuration
```

---

## 2. Chronological Engineering Changelog

### Phase 1: Foundation & Unified REST Client
- Initialized clean React Native (Expo SDK 54 / Expo Router v6) application.
- Implemented `src/types/themis.ts` mirroring the 1:1 data models of the PARAKH Rust engine (`ComplianceReport`, `RuleEvaluation`, `StatutoryPenalty`, `InspectionStats`).
- Implemented `src/services/api.ts` connecting to all 12 REST API endpoints.

### Phase 2: Role-Based Authentication & Session Management
- Built `app/login.tsx` with role selection (`Enforcement Director` vs `Field Inspector`) and quick-fill demo chips.
- Implemented `src/context/AuthContext.tsx` with persistent JWT storage in `AsyncStorage` and automatic 24-hour token expiry validation.
- Implemented automatic 401 interceptor triggering silent session logout.

### Phase 3: Dashboard & Live AI Engine Telemetry
- Built `app/(tabs)/index.tsx` featuring real-time engine telemetry:
  - Connects to `/api/v1/health` to confirm active ONNX CPU Vectorized inference runtime.
  - Live data persistence indicator (`PostgreSQL Persistent Storage` vs `Stateless In-Memory Mode`).
  - 2x2 analytics grid displaying Total Audits, Compliant SKUs, Violations, and Pass Rate.
  - Jan Vishwas Act total compounding fine calculation in Indian Rupees (INR).

### Phase 4: Multi-Modal Packaging Scanner
- Built `app/(tabs)/scan.tsx` supporting three distinct scanning workflows:
  - **Full SKU Multi-Panel Scan:** Hardware camera capture with a horizontal scrollable thumbnail strip allowing officers to preview and remove packaging panels before submitting to `/api/v1/scan-sku`.
  - **Single Panel Scan:** Fast single-photo capture for targeted checks via `/api/v1/scan`.
  - **Server Path Scan:** Direct execution of local server filesystem paths and directories via `/api/v1/scan-path` and `/api/v1/scan-product-path`.

### Phase 5: Inspection Repository & Evidence Assets
- Built `app/(tabs)/inspections.tsx` connecting to `/api/v1/inspections` with debounced search, risk tier filter pills, and pagination.
- Built `app/evidence.tsx` connecting to `/api/v1/evidence/:id/:panel` for full-screen photo evidence inspection.

### Phase 6: Inspection Report UI & Readability Overhaul
- Upgraded `app/result.tsx` with high-legibility typography, generous line heights (`19–22px`), and WCAG 2.1 AA compliant contrast.
- Added visual compliance percentage progress bar.
- Implemented interactive filter tabs (`All`, `Violations`, `Pass`) for rule evaluations.
- Added highlighted "Detected OCR Text" quote boxes in monospace font showing exact matched package text.
- Added Jan Vishwas Act compounding liability highlight box.
- Added collapsible drawer for raw OCR bounding box inspection.

### Phase 7: Mobile In-App Document Viewers (CSV & Notice)
- Resolved the mobile file opening challenge on Expo Go:
  - Built `app/csv-viewer.tsx`: Renders a bidirectional scrollable spreadsheet grid with statutory totals and a **"Share / Save CSV"** button.
  - Built `app/pdf-viewer.tsx`: Renders an official print-ready Directorate of Legal Metrology Show-Cause Notice citing Section 36(1) with a **"Share / Save Notice"** button.
  - Built `src/utils/formatters.ts: generateCsvContent`: Implemented RFC 4180 compliant CSV serialization directly on the client, ensuring 100% functionality even in stateless backend mode.

### Phase 8: Dynamic Host IP Auto-Discovery
- Solved the mobile hotspot subnet hopping paradox:
  - Integrated `Constants.expoConfig?.hostUri` in `AuthContext.tsx`.
  - The mobile app dynamically extracts the laptop's live IP address from the Metro bundler connection.
  - Automatically migrates stale cached IPs in `AsyncStorage`, guaranteeing seamless connectivity across varying Wi-Fi networks and phone hotspots with zero manual configuration.

### Phase 9: Premature Timeout Elimination
- Diagnosed and resolved the 12-second request timeout issue:
  - Removed artificial `AbortController` timers from `ApiClient.request`.
  - Restored patient, rock-solid native `fetch()` logic accommodating the 20–35 second CPU ONNX inference time required for high-resolution packaging scans.

### Phase 10: Codebase Purge & Boilerplate Removal
- Safely purged all unused Expo starter template files (`explore.tsx`, `modal.tsx`, `hello-wave.tsx`, `parallax-scroll-view.tsx`, `external-link.tsx`, `themed-text.tsx`, `themed-view.tsx`, `haptic-tab.tsx`, `collapsible.tsx`, `reset-project.js`).
- Verified zero broken imports and clean `npx tsc --noEmit` compilation (0 errors).
