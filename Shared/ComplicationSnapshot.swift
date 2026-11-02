import Foundation
import AuditModel

/// What the watch face shows. Written by the app into the shared app group;
/// the complication reads it. A snapshot from another shift is ignored, so
/// the face falls back to the window the clock is in.
struct ComplicationSnapshot: Codable, Equatable, Sendable {
    var shiftLabel: String
    var shiftDate: String
    var west: SideGlance?
    var east: SideGlance?

    struct SideGlance: Codable, Equatable, Sendable {
        /// Census countdown. Nil when that side has no stated census.
        var remaining: Int?
        var incomplete: Int
    }
}

enum ComplicationStore {
    static let kind = "MissB"
    static let appGroup = "group.com.atlasautomates.missb"

    static func write(_ snapshot: ComplicationSnapshot) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read() -> ComplicationSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ComplicationSnapshot.self, from: data)
    }

    /// The face at `now`. Charting from a different window is not shown.
    static func display(now: Date, calendar: Calendar = .current) -> ComplicationSnapshot {
        let live = ShiftSchedule.default.instance(containing: now, calendar: calendar)
        if let stored = read(), stored.shiftDate == live.date, stored.shiftLabel == live.label {
            return stored
        }
        return ComplicationSnapshot(shiftLabel: live.label, shiftDate: live.date, west: nil, east: nil)
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("complication.json")
    }
}
