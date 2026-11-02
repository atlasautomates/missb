import WidgetKit
import SwiftUI
import AuditModel

struct MissBEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot
}

struct MissBProvider: TimelineProvider {
    func placeholder(in context: Context) -> MissBEntry {
        MissBEntry(date: Date(), snapshot: ComplicationSnapshot(
            shiftLabel: "2pm-10pm",
            shiftDate: "2026-10-11",
            west: ComplicationSnapshot.SideGlance(remaining: 4, incomplete: 8),
            east: nil
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (MissBEntry) -> Void) {
        let now = Date()
        completion(MissBEntry(date: now, snapshot: ComplicationStore.display(now: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MissBEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let shift = ShiftSchedule.default.instance(containing: now, calendar: calendar)
        let current = MissBEntry(date: now, snapshot: ComplicationStore.display(now: now))
        let rolled = MissBEntry(date: shift.end, snapshot: ComplicationStore.display(now: shift.end))
        completion(Timeline(entries: [current, rolled], policy: .after(shift.end.addingTimeInterval(1))))
    }
}

struct MissBComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: ComplicationSnapshot

    var body: some View {
        face
            .containerBackground(for: .widget) { }
    }

    @ViewBuilder
    private var face: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            Text(inline)
        case .accessoryCorner:
            Text(cornerNumber)
                .widgetLabel(shortWindow)
        default:
            circular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if snapshot.west == nil, snapshot.east == nil {
                Text(shortWindow)
                    .font(.caption.bold())
                    .minimumScaleFactor(0.5)
            } else if snapshot.east == nil {
                oneSide("W", snapshot.west)
            } else if snapshot.west == nil {
                oneSide("E", snapshot.east)
            } else {
                VStack(spacing: 0) {
                    mini("W", snapshot.west)
                    mini("E", snapshot.east)
                }
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(shortWindow)
                .font(.headline)
                .widgetAccentable()
            Text(line("West", snapshot.west))
            Text(line("East", snapshot.east))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: String {
        if snapshot.west == nil, snapshot.east == nil {
            return "MB \(shortWindow)"
        }
        let parts = [("W", snapshot.west), ("E", snapshot.east)].compactMap { letter, glance -> String? in
            guard let glance else { return nil }
            return "\(letter)\(number(glance))"
        }
        return "MB " + parts.joined(separator: " ")
    }

    private var cornerNumber: String {
        if let only = snapshot.west ?? snapshot.east, snapshot.west == nil || snapshot.east == nil {
            return number(only)
        }
        if snapshot.west != nil, snapshot.east != nil {
            let total = (snapshot.west?.remaining ?? 0) + (snapshot.east?.remaining ?? 0)
            return "\(total)"
        }
        return "MB"
    }

    private func oneSide(_ letter: String, _ glance: ComplicationSnapshot.SideGlance?) -> some View {
        VStack(spacing: 0) {
            Text(letter)
                .font(.caption2)
            Text(number(glance))
                .font(.title3.bold())
                .widgetAccentable()
        }
    }

    private func mini(_ letter: String, _ glance: ComplicationSnapshot.SideGlance?) -> some View {
        Text("\(letter) \(number(glance))")
            .font(.caption2.bold())
            .widgetAccentable()
    }

    private func line(_ name: String, _ glance: ComplicationSnapshot.SideGlance?) -> String {
        guard let glance else { return "\(name) —" }
        let value = number(glance)
        if glance.remaining == 0 { return "\(name) done" }
        if let remaining = glance.remaining, remaining < 0 { return "\(name) \(value)" }
        return "\(name) \(value) left"
    }

    private func number(_ glance: ComplicationSnapshot.SideGlance?) -> String {
        guard let remaining = glance?.remaining else { return "—" }
        return "\(remaining)"
    }

    /// "2pm-10pm" becomes "2–10". Short enough for a circular face.
    private var shortWindow: String {
        snapshot.shiftLabel
            .replacingOccurrences(of: "am", with: "")
            .replacingOccurrences(of: "pm", with: "")
            .replacingOccurrences(of: "-", with: "–")
    }
}

struct MissBComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ComplicationStore.kind, provider: MissBProvider()) { entry in
            MissBComplicationView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Miss B")
        .description("Patients left to chart this shift.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

@main
struct MissBComplicationBundle: WidgetBundle {
    var body: some Widget {
        MissBComplication()
    }
}
