// Lead-authored acceptance tests for ticket 004 (issues/004-auditmodel-core.md).
// These define AuditModel's public seam. The implementer makes them compile and
// pass and MAY NOT edit this file without the lead's sign-off. Unit tests the
// implementer adds elsewhere are advisory.
//
// Behavior under test comes from the PRD's Implementation Decisions and the
// skip rules in BRIEF.md: OCC/CAUTI auto-skip, CLABSI manual skip, per-side
// census discrepancy, 10pm-6am/6am-2pm/2pm-10pm shifts, autosave round-trip,
// and a payload that never hides a gap.

import Foundation
import Testing
import AuditModel

// Fixed calendar so shift-window tests are timezone-deterministic.
private func cal() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
}

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    cal().date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

/// A sheet for `side` in the night shift containing 2026-10-05 23:00 PT.
private func freshSheet(_ side: Side = .west) -> AuditSheet {
    let shift = ShiftSchedule.default.instance(containing: date(2026, 10, 5, 23, 0), calendar: cal())
    return AuditSheet(side: side, shift: shift, nurse: "Atlas")
}

@Suite struct RoomsAndSides {
    @Test func sidesCarryTheExactPaperRoomLists() {
        #expect(Side.west.rooms == [
            "301", "302", "303", "304", "305", "306A", "306Z", "307", "308",
            "309", "310", "311", "312", "313", "314", "315", "316", "317",
            "318", "319", "320", "321", "322", "323", "324A", "324Z",
        ])
        #expect(Side.east.rooms == [
            "325A", "325Z", "326", "327", "328", "329", "330", "331", "332",
            "333", "334", "335", "336", "337", "338", "339", "340", "341",
            "342", "343A", "343Z", "344", "345", "346", "347", "348",
        ])
    }

    @Test func aFreshSheetIsEntirelyMissing() {
        let sheet = freshSheet()
        #expect(!sheet.isComplete)
        #expect(sheet.incompleteRooms == Side.west.rooms)
        #expect(sheet.state(of: .occ, in: "301") == .missing)
    }
}

@Suite struct SkipRules {
    @Test func emptyRoomCompletesInOneTap() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(false))
        #expect(sheet.isRoomComplete("301"))
        #expect(sheet.state(of: .braden, in: "301") == .skipped(.emptyRoom))
        #expect(sheet.state(of: .cautiDate, in: "301") == .skipped(.emptyRoom))
        // The OCC answer itself is an answer, not a skip.
        #expect(sheet.state(of: .occ, in: "301") == .answered(.bool(false)))
    }

    @Test func occupyingAfterEmptyReopensTheRoom() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(false))
        sheet.answer("301", .occ, .bool(true))
        #expect(!sheet.isRoomComplete("301"))
        #expect(sheet.state(of: .braden, in: "301") == .missing)
    }

    @Test func noFoleySkipsTheRestOfCAUTIOnly() {
        var sheet = freshSheet()
        sheet.answer("302", .occ, .bool(true))
        sheet.answer("302", .cautiFC, .bool(false))
        #expect(sheet.state(of: .cautiDate, in: "302") == .skipped(.noFoley))
        #expect(sheet.state(of: .cautiPRC, in: "302") == .skipped(.noFoley))
        // Unrelated checks stay missing; the room is not complete.
        #expect(sheet.state(of: .clabsiCL, in: "302") == .missing)
        #expect(!sheet.isRoomComplete("302"))
    }

    @Test func clabsiSubChecksSkipIndividually() {
        var sheet = freshSheet()
        sheet.answer("303", .occ, .bool(true))
        sheet.skip("303", .clabsiDate)
        sheet.skip("303", .clabsiTPN)
        #expect(sheet.state(of: .clabsiDate, in: "303") == .skipped(.manual))
        #expect(sheet.state(of: .clabsiTPN, in: "303") == .skipped(.manual))
        // Skipping some CLABSI checks never touches its siblings.
        #expect(sheet.state(of: .clabsiCL, in: "303") == .missing)
        #expect(sheet.state(of: .clabsiABX, in: "303") == .missing)
    }
}

@Suite struct Completion {
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
        sheet.answer(room, .restraints, .choices(["wrist straps", "green blanket"]))
        sheet.answer(room, .fr, .bool(true))
        sheet.answer(room, .sitter, .bool(false))
        sheet.answer(room, .bariatric, .bool(false))
    }

    @Test func aFullyAnsweredRoomIsCompleteAndAGapIsNamed() {
        var sheet = freshSheet()
        fillRoom(&sheet, "304")
        #expect(sheet.isRoomComplete("304"))
        #expect(!sheet.incompleteRooms.contains("304"))
        #expect(sheet.incompleteRooms.contains("305"))
    }

    @Test func sheetCompletesWhenEveryRoomDoes() {
        var sheet = freshSheet()
        for room in Side.west.rooms where room != "310" {
            sheet.answer(room, .occ, .bool(false))
        }
        #expect(!sheet.isComplete)
        #expect(sheet.incompleteRooms == ["310"])
        fillRoom(&sheet, "310")
        #expect(sheet.isComplete)
        #expect(sheet.incompleteRooms.isEmpty)
    }
}

