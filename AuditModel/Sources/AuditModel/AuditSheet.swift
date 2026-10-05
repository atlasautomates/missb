import Foundation

public struct AuditSheet: Equatable, Codable, Sendable {
    public let side: Side
    public let shift: ShiftInstance
    public let nurse: String
    public var anmRHC: String
    public var startingCensus: Int?

    /// Answered and skipped checks only. Absence is `.missing`, so clearing
    /// a skip removes the entry. An emptied-then-reopened room then matches
    /// a room that was never touched.
    private var answers: [String: [String: CheckState]]

    public init(side: Side, shift: ShiftInstance, nurse: String) {
        self.side = side
        self.shift = shift
        self.nurse = nurse
        self.anmRHC = ""
        self.startingCensus = nil
        self.answers = [:]
    }

    public func state(of check: Check, in room: String) -> CheckState {
        answers[room]?[check.rawValue] ?? .missing
    }

    /// Records `value`.
    ///
    /// OCC = false marks every other check `.skipped(.emptyRoom)` and finishes
    /// the room. While that stands, answers to other checks are ignored —
    /// reopening is OCC = true, which clears empty-room skips back to missing
    /// and does not restore what was overwritten.
    ///
    /// F.C. = false marks `cautiDate` and `cautiPRC` `.skipped(.noFoley)` and
    /// nothing else. F.C. = true clears only those no-foley skips. Answering
    /// a CAUTI tail while F.C. is false is ignored.
    public mutating func answer(_ room: String, _ check: Check, _ value: CheckValue) {
        guard side.rooms.contains(room) else { return }
        if check != .occ, isEmpty(room) { return }
        if check.isCautiTail, isNoFoley(room) { return }

        write(room, check, .answered(value))

        if check == .occ {
            if value == .bool(false) {
                for other in Check.allCases where other != .occ {
                    write(room, other, .skipped(.emptyRoom))
                }
            } else if value == .bool(true) {
                clear(cause: .emptyRoom, in: room, checks: Array(Check.allCases))
            }
        } else if check == .cautiFC {
            if value == .bool(false) {
                write(room, .cautiDate, .skipped(.noFoley))
                write(room, .cautiPRC, .skipped(.noFoley))
            } else if value == .bool(true) {
                clear(cause: .noFoley, in: room, checks: [.cautiDate, .cautiPRC])
            }
        }
    }

    /// Manual N/A. Only CLABSI sub-checks accept it. A manual skip on any
    /// other check would hide a gap, so those calls are ignored. Also ignored
    /// while the room is empty, so an empty-room cause is not overwritten.
    public mutating func skip(_ room: String, _ check: Check) {
        guard side.rooms.contains(room) else { return }
        guard check.isManuallySkippable else { return }
        if isEmpty(room) { return }
        write(room, check, .skipped(.manual))
    }

    public func isRoomComplete(_ room: String) -> Bool {
        guard side.rooms.contains(room) else { return false }
        return Check.allCases.allSatisfy { state(of: $0, in: room) != .missing }
    }

    public var isComplete: Bool {
        incompleteRooms.isEmpty
    }

    public var incompleteRooms: [String] {
        side.rooms.filter { !isRoomComplete($0) }
    }

    /// Rooms whose OCC answer is yes. Missing and empty rooms do not count.
    public var occupiedCount: Int {
        side.rooms.filter { state(of: .occ, in: $0) == .answered(.bool(true)) }.count
    }

    /// Stated census differs from `occupiedCount`. Unset census is not a
    /// discrepancy — there is no stated number to compare.
    public var hasCensusDiscrepancy: Bool {
        guard let startingCensus else { return false }
        return startingCensus != occupiedCount
    }

    public func belongsTo(shift: ShiftInstance) -> Bool {
        self.shift == shift
    }

    /// Listener document. Separate from `Codable` autosave: the wire form is
    /// snake_case and names every check's state. `cause` is present only on
    /// skips. Answered checks carry `value`.
    public func payloadJSON() throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var rooms: [String: [String: Any]] = [:]
        rooms.reserveCapacity(side.rooms.count)
        for room in side.rooms {
            var checks: [String: Any] = [:]
            checks.reserveCapacity(Check.allCases.count)
            for check in Check.allCases {
                checks[check.rawValue] = wire(state(of: check, in: room), dates: formatter)
            }
            rooms[room] = checks
        }

        var body: [String: Any] = [
            "side": side.rawValue,
            "shift": shift.label,
            "nurse": nurse,
            "anm_rhc": anmRHC,
            "date": shift.date,
            "rooms": rooms,
        ]
        if let startingCensus {
            body["starting_census"] = startingCensus
        } else {
            body["starting_census"] = NSNull()
        }
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    private func isEmpty(_ room: String) -> Bool {
        state(of: .occ, in: room) == .answered(.bool(false))
    }

    private func isNoFoley(_ room: String) -> Bool {
        state(of: .cautiFC, in: room) == .answered(.bool(false))
    }

    private mutating func write(_ room: String, _ check: Check, _ state: CheckState) {
        switch state {
        case .missing:
            guard var roomAnswers = answers[room] else { return }
            roomAnswers[check.rawValue] = nil
            answers[room] = roomAnswers.isEmpty ? nil : roomAnswers
        default:
            var roomAnswers = answers[room] ?? [:]
            roomAnswers[check.rawValue] = state
            answers[room] = roomAnswers
        }
    }

    private mutating func clear(cause: SkipCause, in room: String, checks: [Check]) {
        for check in checks {
            if case .skipped(let existing) = state(of: check, in: room), existing == cause {
                write(room, check, .missing)
            }
        }
    }

    private func wire(_ state: CheckState, dates: ISO8601DateFormatter) -> [String: Any] {
        switch state {
        case .missing:
            return ["state": "missing"]
        case .answered(let value):
            return ["state": "answered", "value": jsonValue(value, dates: dates)]
        case .skipped(let cause):
            return ["state": "skipped", "cause": cause.rawValue]
        }
    }

    private func jsonValue(_ value: CheckValue, dates: ISO8601DateFormatter) -> Any {
        switch value {
        case .bool(let v): v
        case .choice(let v): v
        case .choices(let v): v
        case .score(let v): v
        case .date(let v): dates.string(from: v)
        }
    }
}
