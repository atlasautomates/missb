# 007 — All 14 checks with their input widgets

## Parent PRD

`issues/prd.md`

## What to build

Every check answerable on the watch with its decided input method: tap rows
for bed status C/D/NB, C.diff +/R-O, fall bundle (5 items), FR, SITT., BARI.;
crown pickers for Braden and Schmid; backwards-only day+date wheel for
CLABSI/CAUTI dates; preset multi-choice for ISO; multi-select for restraints
incl. green blanket; CLABSI per-check skip affordance; CAUTI auto-skip after
F.C.=no. Answering auto-advances to the next check.

## Acceptance criteria

- [ ] A full occupied room is chartable start-to-finish with zero typing
- [ ] Auto-advance fires on every answer; back-navigation always available
- [ ] F.C.=no completes CAUTI; each CLABSI sub-check individually skippable
- [ ] Date wheel cannot select a future date; shows day + date, no year

## Blocked by

- Blocked by `issues/005-watch-skeleton.md`

## User stories addressed

7, 9, 10, 11, 12, 13, 14, 18.
