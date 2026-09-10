# 03 — Metrics stale snapshot + hardcoded defect series

## Symptom

3 audits visible in Audit Registry, Metrics totals frozen at 0 / 0.0% / ₹0 —
*intermittently*: fresh starts after scanning worked, scans after visiting the
tab didn't. Screenshot proof in the report: totals at zero while the graph
below claimed "35% peak, 4 clauses tracked live" next to a "No inspections
recorded yet" card — self-contradictory UI.

## Root causes (two, compounding)

1. **No subscription.** `DossierScreen` subscribes to `AuditStorageService`
   (`addListener` in `initState`) and refreshes on every save. `MetricsScreen`
   loaded stats once in `initState` and kept the snapshot forever under the
   `IndexedStack`. Any scan landing after Metrics' first load was invisible
   there by construction.
2. **Hardcoded series.** `AuditStorageService::computeStats()` returned fixed
   `defect_frequencies` (35/22/18/11%) regardless of data, and the graph guard
   only checked list length — so an empty store still drew a live-looking
   trajectory. The "35% peak" was never measured; it was a literal.

## Fix (commit `36514ef`)

- Metrics takes the same storage subscription as Dossier, with a spinner-free
  quiet refresh (`_refreshQuietly`).
- `computeStats()` derives per-clause defect rates from stored evaluations
  (ranked, real counts); empty store → empty series → graph hidden. Graph
  guard additionally requires `totalInspections > 0`.
