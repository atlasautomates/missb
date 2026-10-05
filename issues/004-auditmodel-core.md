# 004 — AuditModel: domain core + tests

## Parent PRD

`issues/prd.md`

## What to build

The deep module. Sides/rooms (West 301–324Z, East 325A–348), all check types
and their value sets (incl. placeholder ISO/restraint data files), skip logic
(OCC=no completes room; F.C.=no completes CAUTI; CLABSI per-check skip),
room/sheet completion rules, census discrepancy rule (per side), shift windows
(10pm–6am, 6am–2pm, 2pm–10pm) with fresh-sheet rollover, continuous
autosave/restore, and JSON payload encoding with explicit
answered/skipped(cause)/missing states. No UI, no network.

## Acceptance criteria

- [ ] Unit tests cover: every skip rule, completion with/without gaps, census
      discrepancy raise/clear, shift rollover produces a fresh sheet, payload
      round-trips and marks missing checks explicitly
- [ ] Option lists live in data files marked as placeholders
- [ ] `swift test` green; package imports no UI/network frameworks

## Blocked by

- Blocked by `issues/001-repo-scaffold.md`

## User stories addressed

3, 8, 9, 10, 15, 16, 17, 23, 26, 33, 34, 35.
