# 003 — Listener tracer: webhook → one row in the sheet

## Parent PRD

`issues/prd.md`

## What to build

The Modal listener's first real behavior: an authenticated webhook endpoint
(bearer token from a Modal secret) that accepts a minimal hardcoded-shape
payload (one room's checks) and writes one recognizable row into the "missb
app automated input" tab. Includes the unit-test seam: payload-to-cell-writes
logic tested against a faked Sheets client.

## Acceptance criteria

- [ ] `curl` with the bearer token and a sample payload makes a row appear in
      the tab within seconds
- [ ] `curl` without the token is rejected (401)
- [ ] Unit test: sample payload produces the expected cell writes against the
      fake client
- [ ] Re-sending the same payload updates the same row (no duplicate)

## Blocked by

- Blocked by `issues/001-repo-scaffold.md`
- Blocked by `issues/002-google-service-account.md`

## User stories addressed

24, 25, 30.
