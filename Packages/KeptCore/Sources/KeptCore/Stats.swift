import Foundation

/// One bar of the weekly chart.
public struct WeekCount: Equatable, Sendable, Identifiable {
    public var id: Int { weekStart }
    public let weekStart: Int
    public let count: Int
}

public enum Stats {
    /// Share of expected days that were done over the last `days` days, 0...1.
    ///
    /// Fixed-day habits are scored on the days they were due. Today is only counted once it is done, so an open day
    /// never drags the number down. Flexible habits are scored against `target * days / 7` completions.
    public static func completionRate(schedule: Schedule, completed: Set<Int>, startDay: Int, today: Int,
                                      days: Int = 30) -> Double {
        let from = max(today - days + 1, startDay)
        guard from <= today else { return 0 }

        if schedule.isWeekly {
            let span = Double(today - from + 1)
            let expected = Double(schedule.weeklyTarget) * span / 7
            guard expected > 0 else { return 0 }
            let done = Double((from...today).filter(completed.contains).count)
            return min(1, done / expected)
        }

        var due = 0
        var done = 0
        for day in from...today where schedule.isDue(on: day) {
            if completed.contains(day) {
                due += 1
                done += 1
            } else if day != today {
                due += 1
            }
        }
        return due == 0 ? 0 : Double(done) / Double(due)
    }

    /// Completions per week for the last `weeks` weeks, oldest first, ending with the week containing `today`.
    public static func weeklyCounts(completed: Set<Int>, today: Int, weeks: Int = 12, firstWeekday: Int = 2) -> [WeekCount] {
        let thisWeek = Day.weekStart(of: today, firstWeekday: firstWeekday)
        var perWeek: [Int: Int] = [:]
        for day in completed { perWeek[Day.weekStart(of: day, firstWeekday: firstWeekday), default: 0] += 1 }
        return (0..<weeks).reversed().map { offset in
            let week = thisWeek - offset * 7
            return WeekCount(weekStart: week, count: perWeek[week, default: 0])
        }
    }

    /// How many completions a flexible habit has in the week containing `today`.
    public static func doneThisWeek(completed: Set<Int>, today: Int, firstWeekday: Int = 2) -> Int {
        let start = Day.weekStart(of: today, firstWeekday: firstWeekday)
        return (start...(start + 6)).filter(completed.contains).count
    }
}
