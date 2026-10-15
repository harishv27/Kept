import Foundation

/// The current and best streak for a habit.
public struct Streak: Equatable, Sendable {
    public var current: Int
    public var best: Int
    /// `true` when the numbers count weeks (a "times per week" habit), `false` when they count days.
    public var inWeeks: Bool

    public init(current: Int, best: Int, inWeeks: Bool) {
        self.current = current
        self.best = best
        self.inWeeks = inWeeks
    }

    public var unit: String { inWeeks ? (current == 1 ? "week" : "weeks") : (current == 1 ? "day" : "days") }
}

public enum Streaks {
    /// Streak rules:
    /// - Only days the schedule asks for count. A skipped Sunday on a Mon-Fri habit does not break anything.
    /// - Today never breaks a streak while it is still open: finish it and the streak grows, ignore it and the streak
    ///   shows yesterday's value until midnight.
    /// - A flexible habit (N times a week) counts consecutive weeks that reached N. The week in progress is treated like
    ///   an open today.
    ///
    /// - Parameters:
    ///   - completed: day keys the habit was done.
    ///   - startDay: the day the habit was created; days before it are never counted as missed.
    public static func compute(schedule: Schedule, completed: Set<Int>, startDay: Int, today: Int,
                               firstWeekday: Int = 2) -> Streak {
        if schedule.isWeekly {
            return weekly(target: schedule.weeklyTarget, completed: completed, startDay: startDay, today: today,
                          firstWeekday: firstWeekday)
        }
        return daily(schedule: schedule, completed: completed, startDay: startDay, today: today)
    }

    private static func daily(schedule: Schedule, completed: Set<Int>, startDay: Int, today: Int) -> Streak {
        if case .weekdays(let days) = schedule, days.isEmpty { return Streak(current: 0, best: 0, inWeeks: false) }
        let first = min(startDay, completed.min() ?? startDay)
        guard first <= today else { return Streak(current: 0, best: 0, inWeeks: false) }

        var run = 0
        var best = 0
        for day in first...today where schedule.isDue(on: day) {
            if completed.contains(day) {
                run += 1
                best = max(best, run)
            } else if day != today {
                run = 0
            }
        }

        var current = 0
        var day = today
        while day >= first {
            if schedule.isDue(on: day) {
                if completed.contains(day) { current += 1 } else if day != today { break }
            }
            day -= 1
        }
        return Streak(current: current, best: max(best, current), inWeeks: false)
    }

    private static func weekly(target: Int, completed: Set<Int>, startDay: Int, today: Int, firstWeekday: Int) -> Streak {
        var perWeek: [Int: Int] = [:]
        for day in completed { perWeek[Day.weekStart(of: day, firstWeekday: firstWeekday), default: 0] += 1 }

        let thisWeek = Day.weekStart(of: today, firstWeekday: firstWeekday)
        let first = Day.weekStart(of: min(startDay, completed.min() ?? startDay), firstWeekday: firstWeekday)
        guard first <= thisWeek else { return Streak(current: 0, best: 0, inWeeks: true) }

        var run = 0
        var best = 0
        for week in stride(from: first, through: thisWeek, by: 7) {
            if perWeek[week, default: 0] >= target {
                run += 1
                best = max(best, run)
            } else if week != thisWeek {
                run = 0
            }
        }

        var current = 0
        var week = thisWeek
        while week >= first {
            if perWeek[week, default: 0] >= target { current += 1 } else if week != thisWeek { break }
            week -= 7
        }
        return Streak(current: current, best: max(best, current), inWeeks: true)
    }
}
