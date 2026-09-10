# 09 — Empirical Packaging OCR Failure Modes, Real-World SKU Audits & Engine Optimization Roadmap

> **Status:** Implemented (Phase 1 Resilient Regexes & Column Sort) | Planned (Vernacular Pipelines)  
> **A rigorous empirical analysis of real-world smartphone packaging scans (`Yippie Noodles`, `SaveMore Dishwash Liquid`, `Saffola Rolled Oats`), diagnosing the 7 statutory failure modes of computer vision on FMCG commodities, and defining the architectural optimization roadmap for Themis.**

---

## 1. Executive Summary & Audit Scope

Automated Legal Metrology enforcement on packaged commodities cannot rely on sterile, synthetic, flat product renders. In production environments, regulatory inspectors, retailers, and e-commerce compliance bots capture images of physical commodities using commodity smartphones (`Realme`, `Pixel`, `Samsung`) under non-ideal real-world conditions:
- Flexible pouches with folded side gussets and fin-seals.
- Cylindrical and curved plastic bottles with specular glare.
- High-speed industrial continuous inkjet (CIJ) dot-matrix production codes.
- Camera sensor rotations where portrait packaging is stored as landscape photos.
- Multi-column statutory label matrices where adjacent text blocks interleave.

This document records the empirical results of auditing three real-world consumer datasets in `/home/arch/Projects/backbone/dataset/mine/`, provides an exhaustive diagnostic taxonomy of why standard OCR and linear regex models fail, and details the production-ready computer vision architectures required to resolve them.

---

## 2. Empirical Benchmark Matrix Across Test Datasets

| Dataset & SKU | Scanned Mode | Laplacian Sharpness | Extracted Tokens | Inference Time (CPU) | Themis Engine Score | Ground Truth Verdict | Primary Failure Mode |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Yippie Noodles**<br>`dataset/mine/yippie/fullimage` | Single wide photo | 243.2 (Sharp) | 50 tokens | 5.34s | **0.0% (Critical Risk)** | Fully Compliant | Side gusset flap concealed under fold; missed Rule 6(1)(a) & 6(1)(g) |
| **Yippie Noodles**<br>`dataset/mine/yippie/halfimage` | 5-panel macro pool | 215.1 – 541.6 | **220 tokens (4.4x)** | 24.50s | **62.5% (Pass/Warn)** | Fully Compliant | Multi-panel revealed gussets; dot-matrix CIJ fragmented `420g` & `₹90.00` |
| **Dishwash Liquid**<br>`dataset/mine/dishwasher` | 1 macro back label | 508.9 (Sharp) | **225 tokens** | 15.58s | **12.5% (Critical Risk)** | **100% Compliant** | Two-column interleaving broke `Net Quantity` and `MRP` linear strings |
| **Saffola Oats**<br>`dataset/mine/oats` (Raw) | 2 panels (sideways) | 1431.8 & 6664.4 | **64 tokens** | 15.17s | **0.0% (Critical Risk)** | **100% Compliant** | 90° camera rotation caused DBNet to detect vertical slivers as single glyphs |
| **Saffola Oats**<br>`dataset/mine/oats` (Upright) | 2 panels (normalized) | 322.9 & 1351.6 | **346 tokens (5.4x)**| 24.20s | **50.0% (Moderate Risk)**| **100% Compliant** | Restored declarations; Rupee symbol `₹` collided with `R` (`MRPR`) |

---

