import XCTest
@testable import SeedboardCore

/// 0.14, lane calendar: links to one thing, and care with the calendar that follows the timelines.
final class Calendar14Tests: XCTestCase {
    func testALinkReadsTheBoardFromItsFirstPartAndTheThingFromTheEnd() {
        let board = UUID(), item = UUID()
        let url = URL(string: BoardLink.link(board: board, item: item))!
        XCTAssertEqual(BoardLink.id(from: url), board)
        XCTAssertEqual(BoardLink.item(from: url), item)
        let plain = URL(string: "seedboard://board/\(board.uuidString)")!
        XCTAssertEqual(BoardLink.id(from: plain), board)
        XCTAssertNil(BoardLink.item(from: plain))
        XCTAssertNil(BoardLink.id(from: URL(string: "seedboard://board/")!))
        // The calendar's own key is such a link.
        XCTAssertEqual(CalendarFollow.key(board: board, item: item), url.absoluteString)
    }

    func testTheCalendarIsCarefulWithRemovalsAndOnlyWorksOnChange() {
        var plan = CalendarFollow.Plan()
        plan.remove = (1...8).map { "k\($0)" }
        plan.twins = ["k9": 1]
        let cut = CalendarFollow.limited(plan)
        XCTAssertEqual(cut.plan.remove.count, 5)
        XCTAssertEqual(cut.held, 3)
        XCTAssertEqual(cut.plan.twins, ["k9": 1])
        XCTAssertEqual(CalendarFollow.limited(CalendarFollow.Plan()).held, 0)

        let day = Day(year: 2026, month: 12, day: 1)
        let a = [FollowEvent(key: "x", title: "A", first: day, last: day, notes: "")]
        let sig = CalendarFollow.signature(of: a)
        XCTAssertEqual(sig, CalendarFollow.signature(of: a))
        XCTAssertNotEqual(sig, CalendarFollow.signature(of: []))
        XCTAssertEqual(CalendarFollow.pass(arriving: true, signature: sig, last: nil, force: true), .wait)
        XCTAssertEqual(CalendarFollow.pass(arriving: false, signature: sig, last: sig, force: false), .skip)
        XCTAssertEqual(CalendarFollow.pass(arriving: false, signature: sig, last: sig, force: true), .go)
        XCTAssertEqual(CalendarFollow.pass(arriving: false, signature: sig, last: "other", force: false), .go)
    }

    func testTwoCalendarsOfOneNameJoinIntoTheFirstAndOffKeepsAnyoneElsesDays() {
        let list = [(id: "a", title: "Seedboard"), (id: "b", title: "Home"), (id: "c", title: "Seedboard")]
        let joined = CalendarFollow.joinPlan(list, named: "Seedboard", remembered: nil)
        XCTAssertEqual(joined?.keep, "a")
        XCTAssertEqual(joined?.join, ["c"])
        XCTAssertEqual(CalendarFollow.joinPlan(list, named: "Seedboard", remembered: "c")?.keep, "c")
        XCTAssertNil(CalendarFollow.joinPlan(list, named: "Nothing", remembered: nil))

        XCTAssertTrue(CalendarFollow.mayRemoveCalendar(leftOver: 0))
        XCTAssertFalse(CalendarFollow.mayRemoveCalendar(leftOver: 1))
        let now = Day(year: 2026, month: 11, day: 19)
        let far = Day(year: 2040, month: 1, day: 1)
        XCTAssertEqual(CalendarFollow.reach(first: nil, last: far, now: now).end, far)
        XCTAssertGreaterThan(CalendarFollow.reach(first: nil, last: nil, now: now).end.number, now.number + 3000)
    }
}
