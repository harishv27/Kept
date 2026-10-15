import XCTest
@testable import KeptCore

final class StreakTests: XCTestCase {
    /// A Monday, so offsets read like a calendar: monday + 2 is Wednesday.
    private let monday: Int = {
        var key = 20_000
        while Day.weekday(of: key) != 2 { key += 1 }
        return key
    }()

    func testDailyCountsConsecutiveDaysEndingToday() {
        let today = monday + 9
        let done: Set<Int> = [today, today - 1, today - 2, today - 4]
        let streak = Streaks.compute(schedule: .daily, completed: done, startDay: monday, today: today)
        XCTAssertEqual(streak, Streak(current: 3, best: 3, inWeeks: false))
    }

    func testOpenTodayDoesNotBreakTheStreak() {
        let today = monday + 9
        let done: Set<Int> = [today - 1, today - 2, today - 3]
        let streak = Streaks.compute(schedule: .daily, completed: done, startDay: monday, today: today)
        XCTAssertEqual(streak.current, 3)
    }

    func testMissedYesterdayResetsCurrentButKeepsBest() {
        let today = monday + 9
        let done: Set<Int> = [monday, monday + 1, monday + 2, monday + 3, today]
        let streak = Streaks.compute(schedule: .daily, completed: done, startDay: monday, today: today)
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.best, 4)
    }

    func testDaysBeforeCreationAreNotMisses() {
        let today = monday + 2
        let streak = Streaks.compute(schedule: .daily, completed: [monday + 1, monday + 2], startDay: monday + 1, today: today)
        XCTAssertEqual(streak.current, 2)
    }

    func testNothingDoneIsZero() {
        let streak = Streaks.compute(schedule: .daily, completed: [], startDay: monday, today: monday + 5)
        XCTAssertEqual(streak, Streak(current: 0, best: 0, inWeeks: false))
    }

    func testCreatedInTheFutureIsZero() {
        let streak = Streaks.compute(schedule: .daily, completed: [], startDay: monday + 5, today: monday)
        XCTAssertEqual(streak.current, 0)
    }

    func testWeekdaysHabitSkipsTheWeekend() {
        let schedule = Schedule.weekdays([2, 3, 4, 5, 6])
        // Mon-Fri of week one, then the next Monday.
        let done: Set<Int> = Set((0...4).map { monday + $0 } + [monday + 7])
        let streak = Streaks.compute(schedule: schedule, completed: done, startDay: monday, today: monday + 7)
        XCTAssertEqual(streak.current, 6)
        XCTAssertEqual(streak.best, 6)
    }

    func testWeekdaysHabitDoneOnAnUnscheduledDayChangesNothing() {
        let schedule = Schedule.weekdays([2, 4]) // Mon, Wed
        let done: Set<Int> = [monday, monday + 1, monday + 2] // Tue is a bonus
        let streak = Streaks.compute(schedule: schedule, completed: done, startDay: monday, today: monday + 2)
        XCTAssertEqual(streak.current, 2)
    }

    func testMissedScheduledDayBreaksWeekdayHabit() {
        let schedule = Schedule.weekdays([2, 4]) // Mon, Wed
        let done: Set<Int> = [monday, monday + 7] // missed Wednesday
        let streak = Streaks.compute(schedule: schedule, completed: done, startDay: monday, today: monday + 7)
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.best, 1)
    }

    func testEmptyWeekdaySetNeverLoops() {
        let streak = Streaks.compute(schedule: .weekdays([]), completed: [], startDay: monday, today: monday + 30)
        XCTAssertEqual(streak.current, 0)
    }

    func testWeeklyHabitCountsWeeksThatReachedTheTarget() {
        let schedule = Schedule.timesPerWeek(3)
        var done = Set<Int>()
        for week in 0..<3 { for d in [0, 2, 4] { done.insert(monday + week * 7 + d) } }
        // Week four is in progress with one session so far.
        done.insert(monday + 21)
        let streak = Streaks.compute(schedule: schedule, completed: done, startDay: monday, today: monday + 22)
        XCTAssertEqual(streak, Streak(current: 3, best: 3, inWeeks: true))
    }

    func testWeeklyHabitBreaksOnAShortWeek() {
        let schedule = Schedule.timesPerWeek(2)
        let done: Set<Int> = [monday, monday + 1, monday + 7, monday + 14, monday + 15]
        let streak = Streaks.compute(schedule: schedule, completed: done, startDay: monday, today: monday + 15)
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.best, 1)
    }

    func testWeeklyHabitInProgressWeekGrowsTheStreakWhenTargetIsMet() {
        let schedule = Schedule.timesPerWeek(2)
        let done: Set<Int> = [monday, monday + 1, monday + 7, monday + 8]
        let streak = Streaks.compute(schedule: schedule, completed: done, startDay: monday, today: monday + 8)
        XCTAssertEqual(streak.current, 2)
    }

    func testUnitWording() {
        XCTAssertEqual(Streak(current: 1, best: 1, inWeeks: false).unit, "day")
        XCTAssertEqual(Streak(current: 4, best: 4, inWeeks: false).unit, "days")
        XCTAssertEqual(Streak(current: 1, best: 1, inWeeks: true).unit, "week")
        XCTAssertEqual(Streak(current: 0, best: 0, inWeeks: true).unit, "weeks")
    }
}