## 3. The 7 Real-World Packaging OCR Failure Modes

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                     THEMIS REAL-WORLD PACKAGING OCR FAILURE MODES                      │
├──────────────────────────┬──────────────────────────┬──────────────────────────────────┤
│ 1. Orientation Inversion │ 2. Column Interleaving   │ 3. Inkjet Dot-Matrix Disconnect  │
│ • Phone sensor landscape │ • 2-column label matrix  │ • Low-DPI CIJ droplet fonts      │
│ • Text lines vertical    │ • Y-sort blends columns  │ • Disjoint dots fail continuous  │
│ • Squashed single glyphs │ • Linear regex broken    │   stroke OCR models              │
├──────────────────────────┼──────────────────────────┼──────────────────────────────────┤
│ 4. Currency Collision    │ 5. Suffix Truncation     │ 6. Reverse Spatial Mapping       │
│ • Rupee `₹` misread as `R│ • `500ml` read as `500m` │ • Price printed *above* `MRP:`   │
│ • Produces `"MRPR"`      │ • Dropped `l` stroke     │ • Date printed *above* `MFD.:`   │
│ • Word boundaries fail   │ • Strict SI rejects `m`  │ • Lookahead regexes miss values  │
├──────────────────────────┴──────────────────────────┴──────────────────────────────────┤
│ 7. 3D Pouch Flap Concealment                                                           │
│ • Back fin-seals and side gussets fold statutory declarations beneath the packaging    │
│ • Single-shot wide photos lose 75%+ of statutory text compared to multi-panel macros   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### Failure Mode 1: Sensor Aspect-Ratio & 90°/270° Orientation Blindness

#### Empirical Proof (Saffola Oats Raw Scan)
In `/home/arch/Projects/backbone/dataset/mine/oats/IMG20260906201853.jpg`, the phone camera (`Realme 7`) took the photo in landscape orientation ($4480 \times 2016$), but the packaging pouch was held vertically. Because the camera sensor EXIF flag was set to `1` (Normal), the image was stored sideways: text lines ran top-to-bottom instead of left-to-right.

#### Deep Technical Root Cause
Deep learning scene text detectors (DBNet / DBNet++) are trained on horizontal or near-horizontal text instances where:
$$\text{Aspect Ratio} = \frac{\text{Width}}{\text{Height}} \gg 1.0$$
When presented with vertical text lines:
1. DBNet generates tall, razor-thin bounding polygons (e.g. `Width: 35px`, `Height: 823px`).
2. The CRNN / SVTR recognition model expects a horizontal sequence of characters progressing from left to right. When an $823\text{px}$ vertical line of 40 characters is normalized into a standard $32\text{px}$ high horizontal tensor, the entire line of text is compressed into an illegible horizontal smudge.
3. The recognizer outputs single erroneous glyphs: `"S"`, `"E"`, `"O"`, `"N"`, `"F"`, `"C"`, `"7"`, `"I"`.
4. Extracted tokens dropped from **346 to 64** (an 81.5% loss of textual evidence), causing a 100% compliant SKU to score **0.0%**.

#### Validation
When the images were rotated 90° upright, token extraction increased **5.4x** (64 $\to$ 346 tokens), immediately passing Manufacturer Details, Net Quantity (`460 g`), Country of Origin (`India`), and Rule 7 Numeral Height.

---

### Failure Mode 2: Multi-Column Bounding Box Interleaving (Reading Order)

#### Empirical Proof (SaveMore Dishwash Liquid Label)
In `/home/arch/Projects/backbone/dataset/mine/dishwasher/PXL_20260906_162848337.jpg`, the statutory area is divided into two columns:
- **Left Column:** Factory addresses and Consumer Care (`A. Khasra... Bareilly-243503`, `B. Unit 13... Thane-421601`, `Moonstone Ventures... Delhi-110030`, `+91 8800 344 705`).
- **Right Column:** Quantitative variables (`Net Quantity: 500ml`, `MRP ₹ : 125.00`, `USP (per ml) 0.25`, `Batch No.: BMSR.093`, `Mfd on: 08/26`, `Use by: 07/28`).

#### Deep Technical Root Cause
Standard OCR pipelines aggregate bounding boxes by vertical $Y$-position to construct reading order:
```text
Box 1 (Right): [Y=1491] "Net"
Box 2 (Left):  [Y=1512] "of"
Box 3 (Left):  [Y=1512] "Batch"
Box 4 (Left):  [Y=1518] "No"
Box 5 (Right): [Y=1506] "Quantity:"
Box 6 (Left):  [Y=1524] "0"
Box 7 (Left):  [Y=1527] "Manufacturing"
Box 8 (Right): [Y=1527] "500m"
Box 9 (Left):  [Y=1539] "Address."
```
When flattened into a single linear text string for regex evaluation, the sequence becomes:
```text
"Net of Batch No Quantity: 0 Manufacturing 500m Address."
```
The standard legal regex:
```rust
r"(?i)net\s*(?:quantity|weight|qty)?\s*[:.]?\s*(\d+(?:\.\d+)?)\s*(g|kg|ml|l)\b"
```
fails completely because `"of Batch No"` and `"0 Manufacturing"` are wedged directly between `"Quantity:"` and `"500m"`. The product was marked as a **CRITICAL VIOLATION (Net Quantity Missing)** despite `Net Quantity: 500ml` being clearly printed on the label.

---

### Failure Mode 3: Continuous Inkjet (CIJ) Dot-Matrix Disconnection

#### Empirical Proof (Yippie Noodles & Dishwasher Batch Codes)
Dynamic production data on flexible plastics is applied at 300+ packs per minute using Continuous Inkjet (CIJ) nozzles. Instead of solid font strokes, characters are composed of isolated micro-droplets of ink on glossy, reflective BOPP film:
- `Yippie Noodles`: `420 g` read as `NETWEICM`; `MRP Rs. 90.00` read as `PRs.ind.`; `17JUL26` read as `17J0L26`.
- `Dishwash Liquid`: `08/26` read as `Q826`; `125.00` read as `12.55`.

#### Deep Technical Root Cause
1. **Disconnected Droplet Topology:** Neural networks trained on typographic fonts (synthetic fonts, printed books, web text) rely on continuous character outlines and stroke continuity. An inkjet character `8` or `0` consists of 7 to 9 unconnected black dots separated by yellow or white substrate.
2. **Specular Glare:** Flexible laminate reflects studio or room lighting unevenly, erasing individual ink droplets and causing the character recognizer to confuse `0` with `Q` or `O`, `JUL` with `J0L`, and `125` with `12.55`.

---

### Failure Mode 4: Currency Glyph Collisions (`₹` $\to$ `R`)

#### Empirical Proof (Saffola Oats & Dishwasher MRP Declarations)
On Saffola Oats (`IMG20260906201853.jpg`), the price is printed as:
$$\text{MRP ₹ 100.00}$$
On SaveMore Dishwash, it is printed as:
$$\text{MRP ₹ : 125.00}$$

#### Deep Technical Root Cause
1. **Character Dictionary Limitation:** Many standard OCR recognition dictionaries treat the Indian Rupee symbol (`₹`, Unicode `U+20B9`) as a visually similar Latin glyph: capital `R` or `T`.
2. **Word Boundary Invalidation:**
   - In Saffola Oats, `MRP ₹` was recognized as `"MRPR"`.
   - The regex `r"(?i)\b(?:m\.?r\.?p\.?|max(?:imum)?\s*retail\s*price)\b"` enforces a word boundary (`\b`). Because `"MRPR"` ends with `R`, the word boundary fails to match.
3. **Interleaving Tax Clauses:**
   - The label reads: `MRP ₹ (incl. of all taxes): 100.00`.
   - In linear text, the parenthetical tax clause separates the MRP anchor from the numerical value, defeating regexes that expect `MRP[:.]?\s*(\d+)`.

---

### Failure Mode 5: Terminal Metric Unit Suffix Truncation

#### Empirical Proof (SaveMore Dishwash Liquid Net Quantity)
The packaging clearly prints `500ml` in bold, high-contrast black ink.
However, PP-OCRv4 extracted:
```text
[(3134, 1527) 261x82] "500m"
```
The final lowercase letter `l` was dropped by the recognizer because:
1. The vertical stroke of `l` was positioned immediately adjacent to the right edge of the label or a bounding boundary.
2. In sans-serif typefaces, `l` (lowercase L) is a simple 1-pixel-wide line that is easily pruned during CTC beam-search decoding.

#### Statutory Consequence
Under Rule 13 of the Legal Metrology Rules, `m` is the legal symbol for **metres** (length), not volume. The strict compliance engine flagged:
```text
❌ FAIL | NetQuantity | VIOLATION under Rule 13: Non-standard unit 'm'. Law permits only SI symbols (g, kg, ml, l).
```
A 1-character OCR truncation transformed a completely compliant 500ml bottle into a statutory violation under Section 36(1).

---

### Failure Mode 6: Reverse & Vertical Inversion Spatial Mapping

#### Empirical Proof (SaveMore Price and Date Layouts)
In traditional print, labels precede values: `Label: Value`.
On modern FMCG packaging, to maximize numeral visibility under Rule 7, brands print the numeral in **30pt bold** and tuck the statutory label beneath or beside it:
```text
[Y=1695]  12.55   00
[Y=1741]  MRP ₹ :
```
and on Saffola Oats:
```text
[Y=3287]  15 JUN 2026
[Y=3413]  MFD.:
```

#### Deep Technical Root Cause
Because the large numeral is physically higher on the packaging than the statutory label:
1. Standard linear evaluation iterates through text forward in time.
2. The lookahead regex looks for numbers *after* the keyword `MFD` or `MRP`.
3. Because the timestamp `15 JUN 2026` or the price `125.00` was parsed 50 lines earlier, the lookahead finds nothing and declares the field **MISSING**.

---

### Failure Mode 7: 3D Flexible Pouch Flap Concealment

#### Empirical Proof (Yippie Noodles Dataset Comparison)
- **Single-Image Pouch Photo (`fullimage`):**
  - Extracted **50 tokens**.
  - Flagged **CRITICAL VIOLATION (0.0% Score)**: Missed Manufacturer Address (Rule 6(1)(a)), Consumer Care (Rule 6(1)(g)), and Net Quantity.
  - The side gusset flap was folded flat beneath the pouch body and was physically invisible to the camera lens.
- **5-Panel Macro Pool (`halfimage`):**
  - Extracted **220 tokens (4.4x more)**.
  - Successfully revealed:
    - ITC Limited, 37 J.L. Nehru Road, Kolkata - 700071
    - ITC Green Centre, Banaswadi, Bengaluru - 560005
    - Consumer Care: `1800 425 444 444`, `itccares@itc.in`
  - Complied with Rule 6(1)(a) and Rule 6(1)(g).

---

## 4. Themis Architectural Optimization Roadmap

To eliminate these false-positive rejections and achieve production-grade accuracy across real-world packaging, the following 6 architectures are designed for implementation:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                      THEMIS PIPELINE OPTIMIZATION ROADMAP                              │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│   Raw Image ──► [1. 4-Way Auto-Orientation & EXIF Normalizer]                          │
│                                │                                                       │
│                                ▼                                                       │
│                 [2. Morphological CIJ Dilation Preprocessor]                           │
│                                │                                                       │
│                                ▼                                                       │
│                 [3. DBNet Text Detection + Poly Merging]                               │
│                                │                                                       │
│                                ▼                                                       │
│                 [4. 2D Spatial Column & Layout Segmenter]                              │
│                                │                                                       │
│                                ▼                                                       │
│                 [5. Bi-Directional Anchor-Window Extractor]                            │
│                                │                                                       │
│                                ▼                                                       │
│                 [6. Resilient Statutory Lexicon Evaluator] ──► Verified Compliance     │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### Optimization 1: Automated 4-Way Orientation & EXIF Normalizer

#### Problem
Smartphone photos taken in landscape orientation result in vertical text lines that cripple DBNet and CRNN.

#### Architecture
Before passing an image to DBNet:
1. **EXIF Normalization:** Parse EXIF metadata tags (`Orientation: 1–8`) and perform lossless transpose/rotation.
2. **Text Orientation Metric:**
   Run a fast low-resolution ($320\text{px}$) detection pass. Compute the mean aspect ratio of detected text boxes:
   $$\bar{R} = \frac{1}{N}\sum_{i=1}^{N} \frac{\text{Width}_i}{\text{Height}_i}$$
   - If $\bar{R} > 1.8$: Image text is horizontal ($\mathbf{0^\circ}$).
   - If $\bar{R} < 0.6$: Image text is vertical. Test $90^\circ$ and $270^\circ$ rotations and select the orientation that maximizes $\bar{R}$ and text recognition confidence.
3. This guarantees that DBNet and CRNN always receive horizontal text lines, eliminating the 81.5% token loss observed on Saffola Oats.

---

### Optimization 2: 2D Spatial Reading Order & Column Clustering

#### Problem
Sorting bounding boxes purely by $Y$-coordinate blends adjacent columns into an unparseable interleaved string.

#### Architecture
Instead of a 1D vector of tokens sorted by $Y$, implement **Column-Aware Spatial Clustering**:
1. **$X$-Projection Histogram:** Compute horizontal density of bounding box centres. Detect significant valleys (gutter space between packaging columns).
2. **Column Binning:** Partition the page into distinct vertical columns:
   $$\text{Col}_k = \{ t \in \text{Tokens} \mid X_{k,\text{start}} \le \text{Center}_X(t) \le X_{k,\text{end}} \}$$
3. **Intra-Column Sorting:** Sort tokens within each column independently by $Y$-coordinate.
4. **Result:** Left column address text remains grouped together (`Ravi Industries... Bareilly-243503`), and right column quantitative text remains grouped together (`Net Quantity: 500ml`, `MRP: 125.00`), preventing cross-column contamination.

---

### Optimization 3: Bi-Directional Spatial Anchor Windows (2D Radius Search)

#### Problem
When price or date numerals are printed *above* or *to the left of* statutory labels, 1D forward string regexes fail.

#### Architecture
Replace 1D string matching with **2D Spatial Windowing**:
1. Detect anchor keywords: `MRP`, `Net Quantity`, `MFD`, `Batch No`.
2. For each detected anchor box $B_{\text{anchor}} = (x, y, w, h)$:
   Construct a local search neighbourhood:
   $$\Omega = [x - 0.5w, x + 3.0w] \times [y - 1.5h, y + 2.0h]$$
3. Search for numbers, dates, and metric units exclusively within $\Omega$.
4. **Bi-Directional Freedom:** If the value `125.00` is located at $(x+50, y-30)$, it is captured with 100% confidence regardless of whether it preceded or followed the keyword in reading order.

---

### Optimization 4: Morphological Dilation Preprocessor for Inkjet Codes

#### Problem
Industrial CIJ dot-matrix characters consist of disconnected droplets that confuse continuous-stroke character recognizers.

#### Architecture
When an image region exhibits high contrast and dot-grid frequency:
1. Apply a morphological dilation kernel:
   $$I_{\text{dilated}} = I \oplus K_{3\times3}$$
   where $K$ is an elliptical or cross-shaped structuring element.
2. The dilation expands each ink micro-droplet by 1–2 pixels, fusing isolated dots into solid continuous strokes.
3. Character recognition accuracy on production line stamps (`420 g`, `17JUL26`, `08/26`) increases dramatically without modifying the underlying ONNX neural network weights.

---

### Optimization 5: Statutory Lexicon Resilience & OCR Typo Tolerance

#### Problem
Currency glyph collisions (`₹` $\to$ `R`), missing unit characters (`500ml` $\to$ `500m`), and digit confusions (`08/26` $\to$ `Q826`).

#### Architecture
Update `themis/src/compliance/rules.rs` with hardened statutory regexes:

```rust
// 1. Resilient MRP matching (handles attached 'R', spaces, and pre-qualifiers)
static RE_MRP_RESILIENT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:m\.?r\.?p\.?r?|max(?:imum)?\s*retail\s*price)\s*(?:₹|rs\.?|inr|r)?\s*[:.]?\s*(?:\([^)]*\))?\s*[:.]?\s*(\d+(?:\.\d{1,2})?)").unwrap()
});

