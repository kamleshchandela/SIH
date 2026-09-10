# RAG Architecture & Legal Metrology Cognitive Copilot

> **Architectural blueprint, empirical Do's & Don'ts, ASCII topology, and implementation strategy for integrating Retrieval-Augmented Generation (RAG) into the Themis Legal Metrology Inspection Engine (SIH Problem Statement 26034).**

---

## 1. Executive Summary & The Evidentiary Dilemma

In legal metrology compliance enforcement under the **Legal Metrology Act, 2009**, statutory findings are subject to strict judicial scrutiny in compounding proceedings or magistrate courts. 

A core engineering dilemma arises when introducing Generative AI and RAG into regulatory systems:
- **Judicial Determinism**: An enforcement officer testifying under Section 36 cannot submit probabilistic guesses or hallucinated text as sworn evidence.
- **Regulatory Complexity**: India's Legal Metrology ecosystem spans the Principal Act (2009), the Packaged Commodities Rules (2011), the 2021 E-Commerce Amendments, the Jan Vishwas Act (2023), and hundreds of commodity-specific provisos and exemptions across Schedule II and FSSAI notifications.

To resolve this dilemma, Themis enforces a **Dual-Tier Decoupled Architecture**:
1. **Tier 1 (Deterministic Core)**: High-speed, memory-safe Rust + vectorized ONNX pipeline that extracts ground-truth pixels, computes bounding boxes, and calculates statutory penalties deterministically without LLMs.
2. **Tier 2 (Cognitive RAG Copilot)**: PostgreSQL `pgvector` + Local/Cloud LLM that retrieves statutory exemptions, drafts court-admissible show-cause notices, and provides conversational legal intelligence to field inspectors.

---

## 2. The Strict Do's and Don'ts of RAG in Legal Metrology

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                           RAG EVIDENTIARY MATRIX                                 │
├─────────────────────────────────────────┬────────────────────────────────────────┤
│          ❌ DO NOT DO (Anti-Patterns)    │         ✅ DO (High-Value RAG)          │
├─────────────────────────────────────────┼────────────────────────────────────────┤
│ 1. Text Extraction & OCR Correction:    │ 1. Statutory Exemption Resolution:     │
│    Never use an LLM/RAG to "guess" or   │    Retrieve category provisos          │
│    hallucinate corrupted numbers or text│    (e.g., Rule 6(1)(f) USP exemption   │
│    (e.g. converting "500m" to "500ml"   │    for packs ≤ 1L, or Rule 26 for      │
│    probabilistically without evidence). │    small packs ≤ 10g/10ml).            │
├─────────────────────────────────────────┼────────────────────────────────────────┤
│ 2. Compounding Penalty Math:            │ 2. Show-Cause Notice Drafting:         │
│    Never use an LLM to calculate fines. │    Synthesize court-admissible Form 1  │
│    Compounding amounts under the Jan    │    notices citing exact sections with  │
│    Vishwas Act (₹25,000 to ₹1,00,000)   │    embedded evidence coordinates.      │
│    are strict mathematical schedules.   │                                        │
├─────────────────────────────────────────┼────────────────────────────────────────┤
│ 3. Primary Violation Classification:    │ 3. Judicial Precedent & Case Search:   │
│    Never let an LLM decide if a rule is │    Search past compounding orders,     │
│    violated. Deterministic regexes and  │    state appellate judgments, and high │
│    spatial coordinate checks must gate  │    court rulings on packaging clauses. │
│    the statutory status.                │                                        │
├─────────────────────────────────────────┼────────────────────────────────────────┤
│ 4. Direct Online Web Scraping:          │ 4. Natural Language Officer Copilot:   │
│    Never use live LLM web crawlers that │    Allow inspectors to query dossiers: │
│    break against Cloudflare WAFs or     │    "Under what section can this brand  │
│    consume gigabytes in live demos.     │    compound their second offense?"     │
└─────────────────────────────────────────┴────────────────────────────────────────┘
```

---

## 3. End-to-End System Architecture (ASCII Topology)

```
========================================================================================
                          THEMIS DUAL-TIER INSPECTION TOPOLOGY
