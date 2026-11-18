import XCTest
@testable import SeedboardCore

/// 0.9: done day against the plan, Swedish holidays, and the scale a timeline opens in.
final class Timing09Tests: XCTestCase {
    func testDoneDayAgainstThePlannedLastDay() {
        let today = Day(year: 2026, month: 11, day: 18)
        var board = Board.timeline(title: "Build")
        let late = board.addBar("Late", start: today - 20, days: 3)   // last day 12 Nov... planned end today-18
        let early = board.addBar("Early", start: today, days: 4)      // last day today+3
        let onTime = board.addBar("Exact", start: today - 2, days: 3) // last day today
        let one = board.addBar("One", start: today - 5, days: 1)      // last day today-5
        let mile = board.addMilestone("Gate", on: today + 1)
        board.setDone([late, early, onTime, one, mile], true, on: today)

        XCTAssertEqual(board.item(late)?.doneHint(today: today)?.line, "18 Nov · 18 days late")
        XCTAssertEqual(board.item(early)?.doneHint(today: today)?.line, "18 Nov · 3 days early")
        XCTAssertEqual(board.item(onTime)?.doneHint(today: today)?.line, "18 Nov")
        XCTAssertEqual(board.item(onTime)?.doneTiming, .onTime)
        XCTAssertEqual(board.item(one)?.doneHint(today: today)?.line, "18 Nov · 5 days late")
        // A milestone's one day is its planned day; singular for one day.
        XCTAssertEqual(board.item(mile)?.doneHint(today: today)?.line, "18 Nov · 1 day early")
        XCTAssertEqual(DoneTiming(daysAfterPlan: 1).words, "1 day late")
        XCTAssertEqual(DoneTiming(daysAfterPlan: -8).words, "8 days early")
        // The Dates page line carries it; not done = nothing.
        XCTAssertEqual(board.doneLine(of: early, today: today), "Done on 18 Nov · 3 days early")
        board.setDone([early], false, on: today)
        XCTAssertNil(board.item(early)?.doneHint(today: today))
    }

    func testSwedishHolidays() {
        XCTAssertEqual(SwedishHolidays.easter(2027), Day(year: 2027, month: 3, day: 28))
        let h2027 = Dictionary(uniqueKeysWithValues: SwedishHolidays.holidays(in: 2027).map { ($0.name, $0.day) })
        XCTAssertEqual(h2027.count, 16)
        XCTAssertEqual(h2027["Midsummer Eve"], Day(year: 2027, month: 6, day: 25))
        XCTAssertEqual(h2027["Good Friday"], Day(year: 2027, month: 3, day: 26))
        XCTAssertEqual(h2027["Ascension Day"], Day(year: 2027, month: 5, day: 6))
        let h2026 = Dictionary(uniqueKeysWithValues: SwedishHolidays.holidays(in: 2026).map { ($0.name, $0.day) })
        XCTAssertEqual(h2026["All Saints' Day"], Day(year: 2026, month: 10, day: 31))
        XCTAssertEqual(h2026["Midsummer Day"], Day(year: 2026, month: 6, day: 20))
        let across = SwedishHolidays.names(from: Day(year: 2026, month: 12, day: 24), to: Day(year: 2027, month: 1, day: 6))
        XCTAssertEqual(across.count, 6)
        XCTAssertEqual(across[Day(year: 2027, month: 1, day: 6)], "Epiphany")
    }

    func testTheScaleATimelineOpensIn() {
        XCTAssertEqual(TimeScale.opening(planDays: 100, fitting: .weeks, chosen: nil), .weeks)
        XCTAssertEqual(TimeScale.opening(planDays: 183, fitting: .weeks, chosen: nil), .weeks)
        XCTAssertEqual(TimeScale.opening(planDays: 184, fitting: .weeks, chosen: nil), .months)
        // The owner's choice for this board wins.
        XCTAssertEqual(TimeScale.opening(planDays: 400, fitting: .months, chosen: .days), .days)
        var board = Board.timeline(title: "Long")
        _ = board.addBar("A", start: Day(year: 2027, month: 1, day: 1), days: 10)
        _ = board.addBar("B", start: Day(year: 2027, month: 9, day: 1), days: 10)
        XCTAssertEqual(board.timelinePlanDays, 253)
        XCTAssertEqual(TimelineGeometry.ticks(from: Day(year: 2027, month: 1, day: 1), to: Day(year: 2027, month: 2, day: 5), scale: .months).map(\.label),
                       ["Jan 2027", "Feb 2027"])
    }
}
