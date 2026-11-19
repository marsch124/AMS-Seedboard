import XCTest
@testable import SeedboardCore

final class Timeline14Tests: XCTestCase {
    private let day = Day(year: 2026, month: 12, day: 1)

    func testHideDoneLeavesDoneRowsOutAndRemovesNothing() {
        var b = Board.timeline()
        let ph = b.addPhase("Phase")
        let a = b.addBar("A", start: day, days: 3)
        let m = b.addMilestone("M", on: day + 3)
        let c = b.addBar("C", start: day + 4, days: 2)
        let ph2 = b.addPhase("Two")
        let d = b.addBar("D", start: day, days: 2)
        b.items[b.index(of: a)!].doneDay = day.iso
        b.items[b.index(of: m)!].doneDay = day.iso
        b.items[b.index(of: d)!].doneDay = day.iso
        XCTAssertEqual(b.shownTimelineRows.count, 6)
        b.hideDone = true
        XCTAssertEqual(b.shownTimelineRows.map(\.id), [ph, c, ])
        XCTAssertEqual(b.hiddenDoneCount, 3)
        XCTAssertFalse(b.shownTimelineRows.contains { $0.id == ph2 }, "a phase with only done rows goes too")
        XCTAssertEqual(b.timelineRows.count, 6, "nothing is removed")
        b.hideDone = false
        XCTAssertEqual(b.shownTimelineRows.count, 6)
        XCTAssertEqual(b.hiddenDoneCount, 0)
    }

    func testEmptyPhaseStaysWhenHidingDone() {
        var b = Board.timeline()
        let ph = b.addPhase("Empty")
        b.hideDone = true
        XCTAssertEqual(b.shownTimelineRows.map(\.id), [ph])
    }

    func testSlipInDays() {
        var b = Board.timeline()
        let a = b.addBar("A", start: day, days: 3)
        XCTAssertEqual(b.setPlan(), 1)
        XCTAssertNil(b.item(a)?.slipWords)
        let i = b.index(of: a)!
        b.items[i].setSpan(day + 2, day + 4)
        XCTAssertEqual(b.items[i].slipDays, 2)
        XCTAssertEqual(b.items[i].slipWords, "2 days late")
        b.items[i].setSpan(day - 1, day + 1)
        XCTAssertEqual(b.items[i].slipWords, "1 day early")
        XCTAssertTrue(b.items[i].movedFromPlan)
        let later = b.addBar("New", start: day, days: 2)
        XCTAssertNil(b.item(later)?.planSpan, "a bar added after the plan has no ghost")
        XCTAssertNil(b.item(later)?.slipDays)
        XCTAssertEqual(b.clearPlan(), 1)
        XCTAssertFalse(b.hasPlan)
    }
}
