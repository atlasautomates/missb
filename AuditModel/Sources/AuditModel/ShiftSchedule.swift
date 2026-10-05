import Foundation

/// The floor's three shifts. Windows are half-open on the clock: the minute
/// a window starts belongs to that window (06:00 is morning, not the last
/// minute of night). The night window crosses midnight; its identity is the
/// 22:00 it started, so 23:00 and 01:30 the next morning are one instance.
public struct ShiftSchedule: Sendable {
    public static let `default` = ShiftSchedule()

    private init() {}

    public func instance(containing date: Date, calendar: Calendar) -> ShiftInstance {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let hour = parts.hour, let minute = parts.minute else {
            preconditionFailure("calendar could not read the components of \(date)")
        }

        let minutes = hour * 60 + minute
        let window = Self.window(containing: minutes)
        // After midnight the night shift's start is still the previous evening.
        let dayOffset = (window.spansMidnight && minutes < window.endMinutes) ? -1 : 0
        let start = Self.clock(year: year, month: month, day: day, hour: window.startHour,
                               dayOffset: dayOffset, calendar: calendar)
        let end = Self.clock(on: start, hour: window.endHour,
                             addDay: window.spansMidnight, calendar: calendar)
        return ShiftInstance(label: window.label, start: start, end: end,
                             date: Self.dayString(start, calendar: calendar))
    }

    private static func window(containing minutes: Int) -> Window {
        if minutes >= night.startMinutes || minutes < night.endMinutes {
            return night
        }
        if minutes < morning.endMinutes {
            return morning
        }
        return evening
    }

    private static func clock(year: Int, month: Int, day: Int, hour: Int,
                              dayOffset: Int, calendar: Calendar) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = 0
        parts.second = 0
        parts.nanosecond = 0
        guard let dated = calendar.date(from: parts) else {
            preconditionFailure("calendar could not build \(year)-\(month)-\(day) \(hour):00")
        }
        guard dayOffset != 0 else { return dated }
        guard let shifted = calendar.date(byAdding: .day, value: dayOffset, to: dated) else {
            preconditionFailure("calendar could not shift \(dated) by \(dayOffset) days")
        }
        return shifted
    }

    /// End (or any clock time) on the civil day of `day`, optionally the next
    /// day. Built from clock components rather than adding 8 absolute hours
    /// so a DST fallback still ends at 06:00 local.
    private static func clock(on day: Date, hour: Int, addDay: Bool, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = 0
        parts.second = 0
        parts.nanosecond = 0
        guard var dated = calendar.date(from: parts) else {
            preconditionFailure("calendar could not build hour \(hour) on \(day)")
        }
        if addDay {
            guard let next = calendar.date(byAdding: .day, value: 1, to: dated) else {
                preconditionFailure("calendar could not advance \(dated) one day")
            }
            dated = next
        }
        return dated
    }

    private static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            preconditionFailure("calendar could not read the day of \(date)")
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private struct Window {
        let label: String
        let startHour: Int
        let endHour: Int
        let spansMidnight: Bool

        var startMinutes: Int { startHour * 60 }
        var endMinutes: Int { endHour * 60 }
    }

    private static let night = Window(label: "10pm-6am", startHour: 22, endHour: 6, spansMidnight: true)
    private static let morning = Window(label: "6am-2pm", startHour: 6, endHour: 14, spansMidnight: false)
    private static let evening = Window(label: "2pm-10pm", startHour: 14, endHour: 22, spansMidnight: false)
}

public struct ShiftInstance: Equatable, Codable, Sendable {
    public let label: String
    public let start: Date
    public let end: Date
    /// `yyyy-MM-dd` of `start` in the calendar that resolved the instance.
    /// For the night window this is the evening the shift began, so both
    /// sides of midnight share one sheet date.
    public let date: String
}
