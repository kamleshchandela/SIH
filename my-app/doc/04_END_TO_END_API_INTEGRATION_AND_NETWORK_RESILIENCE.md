# 04 — End-to-End API Integration & Network Resilience

> **Exhaustive technical specification of all 12 REST API endpoints, multipart serialization, token headers, error taxonomy, and stateless backend resilience.**

---

## 1. Complete PARAKH REST API Specification

The frontend client communicates with the PARAKH Rust backend over 12 RESTful endpoints implemented in `src/services/api.ts`:

```
                               PARAKH REST API SURFACE (12 ENDPOINTS)
+---------------------------------------------------------------------------------------------------+
| #  | Endpoint                             | Method | Request Payload             | Success Type   |
|----+--------------------------------------+--------+-----------------------------+----------------|
| 01 | /api/v1/auth/login                   | POST   | LoginRequest (JSON)         | LoginResponse  |
| 02 | /api/v1/health                       | GET    | None                        | HealthResponse |
| 03 | /api/v1/scan                         | POST   | file: Binary (Multipart)    | ComplianceRep  |
| 04 | /api/v1/scan-sku                     | POST   | files: Binaries (Multipart) | ComplianceRep  |
| 05 | /api/v1/scan-path                    | POST   | file_path (JSON)            | ComplianceRep  |
| 06 | /api/v1/scan-product-path            | POST   | product_dir (JSON)          | ComplianceRep  |
| 07 | /api/v1/evidence/{id}/{panel}        | GET    | URL Params                  | JPEG Binary    |
| 08 | /api/v1/inspections                  | GET    | Query String Filters        | InspectionList |
| 09 | /api/v1/inspections/{id}             | GET    | URL Params                  | ComplianceRep  |
| 10 | /api/v1/inspections/{id}/export/csv  | GET    | URL Params                  | text/csv       |
| 11 | /api/v1/inspections/{id}/export/pdf  | GET    | URL Params                  | text/plain-pdf |
| 12 | /api/v1/stats                        | GET    | None                        | InspectStats   |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Detailed Endpoint Contracts & Implementations

### Endpoint 01: `POST /api/v1/auth/login`
- **Method:** `POST`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  { "username": "admin", "password": "admin@themis2026" }
  ```
