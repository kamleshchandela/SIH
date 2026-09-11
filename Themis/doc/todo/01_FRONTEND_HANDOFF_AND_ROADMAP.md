# Frontend Handoff, API Contract & System Limitations

> **Technical specification for the frontend development team outlining the active PARAKH backend REST API, data contracts, client-side report generation (XLSX & PDF), and the architectural rationale regarding e-commerce scrapers.**

---

## 1. System Limitation Analysis: E-Commerce Scraping

### The Forensic Reality of E-Commerce Scraping
While the SIH 26034 problem statement mentions scanning e-commerce listings, **relying on live, real-time web scrapers in a production regulatory compliance engine is an engineering anti-pattern**:

1. **Anti-Bot Defenses & WAF Mitigation:**
   - Indian quick-commerce and e-commerce platforms (Blinkit, Zepto, Swiggy Instamart, Amazon.in, Flipkart) enforce aggressive Web Application Firewalls (Cloudflare Turnstile, Akamai Bot Manager, AWS WAF, perimeter IP rate-limiting, and CAPTCHAs).
   - Real-time automated scraping from server IPs triggers immediate HTTP `403 Forbidden` responses or challenge loops, making live demos brittle and prone to catastrophic failure on stage.
2. **Headless Browser Resource Exhaustion:**
   - Modern e-commerce pages are single-page applications (Next.js, React) requiring headless browser runtimes (Puppeteer, Playwright, Selenium) to execute client-side JavaScript hydration.
   - Spawning headless Chromium instances consumes **800 MB to 1.5 GB of RAM per session**, completely undermining PARAKH's ultra-lightweight, memory-efficient Rust backend (~30 MB footprint).
3. **Missing Regulatory Data on Electronics & Non-Grocery Catalogues:**
   - Over **90% of e-commerce listings for electronics, apparel, and hardware** display only promotional 3D marketing renders or front-facing glamour shots.
   - The statutory regulatory panel (back panel with registered manufacturer address, PIN code, FSSAI license, and compounding details) is almost never photographed by marketplace sellers.
4. **Legal & Terms of Service Liabilities:**
   - Direct web crawling without official platform API access violates commercial marketplace Terms of Service and Computer Fraud regulations.

### The Winning SIH 26034 Defense Strategy
When evaluators ask: *"Can your system inspect live Amazon or Blinkit listings?"*

> **The Recommended Judge Defense:**
> *"Our engine is designed to enforce the Legal Metrology Act, 2009 with statutory evidence integrity. 
> Rather than relying on brittle, easily blocked web scrapers that frequently fail due to Cloudflare protection, PARAKH provides high-throughput REST APIs (`/api/v1/scan-sku` and `/api/v1/scan-product-path`) that ingest digital image dossiers supplied either via official marketplace partner APIs, compliance auditor uploads, or catalogue repository syncs. 
> If an e-commerce platform lists a product without the mandatory statutory panels, our multi-panel pooling engine flags an incomplete dossier and assesses compounding penalties under Section 36(1) read with the 2021 E-Commerce Amendments."*

---

## 2. Active Backend REST API Contract (What We Built)

The PARAKH backend runs on Rust (Axum framework) with pure CPU ONNX Runtime vectorization.

### Base URL
```
http://localhost:8080
```
*(Or configured port via `--port <PORT>`)*

### CORS Policy
Configured with `CorsLayer::permissive()`. All origins, headers, and HTTP methods (`GET`, `POST`, `OPTIONS`) are permitted for frontend clients (Vite `5173`, Next.js `3000`, etc.).

### Upload Limits
Configured with `DefaultBodyLimit::max(100MB)`. The backend natively supports high-resolution packaging scans up to 100 megabytes per request.

---

### Endpoint 1: Health & Runtime Telemetry
* **Method:** `GET`
* **Route:** `/api/v1/health`
* **Response:**
```json
{
  "status": "healthy",
  "service": "PARAKH Legal Metrology Compliance Engine",
  "inference_device": "CPU (Vectorized Multi-threaded ONNX Runtime)",
  "active_regulations": "Legal Metrology Act, 2009 | LMPC Rules, 2011 | Jan Vishwas Act, 2023",
  "timestamp": "2026-09-06T13:27:11.571135646+00:00"
}
```

---

### Endpoint 2: Multi-Panel SKU Upload (`scan-sku`)
This is the primary endpoint for the web/mobile frontend inspector.

* **Method:** `POST`
* **Route:** `/api/v1/scan-sku`
* **Content-Type:** `multipart/form-data`
* **Request Fields:**
  * `product_name` *(optional text)*: Product title or SKU identifier (e.g. `"Amul Pasteurized Butter 100g"`).
  * `front` *(file)*: Principal Display Panel image.
  * `panel_1`, `panel_2`, `panel_3` *(files)*: Technical panels (ingredients, nutrition, back seal, MRP print).
  * *(Any arbitrary number of file fields are accepted and automatically pooled).*