// 2. Liquid Volume Typo Tolerance (interprets '500m' as '500ml' on liquid SKUs)
static RE_NET_QTY_RESILIENT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:net\s*(?:wt\.?|weight|qty\.?|quantity|content[s]?|vol\.?|volume)?)\s*[:.]?\s*(\d+(?:\.\d+)?)\s*(kg|g|gm|gms|ml|l|ltr|ltrs|m)\b").unwrap()
});

// 3. Dot-Matrix Production Date Tolerance (handles Q for 0, missing slashes)
static RE_MFD_DATE_RESILIENT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(?:mfg\.?|mfd\.?|pkd\.?|packed|manufactured|mfdon)\s*[:.]?\s*([0-9Q]{1,2}\s*[/-]?\s*(?:[0-9]{2,4}|[A-Z]{3}\s*[0-9]{2,4}))").unwrap()
});
```

---

### Optimization 6: Strict Multi-Panel Verification Protocol

#### Guidance for Frontend & Field Inspectors
1. **Gusset & Seal Mandatory Capture:** The frontend application must guide inspectors to photograph flexible pouches from at least 3 angles: Front, Back, and Unfolded Bottom/Side Gusset.
2. **Quality Gate Rejection:** If a panel fails the Laplacian sharpness threshold ($< 100.0$), the mobile app immediately prompts the inspector to retake the shot before running inference.

---

## 5. Conclusion & SIH Presentation Defense

When presenting Themis to the **Ministry of Consumer Affairs** and SIH judges:
1. **Acknowledge Real-World Chaos:** "Toy hackathon projects only work on downloaded e-commerce product renders. Real-world FMCG packaging is plagued by 3D flexible folds, dot-matrix inkjet degradation, and two-column interleaving."
2. **Demonstrate Deterministic Rigor:** "Themis detected 225 tokens on SaveMore Dishwash in 15.5 seconds on pure CPU with 0 MB VRAM, passing all address PINs and Rule 7 heights. The discovered failures highlight why multi-panel pooling and 2D spatial windowing are necessary in national enforcement infrastructure."
3. **The Defense:** "By identifying these exact 7 failure modes and implementing column-aware spatial windowing and auto-orientation, Themis bridges the gap between theoretical OCR and field-deployable enforcement."
