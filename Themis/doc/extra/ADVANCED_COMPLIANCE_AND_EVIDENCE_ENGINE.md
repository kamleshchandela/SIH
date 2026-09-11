# Advanced Compliance, Evidence Storage, Auth & Direct Export Specification

This specification documents four core enterprise backend engines integrated into **PARAKH**:
1. **Rule 7 / Schedule II Font Size & Laplacian Blur Detection Engine**
2. **Evidence Photograph Storage & Static Asset Serving (`/api/v1/evidence/...`)**
3. **Role-Based Access Control (JWT Authentication & Inspector vs. Admin Roles)**
4. **Direct PDF & CSV Statutory Notice Export Engine**

---

## 1. Rule 7 / Schedule II Numeral Height & Laplacian Blur Detection

### 1.1 The Statutory Challenge
Under **Rule 7 read with Schedule II of the Legal Metrology (Packaged Commodities) Rules, 2011**, all mandatory declarations—especially Net Quantity and Maximum Retail Price (MRP)—must maintain a minimum numeral height proportional to the Principal Display Panel (PDP) area:

| Area of Principal Display Panel ($A$ in $\text{cm}^2$) | Minimum Height of Numerals ($h$ in mm) | Blown/Molded/Perforated ($h$ in mm) |
|---|---|---|
| $A \le 50$ | 1.0 mm | 2.0 mm |
| $50 < A \le 100$ | 1.5 mm | 3.0 mm |
| $100 < A \le 500$ | 2.5 mm | 4.0 mm |
| $500 < A \le 2500$ | 4.0 mm | 6.0 mm |
| $A > 2500$ | 6.0 mm | 6.0 mm |

In real-world mobile or web uploads, cameras capture packaging at arbitrary zoom levels and viewing angles. A fundamental problem arises: **Is text illegible due to poor camera capture (motion blur / bad focus), or did the manufacturer physically print sub-statutory text?**

### 1.2 Mathematical Formulation of Laplacian Sharpness Gate
PARAKH implements a discrete Laplacian convolution filter on the luminance channel of each packaging panel before compliance scoring:

$$\Delta I(x, y) = \frac{\partial^2 I}{\partial x^2} + \frac{\partial^2 I}{\partial y^2}$$

Using the discrete 4-connected discrete Laplacian convolution kernel:

$$L = \begin{bmatrix} 0 & 1 & 0 \\ 1 & -4 & 1 \\ 0 & 1 & 0 \end{bmatrix}$$

For an image converted to ITU-R BT.601 luminance ($Y = 0.299R + 0.587G + 0.114B$):

$$L(x, y) = I(x+1, y) + I(x-1, y) + I(x, y+1) + I(x, y-1) - 4 \cdot I(x, y)$$

The edge response variance $\sigma_L^2$ is computed across all non-boundary pixels:

$$\mu_L = \frac{1}{N} \sum_{x, y} L(x, y), \quad \sigma_L^2 = \frac{1}{N} \sum_{x, y} \left(L(x, y) - \mu_L\right)^2$$

### 1.3 Sharpness Classification Matrix
The calculated variance $\sigma_L^2$ determines whether an image is legally admissible:

| Laplacian Variance ($\sigma_L^2$) | Quality Tier | Diagnostic Assessment | Statutory Implication |
|---|---|---|---|
| $\ge 250.0$ | **High Sharpness** | Crisp packaging edges; sub-pixel text boundaries verified. | Admissible in legal proceedings. |
| $100.0 - 249.9$ | **Acceptable** | Clean statutory text; valid for automated compliance check. | Standard audit accepted. |
| $50.0 - 99.9$ | **Moderate Blur** | Soft focus or slight camera shake; warning emitted. | Advisory emitted; re-take suggested if OCR fails. |
| $< 50.0$ | **Severe Blur** | Severe motion blur or out-of-focus capture. | Camera artifact flagged; prevents wrongful manufacturer penalties. |

### 1.4 Rule 7 Numeral Height Verification
PARAKH evaluates the bounding box height of declared Net Quantity and MRP relative to the packaging panel dimensions:
- If no declarations exist, `Rule7NumeralHeight` fails immediately.
- If numeral height $H_{\text{numeral}} < 14\text{px}$ or relative ratio $\frac{H_{\text{numeral}}}{H_{\text{panel}}} < 0.8\%$, a statutory warning/violation is recorded under Schedule II.

---

## 2. Evidence Photograph Storage & Static Streaming

### 2.1 Storage Architecture
For Legal Metrology court filings and administrative compounding appeals, raw uncompressed photographic evidence must be preserved verbatim.

On every multi-panel scan (`POST /api/v1/scan-sku`), PARAKH automatically stores the raw image buffers into a structured directory tree:

```
./evidence/
└── INSP-20260906-144917/
    ├── front.jpg         (556 KB)
    ├── panel_raw_1.jpg   (1.1 MB)
    └── panel_raw_2.jpg   (4.1 MB)
```

### 2.2 Static Streaming API
Evidence photographs are directly streamable via HTTP GET with proper MIME negotiation:

