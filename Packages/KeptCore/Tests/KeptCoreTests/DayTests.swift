import XCTest
@testable import KeptCore

final class DayTests: XCTestCase {
    private func calendar(_ id: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: id)!
        return calendar
    }

    func testEpochIsKeyZeroAndThursday() {
        XCTAssertEqual(Day.weekday(of: 0), 5)
        XCTAssertEqual(Day.weekday(of: -1), 4)
        XCTAssertEqual(Day.weekday(of: 3), 1) // 1970-01-04 was a Sunday
        XCTAssertEqual(Day.weekday(of: 9), 7) // 1970-01-10 was a Saturday
    }

    func testKeyUsesTheLocalCalendarDateNotUTC() {
        // 2026-10-14 23:30 in Kolkata is still the 14th locally, but 18:00 UTC.
        let kolkata = calendar("Asia/Kolkata")
        let late = kolkata.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 23, minute: 30))!
        let early = kolkata.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 0, minute: 5))!
        XCTAssertEqual(Day.key(for: late, calendar: kolkata), Day.key(for: early, calendar: kolkata))

        // The same instant is a different local day in Honolulu.
        XCTAssertEqual(Day.key(for: early, calendar: calendar("Pacific/Honolulu")), Day.key(for: early, calendar: kolkata) - 1)
    }

    func testRoundTripAcrossDaylightSavingChange() {
        let ny = calendar("America/New_York")
        let start = ny.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        var key = Day.key(for: start, calendar: ny)
        for _ in 0..<5 {
            let date = Day.date(for: key, calendar: ny)
            XCTAssertEqual(Day.key(for: date, calendar: ny), key)
            key += 1
        }
        // 8 March 2026 is the spring-forward day: consecutive keys, 23 hours apart.
        let before = Day.date(for: key - 4, calendar: ny)
        let after = Day.date(for: key - 3, calendar: ny)
        XCTAssertEqual(after.timeIntervalSince(before), 23 * 3600)
    }

    func testWeekStartRespectsFirstWeekday() {
        let wednesday = 20_000 + ((4 - Day.weekday(of: 20_000) + 7) % 7) // some Wednesday
        XCTAssertEqual(Day.weekday(of: wednesday), 4)
        XCTAssertEqual(Day.weekday(of: Day.weekStart(of: wednesday, firstWeekday: 2)), 2)
        XCTAssertEqual(Day.weekStart(of: wednesday, firstWeekday: 2), wednesday - 2)
        XCTAssertEqual(Day.weekStart(of: wednesday, firstWeekday: 1), wednesday - 3)
        XCTAssertEqual(Day.weekStart(of: wednesday - 2, firstWeekday: 2), wednesday - 2)
    }
}
