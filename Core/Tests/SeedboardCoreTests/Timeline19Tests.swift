import XCTest
@testable import SeedboardCore

/// 0.19, timelines: callout words, note, who, group by colour, repeat.
final class Timeline19Tests: XCTestCase {
    private let dec1 = Day(year: 2026, month: 12, day: 1)

    func testTheCalloutReadsTheDatesAndLeavesTheYearOutThisYear() {
        var board = Board.timeline(title: "T")
        let bar = board.addBar("A", start: dec1, days: 12)
        let milestone = board.addMilestone("M", on: dec1)
        XCTAssertEqual(board.item(bar)?.spanCallout(today: dec1), "1 Dec – 12 Dec · 12 days")
        XCTAssertEqual(board.item(milestone)?.spanCallout(today: dec1), "1 Dec")
        XCTAssertEqual(board.item(bar)?.spanCallout(today: dec1 + 400), "1 Dec 2026 – 12 Dec 2026 · 12 days")
    }

    func testANoteAndInitialsAreKeptClean() {
        var board = Board.timeline(title: "T")
        let milestone = board.addMilestone("M", on: dec1)
        let bar = board.addBar("A", start: dec1)
        XCTAssertTrue(board.setNote(milestone, "  Call the bank  "))
        XCTAssertEqual(board.item(milestone)?.note, "Call the bank")
        XCTAssertTrue(board.setNote(milestone, "   "))
        XCTAssertNil(board.item(milestone)?.note)
        XCTAssertTrue(board.setInitials(bar, "a.s-x y"))
        XCTAssertEqual(board.item(bar)?.initials, "ASX")
        XCTAssertFalse(board.setInitials(milestone, "AB"))
        XCTAssertTrue(board.setInitials(bar, ""))
        XCTAssertNil(board.item(bar)?.initials)
    }

    func testGroupByColourKeepsPhasesAndTheOrderOfFirstAppearance() {
        var board = Board.timeline(title: "T")
        let a = board.addBar("a", start: dec1, colour: "pink")
        let b = board.addBar("b", start: dec1, colour: "teal")
        let c = board.addBar("c", start: dec1, colour: "pink")
        let phase = board.addPhase("P")
        let d = board.addBar("d", start: dec1, colour: "teal")
        let e = board.addBar("e", start: dec1, colour: "blue")
        let f = board.addBar("f", start: dec1, colour: "teal")
        XCTAssertTrue(board.canGroupByColour)
        XCTAssertTrue(board.groupByColour())
        // pink, then teal, then blue (first appearance); inside each part the old order; the phase stays.
        XCTAssertEqual(board.timelineRows.map(\.id), [a, c, b, phase, d, f, e])
        XCTAssertFalse(board.canGroupByColour)
        XCTAssertFalse(board.groupByColour())
    }

    func testRepeatMakesCopiesUnderTheBarWithTheSameLengthAndColour() {
        var board = Board.timeline(title: "T")
        let bar = board.addBar("Gym", start: dec1, days: 2, colour: "green")
        let after = board.addBar("Later", start: dec1 + 30)
        let copies = board.repeatRow(bar, every: .week, times: 4)
        XCTAssertEqual(copies.count, 3)
        XCTAssertEqual(board.timelineRows.map(\.id), [bar] + copies + [after])
        XCTAssertEqual(copies.compactMap { board.item($0)?.span?.start.iso }, ["2026-12-08", "2026-12-15", "2026-12-22"])
        XCTAssertTrue(copies.allSatisfy { board.item($0)?.dayCount == 2 && board.item($0)?.colour == "green" })
        XCTAssertEqual(BarRepeat.clean(times: 99), 12)
        XCTAssertEqual(BarRepeat.clean(times: 0), 2)
    }

    func testAMonthlyRepeatKeepsTheDayOrTheLastOfAShorterMonth() {
        let jan31 = Day(year: 2027, month: 1, day: 31)
        XCTAssertEqual(BarRepeat.month.start(of: 1, from: jan31).iso, "2027-02-28")
        XCTAssertEqual(BarRepeat.month.start(of: 2, from: jan31).iso, "2027-03-31")
        XCTAssertEqual(BarRepeat.month.start(of: 12, from: dec1).iso, "2027-12-01")
        XCTAssertEqual(BarRepeat.twoWeeks.start(of: 3, from: dec1).iso, "2027-01-12")
        XCTAssertEqual(BarRepeat.day.start(of: 2, from: dec1).iso, "2026-12-03")
    }
}
