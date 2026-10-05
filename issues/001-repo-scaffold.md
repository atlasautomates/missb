# 001 — Repo scaffold

## Parent PRD

`issues/prd.md`

## What to build

Turn `missb-app/` into a working git repo with the project skeleton: an Xcode
project with a watchOS app target ("Miss B") that builds and runs empty in the
simulator, a Swift package for AuditModel with one placeholder passing test, a
`listener/` Python project (uv) with Modal dependency that deploys a hello
endpoint, and a README pointing at `BRIEF.md` and `issues/prd.md`. `.gitignore`
covers Xcode junk and credentials.

## Acceptance criteria

- [ ] `git log` shows an initial commit; no secrets tracked
- [ ] Watch app target builds and launches in the watchOS simulator
- [ ] `swift test` passes on the AuditModel package
- [ ] `modal deploy` of the hello endpoint succeeds from `listener/` and the
      endpoint answers over HTTPS

## Blocked by

None - can start immediately.

## User stories addressed

Infrastructure for all; directly 30, 35.
