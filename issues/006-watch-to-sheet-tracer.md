# 006 — Tracer bullet: watch submit → Modal → Google Sheet

## Parent PRD

`issues/prd.md`

## What to build

Wire Courier: from the simulator, submitting the (partially answerable) sheet
sends the real AuditModel payload to the deployed listener and the row(s)
appear in the tab. Courier queues the payload and retries when offline.
This is the demo loop's spine, proven weeks before demo day.

## Acceptance criteria

- [ ] Submit on the simulated watch → data visible in the Google Sheet without
      manual steps
- [ ] Airplane-mode submit → payload sends automatically once connectivity
      returns
- [ ] Resubmit updates the same cells (no duplicates)

## Blocked by

- Blocked by `issues/003-listener-tracer.md`
- Blocked by `issues/005-watch-skeleton.md`

## User stories addressed

24, 25.
