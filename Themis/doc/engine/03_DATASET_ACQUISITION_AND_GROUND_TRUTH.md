# 03 — Dataset Acquisition & Empirical Ground Truth

## 1. Ground Truth Problem in Regulatory Compliance

In real-world retail enforcement, compliance auditing cannot rely on synthetic mockups or clean text files. Systems must evaluate **real packaging under physical constraints**:
- Glossy, reflective plastic pouches (e.g. Kurkure, Lays)
- Curved cylindrical bottles and cans (e.g. Sting, Coke, Mountain Dew)
- Foil packaging with creasing and glare (e.g. Kissan ketchup pouches)
- Multilingual and crowded back-of-pack panels containing nutritional facts, ingredients, FSSAI licenses, and barcodes.

---

## 2. Real FMCG Packaging Dataset Acquisition

To build an empirical testbed without relying on non-existent government training datasets, a high-throughput extraction pipeline was developed in [`scripts/fetch_product_dataset.py`](file:///home/arch/Projects/backbone/scripts/fetch_product_dataset.py).

### Technical Pipeline Specifications:
- **Data Provider:** Open Food Facts India (`world.openfoodfacts.net/api/v2/search`)
- **Zero Third-Party Dependencies:** Implemented using Python 3 standard library (`urllib.request`, `json`, `concurrent.futures`, `pathlib`).
- **Parallel Fetching:** 4 worker threads utilizing `ThreadPoolExecutor`.
- **Resolution Upgrade:** Thumbnail URLs (`.400.jpg`) are programmatically rewritten to master raw scans (`.full.jpg`) to maximize character clarity for OCR.
- **Scope:** 50 diverse Indian household products, totaling **199 high-resolution images** spanning:
  - Biscuits & Confectionery (Parle-G, Oreo, Bourbon, Marie Gold, Cadbury Dairy Milk, Jimjam)
  - Instant Noodles & Ready Meals (Maggi 2-Minute Noodles)
  - Savory Snacks & Extruded Chips (Kurkure Masala Munch, Lay's American Style, Lay's Classic Salted)
  - Dairy & Staples (Amul Pasteurized Butter, Amul Masti Buttermilk, Tata Salt)
  - Sauces & Condiments (Kissan Fresh Tomato Ketchup pouches and bottles, Schezwan Chutney)
  - Beverages (Rooh Afza, Maaza 1.2L, Coca-Cola 750ml, Thums Up, Sprite, Mountain Dew, Storia Coconut Water 1L, Bisleri, Kinley)

---

## 3. Image Panel Taxonomy & Extraction Mapping

Each product directory under [`dataset/real_products/{barcode}_{name}/`](file:///home/arch/Projects/backbone/dataset/real_products/) contains:

| File Name | Panel Type | Target Declarations to Verify under LMPC Rules |
|---|---|---|
| **`front.jpg`** | Principal Display Panel (PDP) | Brand Name, Common / Generic Commodity Identity (Rule 6(1)(b)), Vegetarian/Non-Vegetarian logo. |
| **`panel_raw_1.jpg`** | Primary Compliance Panel | **Net Weight / Volume** (Rule 6(1)(c)), **Manufacturer / Packer address & PIN** (Rule 6(1)(a)), **Consumer Care phone/email** (Rule 6(1)(g)), **Country of Origin** (Rule 6(1)(da)), **Barcode & QR code**. |
| **`panel_raw_2.jpg`** | Technical & Legal Panel | **MRP (incl. of all taxes)** (Rule 6(1)(e)), **Unit Sale Price** (Rule 6(1)(f)), **Date of Manufacture/Packing** (Rule 6(1)(d)), **Ingredients & Nutritional Facts**. |
| **`metadata.json`** | Ground Truth Catalog Data | Verified EAN-13 barcode, official product title, declared nominal quantity, brands, categories. |

### Case Study: Kissan Fresh Tomato Ketchup (`8901030921667`)
Inspecting `dataset/real_products/8901030921667_kissan/panel_raw_1.jpg`:
- **Declared Net Quantity:** `NET WEIGHT: 1.1 kg`
  - *Legal Implication:* Because net quantity exceeds $1\text{ kg}$, Rule 6(1)(f) mandates that a **Unit Sale Price** (e.g. `₹ XX.XX per kg`) must be printed.
- **Consumer Care Declaration:**
  - `LEVERCARE-QUERY/FEEDBACK: TOLL FREE: 1800-10-2222`
  - `PO BOX 14760, MUMBAI 400099`
  - `LEVER.CARE@UNILEVER.COM`
  - *Legal Implication:* Fully complies with Rule 6(1)(g) which requires both phone and email redressal channels.
- **Manufacturer Identity:**
  - `Hindustan Unilever Limited` with registered postal PIN code.
  - *Legal Implication:* Complies with Rule 6(1)(a).

---

## 4. Synthetic Label Generation Strategy for Edge Testing

To stress-test edge-case legal violations that law-abiding national FMCG brands rarely commit on production lines, a synthetic generator creates intentional violations:
1. **Rule 13 Violation Injection:** Substituting standard `500 g` with non-standard `500 gm`, `500 gms`, `500 GM.`, or `1.5 kgs.` to verify that the regex parser flags them immediately.
2. **Missing Tax Clause Injection:** Rendering `MRP Rs. 150.00` without the mandatory phrase `(inclusive of all taxes)`.
3. **Missing Unit Sale Price:** Rendering a `2 kg` detergent or flour pack with an MRP but omitting the price per kilogram.
4. **Undersized Numeral Heights:** Rendering numerals below the minimum prescribed height (e.g. 1.2mm on a $> 1\text{kg}$ panel where 4.0mm is required under Schedule II).
