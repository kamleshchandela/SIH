# 01 — Problem Statement & Legal Regulatory Framework

## 1. Problem Statement Analysis (DoCA / SIH Problem Statement 26034)

### Title
**"Software System to check compliance of Packaged Commodities under Legal Metrology (Packaged Commodities) Rules, 2011 by scanning products, images and labels."**

### Organization & Department
- **Ministry:** Ministry of Consumer Affairs, Food & Public Distribution
- **Department:** Department of Consumer Affairs (DoCA), Government of India
- **Category:** Software / Miscellaneous

### Executive Context
Pre-packaged commodities sold across retail stores, hypermarkets, and e-commerce platforms (Blinkit, Zepto, Amazon, Flipkart) in India are legally mandated to display mandatory statutory declarations under the **Legal Metrology Act, 2009** and the **Legal Metrology (Packaged Commodities) Rules, 2011 (LMPC Rules, 2011)**.

These declarations include:
1. Name and complete address of the manufacturer / packer / importer
2. Generic or common name of the commodity
3. Net quantity in standard SI metric units
4. Maximum Retail Price (MRP) inclusive of all taxes
5. Month and year of manufacture, packing, or import
6. Consumer grievance redressal contact details (phone and email)
7. Country of Origin (mandatory for all domestic and imported goods under 2021 amendments)
8. Unit Sale Price (mandatory for packages > 1kg / 1L)

Manual enforcement across millions of SKUs is physically impossible for state legal metrology inspectorates. This leads to rampant consumer deception, including:
- **Misleading unit declarations** (e.g., using illegal non-standard abbreviations like `gm`, `gms`, `ml.` to obfuscate true weights).
- **Missing or obscured MRP declarations**.
- **Missing manufacturer postal addresses or PIN codes**, preventing accountability.
- **Undersized font sizes** that violate minimum numeral height standards under Schedule II.

The solution requires an automated, robust software system capable of scanning packaging images, extracting textual declarations via Optical Character Recognition (OCR), evaluating extracted data against statutory clauses, highlighting violations visually, calculating compoundable penalties, and generating legal inspection notices.

---

## 2. Analysis of the Government Portal & Regulatory PDFs

The problem statement provided a reference link:
`https://consumeraffairs.gov.in/pages/legal-metrology-act`

### The "Dataset Link" Reality in Government Hackathons
On the Department of Consumer Affairs portal, the page lists over 50 government gazette notifications, corrigenda, and administrative statutory instruments. 

**Critical Distinction:** These documents are **NOT** computer vision / image training datasets. They represent the **Legal Specification & Statutory Ground Truth** that the software engine must programmatically verify.

### Separation of Noise vs. Critical Legal Statutes

| Category on Portal | Documents Listed | Status for Project | Technical Rationale |
|---|---|---|---|
| **LMPC Core Rules** | Legal Metrology (Packaged Commodities) Rules, 2011 | **CRITICAL (Primary Rulebook)** | The foundation of all packaging checks (Rule 6, Rule 7, Rule 13, Schedule I, Schedule II). |
| **2021 Amendments** | LMPC (Amendment) Rules, 2021 (GSR 779(E)) | **CRITICAL (Modern Clauses)** | Mandated **Unit Sale Price (USP)** for packs $> 1\text{kg}$ or $> 1\text{L}$ and mandatory **Country of Origin**. |
| **Jan Vishwas Act** | Jan Vishwas (Amendment of Provisions) Act, 2023 / 2026 | **CRITICAL (Penalty Decriminalization)** | Replaced criminal imprisonment with compoundable monetary fines under Section 49 / Section 36(1). Essential for generating accurate violation notices. |
| **Parent Act (2009)** | The Legal Metrology Act, 2009 | **REFERENCE** | Contains statutory authority for search, seizure, and inspection under Section 18 and Section 36. |
| **National Standards Rules** | Standards of weights and physical prototypes (2011) | **IRRELEVANT** | Governs calibration of physical balance weights and laboratory prototypes. |
| **Approval of Models Rules** | Approval of weighing machine manufacturing designs (2011) | **IRRELEVANT** | Regulates hardware manufacturers of electronic weighing scales and weighbridges. |
| **PBMSEC Act, 1980** | Prevention of Blackmarketing & Maintenance of Supplies | **IRRELEVANT** | Anti-hoarding penal legislation for emergency ration grain distribution. |
| **Essential Commodities Act** | Price controls on fertilizers and raw sugar | **IRRELEVANT** | Price capping on bulk commodities; irrelevant to retail FMCG packaging compliance. |
| **Recruitment Rules** | Civil service hiring rules for inspectors | **IRRELEVANT** | Departmental HR rules for government civil service staffing. |
| **Allocation of Business** | Cabinet secretariat departmental jurisdiction | **IRRELEVANT** | Government cabinet protocol rules. |

---

## 3. The 3 Essential Regulatory Documents Retained

The system downloads and implements the exact clauses from three core legal statutes stored in `dataset/rules/`:

### 1. `LMPC_Rules_2011.pdf` (Primary Rulebook)
- **Rule 6(1)(a):** Every package must bear the name and complete address of the manufacturer, or if the manufacturer is not the packer, the name and complete address of the manufacturer and packer, or if imported, the name and complete address of the importer.
- **Rule 6(1)(b):** Common or generic names of the commodity contained in the package.
- **Rule 6(1)(c):** Net quantity in terms of standard unit of weight or measure.
- **Rule 6(1)(d):** Month and year in which the commodity is manufactured, packed, or imported.
- **Rule 6(1)(e):** Maximum Retail Price (MRP) in standard format inclusive of all taxes.
- **Rule 6(1)(g):** Name, address, telephone number, and email address of the person or office that can be contacted in case of consumer complaints.
- **Rule 7 & Schedule II:** Minimum height of numerals and letters based on the net quantity and area of the Principal Display Panel (PDP).
- **Rule 13:** Prescribed SI symbols for units of measurement. Only `g`, `kg`, `ml`, `l`, `m`, `cm`, `mm`, `N`, and `units` are legal. Symbols must be in lowercase (except `L` or `l` for litre), must never use plurals (e.g. `gms` is strictly illegal), and must never include a trailing period/dot (e.g. `gm.` or `ml.` is strictly illegal).

### 2. `LMPC_Amendment_2021.pdf` (Modern Enforcement)
- **Rule 6(1)(da):** Mandatory declaration of the Country of Origin on every retail commodity.
- **Rule 6(1)(f):** Mandatory declaration of the **Unit Sale Price (USP)** where the net quantity of the package exceeds $1\text{ kg}$ or $1\text{ litre}$, or where package contains multiple items. Format: `₹ XX.XX per g` or `₹ XX.XX per ml`.

### 3. `Jan_Vishwas_Act.pdf` (Statutory Penalties & Decriminalization)
- **Amendment to Section 36(1) of Legal Metrology Act, 2009:**
  Any person who manufactures, packs, imports, sells, or offers for sale any non-standard package violating Rule 6 shall be liable to a penalty:
  - **First offence:** Compounding fine up to **₹25,000 INR** per violation.
  - **Second offence:** Compounding fine up to **₹50,000 INR**.
  - **Subsequent offences:** Compounding fine up to **₹1,00,000 INR**.
- The software automatically computes and itemizes compounding liability under Section 49 in every generated inspection report.