@Suite struct CensusDiscrepancy {
    @Test func discrepancyComparesStatedCensusToOccupiedCount() {
        var sheet = freshSheet()
        sheet.startingCensus = 3
        sheet.answer("301", .occ, .bool(true))
        sheet.answer("302", .occ, .bool(true))
        for room in Side.west.rooms where !["301", "302"].contains(room) {
            sheet.answer(room, .occ, .bool(false))
        }
        #expect(sheet.occupiedCount == 2)
        #expect(sheet.hasCensusDiscrepancy)
        sheet.startingCensus = 2
        #expect(!sheet.hasCensusDiscrepancy)
    }
}

@Suite struct Shifts {
    @Test func theThreeWindowsAre10pm6am6am2pm2pm10pm() {
        let s = ShiftSchedule.default
        let night = s.instance(containing: date(2026, 10, 5, 23, 0), calendar: cal())
        let sameNightAfterMidnight = s.instance(containing: date(2026, 10, 6, 1, 30), calendar: cal())
        let morning = s.instance(containing: date(2026, 10, 6, 6, 1), calendar: cal())
        let evening = s.instance(containing: date(2026, 10, 6, 14, 1), calendar: cal())
        // One shift instance spans midnight; crossing 6am starts a new one.
        #expect(night == sameNightAfterMidnight)
        #expect(night != morning)
        #expect(morning != evening)
        let lastNightMinute = s.instance(containing: date(2026, 10, 6, 5, 59), calendar: cal())
        #expect(lastNightMinute == night)
    }

    @Test func aSheetBelongsToItsShiftAndRolloverMeansAFreshSheet() {
        let night = ShiftSchedule.default.instance(containing: date(2026, 10, 5, 23, 0), calendar: cal())
        let morning = ShiftSchedule.default.instance(containing: date(2026, 10, 6, 7, 0), calendar: cal())
        let nightSheet = AuditSheet(side: .west, shift: night, nurse: "Atlas")
        #expect(nightSheet.belongsTo(shift: night))
        #expect(!nightSheet.belongsTo(shift: morning))
    }
}

@Suite struct Persistence {
    @Test func autosaveRoundTripsExactly() throws {
        var sheet = freshSheet()
        sheet.anmRHC = "SB"
        sheet.startingCensus = 20
        sheet.answer("301", .occ, .bool(false))
        sheet.answer("302", .occ, .bool(true))
        sheet.answer("302", .cautiFC, .bool(false))
        sheet.skip("302", .clabsiDate)
        let data = try JSONEncoder().encode(sheet)
        let restored = try JSONDecoder().decode(AuditSheet.self, from: data)
        #expect(restored == sheet)
    }
}

@Suite struct Payload {
    /// The wire contract with the listener: a gap is always explicit.
    @Test func payloadNamesEveryStateExplicitly() throws {
        var sheet = freshSheet()
        sheet.anmRHC = "SB"
        sheet.startingCensus = 20
        sheet.answer("301", .occ, .bool(false))
        sheet.answer("302", .occ, .bool(true))
        sheet.answer("302", .cautiFC, .bool(false))
        // 302 is otherwise untouched; 303+ entirely untouched.

        let json = try JSONSerialization.jsonObject(with: sheet.payloadJSON()) as! [String: Any]
        #expect(json["side"] as? String == "west")
        #expect(json["shift"] as? String == "10pm-6am")
        #expect(json["nurse"] as? String == "Atlas")
        #expect(json["anm_rhc"] as? String == "SB")
        #expect(json["starting_census"] as? Int == 20)
        #expect(json["date"] is String) // the shift's calendar date, present

        let rooms = json["rooms"] as! [String: [String: [String: Any]]]
        #expect(rooms.count == 26)
        #expect(rooms["301"]!["braden"]!["state"] as? String == "skipped")
        #expect(rooms["301"]!["braden"]!["cause"] as? String == "empty_room")
        #expect(rooms["302"]!["cauti_date"]!["cause"] as? String == "no_foley")
        #expect(rooms["302"]!["braden"]!["state"] as? String == "missing")
        #expect(rooms["303"]!["occ"]!["state"] as? String == "missing")
        #expect(rooms["302"]!["occ"]!["state"] as? String == "answered")
    }
}