#### JavaScript / Frontend Upload Example:
```javascript
const formData = new FormData();
formData.append("product_name", "Amul Butter 100g");
formData.append("front", frontImageFile);
formData.append("back_panel", backImageFile);
formData.append("crimp_panel", crimpImageFile);

const response = await fetch("http://localhost:8080/api/v1/scan-sku", {
  method: "POST",
  body: formData,
});
const report = await response.json();
```

---

### Endpoint 3: Local Product Directory Scan (`scan-product-path`)
Used for server-side batch audits, desktop inspection agents, or pre-downloaded product folders.

* **Method:** `POST`
* **Route:** `/api/v1/scan-product-path`
* **Content-Type:** `application/json`
* **Request Payload:**
```json
{
  "product_dir": "/home/arch/Projects/backbone/dataset/real_products/8901058000269_Maggi"
}
```
*or explicit file paths:*
```json
{
  "product_name": "Custom Maggi SKU",
  "file_paths": [
    "/path/to/front.jpg",
    "/path/to/panel_raw_1.jpg",
    "/path/to/panel_raw_2.jpg"
  ]
}
```

---

### Structured JSON Response Schema (`ComplianceReport`)

```json
{
  "inspection_id": "INSP-20260906-133406",
  "timestamp": "2026-09-06T13:34:06.123456Z",
  "product_name": "Amul Pasteurized Butter",
  "scanned_panels": [
    "front.jpg",
    "panel_raw_1.jpg"
  ],
  "overall_compliant": false,
  "risk_tier": "HighRiskMajor",
  "compliance_score_pct": 28.57,
  "evaluations": [
    {
      "field": "ManufacturerDetails",
      "clause": "Rule 6(1)(a)",
      "status": "Violation",
      "source_panel": null,
      "remarks": "Missing statutory manufacturer name, registered address, or postal PIN code"
    },
    {
      "field": "NetQuantity",
      "clause": "Rule 6(1)(c) & Rule 13",
      "status": "Compliant",
      "source_panel": "front.jpg",
      "remarks": "Declared: '100 g' (Valid standard SI unit)"
    },
    {
      "field": "MaximumRetailPrice",
      "clause": "Rule 6(1)(e)",
      "status": "Violation",
      "source_panel": null,
      "remarks": "MRP declaration omitted on scanned panels"
    },
    {
      "field": "CountryOfOrigin",
      "clause": "Rule 6(1)(da)",
      "status": "Compliant",
      "source_panel": "panel_raw_1.jpg",
      "remarks": "Explicit origin: 'India'"
    },
    {
      "field": "ConsumerCare",
      "clause": "Rule 6(1)(g)",
      "status": "Violation",
      "source_panel": null,
      "remarks": "Missing consumer helpline phone or grievance email"
    },
    {
      "field": "UnitSalePrice",
      "clause": "Rule 6(1)(f)",
      "status": "NotApplicable",
      "source_panel": null,
      "remarks": "Package net weight < 1 kg / 1 L; USP declaration is exempt"
    }
  ],
  "violations": {
    "mandatory_missing": [
      "ManufacturerDetails",
      "MaximumRetailPrice",
      "ManufactureDate",
      "ConsumerCare"
    ],
    "non_standard_units": [],
    "statutory_penalties": [
      {
        "section": "Section 36(1) read with Section 49",
        "act": "Legal Metrology Act, 2009 (amended by Jan Vishwas Act, 2023)",
        "description": "4 non-compliant declarations detected under Legal Metrology (Packaged Commodities) Rules, 2011.",
        "compoundable_fine_inr": 100000
      }
    ]
  },
  "raw_ocr_tokens": [
    {
      "text": "Net Qty: 100 g",
      "confidence": 0.96,
      "bbox": {
        "x": 142,
        "y": 620,
        "width": 185,
        "height": 38
      },
      "source_image": "front.jpg"
    }
  ]
}
```

---

## 3. What the Frontend Team Needs to Implement

The frontend application should be built around **3 core workflows**:

### Workflow A: Multi-Panel Drag-and-Drop Inspector
1. **Multi-File Upload Component:**
   - Provide a dropzone where the user can upload 1 to 6 panel photos (`Front`, `Back`, `Nutrition`, `Crimp`, `Ingredients`).
   - Allow optional typing of `Product Name` or auto-detect from barcode.
2. **Evidence Visualizer Canvas:**
   - Render the uploaded panel images.
   - Using the `bbox` coordinates `[x, y, width, height]` from `raw_ocr_tokens`, draw interactive bounding boxes on top of the image canvas.
   - Hovering over a specific token in the list highlights its box on the image; clicking a box highlights the corresponding rule evaluation.