========================================================================================

  [ Packaging Image Dossier ] (Front, Back, Side, Top Panels via Camera / Desktop GUI)
              │
              ▼
  ┌──────────────────────────────────────────────────────────────────────────────────┐
  │                           TIER 1: DETERMINISTIC CORE                             │
  │                         (Rust Engine • 100% Offline)                             │
  ├──────────────────────────────────────────────────────────────────────────────────┤
  │                                                                                  │
  │   [ Raw Bytes / Filesystem ] ──▶ [ EXIF Normalizer (exif.rs) ]                   │
  │                                           │                                      │
  │                                           ▼                                      │
  │   [ PP-OCRv4 DBNet INT8 ] ─────▶ [ Multi-Quadrant Probe & Rotate (pipeline.rs) ] │
  │   (27.35 MB Vectorized CPU)               │                                      │
  │                                           ▼                                      │
  │   [ PP-OCRv4 CTC Recognizer ] ─▶ [ Inverse Coordinate Mapping (scale_x, scale_y)]│
  │                                           │                                      │
  │                                           ▼                                      │
  │   [ Deterministic Rule Engine ] ── [ Spatial 2D Adjacency & Regex Validation ]   │
  │                                           │                                      │
  │                                           ▼                                      │
  │                [ Statutory Findings JSON: Violations, Fines, BBoxes ]            │
  └───────────────────────────────────────────┬──────────────────────────────────────┘
                                              │
                         Verified Facts & Detected Attributes
                                              │
                                              ▼
  ┌──────────────────────────────────────────────────────────────────────────────────┐
  │                           TIER 2: COGNITIVE RAG COPILOT                          │
  │                      (PostgreSQL pgvector + Local / Cloud LLM)                   │
  ├──────────────────────────────────────────────────────────────────────────────────┤
  │                                                                                  │
  │  ┌────────────────────────┐      Embedding Query     ┌────────────────────────┐  │
  │  │ Regulatory Knowledge   │ ───────────────────────▶ │   pgvector Semantic    │  │
  │  │ Base (Acts, Rules,     │                          │   Vector Store         │  │
  │  │ Schedules, Amendments) │ ◀─────────────────────── │   (IVFFlat / HNSW)     │  │
  │  └────────────────────────┘      Retrieved Provisos  └────────────────────────┘  │
  │               │                                                   ▲              │
  │               ▼                                                   │              │
  │   ┌────────────────────────────────────────────────────────────┐  │              │
  │   │ Proviso & Exemption Filter Engine                          │ ─┘              │
  │   │ • Cross-checks detected commodity category & pack size     │                 │
  │   │ • Automatically clears false warnings (e.g. USP on ≤ 1L)   │                 │
  │   └─────────────────────────────┬──────────────────────────────┘                 │
  │                                 │                                                │
  │                                 ▼                                                │
  │   ┌────────────────────────────────────────────────────────────┐                 │
  │   │ Court-Admissible Show-Cause Notice Generator               │                 │
  │   │ • Formulates statutory Section 36 Notice of Violation      │                 │
  │   │ • Embeds manufacturer address, PIN, and evidence photo     │                 │
  │   │ • Inserts exact compounding liability under Jan Vishwas    │                 │
  │   └─────────────────────────────┬──────────────────────────────┘                 │
  │                                 │                                                │
  │                                 ▼                                                │
  │   ┌────────────────────────────────────────────────────────────┐                 │
  │   │ Interactive Auditor Assistant & Citizen Grievance Portal   │                 │
  │   │ • "Why was this penalty ₹25,000 instead of ₹50,000?"       │                 │
  │   │ • "What is the compounding deadline for this notice?"      │                 │
  │   └────────────────────────────────────────────────────────────┘                 │
  └──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Key RAG Use Cases & Technical Implementations

### Use Case 1: Statutory Proviso & Category Exemption Engine

**The Problem**:
A naive regex flag marks `UnitSalePrice` as a warning on a `500ml` dishwasher bottle. However, under the 2021 LMPC Amendments:
> *Rule 6(1)(f): The unit sale price shall be declared on packages containing more than 1 kg or 1 litre.*

Since $500\text{ml} \le 1000\text{ml}$, the package is legally exempt. Hardcoding thousands of exemptions for cosmetics, electricals, tea, and confectionery in regex is brittle.

**The RAG Solution**:
1. Ingest all official Gazette notifications and LMPC amendments into chunked vectors with metadata:
   ```json
   {
     "rule": "Rule 6(1)(f)",
     "clause": "Unit Sale Price",
     "condition": "volume <= 1000ml OR weight <= 1000g",
     "exemption_type": "Mandatory declaration waived"
   }
   ```
2. When Tier 1 outputs `{ "field": "UnitSalePrice", "detected_volume": "500ml" }`, Tier 2 executes a filtered semantic retrieval query.
3. The Copilot updates the audit finding from `Warning` to `Compliant (Statutorily Exempt under Rule 6(1)(f) proviso)`.

---

