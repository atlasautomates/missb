# Miss B — digital RHC Zero Harm Audit

Working brief. Grill round 1 answered 2026-10-05. The paper form this
digitizes is `../RHC zero harm audit/` (version 5 final; nurses pilot it on
paper for a week starting 2026-10-05).

## Origin

Nurses fill the Zero Harm Audit on paper every shift, then hand-copy it into a
computer. A floor manager asked "is there any way to automate this?" Two routes:

1. **Paper + scanner** — fiducials on the printed form, deterministic OpenCV
   cell cropping, ink-density mark detection (pure code, no LLM); OCR only for
   handwritten cells. Fallback route; build later.
2. **App ("Miss B")** — data born structured, no OCR. **Building this first.**

## Decisions (grill round 1, 2026-10-05)

### Demo
- Audience: the manager + two managing nurses who oversee shifts.
- Hardware: Adrian's own devices only. IT conversations deferred.
- Centerpiece: Apple Watch sends a real webhook → Modal listener → Google
  Sheet fills in live.

### Platform
- "PWA for now; native SwiftUI for both watch and phone; **start with the
  watch first**" (exact sequencing of PWA vs native to confirm in round 2).
- Watch + iPhone share a consistent UI feel. Duolingo-like cuteness and
  animations; Mobbin for reference patterns.
