import XCTest
@testable import SeedboardCore

/// 0.16: one question turns purple milestones orange; other colours stay.
final class Orange16Tests: XCTestCase {
    func testPurpleMilestonesTurnOrangeAndOthersStay() {
        var b = Board.timeline()
        let day = Day(year: 2026, month: 11, day: 19)
        let old = b.addMilestone("Old", on: day, colour: "purple")
        let mine = b.addMilestone("Mine", on: day, colour: "green")
        let bar = b.addBar("Purple bar", start: day, colour: "purple")
        XCTAssertEqual(OrangeMilestones.count([b, Board(title: "plain")]).milestones, 1)
        XCTAssertEqual(OrangeMilestones.line((1, 1)), "1 milestone on 1 timeline is purple. Purple means PARAGON in Seedboard, and new milestones are orange.")
        b.makeMilestonesOrange()
        XCTAssertEqual(b.item(old)?.colour, "orange"); XCTAssertEqual(b.item(mine)?.colour, "green")
        XCTAssertEqual(b.item(bar)?.colour, "purple")
        XCTAssertEqual(OrangeMilestones.count([b]).milestones, 0)
    }
}
