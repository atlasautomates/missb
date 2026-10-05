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

private func shift(containing y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> ShiftInstance {
    ShiftSchedule.default.instance(containing: date(y, mo, d, h, mi), calendar: cal())
}

private func freshSheet(_ side: Side = .west) -> AuditSheet {
    AuditSheet(side: side, shift: shift(containing: 2026, 10, 5, 23, 0), nurse: "Atlas")
}

@Suite struct EmptyRoomEdges {
    @Test func answeringInsideAnEmptyRoomIsIgnored() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(false))
        sheet.answer("301", .braden, .score(18))
        sheet.answer("301", .cautiFC, .bool(false))
        #expect(sheet.state(of: .braden, in: "301") == .skipped(.emptyRoom))
        #expect(sheet.state(of: .cautiFC, in: "301") == .skipped(.emptyRoom))
        #expect(sheet.isRoomComplete("301"))
    }

    @Test func reopeningDoesNotRestoreAnswersTheEmptyRoomOverwrote() {
        var sheet = freshSheet()
        sheet.answer("301", .braden, .score(18))
        sheet.answer("301", .occ, .bool(false))
        #expect(sheet.state(of: .braden, in: "301") == .skipped(.emptyRoom))
        sheet.answer("301", .occ, .bool(true))
        #expect(sheet.state(of: .braden, in: "301") == .missing)
        #expect(sheet.state(of: .occ, in: "301") == .answered(.bool(true)))
        for check in Check.allCases where check != .occ {
            #expect(sheet.state(of: check, in: "301") == .missing)
        }
    }

    @Test func emptyRoomOverwritesANoFoleySkipAndReopeningDropsBoth() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(true))
        sheet.answer("301", .cautiFC, .bool(false))
        sheet.skip("301", .clabsiDate)
        sheet.answer("301", .occ, .bool(false))
        #expect(sheet.state(of: .cautiDate, in: "301") == .skipped(.emptyRoom))
        #expect(sheet.state(of: .clabsiDate, in: "301") == .skipped(.emptyRoom))
        sheet.answer("301", .occ, .bool(true))
        #expect(sheet.state(of: .cautiDate, in: "301") == .missing)
        #expect(sheet.state(of: .cautiFC, in: "301") == .missing)
        #expect(sheet.state(of: .clabsiDate, in: "301") == .missing)
    }
}

@Suite struct ManualSkipEdges {
    @Test func skipOnANonClabsiCheckIsIgnored() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(true))
        sheet.answer("301", .braden, .score(12))
        sheet.skip("301", .braden)
        sheet.skip("301", .occ)
        sheet.skip("301", .cautiDate)
        sheet.skip("301", .bedStatus)
        #expect(sheet.state(of: .braden, in: "301") == .answered(.score(12)))
        #expect(sheet.state(of: .occ, in: "301") == .answered(.bool(true)))
        #expect(sheet.state(of: .cautiDate, in: "301") == .missing)
        #expect(sheet.state(of: .bedStatus, in: "301") == .missing)
    }

    @Test func skipWhileEmptyDoesNotReplaceTheEmptyRoomCause() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(false))
        sheet.skip("301", .clabsiCL)
        sheet.skip("301", .clabsiDate)
        #expect(sheet.state(of: .clabsiCL, in: "301") == .skipped(.emptyRoom))
        #expect(sheet.state(of: .clabsiDate, in: "301") == .skipped(.emptyRoom))
    }

    @Test func answeringASkippedClabsiCheckClearsTheManualSkip() {
        var sheet = freshSheet()
        sheet.answer("301", .clabsiCL, .choice("PICC"))
        sheet.skip("301", .clabsiCL)
        #expect(sheet.state(of: .clabsiCL, in: "301") == .skipped(.manual))
        sheet.answer("301", .clabsiCL, .choice("PICC"))
        #expect(sheet.state(of: .clabsiCL, in: "301") == .answered(.choice("PICC")))
    }

    @Test func occupyingDoesNotClearAManualSkip() {
        var sheet = freshSheet()
        sheet.skip("302", .clabsiABX)
        sheet.answer("302", .occ, .bool(true))
        #expect(sheet.state(of: .clabsiABX, in: "302") == .skipped(.manual))
    }

    @Test func everyClabsiSubcheckIsManuallySkippableAndNothingElseIs() {
        let clabsi: Set<Check> = [.clabsiCL, .clabsiDate, .clabsiABX, .clabsiTPN]
        #expect(Set(Check.allCases.filter(\.isManuallySkippable)) == clabsi)
        #expect(Check.allCases.count == 22)
    }
}

