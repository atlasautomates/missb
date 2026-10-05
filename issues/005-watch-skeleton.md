# 005 — Watch skeleton: profiles → rooms → one check (simulator)

## Parent PRD

`issues/prd.md`

## What to build

The first walkable UI in the simulator: profile picker (Sheila "MB", Cecil
"C", Atlas "🦾"), side picker, sheet-start header entry (ANM/RHC, starting
census; date auto), magnetized snapping room list, and the OCC check working
end-to-end against AuditModel — tap "no" completes the room, tap "yes" shows
the next-check placeholder. Autosave visibly survives app relaunch.

## Acceptance criteria

- [ ] Full path profile → side → header → room list → OCC answer runs in the
      watchOS simulator
- [ ] Room list snaps room-by-room (scroll-wheel feel)
- [ ] OCC=no marks the room complete-N/A in one tap
- [ ] Kill and relaunch: state restored exactly

## Blocked by

- Blocked by `issues/004-auditmodel-core.md`

## User stories addressed

1, 2, 4, 5, 6, 8, 15, 16.
