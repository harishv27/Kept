import XCTest
@testable import KeptCore

final class ScheduleAndStatsTests: XCTestCase {
    private let monday: Int = {
        var key = 20_000
        while Day.weekday(of: key) != 2 { key += 1 }
        return key
    }()

    private var english: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2
        return calendar
    }

    // MARK: Schedule

    func testIsDue() {
        XCTAssertTrue(Schedule.daily.isDue(on: monday))
        XCTAssertTrue(Schedule.timesPerWeek(3).isDue(on: monday + 3))
        XCTAssertTrue(Schedule.weekdays([2]).isDue(on: monday))
        XCTAssertFalse(Schedule.weekdays([2]).isDue(on: monday + 1))
    }

    func testWeeklyTarget() {
        XCTAssertEqual(Schedule.daily.weeklyTarget, 7)
        XCTAssertEqual(Schedule.weekdays([2, 4, 6]).weeklyTarget, 3)
        XCTAssertEqual(Schedule.timesPerWeek(9).weeklyTarget, 7)
        XCTAssertEqual(Schedule.timesPerWeek(0).weeklyTarget, 1)
    }

    func testSummaries() {
        XCTAssertEqual(Schedule.daily.summary(calendar: english), "Every day")
        XCTAssertEqual(Schedule.weekdays([1, 2, 3, 4, 5, 6, 7]).summary(calendar: english), "Every day")
        XCTAssertEqual(Schedule.weekdays([2, 3, 4, 5, 6]).summary(calendar: english), "Weekdays")
        XCTAssertEqual(Schedule.weekdays([1, 7]).summary(calendar: english), "Weekends")
        XCTAssertEqual(Schedule.weekdays([6, 2, 4]).summary(calendar: english), "Mon, Wed, Fri")
        XCTAssertEqual(Schedule.timesPerWeek(1).summary(calendar: english), "Once a week")
        XCTAssertEqual(Schedule.timesPerWeek(3).summary(calendar: english), "3 times a week")
    }

    func testEncodingRoundTrips() {
        for schedule in [Schedule.daily, .weekdays([1, 3, 5]), .timesPerWeek(4)] {
            XCTAssertEqual(Schedule.decode(schedule.encoded), schedule)
        }
        XCTAssertEqual(Schedule.decode(Data()), .daily)
        XCTAssertEqual(Schedule.decode(Data("junk".utf8)), .daily)
    }

    // MARK: Stats

    func testCompletionRateScoresDueDaysAndIgnoresAnOpenToday() {
        let today = monday + 3
        // Mon, Tue done; Wed missed; Thu (today) still open.
        let rate = Stats.completionRate(schedule: .daily, completed: [monday, monday + 1], startDay: monday, today: today, days: 30)
        XCTAssertEqual(rate, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testCompletionRateOnlyScoresScheduledDays() {
        let schedule = Schedule.weekdays([2, 4]) // Mon, Wed
        let rate = Stats.completionRate(schedule: schedule, completed: [monday], startDay: monday, today: monday + 6, days: 30)
        XCTAssertEqual(rate, 0.5, accuracy: 0.0001)
    }

    func testCompletionRateWindowAndStart() {
        // A habit created two days ago is only judged on those days, whatever the window.
        let today = monday + 10
        let rate = Stats.completionRate(schedule: .daily, completed: [today - 1, today], startDay: today - 1, today: today, days: 30)
        XCTAssertEqual(rate, 1)
    }

    func testCompletionRateWithNothingDueIsZero() {
        XCTAssertEqual(Stats.completionRate(schedule: .weekdays([]), completed: [], startDay: monday, today: monday + 5), 0)
        XCTAssertEqual(Stats.completionRate(schedule: .daily, completed: [], startDay: monday + 9, today: monday), 0)
    }

    func testFlexibleCompletionRateIsAgainstTheWeeklyTarget() {
        // 14 days, target 3/week => 6 expected; 3 done => 50%.
        let rate = Stats.completionRate(schedule: .timesPerWeek(3), completed: [monday, monday + 2, monday + 9],
                                        startDay: monday, today: monday + 13, days: 14)
        XCTAssertEqual(rate, 0.5, accuracy: 0.0001)
        let capped = Stats.completionRate(schedule: .timesPerWeek(1), completed: Set(monday...(monday + 6)),
                                          startDay: monday, today: monday + 6, days: 7)
        XCTAssertEqual(capped, 1)
    }

    func testWeeklyCountsAreOldestFirstAndFillGaps() {
        let today = monday + 15 // third week
        let done: Set<Int> = [monday, monday + 1, monday + 15]
        let counts = Stats.weeklyCounts(completed: done, today: today, weeks: 3, firstWeekday: 2)
        XCTAssertEqual(counts.map(\.weekStart), [monday, monday + 7, monday + 14])
        XCTAssertEqual(counts.map(\.count), [2, 0, 1])
    }

    func testDoneThisWeek() {
        let done: Set<Int> = [monday - 1, monday, monday + 3, monday + 7]
        XCTAssertEqual(Stats.doneThisWeek(completed: done, today: monday + 4, firstWeekday: 2), 2)
        XCTAssertEqual(Stats.doneThisWeek(completed: done, today: monday + 4, firstWeekday: 1), 3)
    }
}