- **Response (HTTP 200):**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": { "username": "admin", "role": "Admin" },
    "expires_at": "2026-09-08T18:00:00Z"
  }
  ```
- **Frontend Action:** Stores JWT, user profile, and role in `AsyncStorage`. Sets `Authorization: Bearer <token>` for all subsequent requests.

---

### Endpoint 02: `GET /api/v1/health`
- **Method:** `GET`
- **Response (HTTP 200):**
  ```json
  {
    "status": "healthy",
    "service": "PARAKH Legal Metrology Compliance Engine",
    "inference_device": "CPU (Vectorized Multi-threaded ONNX Runtime)",
    "active_regulations": "Legal Metrology Act, 2009 | LMPC Rules, 2011 | Jan Vishwas Act, 2023",
    "database_connected": false,
    "timestamp": "2026-09-08T00:30:00Z"
  }
  ```
- **Frontend Action:** Renders the "Engine & AI Core" telemetry card on the dashboard. Informs the officer if ONNX CPU vectorized runtime is live and whether PostgreSQL persistence is active.

---

### Endpoint 03: `POST /api/v1/scan` (Single Panel Scan)
- **Method:** `POST`
- **Headers:** `Content-Type: multipart/form-data`
- **Request Body (FormData):**
  - `file`: Packaging panel image file binary.
- **Frontend Implementation (`src/services/api.ts`):**
  ```typescript
  const formData = new FormData();
  formData.append('file', {
    uri: imageUri,
    name: 'panel.jpg',
    type: 'image/jpeg',
  } as any);
  return this.request<ComplianceReport>('/api/v1/scan', {
    method: 'POST',
    body: formData,
  });
  ```
- **Response:** Comprehensive `ComplianceReport` JSON containing rule evaluations, blurriness check, and compounding fines.

---

### Endpoint 04: `POST /api/v1/scan-sku` (Multi-Panel SKU Scan)
- **Method:** `POST`
- **Headers:** `Content-Type: multipart/form-data`
- **Request Body (FormData):**
  - `product_name`: Optional commodity title string.
  - `files`: Multiple image binary parts (`panel_1.jpg`, `panel_2.jpg`, etc.).
- **Frontend Implementation:**
  ```typescript
  images.forEach((img, idx) => {
    formData.append('files', {
      uri: img.uri,
      name: `panel_${idx + 1}.jpg`,
      type: 'image/jpeg',
    } as any);
  });
  ```
- **Engine Logic:** Pools all text tokens from all submitted panels and performs unified statutory evaluation.

---

### Endpoint 05 & 06: `POST /api/v1/scan-path` & `POST /api/v1/scan-product-path`
- **Method:** `POST`
- **Headers:** `Content-Type: application/json`
- **Request Body (Endpoint 05):**
  ```json
  { "file_path": "e:/New folder/PARAKH/dataset/real_products/.../panel_raw_1.jpg" }
  ```
- **Request Body (Endpoint 06):**
  ```json
  { "product_dir": "e:/New folder/PARAKH/dataset/real_products/8901058000269_Maggi" }
  ```
- **Purpose:** Enables instant server-side filesystem testing without transmitting large image payloads over mobile networks.

---

### Endpoint 07: `GET /api/v1/evidence/{id}/{panel}`
- **Method:** `GET`
- **URL Parameters:** `id`: Inspection UUID, `panel`: Panel filename (e.g. `panel_raw_1.jpg`).
- **Response:** Raw JPEG image binary with `Content-Type: image/jpeg`.
- **Frontend Screen:** Renders in `app/evidence.tsx` with full-screen zoom and native share options.

---

### Endpoint 08: `GET /api/v1/inspections` (Audit Repository List)
- **Method:** `GET`
- **Query Parameters:** `page`, `limit`, `risk_tier`, `compliant`, `search`.
- **Response:** Paginated list of historical audits (`InspectionListResponse`).

---

### Endpoint 09: `GET /api/v1/inspections/{id}` (Inspection Detail)
- **Method:** `GET`
- **Response:** Full `ComplianceReport` JSON for the requested inspection ID.

---

### Endpoint 10 & 11: Export Endpoints (`/export/csv` & `/export/pdf`)
- **Backend Endpoints:** Queries PostgreSQL for the inspection report and outputs raw CSV text or statutory show-cause notice text.

---

### Endpoint 12: `GET /api/v1/stats` (Global Analytics)
- **Method:** `GET`
- **Response:**
  ```json
  {
    "total_inspections": 50,
    "compliant_count": 8,
    "violation_count": 42,
    "total_compounding_fines_inr": 1050000.0,
    "tier_breakdown": {
      "Compliant": 8,
      "LowRisk": 12,
      "ModerateRisk": 18,
      "HighRisk": 8,
      "Critical": 4
    }
  }
  ```

---

## 3. Stateless Backend Resilience & Client-Side Generation

### The Stateless Backend Challenge
When running in testing or edge deployment without an active PostgreSQL instance, the Rust engine runs in **Stateless In-Memory Mode**:
- Real-time scans (`/scan`, `/scan-sku`, `/scan-path`) work 100% and return full evaluation JSON.
- However, database query endpoints (`/api/v1/stats` and `/api/v1/inspections/:id/export/*`) return `HTTP 503: PostgreSQL database is not connected`.

### The Frontend Solution: Zero-Dependency Client Generation
Rather than failing or showing a blank screen, the frontend client was engineered with **native client-side document generators**:

1. **Client-Side CSV Generator (`src/utils/formatters.ts: generateCsvContent`):**
   - Parses the active `ComplianceReport` directly from memory.
   - Formats headers, statutory citations, detected OCR values, and remarks into an RFC 4180-compliant CSV string.
   - Saves to `FileSystem.cacheDirectory` and triggers `Sharing.shareAsync`.

2. **In-App Notice Viewer (`app/pdf-viewer.tsx`):**
   - Renders the complete Directorate of Legal Metrology Show-Cause Notice directly on screen.
   - Generates the official notice text document and triggers native share sheets.
   - **Result:** Officers can open, view, verify, and share both CSV and Notice documents with **zero reliance on backend database persistence**.
