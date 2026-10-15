import Foundation

/// How often a habit is meant to happen.
public enum Schedule: Codable, Hashable, Sendable {
    /// Every day.
    case daily
    /// On fixed weekdays, using `Calendar` numbering (1 = Sunday ... 7 = Saturday).
    case weekdays(Set<Int>)
    /// Any days, this many times per week (1...7). Flexible: the streak counts weeks, not days.
    case timesPerWeek(Int)

    /// Whether a habit with this schedule is expected on the given day. Flexible habits can be done on any day.
    public func isDue(on key: Int) -> Bool {
        switch self {
        case .daily, .timesPerWeek: return true
        case .weekdays(let days): return days.contains(Day.weekday(of: key))
        }
    }

    /// A week-based schedule has its streak measured in weeks.
    public var isWeekly: Bool {
        if case .timesPerWeek = self { return true }
        return false
    }

    /// Completions needed per week (daily = 7).
    public var weeklyTarget: Int {
        switch self {
        case .daily: return 7
        case .weekdays(let days): return max(1, days.count)
        case .timesPerWeek(let n): return min(7, max(1, n))
        }
    }

    /// Short text for lists: "Every day", "Mon, Wed, Fri", "3 times a week".
    public func summary(calendar: Calendar = .current) -> String {
        switch self {
        case .daily:
            return "Every day"
        case .weekdays(let days):
            if days.count == 7 { return "Every day" }
            if days == [2, 3, 4, 5, 6] { return "Weekdays" }
            if days == [1, 7] { return "Weekends" }
            let names = calendar.shortWeekdaySymbols
            let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }.filter(days.contains)
            return ordered.map { names[$0 - 1] }.joined(separator: ", ")
        case .timesPerWeek(let n):
            return n == 1 ? "Once a week" : "\(min(7, max(1, n))) times a week"
        }
    }

    /// JSON for storage. A `Data` column is more stable across SwiftData versions than a Codable enum.
    public var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }

    public static func decode(_ data: Data) -> Schedule {
        (try? JSONDecoder().decode(Schedule.self, from: data)) ?? .daily
    }
}
