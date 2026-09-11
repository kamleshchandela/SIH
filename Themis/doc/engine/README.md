# PARAKH — Automated Legal Metrology (Packaged Commodities) Compliance Engine

> **High-performance, memory-safe, CPU-vectorized compliance inspection engine developed for the Ministry of Consumer Affairs, Food & Public Distribution (SIH Problem Statement 26034).**

---

## Documentation Index

| Chapter | Document | Description |
|---|---|---|
| **01** | [**Problem Statement & Regulatory Framework**](file:///home/arch/Projects/backbone/doc/engine/01_PROBLEM_STATEMENT_AND_REGULATORY_FRAMEWORK.md) | In-depth analysis of SIH 26034, the portal statutory documents, LMPC 2011 Rules, 2021 Amendments, and Jan Vishwas Act compounding. |
| **02** | [**Technology Stack & Language Comparison**](file:///home/arch/Projects/backbone/doc/engine/02_LANGUAGE_AND_ARCHITECTURE_EVALUATION.md) | Technical comparison of **Rust vs Go vs C++ vs Python vs Zig** across memory safety, SIMD vectorization, ONNX C-API efficiency, and why Rust was selected. |
| **03** | [**Dataset Acquisition & Ground Truth**](file:///home/arch/Projects/backbone/doc/engine/03_DATASET_ACQUISITION_AND_GROUND_TRUTH.md) | Details of the real-world 199 packaging image dataset across 50 Indian products extracted via Open Food Facts India. |
| **04** | [**PARAKH System Architecture & Pipeline**](file:///home/arch/Projects/backbone/doc/engine/04_THEMIS_SYSTEM_ARCHITECTURE_AND_PIPELINE.md) | Detailed specifications of DBNet detection, PP-OCRv4 recognition, LMPC Rule Engine, Axum REST API, and PostgreSQL schema. |
| **05** | [**Changelog & Complete File Manifest**](file:///home/arch/Projects/backbone/doc/engine/05_CHANGELOG_AND_FILE_MANIFEST.md) | Full chronological engineering changelog and absolute path manifest of all created project files. |
| **06** | [**Empirical Audit Benchmarks & Severity Tiering**](file:///home/arch/Projects/backbone/doc/engine/06_EMPIRICAL_AUDIT_BENCHMARKS_AND_SEVERITY_TIERING.md) | 50-product benchmark results, cross-panel evidence case studies, 5-tier statutory risk framework, and native Rust batch engine. |
| **07** | [**Performance Optimization & Pipeline Pooling**](file:///home/arch/Projects/backbone/doc/engine/07_PERFORMANCE_OPTIMIZATION_AND_PIPELINE_POOLING.md) | Technical post-mortem on throughput regression, root cause analysis (ONNX reloads & thread oversubscription), and channel-based warm pipeline pool architecture. |
| **08** | [**Packaging Ambiguities & Edge-Case Taxonomy**](file:///home/arch/Projects/backbone/doc/engine/08_REAL_WORLD_PACKAGING_AMBIGUITIES_AND_EDGE_CASE_TAXONOMY.md) | The definitive guide to real-world packaging variations, the "Brand vs Legal Entity" paradox, missing evidence panels, and the winning SIH 26034 defense strategy. |
| **09** | [**Empirical OCR Failure Modes & Engine Optimization**](file:///home/arch/Projects/backbone/doc/engine/09_EMPIRICAL_OCR_FAILURE_MODES_AND_ENGINE_OPTIMIZATION_ROADMAP.md) | Empirical analysis of real smartphone packaging scans (Yippie, Dishwasher, Oats), diagnosing the 7 statutory failure modes of computer vision on FMCG commodities, and the 6-part optimization roadmap. |
| **10** | [**Mobile Edge Performance, INT8 Quantization & Hybrid Cascade**](file:///home/arch/Projects/backbone/doc/engine/10_MOBILE_EDGE_PERFORMANCE_QUANTIZATION_AND_HYBRID_CASCADE.md) | In-depth engineering specification of INT8 quantization (74.7% size drop), on-device pre-filtering, Android NNAPI acceleration, and confidence-cascaded Gemini fallback. |
| **11** | [**Backend Compliance Fixes: Orientation, Nutrition, Scoring & Performance**](file:///home/arch/Projects/backbone/doc/engine/11_BACKEND_FIXES_ORIENTATION_NUTRITION_SCORING_AND_PERFORMANCE.md) | Post-audit fix log: quality-gated 90°/270°/180° orientation rescue, nutrition-penalty quantity ranking, N/A-free scoring, threading/probe budgets, with before/after benchmarks and known remaining issues. |
| **12** | [**Flutter Desktop GUI & Multimodal Inspection Interface**](file:///home/arch/Projects/backbone/doc/engine/12_FLUTTER_DESKTOP_GUI_AND_MULTIMODAL_INSPECTION_INTERFACE.md) | Native desktop client architecture, Apple minimalist monochrome design system, 3-tab inspection workflow, multi-panel canvas controls, and live dev telemetry. |
| **13** | [**Deterministic Last-Mile: MRP, Email, Date & Bare-m Guard**](file:///home/arch/Projects/backbone/doc/engine/13_DETERMINISTIC_LAST_MILE_MRP_EMAIL_DATE_AND_BARE_M_GUARD.md) | Ranked MRP selection, split-email stitching, packing-date preference, deterministic eval mode, phantom-quantity guard; training targeting guide (what to / not to train) with live benchmarks. |

---

## Quickstart & CLI Reference Guide

All commands can be executed directly from the project root (`/home/arch/Projects/backbone`).

### 1. Scan a Single Packaging Panel
To inspect a single packaging image (e.g. ingredient table, back panel, MRP print):
```bash
./themis/target/release/themis --scan dataset/real_products/7622201756697_Oreo/panel_raw_3.jpg
```
- Automatically runs PP-OCRv4 server-grade detection (`1280px`, `threshold: 0.15`) and English recognition.
- Outputs detailed compliance evaluation, missing declarations, statutory penalties, and extracted OCR tokens.

---

### 2. Manually Pool Multiple Packaging Panels
If packaging panels are stored separately, pass multiple image paths to `--scan`. The engine pools all text tokens across all panels into a single unified SKU evaluation:
```bash
./themis/target/release/themis --scan \
  dataset/real_products/7622201756697_Oreo/front.jpg \
  dataset/real_products/7622201756697_Oreo/panel_raw_1.jpg \
  dataset/real_products/7622201756697_Oreo/panel_raw_2.jpg \
  dataset/real_products/7622201756697_Oreo/panel_raw_3.jpg
```

---

### 3. Inspect an Entire Product Directory (`--scan-product`)
Point `--scan-product` to any product folder containing packaging panel images:
```bash
./themis/target/release/themis --scan-product dataset/real_products/8901058000269_Maggi
```
- Automatically discovers all panel images (`front.jpg`, `panel_raw_1.jpg`, etc.).
- Evaluates LMPC Rule 6 declarations across the pooled package.
- Displays panel-by-panel evidence mapping and calculates Jan Vishwas compounding liability.

---

### 4. Export Inspection in Machine-Readable JSON (`--json`)
Append `--json` to any scan command to receive structured JSON output for programmatic integration or pipeline ingestion:
```bash
./themis/target/release/themis --scan-product dataset/real_products/8901058000269_Maggi --json
```

---

### 5. Run Native High-Performance Batch Audit (`--batch`)
To audit all product SKUs across the dataset using multi-threaded CPU pipeline pooling:
```bash
./themis/target/release/themis --batch dataset/real_products --profile 5/6
```
- Utilizes **23 parallel worker threads** (~83% host CPU utilization) with pre-warmed ONNX pipeline pooling.
- Classifies each SKU into statutory risk tiers (`COMPLIANT`, `LOW RISK`, `MODERATE RISK`, `HIGH RISK`, `CRITICAL`).
- Displays a live color-coded progress dashboard and writes the full audit report to `dataset/batch_scan_results.json`.

#### Concurrency Profile Options:
- `--profile 5/6` : ~83% of CPU cores (recommended for batch throughput)
- `--profile full`: 100% of CPU cores (maximum throughput)
- `--profile 3/4` : ~75% of CPU cores
- `--profile 1/2` : ~50% of CPU cores (balanced background execution)
- `--profile single`: 1 worker thread (strictly sequential debugging)
- `--profile custom:<N>`: Exact thread count (e.g. `--profile custom:8`)
*(Omitting `--profile` prompts an interactive terminal selector).*

#### Custom Output Path:
```bash
./themis/target/release/themis --batch dataset/real_products --profile 5/6 --out-json my_custom_audit.json
```

---

### 6. Run REST API Daemon Server Mode (`--port`)
```bash
./themis/target/release/themis --port 8080
```
- **Health check:**
  ```bash
  curl -s http://localhost:8080/api/v1/health | jq .
  ```
- **Inspect packaging file path:**
  ```bash
  curl -s -X POST http://localhost:8080/api/v1/scan-path \
    -H "Content-Type: application/json" \
    -d '{"file_path":"/home/arch/Projects/backbone/dataset/real_products/8901058000269_Maggi/panel_raw_2.jpg"}' | jq .
  ```

---

### 7. Important Runtime Notes

1. **Automatic Model Path Resolution**:
   - The engine automatically resolves models from `themis/models` or `models/`.
   - To specify a custom model directory, use `--models-dir <path>`.
2. **High-Accuracy Server Detection**:
   - PARAKH automatically prioritizes the high-capacity `ppocr_det_server.onnx` (109 MB) model.
   - If missing, it smoothly falls back to the lightweight `ppocr_det.onnx` (2.4 MB).
3. **Debug Logging**:
   - Run with `RUST_LOG=themis=debug` to print bounding box coordinates, connected component counts, and raw token decoding traces:
     ```bash
     RUST_LOG=themis=debug ./themis/target/release/themis --scan dataset/real_products/7622201756697_Oreo/panel_raw_3.jpg
     ```