- **Endpoint:** `GET /api/v1/evidence/{inspection_id}/{panel_label}`
- **Security:** Directory traversal sanitization (`..`, `/`, `\` removed from panel label).
- **HTTP Response Headers:**
  - `Content-Type: image/jpeg` (or `image/png`, `image/webp`)
  - `Cache-Control: public, max-age=86400`
  - `Access-Control-Allow-Origin: *`

#### Example Request:
```bash
curl -I http://localhost:8088/api/v1/evidence/INSP-20260906-144917/front.jpg
```
#### Response:
```http
HTTP/1.1 200 OK
content-type: image/jpeg
content-length: 568763
cache-control: public, max-age=86400
```

---

## 3. Role-Based Access Control (RBAC) & JWT Engine

PARAKH provides built-in cryptographic JSON Web Token (JWT) authentication using pure Rust HMAC-SHA256 (`sha2` + `hmac` + `base64`).

### 3.1 Statutory Roles
1. **`Inspector`**: Field enforcement officers who upload SKU panels, execute audits, view historical reports, and download notices.
2. **`Admin`**: Legal Metrology Officers (Directorate level) authorized to configure compounding penalty rates, manage user badges, and purge audit trails.

### 3.2 Token Format & Claims
- **Algorithm:** HS256 (HMAC with SHA-256)
- **Header:** `{"alg": "HS256", "typ": "JWT"}`
- **Payload Claims:**
  - `sub`: User ID / Badge ID
  - `role`: `"Inspector"` or `"Admin"`
  - `exp`: Unix epoch timestamp + 86400s (24 hours)
  - `iat`: Unix epoch issue timestamp

### 3.3 Authentication API

#### Login Endpoint
- **URL:** `POST /api/v1/auth/login`
- **Headers:** `Content-Type: application/json`
- **Body:**
```json
{
  "username": "inspector",
  "password": "inspector@themis2026"
}
```
#### Response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "role": "Inspector",
  "username": "inspector",
  "expires_in_secs": 86400
}
```

#### Pre-Configured Credentials (Environment-Configurable):
- **Inspector:** `inspector` / `inspector@themis2026`
- **Admin:** `admin` / `admin@themis2026`

### 3.4 Axum Route Protection
PARAKH provides compile-time type-safe Axum extractors:
- `AuthenticatedUser(pub Claims)`: Validates signature and expiration; rejects unauthorized callers with `401 Unauthorized`.
- `RequireAdmin(pub Claims)`: Ensures role is `Admin`; rejects non-admins with `403 Forbidden`.

---

## 4. Direct PDF & CSV Statutory Notice Export Engine

Rather than relying on client-side rendering or heavy external Python microservices, PARAKH generates production-grade statutory audit files directly in pure Rust.

### 4.1 RFC 4180 CSV Export
- **Endpoint:** `GET /api/v1/inspections/{id}/export/csv`
- **MIME Type:** `text/csv; charset=utf-8`
- **Header:** `Content-Disposition: attachment; filename="audit_{id}.csv"`
- **Fields Included:**
  1. Inspection ID
  2. Timestamp (ISO 8601)
  3. Product SKU Name
  4. Mandated Declaration Field
  5. Legal Clause (LMPC Rules, 2011)
  6. Compliance Status (`COMPLIANT`, `VIOLATION`, `WARNING`, `NOT_APPLICABLE`)
  7. Detected Text
  8. OCR Confidence %
  9. Source Evidence Panel
  10. Bounding Box `(x, y) wxh`
  11. Statutory Remarks
  12. Summary Section: Total Violations, Risk Tier, and Jan Vishwas Compounding Fines (₹).
  13. Panel Sharpness Section: Laplacian variance and blur diagnostics.

### 4.2 ISO PDF 1.4 Legal Notice of Violation
- **Endpoint:** `GET /api/v1/inspections/{id}/export/pdf`
- **MIME Type:** `application/pdf`
- **Header:** `Content-Disposition: inline; filename="statutory_notice_{id}.pdf"`
- **Visual Structure:**
  1. **Government Header Banner:** Directorate of Legal Metrology, Ministry of Consumer Affairs, Government of India.
  2. **Statutory Title:** Formal Notice of Inspection & Non-Compliance under Section 36(1).
  3. **SKU & Audit Metadata Card:** Inspection ID, timestamp, SKU title, risk tier, compliance percentage.
  4. **Rule Evaluation Table:** Two-tone table listing all Rule 6 clauses, detection status, confidence, and remarks.
  5. **Panel Sharpness Diagnostics:** Displays image sharpness and Laplacian edge variance for evidence admissibility.
  6. **Compounding Assessment & Seal Box:** Total compounding penalty under Jan Vishwas Act, 2023, with official Inspector Signature & Seal placeholder.

---

## 5. REST API Quick Reference

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/api/v1/health` | Service health, inference engine, DB status | None |
| `POST` | `/api/v1/auth/login` | Authenticate inspector/admin; receive JWT | None |
| `POST` | `/api/v1/scan-sku` | Multi-panel packaging upload & audit | Optional / Protected |
| `GET` | `/api/v1/evidence/{id}/{panel}` | Stream raw uploaded evidence image | None (Public asset) |
| `GET` | `/api/v1/inspections` | Paginated search & historical audits | Inspector / Admin |
| `GET` | `/api/v1/inspections/{id}` | Detailed JSON inspection report | Inspector / Admin |
| `GET` | `/api/v1/inspections/{id}/export/csv` | Download RFC 4180 audit spreadsheet | Inspector / Admin |
| `GET` | `/api/v1/inspections/{id}/export/pdf` | Stream ISO PDF 1.4 statutory notice | Inspector / Admin |
| `GET` | `/api/v1/stats` | Macro compliance rates & risk breakdown | Inspector / Admin |
