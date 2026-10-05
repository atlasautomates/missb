import AuditModel

/// Where the occupied-room flow sits in paper order. OCC stays on its own
/// screen in front of this cursor. Skipped checks are never presented.
enum CheckCursor {
    static func entry(in room: String, sheet: AuditSheet) -> Check {
        let tail = Check.allCases.filter { $0 != .occ }
        if let missing = tail.first(where: { sheet.state(of: $0, in: room) == .missing }) {
            return missing
        }
        return .bedStatus
    }

    /// Next check to show after an answer.
    ///
    /// Unanswered checks win, so a resumed room jumps the gap instead of
    /// re-asking finished ones. A fully charted room keeps walking the
    /// remaining answered checks; otherwise a reopen could not reach them.
    /// Nil means this room is done — the caller returns to the room list
    /// and does not open another room.
    static func next(after check: Check, in room: String, sheet: AuditSheet) -> Check? {
        let order = Array(Check.allCases)
        guard let idx = order.firstIndex(of: check) else { return nil }
        let rest = order[order.index(after: idx)...]

        if let missing = rest.first(where: { sheet.state(of: $0, in: room) == .missing }) {
            return missing
        }
        if let earlier = order[..<idx].first(where: { $0 != .occ && sheet.state(of: $0, in: room) == .missing }) {
            return earlier
        }
        guard sheet.isRoomComplete(room) else { return nil }
        return rest.first { !isSkipped($0, in: room, sheet: sheet) }
    }

    static func previous(before check: Check, in room: String, sheet: AuditSheet) -> Check? {
        let order = Array(Check.allCases)
        guard let idx = order.firstIndex(of: check) else { return nil }
        return order[..<idx].reversed().first { candidate in
            candidate != .occ && !isSkipped(candidate, in: room, sheet: sheet)
        }
    }

    static func title(for check: Check) -> String {
        switch check {
        case .occ: "OCC."
        case .bedStatus: "BED"
        case .iso: "ISO"
        case .cdiff: "C.DIFF"
        case .braden: "BRADEN"
        case .schmid: "SCHMID"
        case .bundleDoor: "DOOR"
        case .bundleRails: "RAILS"
        case .bundleArm: "ARM"
        case .bundleSocks: "SOCKS"
        case .bundleBook: "BOOK"
        case .clabsiCL: "CLABSI CL"
        case .clabsiDate: "CLABSI DATE"
        case .clabsiABX: "CLABSI ABX"
        case .clabsiTPN: "CLABSI TPN"
        case .cautiFC: "F.C."
        case .cautiDate: "CAUTI DATE"
        case .cautiPRC: "P/R/C"
        case .restraints: "RESTRAINTS"
        case .fr: "FR"
        case .sitter: "SITT."
        case .bariatric: "BARI."
        }
    }

    private static func isSkipped(_ check: Check, in room: String, sheet: AuditSheet) -> Bool {
        if case .skipped = sheet.state(of: check, in: room) { return true }
        return false
    }
}
