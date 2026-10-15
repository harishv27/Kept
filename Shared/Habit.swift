import Foundation
import SwiftData
import KeptCore

/// One habit and every day it was done. Shared by the app and the widget.
///
/// Completions are a plain array of day keys (see `Day`) rather than a related model: a habit with years of history is
/// still a few kilobytes, a toggle is one write, and the widget can read everything it needs from a single row.
@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbol name.
    var symbol: String = "checkmark"
    /// Index into `HabitPalette`.
    var colorIndex: Int = 0
    var scheduleData: Data = Schedule.daily.encoded
    var completedDays: [Int] = []
    /// Minutes after midnight for the daily reminder, or nil for none.
    var reminderMinutes: Int?
    var createdDay: Int = 0
    var sortOrder: Int = 0
    var archived: Bool = false

    init(name: String, symbol: String, colorIndex: Int, schedule: Schedule, reminderMinutes: Int? = nil,
         createdDay: Int, sortOrder: Int) {
        self.name = name
        self.symbol = symbol
        self.colorIndex = colorIndex
        self.scheduleData = schedule.encoded
        self.reminderMinutes = reminderMinutes
        self.createdDay = createdDay
        self.sortOrder = sortOrder
    }

    var schedule: Schedule {
        get { Schedule.decode(scheduleData) }
        set { scheduleData = newValue.encoded }
    }

    var completed: Set<Int> { Set(completedDays) }

    func isDone(on day: Int) -> Bool { completedDays.contains(day) }

    /// Marks the day done or not done. Returns the new state.
    @discardableResult
    func toggle(_ day: Int) -> Bool {
        if let index = completedDays.firstIndex(of: day) {
            completedDays.remove(at: index)
            return false
        }
        completedDays.append(day)
        return true
    }

    func set(_ day: Int, done: Bool) {
        if done != isDone(on: day) { toggle(day) }
    }
}

extension Habit {
    static func today(calendar: Calendar = .current) -> Int { Day.key(for: .now, calendar: calendar) }

    /// A habit is shown today when its schedule asks for it.
    func isDue(today: Int) -> Bool { schedule.isDue(on: today) }

    func streak(today: Int, calendar: Calendar = .current) -> Streak {
        Streaks.compute(schedule: schedule, completed: completed, startDay: createdDay, today: today,
                        firstWeekday: calendar.firstWeekday)
    }

    func rate(today: Int, days: Int = 30) -> Double {
        Stats.completionRate(schedule: schedule, completed: completed, startDay: createdDay, today: today, days: days)
    }

    /// Whether the habit belongs in today's list. A flexible habit steps aside once its weekly target is met, unless
    /// it was done today (so it does not vanish the moment you tick it).
    func isOpenToday(_ today: Int, calendar: Calendar = .current) -> Bool {
        guard isDue(today: today) else { return false }
        if let week = weekProgress(today: today, calendar: calendar), week.done >= week.target, !isDone(on: today) {
            return false
        }
        return true
    }

    /// "2 of 3 this week" for flexible habits, nil for the rest.
    func weekProgress(today: Int, calendar: Calendar = .current) -> (done: Int, target: Int)? {
        guard schedule.isWeekly else { return nil }
        return (Stats.doneThisWeek(completed: completed, today: today, firstWeekday: calendar.firstWeekday),
                schedule.weeklyTarget)
    }
}
