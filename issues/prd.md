# PRD — Miss B (RHC Zero Harm Audit, Apple Watch)

Source of truth for scope: `../BRIEF.md` (grill rounds 1–3, 2026-10-05).
Deadline: demo in one week (2026-10-12), Adrian's own hardware.

## Problem Statement

Every shift, a nurse walks the floor and fills out the RHC Zero Harm Audit on
paper: 26 rooms per side, two sides, ~14 checks per room. Afterwards someone
hand-copies every sheet into a computer. The copying is slow, error-prone, and
duplicated across dozens of sheets a night. A floor manager asked whether this
can be automated.

## Solution

Miss B: a native Apple Watch app on a shared unit device. A nurse taps their
profile, walks the floor, and answers each check with single taps (or a crown
scroll for numbers, a wheel for dates — no typing anywhere). The app enforces
completeness without ever blocking navigation, saves itself continuously, and
on submission fires a JSON webhook to a listener that fills a spreadsheet
mirroring the paper form — ending the hand-copying entirely. The demo shows a
watch tap populating a Google Sheet row by row in front of the managers.

No patient names anywhere; rooms only. All audit data stays on-device until
the nurse submits. The app never invents data: anything missing at shift end
is sent as missing and shown red in the output.

## User Stories

1. As a nurse, I want to tap my profile icon on the shared watch, so that my
   initials ride along with every sheet I submit without typing.
2. As a nurse, I want to pick the side (West/East) I'm auditing, so that I see
   only its 26 rooms.
3. As a nurse, I want a fresh sheet per side at the start of every shift, so
   that I never confuse tonight's audit with the last one.
4. As a nurse, I want to enter ANM/RHC and starting census at sheet start, so
   that the header matches what the floor hands me.
5. As a nurse, I want the date stamped automatically from the device clock, so
   that I never fill it in.
6. As a nurse, I want to scroll a magnetized room list that snaps room by
   room, so that I always know which room I'm charting.
7. As a nurse, I want tapping an answer to auto-advance me to the next check,
   so that charting a room takes seconds.
8. As a nurse, I want answering OCC "no" to complete the whole room as N/A,
   so that empty rooms cost one tap.
9. As a nurse, I want answering F.C. "no" to auto-complete the rest of CAUTI,
   so that rooms without a foley skip meaningless questions.
10. As a nurse, I want each CLABSI sub-check (CL, DATE, ABX, TPN) to be
    individually skippable/N/A, so that partial line information is recordable.
11. As a nurse, I want bed status (C/D/NB), C.diff (+/R-O), the five fall
    bundle items, FR, SITT., and BARI. as single-tap choices, so that the
    binary and pick-one checks stay instant.
12. As a nurse, I want Braden and Schmid as crown-scrollable number pickers,
    so that scores need no keyboard.
13. As a nurse, I want ISO and restraints (incl. green blanket) as preset
    multi-choice lists, so that what was free-text on paper becomes taps.
14. As a nurse, I want insertion dates picked on a compact wheel (day + date,
    no year, today-and-backwards only), so that a line placed yesterday is two
    flicks away.
15. As a nurse, I want to cancel out at any moment with progress saved
    silently, so that an emergency never costs me data or a "save?" prompt.
16. As a nurse, I want to resume exactly where I left off, so that
    interruptions don't restart rooms.
17. As a nurse, I want to start a sheet over deliberately, so that a botched
    audit can be redone.
18. As a nurse, I want to navigate anywhere anytime — only *submission*
    requires completeness — so that the app never fights me.
19. As a nurse, I want to reopen and edit any room during my shift, including
    after submitting, so that the sheet stays a working document.
20. As a nurse, I want a confirmation popup only when revising a check on an
    already-completed room, so that accidental edits are caught but normal
    charting is never nagged.
21. As a nurse, I want to be told which rooms are incomplete when I finish the
    last room, so that I can close the gaps while still on the floor.
22. As a nurse, I want a reminder about incomplete rooms an hour before shift
    end, so that nothing is discovered missing at 6 a.m.
23. As a nurse, I want a census discrepancy popup (stated census vs. occupied
    count, per side) at sheet completion and on every subsequent complete-
    confirm, so that mismatches are resolved by me, not guessed by software.
24. As a nurse, I want "sheet complete → send" to push my side's data off the
    watch, so that hand-copying is dead.
25. As a nurse, I want resubmission to UPDATE the existing output in place, so
    that there is exactly one authoritative sheet, never 15 versions.
26. As a managing nurse, I want anything missing at shift end auto-sent and
    marked red in the output sheet, so that gaps are visible, never papered
    over — the app must never fill in data itself.
27. As a managing nurse, I want the output spreadsheet to mirror the paper
    form's layout, so that reading it requires no retraining.
28. As a managing nurse, I want each output sheet identified by date, shift,
    side, and nurse initials, so that accountability is built in.
29. As an incoming nurse, I want to see that the previous shift left rooms
    incomplete, so that I know the floor's true state (notification behavior
    beyond the red marks is out of scope for now).
30. As the hospital's IT department, I want all audit data to live on-device
    with no patient names and leave only as an explicit submission, so that
    the security review is short.
