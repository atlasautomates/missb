import SwiftUI

/// Today at index 0, then older days. A future day is not in the collection,
/// and the crown is not continuous, so it cannot scroll past today.
enum PastDates {
    static let lookbackDays = 366

    static func days(today: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: today)
        return (0...lookbackDays).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: start)
        }
    }

    static func label(_ date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let week = calendar.shortWeekdaySymbols[weekday - 1]
        let mon = calendar.shortMonthSymbols[month - 1]
        return "\(week) \(mon) \(day)"
    }
}

struct DateCheckView: View {
    let days: [Date]
    @Binding var picking: Bool
    let onCommit: (Date) -> Void

    @State private var index: Int
    @FocusState private var crownFocused: Bool

    init(stored: Date?, picking: Binding<Bool>, onCommit: @escaping (Date) -> Void) {
        let days = PastDates.days()
        self.days = days
        self.onCommit = onCommit
        _picking = picking
        let matched = stored.flatMap { stored in
            days.firstIndex { Calendar.current.isDate($0, inSameDayAs: stored) }
        }
        _index = State(initialValue: matched ?? 0)
    }

    var body: some View {
        if picking {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(days.enumerated()), id: \.offset) { offset, day in
                        CheckTap(
                            selected: offset == safeIndex,
                            identifier: "date.\(offset)",
                            action: { onCommit(day) }
                        ) {
                            Text(PastDates.label(day))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 4) {
                wheel
                    .focusable()
                    .focused($crownFocused)
                    .digitalCrownRotation(
                        detent: $index,
                        from: 0,
                        through: max(days.count - 1, 0),
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                Text("Today or earlier")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    CheckTap(selected: true, identifier: "check.set", action: commitShown) {
                        Text("Set")
                    }
                    CheckTap(selected: false, identifier: "check.pick", action: { picking = true }) {
                        Text("Pick")
                    }
                }
            }
            .onAppear { crownFocused = true }
        }
    }

    private var wheel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(PastDates.label(days[safeIndex]))
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("date.current")
            ForEach(Array(older.enumerated()), id: \.offset) { offset, day in
                Text(PastDates.label(day))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("date.older.\(offset + 1)")
            }
        }
    }

    private var safeIndex: Int {
        guard !days.isEmpty else { return 0 }
        return min(max(index, 0), days.count - 1)
    }

    private var older: [Date] {
        let start = safeIndex + 1
        guard start < days.count else { return [] }
        return Array(days[start..<min(days.count, start + 2)])
    }

    private func commitShown() {
        guard days.indices.contains(safeIndex) else { return }
        onCommit(days[safeIndex])
    }
}