@Suite struct FoleyEdges {
    @Test func foleyYesClearsNoFoleySkipsToMissing() {
        var sheet = freshSheet()
        sheet.answer("302", .cautiFC, .bool(false))
        sheet.answer("302", .cautiFC, .bool(true))
        #expect(sheet.state(of: .cautiDate, in: "302") == .missing)
        #expect(sheet.state(of: .cautiPRC, in: "302") == .missing)
        #expect(sheet.state(of: .cautiFC, in: "302") == .answered(.bool(true)))
        #expect(sheet.state(of: .braden, in: "302") == .missing)
    }

    @Test func answeringACautiTailWhileNoFoleyIsIgnored() {
        var sheet = freshSheet()
        sheet.answer("302", .cautiFC, .bool(false))
        sheet.answer("302", .cautiDate, .date(date(2026, 10, 1, 8, 0)))
        sheet.answer("302", .cautiPRC, .bool(true))
        #expect(sheet.state(of: .cautiDate, in: "302") == .skipped(.noFoley))
        #expect(sheet.state(of: .cautiPRC, in: "302") == .skipped(.noFoley))
    }

    @Test func foleyNoOverwritesADateAlreadyEntered() {
        var sheet = freshSheet()
        sheet.answer("302", .cautiDate, .date(date(2026, 10, 1, 8, 0)))
        sheet.answer("302", .cautiFC, .bool(false))
        #expect(sheet.state(of: .cautiDate, in: "302") == .skipped(.noFoley))
        #expect(sheet.state(of: .clabsiCL, in: "302") == .missing)
    }
}

@Suite struct ShiftBoundaries {
    @Test func exactWindowStartsBelongToTheShiftThatStartsThen() {
        let night = shift(containing: 2026, 10, 5, 23, 0)
        let at2200 = shift(containing: 2026, 10, 5, 22, 0)
        let at0600 = shift(containing: 2026, 10, 6, 6, 0)
        let morning = shift(containing: 2026, 10, 6, 6, 1)
        let at1400 = shift(containing: 2026, 10, 6, 14, 0)
        let evening = shift(containing: 2026, 10, 6, 14, 1)
        let at2159 = shift(containing: 2026, 10, 6, 21, 59)
        let nextNight = shift(containing: 2026, 10, 6, 22, 0)

        #expect(at2200 == night)
        #expect(at0600 == morning)
        #expect(at0600 != night)
        #expect(at1400 == evening)
        #expect(at1400 != morning)
        #expect(at2159 == evening)
        #expect(nextNight != night)
        #expect(nextNight != evening)
    }

    @Test func fallBackNightIsStillOneInstance() {
        // 2026-11-01 is the US fallback. 05:30 is after the repeated hour.
        let before = shift(containing: 2026, 10, 31, 23, 0)
        let after = shift(containing: 2026, 11, 1, 5, 30)
        let morning = shift(containing: 2026, 11, 1, 6, 0)
        #expect(before == after)
        #expect(before != morning)
        #expect(before.date == "2026-10-31")
    }

    @Test func aNewShiftIsANewSheet() {
        let night = shift(containing: 2026, 10, 5, 23, 0)
        let morning = shift(containing: 2026, 10, 6, 6, 0)
        var nightSheet = AuditSheet(side: .west, shift: night, nurse: "Atlas")
        nightSheet.answer("301", .occ, .bool(false))
        let morningSheet = AuditSheet(side: .west, shift: morning, nurse: "Atlas")
        #expect(morningSheet.state(of: .occ, in: "301") == .missing)
        #expect(!morningSheet.belongsTo(shift: night))
        #expect(nightSheet.belongsTo(shift: night))
    }
}

@Suite struct CensusAndRoomEdges {
    @Test func unsetCensusIsNotADiscrepancyAndMissingOccDoesNotCount() {
        var sheet = freshSheet()
        sheet.answer("301", .occ, .bool(true))
        sheet.answer("302", .occ, .bool(false))
        #expect(sheet.occupiedCount == 1)
        #expect(!sheet.hasCensusDiscrepancy)
        sheet.startingCensus = 0
        #expect(sheet.hasCensusDiscrepancy)
        sheet.startingCensus = 1
        #expect(!sheet.hasCensusDiscrepancy)
    }

    @Test func anUnknownRoomIsIgnored() {
        var sheet = freshSheet()
        sheet.answer("999", .occ, .bool(false))
        sheet.answer("325A", .occ, .bool(false))
        sheet.skip("999", .clabsiCL)
        #expect(sheet.state(of: .occ, in: "999") == .missing)
        #expect(sheet.state(of: .occ, in: "325A") == .missing)
        #expect(!sheet.isRoomComplete("999"))
        #expect(sheet.incompleteRooms == Side.west.rooms)
    }
}

