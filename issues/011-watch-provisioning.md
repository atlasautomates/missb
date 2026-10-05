# 011 — Watch hardware provisioning + install (HITL)

## Parent PRD

`issues/prd.md`

## What to build

A wizard (per the `wizard` skill) walking Adrian through: pairing his iPhone
to Xcode, registering the physical Apple Watch as a development device on his
developer account, provisioning the Miss B watch target, and installing the
current build on the watch. Ends with the app launching on the wrist.

## Acceptance criteria

- [ ] Watch appears as a run destination in Xcode
- [ ] Miss B installs and launches on the physical watch
- [ ] A submit from the wrist reaches the Google Sheet (hardware repeat of the
      006 tracer)

## Blocked by

- Blocked by `issues/006-watch-to-sheet-tracer.md` (needs an app worth
  installing; can run any time after)

## User stories addressed

24, 31 (demo readiness).
