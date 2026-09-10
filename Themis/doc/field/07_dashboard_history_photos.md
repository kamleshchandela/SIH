# 07 — Dashboard history photos + Recently Scanned removal

## Blank history cards

After a data clear, demo photo cards render; after real scans, history cards
rendered gradient-only tiles that read as blank (scrolling right: all empty).
Cause: `_PlaceCard` only knew `imageAsset`, and history items never passed
one — no photo path existed for real audits.

Fix (commit `02bd47b`): cards resolve photos through `_resolvePanelImage`
per history item — bundled demo asset by product-name match → surviving
scanned-panel file off disk (existence-checked at build) → gradient +
watermark fallback, so a card is never blank. `_PlaceCard` gained an
`imageFile` path with an `errorBuilder` guard. Rationale for the fallback
chain: cleared app data wipes panel files, so post-clear scans can be
genuinely photo-less until a panel-bearing audit lands.

## Recently Scanned removal

Null `product_name`s degenerated the row into a wall of "P" cells. Removed the
section, its method, and `_PeopleCell` entirely (−132/+65 with the photo fix):
cards plus mini actions carry the dashboard. Deleted code has no second
consumer — verified by grep before removal.