@Suite struct PayloadAndAutosaveEdges {
    @Test func payloadCarriesValuesAndOmitsCauseUnlessSkipped() throws {
        var sheet = freshSheet()
        sheet.answer("304", .occ, .bool(true))
        sheet.answer("304", .braden, .score(18))
        sheet.answer("304", .restraints, .choices(["wrist straps", "green blanket"]))
        sheet.answer("304", .clabsiDate, .date(date(2026, 10, 4, 12, 0)))
        sheet.skip("304", .clabsiTPN)
        sheet.answer("301", .occ, .bool(false))

        let json = try JSONSerialization.jsonObject(with: sheet.payloadJSON()) as! [String: Any]
        let rooms = json["rooms"] as! [String: [String: [String: Any]]]
        #expect(rooms.count == 26)
        for room in Side.west.rooms {
            #expect(rooms[room]?.count == 22)
        }

        let keys = Set(rooms["304"]!.keys)
        #expect(keys == Set(Check.allCases.map(\.rawValue)))

        #expect(rooms["304"]!["braden"]!["value"] as? Int == 18)
        #expect(rooms["304"]!["braden"]!["cause"] == nil)
        let restraints = rooms["304"]!["restraints"]!["value"] as? [String]
        #expect(restraints == ["wrist straps", "green blanket"])
        #expect(rooms["304"]!["clabsi_tpn"]!["state"] as? String == "skipped")
        #expect(rooms["304"]!["clabsi_tpn"]!["cause"] as? String == "manual")
        #expect(rooms["301"]!["occ"]!["value"] as? Bool == false)
        #expect(rooms["301"]!["occ"]!["cause"] == nil)

        let rawDate = rooms["304"]!["clabsi_date"]!["value"] as? String
        #expect(ISO8601DateFormatter().date(from: rawDate ?? "") == date(2026, 10, 4, 12, 0))

        let missing = rooms["303"]!["schmid"]!
        #expect(missing["state"] as? String == "missing")
        #expect(missing["cause"] == nil)
        #expect(missing["value"] == nil)
    }

    @Test func nightShiftDateIsTheEveningItStarted() throws {
        let late = AuditSheet(side: .east, shift: shift(containing: 2026, 10, 6, 1, 30), nurse: "Atlas")
        let morning = AuditSheet(side: .east, shift: shift(containing: 2026, 10, 6, 6, 0), nurse: "Atlas")
        let evening = AuditSheet(side: .east, shift: shift(containing: 2026, 10, 6, 14, 0), nurse: "Atlas")

        let lateJSON = try JSONSerialization.jsonObject(with: late.payloadJSON()) as! [String: Any]
        let morningJSON = try JSONSerialization.jsonObject(with: morning.payloadJSON()) as! [String: Any]
        let eveningJSON = try JSONSerialization.jsonObject(with: evening.payloadJSON()) as! [String: Any]

        #expect(lateJSON["shift"] as? String == "10pm-6am")
        #expect(lateJSON["date"] as? String == "2026-10-05")
        #expect(lateJSON["side"] as? String == "east")
        #expect((lateJSON["rooms"] as! [String: Any]).count == 26)
        #expect(morningJSON["shift"] as? String == "6am-2pm")
        #expect(morningJSON["date"] as? String == "2026-10-06")
        #expect(eveningJSON["shift"] as? String == "2pm-10pm")
        #expect(eveningJSON["date"] as? String == "2026-10-06")
        #expect(lateJSON["starting_census"] is NSNull)
        #expect(lateJSON["anm_rhc"] as? String == "")
    }

    @Test func autosaveRoundTripsDatesScoresAndChoices() throws {
        var sheet = freshSheet()
        sheet.answer("310", .occ, .bool(true))
        sheet.answer("310", .braden, .score(6))
        sheet.answer("310", .restraints, .choices(["ankle straps"]))
        sheet.answer("310", .clabsiDate, .date(date(2026, 9, 30, 0, 0)))
        sheet.skip("310", .clabsiABX)
        let data = try JSONEncoder().encode(sheet)
        let restored = try JSONDecoder().decode(AuditSheet.self, from: data)
        #expect(restored == sheet)
    }
}

@Suite struct PlaceholderLists {
    @Test func isoAndRestraintsMatchTheBriefPlaceholders() {
        #expect(PlaceholderOptionLists.iso == ["contact", "droplet", "airborne", "enteric"])
        #expect(PlaceholderOptionLists.restraints == ["wrist straps", "ankle straps", "green blanket"])
    }
}
