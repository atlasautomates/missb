# 013 — Demo dry run (HITL)

## Parent PRD

`issues/prd.md`

## What to build

Full rehearsal of the demo script on real hardware: profile tap → West sheet →
several rooms live on the wrist → completion + census popup → send → Google
Sheet fills row by row on a laptop; East pre-filled to show a finished floor.
Verify the connectivity fallback (hotspot / watch cellular). Fix everything
that stumbles; rehearse twice.

## Acceptance criteria

- [ ] End-to-end run succeeds twice consecutively on hardware with no touch of
      a computer mid-demo
- [ ] Connectivity fallback tested (Wi-Fi off → hotspot or cellular)
- [ ] Live smoke test against the real tab passed same-day
- [ ] Adrian can run the script solo

## Blocked by

- Blocked by `issues/009-full-sheet-output.md`
- Blocked by `issues/010-shift-engine.md`
- Blocked by `issues/011-watch-provisioning.md`
- Blocked by `issues/012-demo-polish.md`

## User stories addressed

31, 32; validates the whole set.