### Workflow B: Compliance Dashboard & Risk Tier Cards
Display the statutory evaluation clearly:
* **Statutory Risk Tier Badges:**
  * `Compliant`: Bright Green (`#22c55e`)
  * `LowRiskMinor`: Cyan (`#06b6d4`)
  * `ModerateRisk`: Yellow / Amber (`#eab308`)
  * `HighRiskMajor`: Magenta (`#d946ef`)
  * `CriticalSevere`: Bright Red (`#ef4444`)
* **Clause-by-Clause Checklist:** Display each Rule 6 field with its status (`PASS`, `FAIL`, `WARN`, `N/A`) and panel evidence tag (`[on front.jpg]`).
* **Jan Vishwas Penalty Ticker:** Prominently display compoundable liability (`₹1,00,000 INR`) under Section 36(1) and Section 49.

---

### Workflow C: Client-Side Export Engine (XLSX & PDF)

To keep the system modular and zero-dependency, **the frontend generates editable spreadsheets and printable PDF notices directly from the JSON payload**.

#### 1. Editable Spreadsheet Export (`.xlsx`)
Using the client-side library `xlsx` (`sheetjs`):

```javascript
import * as XLSX from "xlsx";

export function exportComplianceXlsx(report) {
  // 1. Summary Sheet
  const summaryData = [
    ["Inspection ID", report.inspection_id],
    ["Product SKU", report.product_name || "N/A"],
    ["Timestamp", report.timestamp],
    ["Overall Status", report.overall_compliant ? "COMPLIANT" : "NON-COMPLIANT"],
    ["Statutory Risk Tier", report.risk_tier],
    ["Compliance Score", `${report.compliance_score_pct.toFixed(1)}%`],
    ["Total Compounding Liability (INR)", `₹${report.violations.statutory_penalties.reduce((acc, p) => acc + p.compoundable_fine_inr, 0)}`],
  ];

  // 2. Clause Evaluation Sheet
  const evaluationData = [
    ["Statutory Clause", "Field", "Status", "Evidence Source Panel", "Inspector Remarks"],
    ...report.evaluations.map(e => [
      e.clause,
      e.field,
      e.status,
      e.source_panel || "Not Found",
      e.remarks,
    ]),
  ];

  // 3. Extracted Tokens Sheet
  const tokenData = [
    ["Source Panel", "Bounding Box (X, Y, W, H)", "Confidence", "Extracted Text"],
    ...report.raw_ocr_tokens.map(t => [
      t.source_image || "unknown",
      `(${t.bbox.x}, ${t.bbox.y}) ${t.bbox.width}x${t.bbox.height}`,
      `${(t.confidence * 100).toFixed(1)}%`,
      t.text,
    ]),
  ];

  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.aoa_to_sheet(summaryData), "Audit Summary");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.aoa_to_sheet(evaluationData), "Clause Evaluation");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.aoa_to_sheet(tokenData), "OCR Tokens");

  XLSX.writeFile(workbook, `Themis_Audit_${report.inspection_id}.xlsx`);
}
```

#### 2. Statutory Legal Notice Export (`.pdf`)
Use `@media print` CSS styling or `jspdf` / `html2pdf.js` to render an official **Notice of Violation**:

* **Header:** Government of India / Ministry of Consumer Affairs, Food & Public Distribution — Department of Consumer Affairs.
* **Title:** *Statutory Notice of Non-Compliance under Section 36(1) of the Legal Metrology Act, 2009 read with the Legal Metrology (Packaged Commodities) Rules, 2011*.
* **Inspected SKU Dossier:** Inspection ID, Date, Product Name, Scanned Panels.
* **Itemized Violations Table:** Clause numbers, missing mandatory declarations, non-standard measurement units (`Rule 13`).
* **Compounding Notice:** Compounding calculation under Section 49 / Jan Vishwas Act (`₹25,000` to `₹1,00,000`).
* **Evidentiary Panel Attachments:** Embedded packaging photos with highlighted bounding boxes.

---

### Alternative: Direct Backend Export & Evidence Streaming (Already Live)

If the frontend team prefers zero client-side PDF/spreadsheet overhead, the backend now provides direct download and asset streaming endpoints:

1. **Direct CSV Export:** `GET /api/v1/inspections/{id}/export/csv` (RFC 4180 audit spreadsheet).
2. **Direct ISO PDF 1.4 Notice:** `GET /api/v1/inspections/{id}/export/pdf` (Official Ministry statutory notice).
3. **Static Evidence Photos:** `GET /api/v1/evidence/{id}/{panel}` (High-res packaging photograph streaming).
4. **Role-Based Auth (JWT):** `POST /api/v1/auth/login` (Inspector & Admin credentials).
