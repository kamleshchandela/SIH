# 06 — Sober Red-Only Skin, Reference Dashboard & Metrics Merge

**Status:** shipped on device (release APK 115.6MB, Pixel 4a 5G), sober default ON.
**Follows:** ch.05 spec — this chapter records what was actually built, where it
deviated, and what is left for tomorrow.

## 1. Red-only purge (reference light version as law)

The reference light theme settled the palette debate: every CTA, badge, bar and
FAB is red/orange — no blue anywhere. Rule now enforced in sober mode:

- Single choke point: `SoberTheme.swap(glassColor, sober)` in
  `lib/theme/sober_theme.dart`. Brand blues (neon/ocean/electric) → saffron
  `#E8762B`; good → pin green; info → pin blue; exotic → pin purple.
  Chains with `.withValues(alpha:)` and inside gradient lists, so call sites
  stay one-liners (`_acc(...)` helpers per screen).
- Swapped, all hot-applying via `ListenableBuilder`: action-grid hero tile +
  badge, gauge arc + sweep start, full wave-chart chrome + painter, segmented
  pill, primary CTAs, dropzone/carousel accents, viewport header, dev console,
  dossier chips/search/refresh/links/scores, metrics spinners/refresh/defect
  bars, engine settings chrome, risk badges, evidence-box painter + spinner.
- Deliberately untouched: `fluid_background` and `glass_bottom_bar`
  (never mounted in sober), `GlassContainer` glass-path shadows, `clause_tile`
  (glass branch only), health/status greens (reference has green badges).
- Glass theme preserved pixel-for-pixel for flip-back (ch.04 tiers intact).

## 2. Reference Dashboard (Inspect header, faithful recreation)

`lib/widgets/sober/sober_dashboard.dart`, wired into Inspect's sober branch
(glass keeps top bar + bento grid; toggle hot-applies, no restart):

- Seal avatar + presence dot, centered Poppins "Dashboard", short-middle-bar
  hamburger (→ Engine); "Legal Metrology / N audits" + pin shortcut (→ Dossier).
- Vertical rail (All / Critical / Moderate) that genuinely filters the cards.
- Asymmetric snap cards (`BorderRadius.only(topLeft 26, bottomRight 18)`
  badge): live registry data — fine = badge, risk = art color. Offline/empty →
  Sample / New Scan entry cards so layout never breaks.
- "Recently Scanned" initials row (risk-tier initial fallback, tint-coded);
  session panel thumbnails when present.
- The four bento tiles shrunk to 48px mini icons (SCAN/FILES/MULTI/SAMPLE).
- Shell passes `onOpenTab` into `InspectScreen` for cross-tab jumps.
- Poppins bundled locally (`assets/fonts/`, pubspec) — offline-safe; sober
  widgets use `SoberTheme.fontFamily`. APK cost: +0.4MB.
- Bottom bar rewritten plain per reference: 4 icon-only slots
  (home/calendar/folder/gear), no notch, no FAB (scan lives in mini actions).

## 3. Metrics merge + AMOLED + hairlines

- 4 bento stat cards → ONE merged asymmetric card (three open corners, one
  tight — rhymes with the badge motif), same four live numbers, hairline
  divider. Glass keeps the bento grid (`if (sober)` / `if (!sober)` branches).
- Below it: the real glassmorphism dual-wave chart fed LIVE registry data —
  failure rates = front wave, normalized defect counts = back wave, peak% +
  clause count derived per refresh. Zero hardcoded series. Black fill
  (`soberFill` passthrough) + thin red border (`borderColor` honored by the
  sober card path — both new `GlassContainer` params, glass-ignored).
- `pageBg` → pure `#000000`; `cardBorder` → grayish-white `#7A8090`, which
  now separates every surface including the bottom bar.
- Shared `SoberBottomSpacer` (160 sober / 90–100 glass) on all four tabs —
  the taller sober bar no longer eats scrolled-to-bottom content.

