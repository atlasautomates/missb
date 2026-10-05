# 008 — Completion, discrepancy, and revision UX

## Parent PRD

`issues/prd.md`

## What to build

The workflow rules as UI: sheet-complete flow with census discrepancy popup
(stated vs occupied count, per side; fires at completion and on every
subsequent complete-confirm while unresolved), incomplete-rooms notice upon
finishing the last room, confirmation popup ONLY when revising a check on an
already-completed room, free editing everywhere else, start-over flow.

## Acceptance criteria

- [ ] Census mismatch triggers the popup at completion and again on each
      complete-confirm until resolved; match triggers nothing
- [ ] Completing the final room with gaps elsewhere lists the incomplete rooms
- [ ] Editing a completed room asks to confirm; editing an incomplete room
      never does
- [ ] After revising one check in a completed room, the flow returns straight
      to the room list instead of walking the remaining answered checks
      (lead ruling on 007 question 1; today the flow keeps walking because
      that was the only way to reach later stored values)
- [ ] Start-over wipes the sheet after an explicit confirm

## Blocked by

- Blocked by `issues/007-all-check-inputs.md`

## User stories addressed

17, 18, 19, 20, 21, 23.
