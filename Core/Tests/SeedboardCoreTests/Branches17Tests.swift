import XCTest
@testable import SeedboardCore

/// 0.17: new branches never come purple; the purple ones can be recoloured; other colours stay.
final class Branches17Tests: XCTestCase {
    func testNoPurpleBranchAndPurpleOnesRecolour() {
        XCTAssertFalse(Palette.branches.contains("purple")); XCTAssertFalse(Board.whoColours.contains("purple"))
        var b = Board(title: "Map")
        let c = b.add(.idea, centre: .zero, text: "Centre", colour: "")
        var kids: [UUID] = []
        for n in 0..<5 { kids.append(b.add(.idea, centre: .zero, text: "B\(n)", colour: Palette.branches[n])) }
        for k in kids { _ = b.reparent(k, under: c) }
        b.items[b.items.firstIndex { $0.id == kids[4] }!].colour = "purple"
        XCTAssertEqual(b.purpleBranches, 1)
        XCTAssertEqual(PurpleBranches.count([b, Board(title: "plain")]).maps, 1)
        XCTAssertEqual(PurpleBranches.line((1, 1)), "1 branch on 1 mind map is purple. Purple means PARAGON in Seedboard, and new branches skip it.")
        b.recolourPurpleBranches()
        XCTAssertEqual(b.item(kids[4])?.colour, "yellow")
        XCTAssertEqual(b.item(kids[0])?.colour, "pink")
        XCTAssertEqual(b.purpleBranches, 0)
    }
}