## 4. State + verification

- `soberMode` defaults ON (demo season), persisted in
  `themis_glass_config.json`, toggled in Engine → SOBER MODE card.
- `flutter analyze lib/` clean; release APK installed via adb; backend
  server started manually (`themis` axum, healthy, 21 inspections, `adb
  reverse` re-established); screenshots verified on-device for Inspect,
  Metrics, and boot-default state.

## 5. Tomorrow (explicitly deferred)

1. Multi-SKU carousel thumbs keep glass styling (surrounding cards flatten —
   looks intentional, but not fully sober).
2. Metrics typography: only new widgets are Poppins; headers/labels still
   default sans.
3. Dossier/snap cards use gradient art — no photo thumbs (registry has no
   device-local images).
4. Rail filter is cards-local; does not touch Dossier filters.
5. Backend server has no managed run setup — started by hand this session;
   decide daemon/supervised story before field demo.
6. Revisit copy ("demo season" default) before judge build.

## 6. Metrics staleness fix + dashboard card photos (follow-up)

- **"History shows 3, totals show 0"**: `MetricsScreen` loaded stats once in
  `initState` and never again (`IndexedStack` keeps it alive), while
  `DossierScreen` subscribes to `AuditStorageService` — so tab 2 was always
  fresh and tab 3 froze at whatever it first saw. Fix: Metrics takes the same
  storage subscription with a spinner-free quiet refresh. Ghost symptom in
  the same screenshot (a "35% peak, 4 clauses" graph next to "no inspections")
  came from hardcoded `defect_frequencies` in `computeStats()` — replaced
  with real per-clause rates ranked from stored evaluations (empty store →
  empty series, graph guard additionally requires `totalInspections > 0`).
- **Blank history cards**: `_PlaceCard` only knew `imageAsset`, and history
  items never passed one — post-clear scans rendered gradient-only cards that
  read as empty. Cards now resolve photos via `_resolvePanelImage` (bundled
  demo asset by name → surviving panel file → gradient fallback, never blank),
  with an `imageFile` path on the card (existence-checked, errorBuilder-safe).
- **Recently Scanned row removed entirely** (null product names rendered a
  wall of "P" cells) — cards + mini actions carry the dashboard now; less
  code, less confusion.

## 6. Metrics staleness fix (bug01, device-verified)

**Symptom (Pixel 4a 5G, screenshots `temp/bug01/`):** 3 scans visible in
Inspect results and Dossier history, but Metrics totals stuck at 0/0.0%/₹0 —
sometimes; other times correct. Screenshot 1 also showed a self-contradicting
Metrics: "No inspections recorded yet" next to a "35% peak, 4 clauses tracked
live" graph.

**Root causes (both in app code, no backend involvement):**
1. `MetricsScreen` never subscribed to `AuditStorageService` — it kept its
   `initState` snapshot (often empty) under the `IndexedStack` while scans
   landed. `DossierScreen` subscribes (line 40) and always refreshed, which is
   why tab 2 was always right and tab 3 only sometimes. Init order vs scan
   order fully explains the intermittency.
2. `computeStats()` returned HARDCODED defect rates (35/22/18/11%) and the
   graph guard only checked series length — so an empty store still drew a
   live-looking trajectory. The ghost graph.

**Fix (`audit_storage_service.dart`, `metrics_screen.dart`):**
- Metrics adds the same storage listener Dossier uses, with a quiet refresh
  (numbers update, no spinner flash); dispose removes it.
- Defect frequencies derived from real stored evaluations per clause, ranked
  desc; empty store yields an empty series — ghost graph impossible.
- Graph guard additionally requires `totalInspections > 0`.
- User verified fixed on device. Note: device registry was empty at verify
  time (pm clear during testing), so the live-tick path was verified by code
  inspection + empty-state screenshot, not a full scan cycle.
