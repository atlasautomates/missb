# 010 — Shift engine: rollover, auto-send, notifications

## Parent PRD

`issues/prd.md`

## What to build

Shift awareness end-to-end: settings view with the three shift windows,
fresh sheets at shift start, auto-send of whatever exists at shift end (gaps
and all — the app never fills anything in), local notification one hour before
shift end naming incomplete rooms, and the end-of-last-room notice from 008
wired to real shift context.

## Acceptance criteria

- [ ] Crossing a shift boundary yields fresh sheets; the old sheet auto-sends
      with missing checks intact (red in output)
- [ ] 1-hour-before notification fires naming incomplete rooms (verifiable
      with shortened test windows)
- [ ] Shift hours editable in settings; no onboarding flow exists

## Blocked by

- Blocked by `issues/008-completion-ux.md`
- Blocked by `issues/009-full-sheet-output.md`

## User stories addressed

3, 21, 22, 26, 29, 33.
