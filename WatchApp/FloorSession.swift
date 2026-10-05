import Foundation
import AuditModel

/// One launch's nurse plus the two side sheets for the shift that contained
/// launch. The watch UI reads this; completion and skip rules stay in AuditModel.
@MainActor
@Observable
final class FloorSession {
    let shift: ShiftInstance
    private(set) var nurse: NurseProfile?
    private(set) var sheets: [String: AuditSheet] = [:]
    private let directory: URL

    init(now: Date = Date(), directory: URL? = nil) {
        let calendar = Calendar.current
        // Resolved once per launch. Crossing a shift boundary while the app
        // stays open is out of scope for this skeleton; the next launch
        // re-resolves and drops a sheet that fails belongsTo.
        shift = ShiftSchedule.default.instance(containing: now, calendar: calendar)
        if let directory {
            self.directory = directory
        } else {
            self.directory = (try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? FileManager.default.temporaryDirectory
        }
        restore()
    }

    func select(nurse: NurseProfile) {
        // Not persisted. A relaunch may ask who's holding the watch again.
        // An existing sheet keeps the nurse who started it.
        self.nurse = nurse
    }

    func sheet(for side: Side) -> AuditSheet? {
        sheets[side.rawValue]
    }

    func needsHeader(_ side: Side) -> Bool {
        guard let sheet = sheet(for: side) else { return true }
        return sheet.anmRHC.isEmpty || sheet.startingCensus == nil
    }

    @discardableResult
    func commitHeader(side: Side, anmRHC: String, census: Int) -> Bool {
        guard !anmRHC.isEmpty, (0...26).contains(census) else { return false }
        let sheet: AuditSheet
        if var existing = sheets[side.rawValue] {
            existing.anmRHC = anmRHC
            existing.startingCensus = census
            sheet = existing
        } else {
            guard let nurse else { return false }
            var created = AuditSheet(side: side, shift: shift, nurse: nurse.name)
            created.anmRHC = anmRHC
            created.startingCensus = census
            sheet = created
        }
        store(sheet)
        return true
    }

    func answerOcc(side: Side, room: String, occupied: Bool) {
        guard var sheet = sheets[side.rawValue] else { return }
        sheet.answer(room, .occ, .bool(occupied))
        store(sheet)
    }

    private func store(_ sheet: AuditSheet) {
        sheets[sheet.side.rawValue] = sheet
        persist(sheet)
    }

    private func persist(_ sheet: AuditSheet) {
        // Default date strategy, same as AuditModel's round-trip tests.
        // belongsTo compares ShiftInstance dates; a custom strategy can bring
        // them back unequal and the next launch would drop a live sheet.
        guard let data = try? JSONEncoder().encode(sheet) else { return }
        try? data.write(to: fileURL(sheet.side), options: .atomic)
    }

    private func restore() {
        for side in [Side.west, Side.east] {
            guard let data = try? Data(contentsOf: fileURL(side)),
                  let sheet = try? JSONDecoder().decode(AuditSheet.self, from: data) else {
                continue
            }
            // A file from another shift stays on disk until this shift
            // overwrites it, but it must not open as today's sheet.
            guard sheet.side == side, sheet.belongsTo(shift: shift) else { continue }
            sheets[side.rawValue] = sheet
        }
    }

    private func fileURL(_ side: Side) -> URL {
        directory.appendingPathComponent("audit-\(side.rawValue).json")
    }
}
