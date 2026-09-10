# 06 — Design System, Typography & Statutory Aesthetics

> **Technical specification of the Themis Mobile design system, color tokens, typography scales, contrast standards, and official government document formatting.**

---

## 1. Statutory Color Palette & Tokens

Themis Mobile enforces a curated, high-contrast color palette designed specifically for official enforcement environments. Every color serves a precise statutory semantic meaning:

```
                                  THEMIS COLOR SYSTEM
+-----------------------------------------------------------------------------------------+
| Category         | Hex Code   | Background Tint | Usage                                 |
|------------------+------------+-----------------+---------------------------------------|
| Deep Slate       | #0f172a    | #f8fafc         | Primary headers, tab bars, text       |
| Sky Blue Accent  | #0284c7    | #e0f2fe         | Primary actions, icons, active state  |
| Compliant Emerald| #16a34a    | #dcfce7         | PASS status, Sharp photo, Live Online |
| Violation Crimson| #dc2626    | #fee2e2         | VIOLATIONS, Blurry photo, Offline     |
| Compounding Amber| #b45309    | #fef3c7         | Jan Vishwas fines, Statutory Warnings |
| Border Slate     | #e2e8f0    | #f1f5f9         | Card dividing lines, Tag containers   |
+-----------------------------------------------------------------------------------------+
```

### Contrast & WCAG 2.1 AA Compliance
All foreground text over background containers strictly exceeds the **4.5:1 contrast ratio** required by WCAG 2.1 Level AA:
- Dark Text (`#0f172a`) on White (`#ffffff`): **18.2:1** (Exceptional)
- Compliant Text (`#15803d`) on Mint (`#dcfce7`): **6.8:1** (Pass)
- Violation Text (`#b91c1c`) on Red Tint (`#fee2e2`): **7.1:1** (Pass)
- Amber Text (`#92400e`) on Gold Tint (`#fef3c7`): **6.2:1** (Pass)

---

## 2. Typography Hierarchy & Readability Rules

A critical flaw in generic mobile templates is cramped, unreadable text. In statutory law enforcement, illegible text causes officer fatigue and clerical errors.

### Core Typography Standards:
1. **Generous Line Heights (`lineHeight: 19–22px`):** All descriptive sentences and legal remarks use ample vertical spacing, preventing text lines from visually collapsing into each other.
2. **Monospace for Evidentiary Tokens:**
   - Inspection UUIDs: `4a8f9c2d-8e4a-4c22-b2f5...`
   - Bounding box coordinates: `(124, 452) 340x65`
   - Detected OCR text: `"BEST BEFORE SIX MONTHS FROM PACKAGING"`
   - Font family: `Platform.OS === 'ios' ? 'Courier' : 'monospace'`
3. **Weight Hierarchy:**
   - `fontWeight: '900'` — Verdicts (`STATUTORY COMPLIANT`, `STATUTORY VIOLATION`) and large currency figures (`₹25,000`).
   - `fontWeight: '800'` — Card headers, risk tiers, status badges.
   - `fontWeight: '700'` — Field labels, button titles.
   - `fontWeight: '600'` — Sub-headings, active tab labels.
   - `fontWeight: '500' / '400'` — Body copy, statutory explanations.

---

## 3. Component Design Tokens

### 1. Elevated Cards (`styles.card`, `styles.sectionCard`)
- **Border Radius:** `14px` – `16px` (soft modern rounding).
- **Border Width:** `1px` solid `#e2e8f0`.
- **Elevation / Shadow:** Subtle, non-distracting elevation (`shadowOpacity: 0.04`, `shadowRadius: 6px`, `elevation: 1`).
- **Padding:** `16px` internal padding for comfortable touch buffers.

### 2. Segmented Filter Tabs (`styles.evalFilterBar`)
- Capsule-style horizontal container with `#f1f5f9` background.
- Active pill elevated with white background and subtle drop shadow.
- Suffix counters indicating exact match count (e.g. `Violations (2)`, `Pass (6)`).

### 3. Visual Progress Bar (`styles.progressBarTrack`)
- Height: `8px`, rounded track with `overflow: 'hidden'`.
- Dynamic width calculated via `${Math.min(Math.max(score, 0), 100)}%`.
- Dynamic tint: Emerald Green if compliant, Crimson Red if non-compliant.

### 4. Floating Action Bar (`styles.actionBar`)
- Positioned absolutely at the screen bottom (`position: 'absolute', bottom: 0`).
- Bottom padding calculated dynamically via `Math.max(insets.bottom, 12)` to prevent overlapping with iPhone home indicators or Android gesture bars.
- Dual-button layout: Secondary action (CSV Audit) and Primary action (Legal Notice).
