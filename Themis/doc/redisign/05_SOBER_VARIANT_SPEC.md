# 05 — Sober Variant Spec (Judge-Safe Theme)

**Status:** spec approved, unbuilt. **Goal:** a one-tap alternate skin that reads
"serious government tool" to a conservative judging panel while keeping the same
screens, same data, same Rust backend. Zero `BackdropFilter`, zero wallpaper
compositing — solid surfaces throughout, so it holds 60fps on any device with no
quality tiers involved.

**Design reference:** dark travel-app Dribbble set (Dashboard / Trip Plan / Bali
detail). Why it works as the "old-judge" skin: classic information hierarchy
(title → cards → list), high-contrast text, static layout — with just enough
modern chrome (docked FAB, timeline pins, badge clips) to avoid looking dated.
Modern bones, sober skin.

---

## 1. Palette (maps 1:1 onto existing theme slots)

| Slot | Sober value | Current glass value it replaces |
|---|---|---|
| Page bg | `#101216` near-black | wallpaper image |
| Surface / card | `#1B1E25` → card `#23262F` | `GlassContainer` translucent fill |
| Inset row | `#262A34` | inner glass rows |
| Accent (CTA, active) | saffron-amber `#E8762B` (gov-appropriate orange) | teal/cyan glows |
| Category pins | red `#FF4A3D` / green `#2ECC71` / blue `#2E9BFF` / purple `#A259FF` | clause severity colors (reuse!) |
| Text primary / secondary | `#FFFFFF` / `#9AA0AE` | same |
| Divider / dashed line | `#3A3E48` | hairline glass borders |

Typography: keep the app's existing family (one less variable for judges to
notice); tighten letter-spacing on headings, sentence-case body.

## 2. The two "hard" widgets, demystified

### 2a. Docked center FAB with concave cradle ("floating search icon + half circle")

What you see: bottom bar with rounded top corners, four dim icons, and a raised
search button sitting in a semicircular bite taken out of the bar's top edge.

Build (custom painter, ~100 lines, half a day to pixel-match):

- `Stack`: bar background (`CustomPaint`, height 84, top corners r=30) with the
  FAB as a separate `Positioned(bottom: 52)` widget on top — so hit-testing is
  free and the painter never handles taps.
- Cradle path, bar width `W`, center `cx = W/2`, cradle radius `R = 38`:
  top edge runs left→right, then `arcTo` a **concave upper semicircle**
  centered at `(cx, 0)` from angle π to 2π (i.e. `(cx−R,0)` → `(cx+R,0)`,
  bulging up to `(cx,−R)`), then continues to the right corner. Fill solid
  `#23242E` + 1px top highlight + soft upward shadow.
- FAB: 62dp circle on the 76dp cradle → 7px dark gap ring each side, which is
  what sells the "floating" illusion. Slight elevation, search icon, tap = scan.
- Shortcut alternative (1 hour, 90% fidelity): stock `BottomAppBar` with
  `CircularNotchedRectangle` + centered `FloatingActionButton` — Flutter ships
  this exact pattern; only the rounded top corners need the custom painter.

Themis mapping: icons become Home / Inspect / (scan FAB) / Reports / Engine.
Active tab = white filled icon, rest dim `#6B7280`.

### 2b. Timeline pin bubbles ("flight card bubbles")

What you see: dashed vertical line; each card has a colored node on its left
edge — a small dot on the line, a short capsule tail, and a 36dp filled circle
with a white glyph.

Build (no painter math beyond a dashed line, half a day):

- **One** full-height `CustomPaint` dashed line (`dash 6 / gap 6, #3A3E48, 2px`)
  behind the list — painted once per list, not per card, so no per-row cost and
  no segment-continuity bugs.
- Each row: `Padding(left: 56)` card + `Positioned` node = `Row(dot 8dp,
  capsule tail, circle 36dp with `Icon` 18dp white)`. Pure widgets, no paths.
- Colors carry meaning for free: red = MRP clause, green = date/expiry,
  blue = net-quantity, purple = font/packaging — the exact severity palette the
  checklist already uses.

Themis mapping: Trip Plan days → inspection clauses; `Flight 8:30 am` row →
`MRP Violation · ₹48,000`; `From/To` sub-rows → rule citation + measured value.

### 2c. Everything else on those screens is layout, not widgets

- **Price badge** (looks like a custom clip — it's one line):
  `BorderRadius.only(topLeft: 20, bottomRight: 20)` on a saffron container
  pinned top-left of the image card. `₹48,000` fine / `14–20 June` → seizure ID.
- **Snap cards + vertical rail:** `PageView(viewportFraction: 0.62)` for
  Bali/Lahore cards; `RotatedBox(quarterTurns: 3)` text for Cycling/Mountain →
  Food/Textiles/Electronics category rail.
- **Detail hero:** image with bottom sheet-style dark card overlapping via
  `Stack` + `Positioned`; thumbnail row = horizontal `ListView` of evidence photos.

## 3. Screen-by-screen map (reuse, don't rebuild)

| Reference screen | Becomes | Reused glass widget (with `enableBlur: false` + solid fill) |
|---|---|---|
| Dashboard | Home: category rail + package snap cards + recent-people row → recent inspections | `GlassContainer`, snap `PageView`, avatar row |
| Trip Plan | Inspect checklist: pin timeline of clauses, day tabs → rule tabs | timeline (§2b), tab strip |
| Bali detail | Dossier: hero evidence photo, saffron fee block, violation summary, photo thumbs | hero `Stack`, fee badge (§2c) |
| Bottom bar + FAB | Global nav, scan FAB docked in cradle | §2a |

Data layer untouched: same providers, same engine API, same PDF/export.

## 4. Toggle + perf

- New `soberMode` bool next to the Glass Quality card in Engine settings
  (`GlassPerfService`, persisted in `themis_glass_config.json`): hides
  `FluidBackground` (solid `#101216`), forces all `GlassContainer`s to solid
  fills, swaps `glass_bottom_bar` for the notched bar.
- Perf: no blur passes anywhere → 60fps trivially, tiers irrelevant in sober
  mode. Demo line if a judge frowns: *"high-contrast field mode for outdoor
  readability"* — a taste complaint becomes an accessibility feature.
- Accessibility bonus: contrast ratios pass WCAG AA, which the glass theme
  cannot claim — say that out loud only if asked.

## 5. Build order + effort (~2 days)

1. Notched bottom bar (§2a) — 0.5 day, standalone, testable on any screen.
2. Pin timeline (§2b) on the Inspect checklist — 0.5 day.
3. Badge clip + snap cards (§2c) on Home — 0.5 day.
4. Dossier hero re-skin + sober toggle wiring — 0.5 day.
