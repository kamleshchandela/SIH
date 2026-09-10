# 01 — Problem Statement & Mobile UX Framework

> **A comprehensive analysis of Smart India Hackathon (SIH) Problem Statement 26034 from the perspective of field enforcement mobility, statutory officer personas, and frontline UX design.**

---

## 1. Statutory Context: SIH Problem Statement 26034

The **Ministry of Consumer Affairs, Food & Public Distribution (Directorate of Legal Metrology)** tasked hackathon teams with solving a critical national enforcement bottleneck:

> **"Development of an Automated Image-Based Compliance Evaluation System for Packaged Commodities under the Legal Metrology (Packaged Commodities) Rules, 2011 and Legal Metrology Act, 2009."**

### The Enforcement Challenge:
1. **Billions of Pre-Packaged Commodities:** India's retail ecosystem encompasses millions of retail stores, hypermarkets, and e-commerce fulfillment warehouses selling packaged commodities.
2. **Mandatory Rule 6 Declarations:** Under Rule 6(1) of the LMPC Rules, every package must mandatorily declare:
   - Manufacturer / Packer / Importer Name & Complete Address
   - Generic or Common Name of the Commodity
   - Net Quantity in standard SI units (Rule 13 compliance)
   - Month and Year of Manufacture / Pre-packing / Import
   - Maximum Retail Price (MRP) inclusive of all taxes
   - Consumer Care Details (Name, Address, Telephone, Email)
   - Unit Sale Price (USP) where mandatory
   - Country of Origin (for imported commodities)
3. **Severe Human Bottleneck:** Field Metrology Officers manually inspect packages with hand-held magnifying glasses and physical rulebooks. Inspecting a single product SKU with 4 panels takes 10–15 minutes of manual cross-referencing.
4. **Sub-optimal Record Keeping:** Manual inspection memos lead to clerical discrepancies, contested citations in consumer courts, and compounding fee calculation errors.

---

## 2. The Field Officer Persona & Environmental Constraints

Unlike corporate enterprise software used in air-conditioned offices on 4K monitors, **Themis Mobile** is built for real-world field conditions:

### Operational Realities of Legal Metrology Officers:
| Environmental Constraint | Impact on Mobile UX | Frontend Architectural Mitigation |
|---|---|---|
| **Harsh Glare & Outdoor Lighting** | Low-contrast or washed-out UI themes become unreadable in outdoor markets or wholesale mandis. | High-contrast Slate & Crisp White theme (`#0f172a`, `#ffffff`) with bold saturated badges (`#15803d`, `#b91c1c`). Zero low-contrast grey-on-grey text. |
| **Physical Commodity Handling** | Officers hold the physical package in one hand and their smartphone in the other hand. | Large 48px+ touch targets, bottom-anchored action bars, one-handed thumb navigation, and swipeable tabs. |
| **Unstable Field Connectivity** | Wholesale warehouses, basements, and rural markets frequently suffer from spotty 4G/5G coverage. | In-app document generation, cached auth tokens, intelligent auto-reconnect, and stateless fallback resilience. |
| **High Legal Scrutiny** | Reports are used as evidence in compounding proceedings under the Jan Vishwas Act, 2023. | **Zero dummy data.** Every character, score, confidence percentage, and statutory citation maps directly to the active AI OCR engine. |

---

## 3. Core UX Architectural Principles

### Principle 1: 100% Real Statutory Data Flow (Zero Dummy Data)
In statutory law enforcement, displaying mocked values, hardcoded penalty numbers, or placeholder test strings is legally dangerous. 
- All data rendered on the **Dashboard (`index.tsx`)**, **Inspection Detail (`result.tsx`)**, **CSV Audit (`csv-viewer.tsx`)**, and **Legal Notice (`pdf-viewer.tsx`)** is derived **100% from active backend engine responses**.
- If a data field is unavailable (e.g., in stateless database mode), the UI transparently communicates the exact engine state rather than masking it with synthetic figures.

### Principle 2: The Multi-Panel Packaging Reality
Physical packaged commodities are 3-dimensional objects (cylinders, pouches, tetra packs, boxes). A product's declarations are almost never printed on a single panel:
- **Front Panel:** Brand Name, Product Classification, Net Quantity.
- **Back Panel:** Ingredients, FSSAI License, Storage Instructions, Barcode.
- **Side Panel 1:** MRP, Unit Sale Price, Batch Number, Date of Packing.
- **Side Panel 2:** Manufacturer Name, Factory Address, Consumer Care Cell.

**UX Innovation — The Multi-Panel SKU Strip:**
In `app/(tabs)/scan.tsx`, officers can capture multiple photos sequentially. Each captured panel is displayed in a horizontal preview strip with delete/re-shoot capabilities. When submitted, the backend pools all text tokens into a single unified SKU evaluation report.

### Principle 3: Instant In-App Document Verification (View Before Sharing)
Field officers should never be forced to blindly download a file to device storage and guess whether third-party spreadsheet or PDF apps can open it.
- **In-App CSV Viewer (`csv-viewer.tsx`):** Renders a responsive, horizontally scrollable statutory audit grid directly on the smartphone screen.
- **In-App Notice Viewer (`pdf-viewer.tsx`):** Renders the official Directorate of Legal Metrology Show-Cause Notice complete with Section 36(1) charges, Rule 6 violations, and compounding fee calculations directly on screen.
- **Native Share Bridge:** Both screens feature a one-tap **"Share / Save"** button connecting to native iOS and Android share sheets (WhatsApp, Email, AirDrop, Files app).

### Principle 4: Deep Indian Statutory Localization
- **Jan Vishwas (Amendment of Provisions) Act, 2023:** Decriminalized technical packaging errors into civil compounding penalties. The mobile app prominently calculates and highlights first-offense compounding amounts.
- **Indian Rupee (INR) Formatting:** All fines and MRP values are strictly formatted using the Indian numbering system (`₹25,000`, `₹1,00,000`, `₹2,50,000`) rather than Western millions.
