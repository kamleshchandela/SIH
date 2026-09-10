# 04 — Themis System Architecture & Pipeline Specification

## 1. System High-Level Topology

```
   ┌─────────────────────────────────────────────────────────────┐
   │             Packaging Image Input Source                     │
   │  (Physical Camera Scan / E-Commerce Image / Directory Batch) │
   └──────────────────────────────┬──────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              Themis Engine Core (High-Performance Rust)                 │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ 1. Vision & OCR Ingestion Subsystem (ort on CPU)                  │  │
│  │    • Preprocessing: Dynamic resizing (x32) + ImageNet float norm  │  │
│  │    • Detection: DBNet (ppocr_det.onnx) → Probability Heatmap      │  │
│  │    • Bounding Boxes: Connected Components Analysis (4-neighbor)   │  │
│  │    • Recognition: PP-OCRv4 (en_ppocr_v4_rec.onnx) + CTC Decode   │  │
│  └─────────────────────────────────┬─────────────────────────────────┘  │
│                                    │ Extracted Tokens [(x,y,w,h), text] │
│  ┌─────────────────────────────────▼─────────────────────────────────┐  │
│  │ 2. LMPC 2011 Statutory Rule Engine                                │  │
│  │    • Regex pattern matching against LMPC clauses                  │  │
│  │    • Rule 6(1)(a): Manufacturer name, address & PIN code check    │  │
│  │    • Rule 6(1)(c) & Rule 13: SI unit whitelist & illegal suffixes │  │
│  │    • Rule 6(1)(e): MRP presence & 'incl. of all taxes' validation │  │
│  │    • Rule 6(1)(d): Month & Year manufacturing date extraction     │  │
│  │    • Rule 6(1)(da): Country of Origin declaration validation      │  │
│  │    • Rule 6(1)(f): Unit Sale Price logic (triggered if >1kg/1L)   │  │
│  │    • Rule 6(1)(g): Consumer grievance phone & email validation   │  │
│  │    • Jan Vishwas Act: Compounding monetary liability calculation  │  │
│  └─────────────────────────────────┬─────────────────────────────────┘  │
│                                    │ ComplianceReport JSON              │
│  ┌─────────────────────────────────▼─────────────────────────────────┐  │
│  │ 3. Interfaces & Persistence                                       │  │
│  │    • CLI Runner: One-shot scan (--scan) + JSON exporter (--json)  │  │
│  │    • REST Web API: Axum HTTP daemon on port 8080                  │  │
│  │    • Database: PostgreSQL schema with JSONB GIN indexing          │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. OCR Subsystem: DBNet Detection & PP-OCRv4 Recognition

### 1. DBNet Text Detection (`src/ocr/detector.rs`)
- **Model:** `ppocr_det.onnx` (2.4 MB)
- **Input Constraints:** Dynamic input `[1, 3, H, W]` where $H, W$ are multiples of 32, scaled to a maximum dimension of 640 or 960 pixels.
- **Normalization:**
  $$\text{Normalized} = \frac{\frac{\text{Pixel}}{255.0} - \text{Mean}}{\text{Std}}$$
  where $\text{Mean} = [0.485, 0.456, 0.406]$ and $\text{Std} = [0.229, 0.224, 0.225]$.
- **Post-Processing (Connected Components Segmentation):**
  The model outputs a probability map $[1, 1, H, W]$. Pixels above threshold $\tau = 0.30$ are binarized. Connected components are discovered using a 4-neighborhood BFS queue. Bounding boxes are filtered by minimum area ($\ge 16\text{ px}$) and scaled back to original image dimensions with 10% horizontal and 15% vertical padding to capture ascenders and descenders.

### 2. PP-OCRv4 Text Recognition (`src/ocr/recognizer.rs`)
- **Model:** `en_ppocr_v4_rec.onnx` (7.4 MB)
- **Vocabulary:** 94 alphanumeric characters + symbols (`0-9`, `a-z`, `A-Z`, punctuation, `₹`, `@`, `/`).
- **Input Tensor:** $[1, 3, 48, W]$ where height is fixed at $48\text{ px}$ and width scales dynamically according to crop aspect ratio ($W \in [64, 640]$).
- **Greedy CTC Decoding:**
  The output tensor has shape $[1, \text{seq\_len}, 97]$. CTC blank is at index 0. Consecutive repeating non-blank tokens are collapsed, producing the final text string.

### 3. CPU Execution Optimization
- Configured with `GraphOptimizationLevel::Level3` and 4 intra-op execution threads in ONNX Runtime.
- Measured execution latency on multi-core CPU: **~140 ms – 160 ms per packaging image**, requiring **0 MB of VRAM**.

---

## 3. LMPC 2011 Compliance Rule Engine (`src/compliance/rules.rs`)

The compliance engine evaluates the extracted token graph against statutory clauses:

| Legal Provision | Evaluated Conditions | Pass / Fail Criteria |
|---|---|---|
| **Rule 6(1)(a)** | Matches `Mfg by`, `Marketed by`, `Packed by` + 6-digit postal PIN (`[1-9][0-9]{2}\s?[0-9]{3}`) | **PASS:** Both keyword and PIN found.<br>**WARN:** Only one found.<br>**FAIL:** Missing completely. |
| **Rule 6(1)(c) & Rule 13** | Matches nominal quantity + unit symbol. Whitelist: `g`, `kg`, `ml`, `l`, `m`, `cm`, `mm`, `N`, `units`. | **PASS:** Standard SI symbol.<br>**FAIL:** Illegal unit detected (`gm`, `gms`, `ml.`, `kgs.`, `Gms`). |
| **Rule 6(1)(e)** | Matches `MRP` / `Maximum Retail Price` + price value + `inclusive of all taxes`. | **PASS:** Price and tax phrase present.<br>**WARN:** Price found but tax phrase absent.<br>**FAIL:** No MRP. |
| **Rule 6(1)(d)** | Matches `MFG`, `PKD`, `Packed` + date format (`MM/YYYY` or `Month YYYY`). | **PASS:** Valid packing date format found.<br>**FAIL:** Packing date omitted. |
| **Rule 6(1)(da)** | Matches `Country of Origin`, `Made in`, or domestic provenance `India`. | **PASS:** Explicit origin stated.<br>**WARN:** Inferred from local manufacturer.<br>**FAIL:** Missing. |
| **Rule 6(1)(f)** | Condition: Package Net Weight $\ge 1\text{ kg}$ or $\ge 1\text{ L}$. Matches `Unit Sale Price` or `USP ₹ XX/g`. | **PASS:** USP declared on bulk pack.<br>**FAIL:** Pack $\ge 1\text{kg/1L}$ without USP.<br>**N/A:** Exempt if pack $< 1\text{kg/1L}$. |
| **Rule 6(1)(g)** | Matches grievance redressal email (`[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+`) and telephone (`1800-XXX-XXXX` or 10-digit). | **PASS:** Both phone and email present.<br>**WARN:** Only one present.<br>**FAIL:** Grievance channels absent. |
| **Jan Vishwas Act** | Compounding liability under Section 36(1) read with Section 49. | **COMPUTATION:** ₹25,000 INR compounding fine per detected violation. |

---

## 4. PostgreSQL Persistence Architecture

The database records all inspection events for statutory audit trails:

```sql
CREATE TABLE IF NOT EXISTS product_inspections (
    id SERIAL PRIMARY KEY,
    inspection_id VARCHAR(64) UNIQUE NOT NULL,
    barcode VARCHAR(32),
    product_name VARCHAR(255),
    image_path TEXT NOT NULL,
    overall_compliant BOOLEAN NOT NULL,
    compliance_score_pct REAL NOT NULL,
    total_violations INT NOT NULL,
    compounding_fine_inr BIGINT DEFAULT 0,
    evaluations JSONB NOT NULL,
    violations JSONB NOT NULL,
    raw_ocr_tokens JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inspections_compliant ON product_inspections(overall_compliant);
CREATE INDEX idx_inspections_evaluations_gin ON product_inspections USING GIN (evaluations);
```

---

## 5. Concurrency Profiles & Multi-Threading Specification (Frontend Spec)

To ensure the inspector daemon does not freeze the host system or overheat mobile/laptop inspection terminals, the batch processing pipeline implements a configurable concurrency throttling model.

### Hardware Concurrency Profiles

| Profile Name | Fraction | Formula | On 28-Core Host | Use Case |
|---|---|---|---|---|
| **5/6 Workers (Recommended)** | **~83%** | $\lfloor N_{\text{cpus}} \times \frac{5}{6} \rfloor$ | **23 workers** | High-throughput batch processing while leaving $1/6$ of system resources free for OS UI and browser responsiveness. |
| **Full Power** | **100%** | $N_{\text{cpus}}$ | **28 workers** | Dedicated headless server runs where maximum throughput is desired. |
| **3/4 Workers** | **75%** | $\lfloor N_{\text{cpus}} \times \frac{3}{4} \rfloor$ | **21 workers** | Balanced multi-tasking during concurrent report generation. |
| **1/2 Workers** | **50%** | $\lfloor N_{\text{cpus}} \times \frac{1}{2} \rfloor$ | **14 workers** | Thermal-budgeted inspection on laptops or low-power embedded edge devices. |
| **Single Worker** | **Sequential** | $1$ | **1 worker** | Deterministic debugging, step-by-step visual audits, and memory-constrained scenarios. |

### Frontend Settings Contract
When exposing this in the upcoming UI, the frontend settings modal should present:
1. **Concurrency Slider / Preset Selector:** Defaulting to `5/6 Threads (Recommended)`.
2. **Dynamic Thread Counter Badge:** Displays live worker allocation (e.g. `23 / 28 Cores`).
3. **API Query Param:** Sent to the backend daemon as:
   `POST /api/v1/batch-scan?concurrency_profile=5_6` or `?workers=23`.

---

## 6. Native Rust Batch Scanning Engine (`src/batch.rs`)

To achieve maximum throughput with zero interpreter overhead, Themis embeds the batch inspection orchestrator directly inside the native binary:

### 1. Architectural Components
- **SKU Directory Discoverer (`discover_product_skus`):** Recursively groups panel images (`front.jpg`, `panel_raw_1.jpg`, `panel_raw_2.jpg`, `panel_raw_3.jpg`) into distinct product entities (`TargetSku`).
- **Interactive Hardware Concurrency Resolver (`resolve_concurrency_workers`):** Detects system logical cores (`std::thread::available_parallelism()`) and provides an interactive terminal selector or parses `--profile` (`5/6`, `full`, `3/4`, `1/2`, `single`, `custom:<N>`).
- **Bounded Tokio Semaphore:** Implements an asynchronous worker pool using `Arc<Semaphore>` where CPU-intensive DBNet and PP-OCRv4 operations run in `tokio::task::spawn_blocking` threads to maintain full CPU saturation without starving Tokio timers.
- **Smart Model Resolver (`resolve_models_path`):** Automatically discovers `./models`, `themis/models`, or system paths without requiring manual CLI flags.
- **Live ANSI Dashboard:** Renders real-time percentage progress, color-coded risk tier badges, SKU names, and primary violation remarks.

---

## 7. Statutory Severity Risk Tiers (`src/compliance/types.rs`)

Compliance is graded into 5 statutory risk tiers rather than a misleading binary pass/fail:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum RiskTier {
    Compliant,        // 100% Score, 0 violations
    LowRiskMinor,     // Score >= 70%, advisory warnings / minor infractions
    ModerateRisk,     // Score 40% - 69%, 1-2 non-critical violations (e.g. MRP on neck/crimp)
    HighRiskMajor,    // Score 20% - 39%, multiple mandatory clauses missing
    CriticalSevere,   // Score < 20%, unlabelled / gross non-compliance / counterfeit risk
}
```

### Risk Calculation Algorithm
```rust
let risk_tier = if violations_count == 0 {
    RiskTier::Compliant
} else if score >= 70.0 {
    RiskTier::LowRiskMinor
} else if score >= 40.0 {
    RiskTier::ModerateRisk
} else if score >= 20.0 {
    RiskTier::HighRiskMajor
} else {
    RiskTier::CriticalSevere
};
```

---

## 8. Line-Quantized Total-Order Text Sorting (`src/ocr/detector.rs`)

To eliminate slice sorting panics caused by non-transitive bounding box comparisons across non-standard packaging layouts, Themis implements a line-quantized strict total order:

```rust
// Sort top-to-bottom, left-to-right reading order using a strict total order
boxes.sort_by(|a, b| {
    let line_a = a.y / 16;
    let line_b = b.y / 16;
    line_a.cmp(&line_b).then_with(|| a.x.cmp(&b.x))
});
```
This guarantees strict mathematical transitivity ($A \le B \land B \le C \implies A \le C$) and prevents panics in Rust's sorting routines regardless of text region density or rotation.