31. As Adrian (demo presenter), I want the Google Sheet to fill row by row
    (~1s apart), so that the automation is visible and impressive live.
32. As Adrian, I want the row-by-row effect to be a one-line switch away from
    an all-at-once upsert, so that production doesn't inherit demo theater.
33. As Adrian, I want shift hours (10pm–6am, 6am–2pm, 2pm–10pm) configurable
    in settings, not onboarding, so that setup friction is near zero.
34. As Adrian, I want ISO/restraint option lists isolated as data, so that
    swapping placeholders for the floor's real value sets is a one-file edit.
35. As Adrian, I want the phone app (phase 2) to reuse the entire domain and
    backend untouched, so that only the UI layer is new work.

## Implementation Decisions

Modules (deep-module vocabulary; the first two are the test surfaces):

- **AuditModel** (Swift package, zero UI/network imports): the whole domain —
  sides/rooms/checks, check value types, skip logic (OCC, CAUTI, CLABSI
  rules), completion rules, shift windows and rollover, census discrepancy,
  autosave/restore of sheet state, and the JSON payload encoding. Everything
  the watch UI renders is a projection of this model. Phase-2 phone app
  consumes it unchanged.
- **Listener** (Python on Modal, account `adrianp916`): one webhook endpoint.
  Validates payload → upserts the "missb app automated input" tab of the
  existing audit spreadsheet, keyed by (date, shift, side), West/East blocks
  laid out like the paper form, red formatting on missing checks. Demo mode:
  row-by-row writes ~1s apart; production mode: single batch upsert. Google
  access via a service account credential shared on the spreadsheet; vendor
  (Modal, Google Sheets) specifics stay inside this module.
- **Courier** (thin Swift adapter): sends an encoded payload to the listener
  URL; queues and retries while the watch lacks connectivity; nothing else.
- **Watch UI** (SwiftUI, watchOS): profile picker, side picker, magnetized
  room list, per-check input views (tap rows, crown pickers, date wheel,
  multi-select lists), confirmations, local notifications. Deliberately
  shallow — logic lives in AuditModel.

Contracts and decisions:

- Payload: one JSON document per (date, shift, side) carrying header fields,
  nurse identity, every room's checks with explicit states — answered /
  skipped-N/A (with cause: empty room, no foley, per-check skip) / missing.
- Upsert key: (date, shift, side). Initials and timestamps are data, not key.
- Profiles hardcoded for demo: Sheila Bernardez ("MB"), Cecil ("C"),
  Atlas ("🦾").
- Option lists (ISO, restraints) ship as marked placeholder data files.
- Shifts hardcoded defaults in settings: 10pm–6am, 6am–2pm, 2pm–10pm.
- UI feel: Duolingo-ish warmth (animations, haptics); Mobbin for reference
  patterns; watch and future phone share the visual language.

## Testing Decisions

- Good tests assert external behavior only: given answers, is the room/sheet
  complete; given OCC=no, does the payload mark every check N/A-empty-room;
  given stated census ≠ occupied count, does the discrepancy flag raise;
  given a sheet resubmission, does the listener write the same cells, not new
  rows. No tests of view internals or private state.
- **AuditModel**: full unit coverage of skip logic, completion, shift
  rollover, discrepancy, payload encoding (round-trip). This is the module
  where bugs would embarrass us in front of nurses.
- **Listener**: unit tests with a faked Sheets client (payload → exact cell
  writes, red-mark placement, upsert idempotency), plus one live smoke test
  against the real tab before the demo.
- Watch UI and Courier: exercised by the end-to-end tracer and the demo dry
  run, not unit-tested in week one.
- No prior art in this repo (greenfield); Hermes testing style (typed
  entries, behavior-level assertions) is the reference culture.

## Out of Scope

- The iPhone app (phase 2; begins only if the watch is flawless with time to
  spare before demo day).
- The PWA and any web UI.
- The paper-route scanner (fiducials/OpenCV) — separate project, later.
- Multi-nurse / multi-device sync, the cross-floor shared repository, and
  nurses covering each other's rooms.
- Hospital IT integration: MDM distribution, local-network listener,
  EHR/Epic anything.
- Incoming-nurse notification behavior beyond red marks in the output sheet.
- Authentication/hardening of the webhook beyond a shared secret header
  (noted: URL obscurity is not auth; a bearer token ships day one).
- Real ISO/restraint value sets (placeholders until Adrian returns from the
  floor).

## Further Notes

- Demo flow to rehearse: profile tap → West sheet → a few rooms live → sheet
  complete → census popup resolved → send → Google Sheet fills row by row on
  a laptop; East pre-filled earlier that day to show a finished floor.
- Apple Watch hardware provisioning is a HITL wizard step (Adrian + Xcode).
- Demo-day connectivity: the watch needs internet to reach Modal (hotspot or
  watch cellular as fallback if hospital guest Wi-Fi is hostile).
- Modal token lives in `~/.modal.toml` (profile `adrianp916`); Google service
  account JSON will live in a Modal secret — neither ever lands in the repo.
