# 009 — Full-sheet output: paper-mirror layout, red gaps, demo cadence

## Parent PRD

`issues/prd.md`

## What to build

Listener maps the complete payload to the tab laid out like the paper form:
West and East blocks, header fields, one row per room, upserted in place keyed
by (date, shift, side). Missing checks render with red formatting. Demo mode
writes row-by-row ~1s apart; production mode batches — switchable in one line.

## Acceptance criteria

- [ ] A submitted full side reads like the paper form in the tab
- [ ] Missing checks are red; N/A-skipped checks are visually distinct from
      missing
- [ ] Resubmission updates in place; a new (date, shift) replaces the blocks
- [ ] Demo mode visibly fills row by row; flipping one flag batches it
- [ ] Unit tests cover cell mapping, red placement, upsert idempotency

## Blocked by

- Blocked by `issues/006-watch-to-sheet-tracer.md`

## User stories addressed

25, 26, 27, 28, 31, 32.