### Use Case 2: Automated Statutory Show-Cause Notice Generation

**The Problem**:
Enforcement officers currently spend 30–45 minutes per product manually typing violation notices, copying addresses, looking up legal section numbers, and calculating compounding fees.

**The RAG Solution**:
The Copilot takes the verified Tier 1 JSON payload and synthesizes an official **Form 1 / Show Cause Notice**:

```
========================================================================================
                 GOVERNMENT OF INDIA • MINISTRY OF CONSUMER AFFAIRS
                  LEGAL METROLOGY DIVISION • ENFORCEMENT NOTICE
========================================================================================

NOTICE UNDER SECTION 36(1) OF THE LEGAL METROLOGY ACT, 2009
READ WITH RULE 6 & RULE 32 OF THE LEGAL METROLOGY (PACKAGED COMMODITIES) RULES, 2011

Notice Reference: THEMIS/DOCA/2026/INSP-073844
Date of Inspection: 08 September 2026

TO:
M/s Hindustan Unilever Limited / Packer Entity
Plot No. 42, Industrial Area, Sector 5, Haridwar - 249403, Uttarakhand

COMMODITY UNDER AUDIT:
Dishwashing Liquid / Savemore Dishwash Liquid (Declared Volume: 500 ml)

SUMMARY OF STATUTORY NON-COMPLIANCE:
During digital metrological inspection of product evidence under Inspection ID
INSP-073844, the following contraventions of the Legal Metrology Act, 2009 were recorded:

1. CONTRAVENTION OF RULE 6(1)(c) & RULE 13:
   Non-standard or illegible Net Quantity declaration. The net volume symbol was
   recorded as truncated non-standard SI unit '500m' without certified SI metric symbol.

COMPOUNDING LIABILITY & PENALTY ASSESSMENT:
Under Section 36(1) of the Legal Metrology Act, 2009 read with Section 49
(as amended by the Jan Vishwas (Amendment of Provisions) Act, 2023):
• Baseline Statutory Compounding Liability: ₹25,000 INR (First Offense)
• Maximum Judicial Penalty: ₹1,00,000 INR

TAKE NOTICE:
You are hereby called upon to show cause within 15 (fifteen) days from the receipt
of this notice as to why compounding proceedings should not be initiated against you.

EVIDENTIARY EXHIBITS ATTACHED:
• Exhibit A: High-Resolution Photographic Evidence [PXL_20260906_162848337.jpg]
• Exhibit B: Verified OCR Coordinate Matrix & Laplacian Sharpness Telemetry (Score: 71.4%)
========================================================================================
```

---

### Use Case 3: Interactive Auditor & Adjudication Assistant

Field inspectors can query the inspection dossier using natural language:

* **Query**: *"Why was this product charged ₹25,000 rather than ₹50,000?"*
* **RAG Response**:
  > *"Under Section 36(1) of the Legal Metrology Act, 2009 read with Section 49 (as amended by the Jan Vishwas Act, 2023), the compounding fee for a first offense under Rule 6(1) is fixed at ₹25,000. PostgreSQL registry search shows no prior offenses on record for manufacturer PIN 249403 in the past 3 years. A subsequent violation within 3 years would incur ₹50,000."*

---

## 5. Judge Presentation & Evaluation Strategy (Winning SIH 26034)

When SIH evaluators ask:
> *"Did you just plug this into an LLM or ChatGPT to check compliance?"*

### The Winning Defense:
> *"No, evaluators. Relying solely on an LLM for regulatory enforcement is an evidentiary anti-pattern. Large language models hallucinate, struggle with spatial coordinates, have non-deterministic outputs, and cannot be introduced as legal evidence in an Indian court under the Bharatiya Sakshya Adhiniyam, 2023.*
>
> *Instead, Themis uses a **Dual-Tier Decoupled Architecture**:*
> *1. **The Core Engine is 100% Deterministic Rust**: We run vectorized INT8 ONNX DBNet detection and PP-OCRv4 recognition that performs exact pixel-level coordinate mapping and rule math in milliseconds on CPU with zero hallucinations.*
> *2. **RAG is strictly an Exemption & Legal Synthesis Layer**: We use PostgreSQL `pgvector` to store the Legal Metrology Act, LMPC amendments, and compounding schedules. The RAG Copilot checks category-specific provisos (like USP exemptions on packs $\le 1\text{L}$) and drafts court-admissible Form 1 Show-Cause Notices in seconds.*
>
> *This delivers the best of both worlds: **uncompromising evidentiary determinism for the court, and generative intelligence for the legal officer**."*
