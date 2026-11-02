// Implementer tests for ticket 014 (issues/014-feedback-pass-1.md):
// census countdown math and next-incomplete-room ordering for the list snap.

import Foundation
import Testing
import AuditModel

private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
}

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    cal().date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

private func freshSheet(_ side: Side = .west) -> AuditSheet {
    let shift = ShiftSchedule.default.instance(containing: date(2026, 10, 5, 23, 0), calendar: cal())
    return AuditSheet(side: side, shift: shift, nurse: "Atlas")
}

/// Answer every check of an occupied room with plausible values.
private func fillRoom(_ sheet: inout AuditSheet, _ room: String) {
    sheet.answer(room, .occ, .bool(true))
    sheet.answer(room, .bedStatus, .choice("C"))
    sheet.answer(room, .iso, .choice("contact"))
    sheet.answer(room, .cdiff, .choice("+"))
    sheet.answer(room, .braden, .score(18))
    sheet.answer(room, .schmid, .score(3))
    for bundle: Check in [.bundleDoor, .bundleRails, .bundleArm, .bundleSocks, .bundleBook] {
        sheet.answer(room, bundle, .bool(true))
    }
    sheet.answer(room, .clabsiCL, .choice("PICC"))
    sheet.answer(room, .clabsiDate, .date(date(2026, 10, 4, 12, 0)))
    sheet.answer(room, .clabsiABX, .bool(true))
    sheet.answer(room, .clabsiTPN, .bool(false))
    sheet.answer(room, .cautiFC, .bool(false)) // skips the rest of CAUTI
    sheet.answer(room, .restraints, .choices(["wrist straps"]))
    sheet.answer(room, .fr, .bool(true))
    sheet.answer(room, .sitter, .bool(false))
    sheet.answer(room, .bariatric, .bool(false))
}

@Suite struct CensusCountdown {
    @Test func countdownStartsAtStatedCensusAndNeedsOne() {
        var sheet = freshSheet()
        #expect(sheet.censusCountdown == nil) // no stated census yet
        sheet.startingCensus = 5
        #expect(sheet.censusCountdown == 5)
    }

    @Test func onlyACompletedOccupiedRoomDecrements() {
        var sheet = freshSheet()
        sheet.startingCensus = 5

        // Occupied but not finished: no decrement.
        sheet.answer("301", .occ, .bool(true))
        #expect(sheet.censusCountdown == 5)

        // Empty room completes in one tap but holds no patient: no decrement.
        sheet.answer("302", .occ, .bool(false))
        #expect(sheet.censusCountdown == 5)

        fillRoom(&sheet, "301")
        #expect(sheet.completedOccupiedCount == 1)
        #expect(sheet.censusCountdown == 4)
    }

    @Test func countdownReachesZeroWhenCensusIsMet() {
        var sheet = freshSheet()
        sheet.startingCensus = 2
        fillRoom(&sheet, "301")
        fillRoom(&sheet, "303")
        #expect(sheet.censusCountdown == 0)
    }

    @Test func overshootGoesNegativeInsteadOfClampingOrCrashing() {
        var sheet = freshSheet()
        sheet.startingCensus = 1
        fillRoom(&sheet, "301")
        fillRoom(&sheet, "302")
        fillRoom(&sheet, "303")
        #expect(sheet.censusCountdown == -2)
    }

    @Test func reopeningACompletedRoomGivesTheCountBack() {
        var sheet = freshSheet()
        sheet.startingCensus = 3
        fillRoom(&sheet, "301")
        #expect(sheet.censusCountdown == 2)
        // Flipping OCC to no clears the room's answers; flipping back leaves
        // it occupied but incomplete, so the countdown returns to 3.
        sheet.answer("301", .occ, .bool(false))
        sheet.answer("301", .occ, .bool(true))
        #expect(sheet.censusCountdown == 3)
    }
}

@Suite struct NextIncompleteRoom {
    @Test func picksTheFirstIncompleteRoomAfterTheGivenOne() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(false))
        sheet.answer("302", .occ, .bool(false))
        #expect(sheet.nextIncompleteRoom(after: "301") == "303")
    }

    @Test func skipsCompletedRoomsInBetween() {
        var sheet = freshSheet()
        sheet.answer("302", .occ, .bool(false))
        fillRoom(&sheet, "303")
        #expect(sheet.nextIncompleteRoom(after: "301") == "304")
    }

    @Test func wrapsPastTheEndOfTheSide() {
        var sheet = freshSheet()
        // Everything after 324A is complete; 305 upward too. Only 301-304 left.
        for room in Side.west.rooms where !["301", "302", "303", "304"].contains(room) {
            sheet.answer(room, .occ, .bool(false))
        }
        #expect(sheet.nextIncompleteRoom(after: "324A") == "301")
    }

    @Test func excludesTheGivenRoomAndReturnsNilWhenAllOthersAreDone() {
        var sheet = freshSheet()
        for room in Side.west.rooms where room != "310" {
            sheet.answer(room, .occ, .bool(false))
        }
        // 310 itself is the only incomplete room; "after 310" has nowhere to go.
        #expect(sheet.nextIncompleteRoom(after: "310") == nil)
        #expect(sheet.nextIncompleteRoom(after: "305") == "310")
    }

    @Test func unknownRoomYieldsNil() {
        let sheet = freshSheet()
        #expect(sheet.nextIncompleteRoom(after: "999") == nil)
    }
}