- LLM note: none needed in-app. If handwriting ever needs reading (paper
  route's notes section), modern iPhones can run small local models via MLX.

### Shifts & data
- One dataset per side (West 26 rooms / East 26 rooms), fresh every shift.
  One nurse per floor for v1; this floor = two sides = two sheets per shift.
- Audits happen in the first 30 minutes of every shift.
- Shifts: settled in round 2 (10pm–6am, 6am–2pm, 2pm–10pm).
- The app NEVER fills in missing data. If incomplete at shift end, it
  auto-sends anyway with missing checks marked as a big red indicator in the
  output sheet; the incoming nurse is simply notified that the previous nurse
  didn't finish. No further behavior for this yet.
- Past data: rooms/sheets freely editable within their shift. New shift =
  fresh sheet, always.

### Skip / N/A logic
- OCC = no (empty room) → entire room complete, all checks N/A.
- CAUTI: F.C. = no → rest of CAUTI auto-skipped (no foley, nothing applies).
- CLABSI does NOT auto-skip: CL can be filled while DATE/ABX/TPN are not.
  Each CLABSI sub-check needs its own skip/N/A affordance.

### Header fields
- DATE: auto from device clock.
- ANM/RHC and STARTING CENSUS: always entered by a human, never computed.
- Census discrepancy check: if stated census ≠ count of occupied rooms, popup
  asking the nurse to confirm which is true. Fires on sheet completion and on
  every subsequent "sheet complete" confirm while a discrepancy exists.

### Editing & confirmation
- Rooms: scrollable, magnetized/snapping list (scroll-wheel feel on Watch);
  tapping an answer auto-advances to the next check. Navigation never locked;
  only submission requires completeness.
- Progress saves itself continuously (cancel anytime, resume, start over).
- Revising a check on an already-COMPLETED room → confirmation popup.
  Incomplete rooms never ask for confirmation.
- Resubmission UPDATES the existing output sheet (upsert) — never a new copy.
  No 15-versions problem.
- Sheet identity: shift + floor/side + timestamp + nurse initials.

### Output pipeline (new feature, decided this round)
- On "sheet complete → send" (or auto-send at shift end): webhook with JSON
  payload of the whole sheet.
- Demo: Modal listener receives payload → script upserts a Google Sheet that
  mirrors the paper form (red highlights for missing checks).
- Modal account: Adrian believes current account is out of free apps; may
  create a new one.
- Production vision (later): same webhook across the hospital's local network
  to an on-site device running the script, or generate the file on-device.
  Destination format is whatever the floor wants (Excel first).

## Decisions (grill round 2, 2026-10-05)

- **Build order**: native watchOS app IS the initial build and the demo
  centerpiece (watch → Modal listener → Google Sheet, one coherent loop).
  Phone version is phase 2 with identical backend; "if they ask, same demo on
  the phone 5 minutes later" (whether phone must exist by demo day: round 3).
- **Shifts**: 10pm–6am, 6am–2pm, 2pm–10pm.
- **Nurse identity**: preset nurse profiles on the shared device — tap your
  circular profile icon (picked avatar/color + initials or full name). Plays
  into the shared-device story.
- **Input methods — no typing anywhere on the watch**:
  - Every paper column without icons/checkboxes is a preset multi-choice list
    (those columns were free-text on paper only because the options wouldn't
    fit on a printed page).
  - ISO: preset list (contact / droplet / airborne / enteric as placeholders —
    real value set from the floor, TBD).
  - RESTRAINTS & GB = "restraints & green blanket": multi-select of restraint
    items (wrist straps, ankle straps, more TBD) + green blanket as one more
    choice in the same list.
  - BRADEN: crown-scrollable number picker (standard scale 6–23; confirm).
  - SCHMID: crown-scrollable 0–6.
  - DATEs (CLABSI/CAUTI): compact scroll-wheel picker, day-of-week + date, no
    year, cycling today-and-backwards only (insertion may predate the shift).
- **Census discrepancy check**: per side, mirroring the paper form.
- **Output target (demo)**: the existing audit spreadsheet
  (`1deoDnkmTk72Hl43irxqc5fX-pW_qOPWCF-AxLHRk96M`), tab
  **"missb app automated input"** (sheetId 1966196459) — verified to exist.
- Adrian wants a walkthrough for registering his Apple Watch as a development
  device on his Apple Developer account when we reach provisioning (use the
  `wizard` skill then).

## Feedback pass 1 (2026-10-05, Adrian testing the 005 skeleton)

- Selecting a profile auto-fills the ANM field. Add an **"Other" profile**:
  tapping it opens the watch keyboard for a free-typed name, which fills the
  ANM line (the one sanctioned typing exception on the watch).
- Room-list header bar: compact, between the back button and the top-right
  time/side — profile icon + a **census countdown**: starts at the stated
  starting census and counts down as (occupied) rooms are completed; on
  reaching zero it gets a celebratory glow. No date in the bar.
- Confirmed correct in testing: auto date stamp, side selection, overall flow.
- Workflow confirmed as designed: depth-first per room (all checks of one
  room, then the next room), never breadth-first across rooms. Refinement:
  after a room completes, snap the list to the next incomplete room.

## Decisions (grill round 3, 2026-10-05)

- **Timeline: one week to demo day.** Watch app is the sole focus; the phone
  app happens before the demo ONLY if the watch works flawlessly with time to
  spare. One polished demo.
- **Modal**: dedicated account adrianp916@gmail.com, profile `adrianp916`.
  Token verified and stored in `~/.modal.toml` (2026-10-05) — never in this
  file or any repo.
- **Demo flourish**: the Modal script fills the sheet row by row with ~1s
  offset between rows — a progress-bar feel, reads as "more automated" to the
  audience. Production flips to a single all-at-once upsert (keep it one line
  of code away).
- **Upsert semantics (demo)**: the "missb app automated input" tab always
  shows current state — West and East blocks overwritten in place, keyed by
  (date, shift, side). History/archive is a production decision for later.
- **Nurse profiles (3)**:
  - **Sheila Bernardez** — managing nurse, the app's namesake ("Miss B").
    Icon: "MB".
  - **Cecil** — managing nurse. Icon: "C".
  - **Atlas** — Adrian. Icon: 🦾 (robot arm emoji).
- Standing assumption (blessed): ISO and RESTRAINTS option lists ship as
  marked placeholders until Adrian brings the real value sets from the floor;
  swapping them is a one-file edit.
