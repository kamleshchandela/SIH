# 05 — Changelog & Complete File Manifest

## 1. Chronological Project Changelog

### Phase 1: Problem Statement Deconstruction & Regulatory Audit
- **Analyzed:** [`sih26034.txt`](file:///home/arch/Projects/backbone/sih26034.txt) (Ministry of Consumer Affairs problem statement).
- **Analyzed:** [`neo/screenshot/dataset_geenarl.png`](file:///home/arch/Projects/backbone/neo/screenshot/dataset_geenarl.png) and [`neo/screenshot/screenshot.txt`](file:///home/arch/Projects/backbone/neo/screenshot/screenshot.txt).
- **Finding:** Determined that the portal link (`https://consumeraffairs.gov.in/pages/legal-metrology-act`) was not a machine learning image dataset, but the government gazette legal rulebook.
- **Filtered Statutes:** Identified that 90% of portal links were irrelevant civil service/calibration rules (PBMSEC, Recruitment Rules, Allocation of Business, Weighbridge rules), isolating the **3 critical legal statutes**:
  1. *The Legal Metrology (Packaged Commodities) Rules, 2011* (Core Rulebook)
  2. *The Legal Metrology (Packaged Commodities) Amendment Rules, 2021* (Unit Sale Price & Country of Origin)
  3. *Jan Vishwas (Amendment of Provisions) Act, 2023 / 2026* (Decriminalization & Compounding Fines under Section 49)

### Phase 2: Empirical Dataset Extraction Pipeline
- **Created:** [`scripts/fetch_product_dataset.py`](file:///home/arch/Projects/backbone/scripts/fetch_product_dataset.py) using pure Python standard library (`urllib.request`, `json`, `concurrent.futures`, `pathlib`).
- **Executed:** Downloaded **199 real FMCG packaging images across 50 Indian products** (Parle-G, Maggi, Kissan, Amul, Tata Salt, Lays, Kurkure, Cadbury, Rooh Afza, Storia, etc.) into [`dataset/real_products/`](file:///home/arch/Projects/backbone/dataset/real_products/).
- **Downloaded:** Downloaded the 3 essential legal rulebook PDFs into [`dataset/rules/`](file:///home/arch/Projects/backbone/dataset/rules/).

### Phase 3: Systems Architecture & Engine Implementation
- **Evaluated:** Evaluated Rust vs Python vs Go vs C++ vs Zig across SIMD vectorization, memory safety, tail latency, and ONNX Runtime C-API efficiency. Selected **Rust**.
- **Created:** `themis/` backend project:
  - [`themis/Cargo.toml`](file:///home/arch/Projects/backbone/themis/Cargo.toml): Configured with `axum 0.8`, `tokio`, `ort 2.0-rc`, `ndarray 0.17`, `image 0.25`, `serde`, `chrono`, `regex`, `clap`.
  - [`themis/models/`](file:///home/arch/Projects/backbone/themis/models/): Copied pre-trained ONNX models (`ppocr_det.onnx`, `en_ppocr_v4_rec.onnx`, `ppocr_cls.onnx`, `en_dict.txt` — ~11 MB total).
  - [`themis/src/compliance/types.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/types.rs): Defined LMPC legal clauses, requirement evaluations, bounding box structures, and statutory compounding penalty structs.
  - [`themis/src/compliance/rules.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/rules.rs): Implemented deterministic evaluation logic for Rule 6(1)(a)-(g), Rule 13 SI units, and Jan Vishwas Act compounding calculations.
  - [`themis/src/ocr/detector.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/detector.rs): Implemented DBNet text detection with 4-neighborhood connected components polygon bounding box extraction.
  - [`themis/src/ocr/recognizer.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/recognizer.rs): Implemented PP-OCRv4 text recognition with CTC greedy decoding.
  - [`themis/src/ocr/pipeline.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/pipeline.rs): Orchestrated end-to-end CPU image-to-token inference.
  - [`themis/src/api/routes.rs`](file:///home/arch/Projects/backbone/themis/src/api/routes.rs): Created Axum REST API endpoints (`/api/v1/health`, `/api/v1/scan`, `/api/v1/scan-path`).
  - [`themis/src/main.rs`](file:///home/arch/Projects/backbone/themis/src/main.rs): Configured CLI runner with one-shot scan (`--scan`), JSON output (`--json`), and HTTP daemon mode.

### Phase 4: Compilation, Tuning & Interactive Batch Scanner
- **Compiled:** Built optimized release binary (`cargo build --release`). Verified **zero compiler warnings and zero errors**.
- **Verified:** Ran one-shot scan on sample packaging (`Kissan panel_raw_1.jpg`), delivering full OCR and compliance assessment in **~140 ms on CPU** with **0 MB VRAM / 0% GPU load**.
- **Created:** [`scripts/batch_scan.py`](file:///home/arch/Projects/backbone/scripts/batch_scan.py): Interactive batch CLI scanner featuring recursive image discovery, live colored terminal table, statistical breakdown, top violation frequency graphs, and JSON export.
- **Created:** Comprehensive documentation suite in [`doc/`](file:///home/arch/Projects/backbone/doc/).

### Phase 5: Multi-Panel SKU Pooling & Robust OCR Pre-Processing
- **Architecture Upgrade (Multi-Image SKU Pooling):**
  - Upgraded [`themis/src/main.rs`](file:///home/arch/Projects/backbone/themis/src/main.rs) with `--scan-product <dir>` and multi-argument `--scan <p1> <p2>...`.
  - Aggregates all 4 packaging panel images (`front.jpg`, `panel_raw_1.jpg`, `panel_raw_2.jpg`, `panel_raw_3.jpg`) into a single pooled token array representing the complete physical package.
  - Tagged every text token with its exact `source_image` packaging panel to provide legal evidence tracking.
- **LMPC Rule Engine Refinement & Whitespace Resilience ([`themis/src/compliance/rules.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/rules.rs)):**
  - **Merged-Word Resilience:** Tuned regexes to handle zero-space tokens commonly produced by DBNet/PP-OCR (`MADEININDIA`, `INCL.OFALLTAXES`, `NETWT`, `NETQUANTITY`, `NETWEIGHT`, `MFDBY`, `MARKETEDBY`, `REGDOFFICE`).
  - **Nutrition Table Disambiguation:** Implemented negative lookahead filter (`RE_NUTRITION_IGNORE`) to prevent nutritional carbohydrate, protein, and fat values (e.g. `Carbohydrate 60.4g`) from triggering false positive Net Quantity matches.
  - **Strict Manufacturing Date Validation:** Enforced explicit English month names (`Jan` through `Dec`) to eradicate false date matches on address words (e.g., `BYADDRESS 1800`).
  - **Sliding-Window Token Merging (`find_first_match`):** Implemented multi-token window evaluation (window sizes 1, 2, and 3) across consecutive tokens on the same packaging panel, correctly associating multi-word legal declarations (e.g. `MADE IN` + `INDIA`, `MFD BY` + `COMPANY`) with their source panel and merged bounding box.
- **Empirical Batch Evaluation:** Executed multi-threaded audit across 50 complete Indian FMCG products (199 images) using 23 parallel CPU worker threads (5/6 profile) in ~16 seconds (~320 ms per complete product SKU). Verified that multi-panel products (e.g., Thums Up, Maggi, Masala Munch) successfully resolve declarations distributed across distinct physical panels.

### Phase 6: Embedded Native Rust Batch Engine & Statutory Risk Tiers
- **Embedded Batch Engine ([`themis/src/batch.rs`](file:///home/arch/Projects/backbone/themis/src/batch.rs)):**
  - Integrated full multi-threaded batch scanning directly into the native compiled Rust binary, replacing the external Python script.
  - Implemented interactive hardware concurrency selector querying host logical CPU cores (28 cores).
  - Configured bounded `tokio::sync::Semaphore` with `spawn_blocking` task isolation, achieving **3.1 targets/sec** on CPU.
- **Statutory Severity Risk Tiers ([`themis/src/compliance/types.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/types.rs)):**
  - Eliminated the misleading binary `FAIL` status in favor of 5 regulatory risk tiers: `COMPLIANT`, `LOW RISK (MINOR)`, `MODERATE RISK`, `HIGH RISK (MAJOR)`, and `CRITICAL (SEVERE)`.
  - Added ANSI color-coded terminal badges and structured JSON audit serialization.
- **Slice Sort Total-Order Bug Fix ([`themis/src/ocr/detector.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/detector.rs)):**
  - Fixed a mathematical non-transitivity bug in `boxes.sort_by` by implementing line-quantized sorting (`(a.y / 16).cmp(...)`), ensuring zero panics across arbitrary image layouts.
- **Smart Models Path Resolver ([`themis/src/main.rs`](file:///home/arch/Projects/backbone/themis/src/main.rs)):**
  - Automatically resolves ONNX model artifacts without requiring manual `--models-dir` CLI arguments.
- **Created:** [`doc/06_EMPIRICAL_AUDIT_BENCHMARKS_AND_SEVERITY_TIERING.md`](file:///home/arch/Projects/backbone/doc/06_EMPIRICAL_AUDIT_BENCHMARKS_AND_SEVERITY_TIERING.md) documenting empirical 50-product benchmark results, cross-panel case studies, and e-commerce compliance findings.

### Phase 7: Performance Optimization, Warm Pipeline Pooling & Concurrency Realignment
- **Diagnosed Throughput Discrepancy:**
  - Evaluated the throughput gap between single-panel scans (~14–17 images/sec) and embedded multi-panel SKU pooling (~3.1–3.5 targets/sec).
  - Clarified unit semantics: 3.2 product targets/sec equates to ~12.8 individual packaging panels/sec.
- **Root Cause Analysis (Dual Concurrency Bottlenecks):**
  - **Bottleneck 1 (Model Re-Instantiation):** Identified that `themis/src/batch.rs` called `OcrPipeline::new()` inside every spawned SKU task, triggering 50 redundant disk I/O reads and 100 ONNX session graph re-compilations.
  - **Bottleneck 2 (Thread Oversubscription):** Identified that `with_intra_threads(4)` in `TextDetector` and `TextRecognizer` spawned 92 active ONNX compute threads across 23 workers, causing severe L1/L2 cache evictions and OS scheduler context switching.
- **Architectural Solution (Channel-Based Object Pool):**
  - Refactored `themis/src/batch.rs` to pre-warm exactly `W` `OcrPipeline` instances once at startup.
  - Implemented a lock-free, zero-allocation asynchronous object pool using a bounded `tokio::sync::mpsc::channel::<OcrPipeline>(W)`.
  - The channel's `recv().await` acts as a natural backpressure semaphore, ensuring zero disk I/O during execution and zero heap lock contention.
- **Intra-Op Concurrency Tuning:**
  - Realigned `with_intra_threads` to `1` in both [`themis/src/ocr/detector.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/detector.rs) and [`themis/src/ocr/recognizer.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/recognizer.rs).
  - Shifted concurrency model from inefficient tensor micro-parallelism to task-level macro-parallelism (23 independent products simultaneously vectorizing across 23 CPU cores).
- **Compilation & Verification:**
  - Built optimized release binary (`themis/target/release/themis`) with zero warnings and zero errors.
### Phase 8: High-Accuracy Server Detection, High-Resolution Inference & CTC Space Fix
- **PP-OCRv4 Server Detection Model Integration ([`themis/src/ocr/pipeline.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/pipeline.rs)):**
  - Downloaded and deployed `ppocr_det_server.onnx` (109 MB, ~45× larger capacity than the 2.4 MB mobile detector).
  - Updated `themis/src/ocr/pipeline.rs` to automatically prefer `ppocr_det_server.onnx` with automatic fallback to `ppocr_det.onnx`.
- **High-Resolution Inference & Sensitive Binarization ([`themis/src/ocr/detector.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/detector.rs)):**
  - Doubled detector `target_size` from 640 to **1280** (4× pixel area) and raised clamp limit from 960 to **1920**.
  - Lowered binarization threshold from 0.30 to **0.15** to capture small-font, low-contrast ingredient lists and allergen text.
  - Verification: Token extraction count on dense packaging (`Oreo panel_raw_3.jpg`) jumped from **7 tokens to 28 tokens**, and multi-panel SKU extraction jumped from **15 tokens to 124 tokens**.
- **CTC Space Character Decoding & Aspect Ratio Fix ([`themis/src/ocr/recognizer.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/recognizer.rs)):**
  - **Root Cause:** PaddleOCR's `en_PP-OCRv4_rec` model outputs 97 classes (class 0 = blank, classes 1..95 = dictionary characters, class 96 = `' '` space added by `use_space_char = true`). Because `en_dict.txt` had 95 items, class 96 mapped to `char_idx = 95` which exceeded `charset.len()`, silently dropping spaces between words (producing `MaidaSugar,`, `FractionatedFat,`, `MayContainMilka`).
  - **Fix:** Expanded `charset` to 96 entries (`charset.resize(96, ' ')`), properly decoding inter-word whitespace across all tokens (`Maida Sugar,`, `Fractionated Fat,`, `May Contain Milk a`).
### Phase 9: Real-World Packaging Edge-Case Taxonomy & SIH Defense Architecture
- **Packaging Edge-Case Forensic Investigation:**
  - Conducted in-depth forensic breakdown of real-world FMCG packaging failures (exemplified by `7622201756697_Oreo`).
  - Formulated the 6-factor packaging ambiguity taxonomy:
    1. *Brand Name vs Legal Corporate Entity Paradox* (Rule 6(1)(a) mandates registered corporate entity + physical PIN-code address, rejecting floating brand trademarks like "Cadbury").
    2. *Dynamic Continuous Inkjet (CIJ) Stamping vs Static Flexo Printing* (MRP, Batch, Mfg Date stamped on back crimp fin-seals at 30–60 DPI).
    3. *E-Commerce Evidence Gap* (E-commerce and crowdsourced platforms routinely omit back crimp panels, constituting actionable statutory violations under the 2021 LMPC E-Commerce Amendments).
    4. *Artistic / Calligraphic Typography* (Proprietary scripts like Cadbury or Coca-Cola designed as visual marks rather than standardized machine text).
    5. *Nutritional Attribute Collision Filtering* (Preventing `Carbohydrate 71.9g` from false-positive Net Quantity matching via `RE_NUTRITION_IGNORE`).
    6. *Jan Vishwas Compounding Liability Quantification* (Automating exact Section 49 penalty calculations).
- **SIH Evaluator Defense Strategy:**
  - Structured the comprehensive judge Q&A defense demonstrating that failing incomplete evidence dossiers is the legally mandated behavior for regulatory enforcement engines.
- **Created:** [`doc/engine/08_REAL_WORLD_PACKAGING_AMBIGUITIES_AND_EDGE_CASE_TAXONOMY.md`](file:///home/arch/Projects/backbone/doc/engine/08_REAL_WORLD_PACKAGING_AMBIGUITIES_AND_EDGE_CASE_TAXONOMY.md).

### Phase 10: Multi-Panel REST API Endpoints & 100MB Upload Scaling
- **Multi-Panel SKU Endpoints ([`themis/src/api/routes.rs`](file:///home/arch/Projects/backbone/themis/src/api/routes.rs)):**
  - Added `POST /api/v1/scan-sku` handling `multipart/form-data` uploads with multiple packaging panels (`front`, `panel_raw_1`, `panel_raw_2`, `crimp`, etc.) and optional `product_name`.
  - Added `POST /api/v1/scan-product-path` accepting JSON payloads with product directory paths or explicit file path lists.
  - Returns unified `ComplianceReport` JSON with individual panel provenance tags (`source_panel`).
- **High-Resolution Upload Body Limit ([`themis/src/main.rs`](file:///home/arch/Projects/backbone/themis/src/main.rs)):**
  - Configured `DefaultBodyLimit::max(100 * 1024 * 1024)` on the Axum router to support multi-megabyte high-resolution packaging image uploads.
- **Verification:** Successfully tested both endpoints against live packaging images (Amul Butter and Maggi) yielding accurate multi-panel compliance reports.

### Phase 11: PostgreSQL Persistence Layer, Audit History & Cross-Platform Handoff
- **PostgreSQL Persistence Engine ([`themis/src/db/repo.rs`](file:///home/arch/Projects/backbone/themis/src/db/repo.rs)):**
  - Added `sqlx` (v0.8 with `postgres`, `runtime-tokio`, `chrono`, `json`) to `Cargo.toml`.
  - Implemented `init_db` for automatic DDL table creation and GIN/B-tree indexing on `product_inspections`.
  - Wired auto-save on all inspection endpoints (`/scan`, `/scan-path`, `/scan-sku`, `/scan-product-path`).
  - Added historical query endpoints: `GET /api/v1/inspections` (paginated with filters), `GET /api/v1/inspections/{id}`, and `GET /api/v1/stats`.
- **Created:** [`doc/extra/WINDOWS_DEPENDENCY_AND_SETUP_GUIDE.md`](file:///home/arch/Projects/backbone/doc/extra/WINDOWS_DEPENDENCY_AND_SETUP_GUIDE.md) with winget commands and official links.
- **Created:** [`doc/extra/FRONTEND_VS_BACKEND_RESPONSIBILITIES.md`](file:///home/arch/Projects/backbone/doc/extra/FRONTEND_VS_BACKEND_RESPONSIBILITIES.md) specifying the data contract and client-side SheetJS XLSX / statutory notice PDF generator guides.

### Phase 12: Rule 7 Schedule II Numeral Height & Laplacian Blur Detection Engine
- **Rule 7 & Schedule II Numeral Height Engine ([`themis/src/compliance/rules.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/rules.rs)):**
  - Implemented statutory height validation matching net quantity numeral bounding boxes against package surface area ratios.
  - Automatically verifies minimum font height thresholds (e.g. area $\ge 500\text{ cm}^2 \implies \text{height} \ge 4.0\text{ mm}$).
- **In-Memory Laplacian Variance Blur Gate ([`themis/src/compliance/quality.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/quality.rs)):**
  - Convolved $3 \times 3$ discrete Laplacian kernel across panel pixel luminance to compute variance of the Laplacian ($\sigma^2$).
  - Classified panel sharpness into `SHARP` ($\sigma^2 \ge 100.0$), `ACCEPTABLE` ($50.0 \le \sigma^2 < 100.0$), and `BLURRY` ($\sigma^2 < 50.0$), logging statutory warnings on degraded evidence.

### Phase 13: Role-Based Access Control (RBAC), Evidence Photo Serving, and Direct PDF/CSV Export
- **RBAC Auth Subsystem ([`themis/src/auth/mod.rs`](file:///home/arch/Projects/backbone/themis/src/auth/mod.rs)):**
  - Implemented HMAC-SHA256 JWT tokens with role separation (`Inspector` vs `EnforcementAdmin`).
  - Added role-based authorization middleware protecting administrative and export routes.
- **Evidence Photograph Storage & Static Serving ([`themis/src/api/routes.rs`](file:///home/arch/Projects/backbone/themis/src/api/routes.rs)):**
  - Automatically stores uploaded packaging panels in `themis/evidence/{inspection_id}/`.
  - Exposed `/api/v1/evidence/{inspection_id}/{panel_filename}` with content negotiation for secure visual audit.
- **Backend Direct PDF & CSV Export Engine ([`themis/src/export/mod.rs`](file:///home/arch/Projects/backbone/themis/src/export/mod.rs)):**
  - Added direct statutory inspection notice PDF generation (`GET /api/v1/inspections/{id}/export/pdf`).
  - Added CSV tabular audit trail export (`GET /api/v1/inspections/{id}/export/csv`).

### Phase 14: Auto-Orientation Normalizer, Reading-Order Line Clustering, and Robust Statutory Parsing
- **Automated 90° Orientation Normalizer ([`themis/src/ocr/pipeline.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/pipeline.rs)):**
  - Integrated dynamic bounding box aspect ratio heuristic: if $> 35\%$ of detected boxes have $\text{height} > 1.4 \times \text{width}$ (sideways smartphone capture), automatically rotates the image $90^\circ$ and re-runs DBNet for upright OCR.
- **Transitive Reading-Order Line Clustering ([`themis/src/compliance/rules.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/rules.rs)):**
  - Implemented `sort_tokens_reading_order` grouping tokens that share vertical overlap ($(\text{overlap}) \times 4 \ge \text{height}$) and sorting left-to-right, eliminating DBNet contour shuffle.
- **Multi-Column Layout Linearization ([`themis/src/compliance/rules.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/rules.rs)):**
  - Detects multi-column packaging layouts (horizontal span $> 800\text{px}$) and separates left vs. right columns, preventing text interleaving.
- **2D Spatial Proximity Windowing ([`themis/src/compliance/rules.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/rules.rs)):**
  - Implemented 2D bounding box radius search ($\Delta Y \le 160\text{px}, \Delta X \le 700\text{px}$) to bind detached floating price numerals to the MRP anchor keyword.
- **CIJ Dot-Matrix Hardened Statutory Lexicon ([`themis/src/compliance/rules.rs`](file:///home/arch/Projects/backbone/themis/src/compliance/rules.rs)):**
  - Hardened regexes for `RE_NET_QTY` (`500m` $\to$ `500ml`), `RE_MFG_DATE` (CIJ dot-matrix slashes, `Q` for `0`, `07/28`), `RE_TAX_INCL`, and `RE_PHONE`.

### Phase 15: INT8 Quantization Suite, Micro-Noise Pre-Filtering, Adaptive Contrast & Mobile Cascade
- **INT8 Dynamic Quantization Suite ([`themis/models/`](file:///home/arch/Projects/backbone/themis/models/)):**
  - Performed graph surgery on Paddle2ONNX `Constant` nodes, converting them to initializers.
  - Quantized `ppocr_det_server.onnx` from **108.10 MB down to 27.35 MB** (-74.7%).
  - Quantized mobile detector `ppocr_det.onnx` to **0.76 MB** and recognizer to **2.00 MB** (Total mobile suite: **2.76 MB**).
- **On-Device Micro-Noise Pre-Filtering ([`themis/src/ocr/pipeline.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/pipeline.rs)):**
  - Discarded bounding boxes with $\text{width} < 18\text{px}$ or $\text{height} < 8\text{px}$, eliminating 80% of useless recognition forward passes on cardboard textures.
- **Adaptive Contrast Enhancement ([`themis/src/ocr/pipeline.rs`](file:///home/arch/Projects/backbone/themis/src/ocr/pipeline.rs)):**
  - Implemented `enhance_text_contrast_if_needed` to linearly stretch compressed dynamic ranges ($15 < \text{range} < 140$) on low-contrast patches.
- **Dynamic Model Tier Selection ([`themis/src/main.rs`](file:///home/arch/Projects/backbone/themis/src/main.rs)):**
  - Added `--model-tier` CLI option (`server-int8`, `server`, `mobile-int8`, `mobile`, `auto`).
- **Created:** [`doc/engine/10_MOBILE_EDGE_PERFORMANCE_QUANTIZATION_AND_HYBRID_CASCADE.md`](file:///home/arch/Projects/backbone/doc/engine/10_MOBILE_EDGE_PERFORMANCE_QUANTIZATION_AND_HYBRID_CASCADE.md).

---

## 2. Complete File Manifest

```
/home/arch/Projects/backbone/
├── sih26034.txt                                   # Official SIH Problem Statement text
│
├── dataset/
│   ├── rules/                                     # Statutory Ground Truth Regulations
│   │   ├── LMPC_Rules_2011.pdf                    # Legal Metrology (Packaged Commodities) Rules, 2011
│   │   ├── LMPC_Amendment_2021.pdf                # 2021 Amendment: Unit Sale Price & Country of Origin
│   │   └── Jan_Vishwas_Act.pdf                    # Decriminalization & Compounding Fines (Sec 49)
│   │
│   ├── real_products/                             # 199 high-res images across 50 Indian FMCG products
│   ├── mine/                                      # 13 real smartphone camera packaging test images
│   │   ├── dishwasher/                            # Savemore dishwash liquid bottle
│   │   ├── yippie/                                # Yippie noodles (full image & half image panels)
│   │   ├── oats/                                  # Saffola oats (sideways orientation test case)
│   │   ├── maggie/                                # Maggi noodle packaging panels
│   │   └── random-noodles/                        # Noodle packaging comparative panels
│   │
│   └── batch_scan_results.json                    # Consolidated JSON export from batch inspections
│
├── scripts/
│   ├── fetch_product_dataset.py                   # Parallel Open Food Facts India extraction script
│   └── batch_scan.py                              # Interactive live CLI batch compliance scanner
│
├── themis/                                        # PARAKH Rust Backend Service
│   ├── Cargo.toml                                 # Package configuration & dependencies
│   ├── models/                                    # ONNX Runtime CPU Models
│   │   ├── ppocr_det_server_int8.onnx             # Quantized Server text detector (27.35 MB, high-accuracy)
│   │   ├── ppocr_det_int8.onnx                    # Quantized Mobile text detector (0.76 MB, ultra-fast)
│   │   ├── en_ppocr_v4_rec_int8.onnx              # Quantized Mobile text recognizer (2.00 MB)
│   │   ├── ppocr_det_server.onnx                  # PP-OCRv4 Server text detector (108.10 MB, FP32)
│   │   ├── ppocr_det.onnx                         # DBNet Mobile text detector (2.32 MB, FP32)
│   │   ├── en_ppocr_v4_rec.onnx                   # PP-OCRv4 English text recognizer (7.31 MB, FP32)
│   │   ├── ppocr_cls.onnx                         # Angle orientation classifier (572 KB)
│   │   └── en_dict.txt                            # 96-char vocabulary mapping
│   │
│   └── src/
│       ├── main.rs                                # CLI flags, --model-tier & Axum bootstrap
│       ├── batch.rs                               # Native Rust multi-threaded batch engine & live dashboard
│       ├── auth/                                  # JWT RBAC auth middleware (Inspector vs EnforcementAdmin)
│       ├── export/                                # Direct PDF notice & CSV audit export engines
│       ├── ocr/
│       │   ├── mod.rs                             # Module exports
│       │   ├── detector.rs                        # DBNet inference & line-quantized total order
│       │   ├── recognizer.rs                      # PP-OCRv4 CTC inference & logit decoding
│       │   └── pipeline.rs                        # Auto-orientation, noise filtering & adaptive contrast
│       ├── compliance/
│       │   ├── mod.rs                             # Module exports
│       │   ├── types.rs                           # Statutory enums, RiskTier & report structs
│       │   ├── quality.rs                         # In-memory Laplacian variance sharpness gate
│       │   └── rules.rs                           # Rule 6, Rule 7 font height, 2D windowing, column split
│       ├── db/
│       │   ├── mod.rs                             # Module exports
│       │   └── repo.rs                            # PostgreSQL DDL, auto-persistence, query & stats
│       └── api/
│           ├── mod.rs                             # Module exports
│           └── routes.rs                          # Axum handlers (/scan, /scan-sku, evidence serving, export)
│
└── doc/                                           # Project Documentation Suite
    ├── engine/                                    # Core Engine Technical Documentation
    │   ├── README.md                              # Documentation index & quickstart guide
    │   ├── 01_PROBLEM_STATEMENT_AND_REGULATORY_FRAMEWORK.md
    │   ├── 02_LANGUAGE_AND_ARCHITECTURE_EVALUATION.md
    │   ├── 03_DATASET_ACQUISITION_AND_GROUND_TRUTH.md
    │   ├── 04_THEMIS_SYSTEM_ARCHITECTURE_AND_PIPELINE.md
    │   ├── 05_CHANGELOG_AND_FILE_MANIFEST.md
    │   ├── 06_EMPIRICAL_AUDIT_BENCHMARKS_AND_SEVERITY_TIERING.md
    │   ├── 07_PERFORMANCE_OPTIMIZATION_AND_PIPELINE_POOLING.md
    │   ├── 08_REAL_WORLD_PACKAGING_AMBIGUITIES_AND_EDGE_CASE_TAXONOMY.md
    │   ├── 09_EMPIRICAL_OCR_FAILURE_MODES_AND_ENGINE_OPTIMIZATION_ROADMAP.md
    │   └── 10_MOBILE_EDGE_PERFORMANCE_QUANTIZATION_AND_HYBRID_CASCADE.md
    │
    ├── frontend/                                  # Frontend Specifications & Contracts
    ├── todo/                                      # Engineering Backlog & System Limitations
    │   ├── README.md
    │   └── 01_FRONTEND_HANDOFF_AND_ROADMAP.md     # Full API contracts & e-commerce scraper defense
    │
    └── extra/                                     # Cross-Platform Setup & Inter-Team Guides
        ├── README.md
        ├── WINDOWS_DEPENDENCY_AND_SETUP_GUIDE.md  # Windows 10/11 winget & MSVC setup guide
        └── FRONTEND_VS_BACKEND_RESPONSIBILITIES.md# Responsibilities matrix & client SheetJS/PDF guides
```
