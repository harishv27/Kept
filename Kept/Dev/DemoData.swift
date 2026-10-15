import Foundation
import SwiftData
import KeptCore

/// Sample habits with believable history, for screenshots and trying the app. Debug builds only: runs when launched with `-seedDemo`
/// and only into an empty store, so it can never overwrite real habits.
enum DemoData {
    @MainActor
    static func seedIfRequested(_ container: ModelContainer) async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return }
        let context = container.mainContext
        guard ((try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0) == 0 else { return }

        let today = Habit.today()
        // (name, symbol, colour, schedule, reminder, days of history, chance of doing it, done today, streak right now)
        let specs: [(String, String, Int, Schedule, Int?, Int, Double, Bool, Int)] = [
            ("Morning run", "figure.run", 1, .weekdays([2, 4, 6]), 7 * 60, 120, 0.88, true, 4),
            ("Read 20 pages", "book.fill", 2, .daily, 21 * 60, 120, 0.82, false, 6),
            ("Drink 2L of water", "drop.fill", 0, .daily, nil, 120, 0.9, true, 12),
            ("Meditate", "figure.mind.and.body", 3, .daily, 8 * 60, 90, 0.7, false, 0),
            ("Strength training", "dumbbell.fill", 4, .timesPerWeek(3), nil, 120, 0.8, true, 0),
            ("Practice guitar", "guitars.fill", 5, .weekdays([2, 3, 4, 5, 6]), 19 * 60, 100, 0.75, false, 3),
        ]

        var seed: UInt64 = 42
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }

        for (index, spec) in specs.enumerated() {
            let (name, symbol, color, schedule, reminder, history, chance, doneToday, tailStreak) = spec
            let habit = Habit(name: name, symbol: symbol, colorIndex: color, schedule: schedule, reminderMinutes: reminder,
                              createdDay: today - history, sortOrder: index)
            var done = Set<Int>()
            for day in (today - history)..<today where schedule.isDue(on: day) {
                switch schedule {
                case .timesPerWeek(let n):
                    // Roughly n sessions a week, spread over the week.
                    if random() < Double(n) / 7 * (chance + 0.15) { done.insert(day) }
                default:
                    if random() < chance { done.insert(day) }
                }
            }
            // Shape the tail so the streaks on screen are interesting and exact.
            if tailStreak >= 0, !schedule.isWeekly {
                var day = today - 1
                var run = 0
                while run < tailStreak {
                    if schedule.isDue(on: day) { done.insert(day); run += 1 }
                    day -= 1
                }
                while !schedule.isDue(on: day) { day -= 1 }
                done.remove(day) // the day before the run was missed
                if tailStreak == 0 { for d in (today - 2)...(today - 1) { done.remove(d) } }
            }
            if doneToday { done.insert(today) } else { done.remove(today) }
            habit.completedDays = done.sorted()
            context.insert(habit)
        }
        try? context.save()
        #endif
    }
}
