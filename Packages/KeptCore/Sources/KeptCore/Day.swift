import Foundation

/// A calendar day as a plain integer: days since 1970-01-01 on the local calendar.
///
/// Habits are stored as sets of these integers instead of `Date`s, so "did I do it today?" never depends on a time
/// zone, daylight saving or the time of day the tap happened. Everything below is calendar arithmetic on integers.
public enum Day {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// The day key for the local calendar date of `date`.
    public static func key(for date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let utcMidnight = utc.date(from: parts)!
        return Int((utcMidnight.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Start of the local day for a key.
    public static func date(for key: Int, calendar: Calendar = .current) -> Date {
        let utcMidnight = Date(timeIntervalSince1970: TimeInterval(key) * 86_400)
        let parts = utc.dateComponents([.year, .month, .day], from: utcMidnight)
        return calendar.date(from: parts)!
    }

    /// Weekday of a key in `Calendar` numbering: 1 = Sunday ... 7 = Saturday. 1970-01-01 was a Thursday.
    public static func weekday(of key: Int) -> Int {
        (((key % 7) + 7 + 4) % 7) + 1
    }

    /// First day of the week containing `key`, where `firstWeekday` uses the same 1 = Sunday numbering.
    public static func weekStart(of key: Int, firstWeekday: Int) -> Int {
        key - ((weekday(of: key) - firstWeekday + 7) % 7)
    }
}
