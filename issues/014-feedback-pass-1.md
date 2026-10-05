# 014 — Feedback pass 1: ANM autofill, Other profile, census countdown

## Parent PRD

`issues/prd.md` (amended by BRIEF.md "Feedback pass 1" section, 2026-10-05)

## What to build

Adrian's first hands-on feedback on the 005 skeleton:

1. Selecting a profile auto-fills ANM/RHC (the header entry keeps a way to
   override).
2. Fourth profile tile "Other": opens the watch keyboard, the typed name
   becomes the nurse identity and the ANM value — the single sanctioned
   typing path on the watch.
3. Room-list header bar: compact strip between back button and the system
   top-right (time / side label) — active profile icon + census countdown.
   Countdown starts at stated starting census, decrements per completed
   occupied room, glows on zero. No date in the bar.
4. Completing a room snaps the magnetized list to the next incomplete room
   (depth-first flow reinforcement).

## Acceptance criteria

- [ ] Picking a profile lands its initials in ANM without a separate step
- [ ] "Other" profile: typed name appears as nurse + ANM on the sheet payload
- [ ] Countdown tracks completed occupied rooms against stated census and
      glows at zero (behavior when census is overshot: keeps counting signed,
      no crash — exact visual is implementer's call, flag it)
- [ ] Room completion auto-advances the list to the next incomplete room

## Blocked by

- Blocked by `issues/005-watch-skeleton.md`
- Countdown + snap interact with full check flow: coordinate with
  `issues/007-all-check-inputs.md` (whichever lands second wires them up)

## User stories addressed

User stories 1, 4, 6, 7 (PRD), extended by BRIEF feedback pass 1.
