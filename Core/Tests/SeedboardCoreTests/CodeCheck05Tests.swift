import XCTest
@testable import SeedboardCore

/// Rules added after the 0.5 code check.
final class CodeCheck05Tests: XCTestCase {
    func testABoardMadeOfAStarterStartsUndone() {
        var bar = Item(kind: .bar, text: "Permit")
        bar.start = "2026-12-01"; bar.end = "2026-12-05"; bar.row = 0
        bar.doneDay = "2026-12-04"
        var plan = Board.timeline(title: "Plan")
        plan.items = [bar]
        let made = StarterShelf.fresh(plan, titled: "Plan")
        XCTAssertEqual(made.items.count, 1)
        XCTAssertNil(made.items[0].doneDay)
    }
}
