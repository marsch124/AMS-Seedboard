import XCTest
@testable import SeedboardCore

/// 0.18: new branches and new people never come red (red means late); purple and red main branches recolour.
final class Branches18Tests: XCTestCase {
    func testNoRedBranchAndPurpleOrRedOnesRecolour() {
        XCTAssertFalse(Palette.branches.contains("red")); XCTAssertFalse(Board.whoColours.contains("red"))
        XCTAssertFalse(Palette.branches.contains("purple"))
        var b = Board(title: "Map")
        let c = b.add(.idea, centre: .zero, text: "Centre", colour: "")
        var kids: [UUID] = []
        for n in 0..<4 { kids.append(b.add(.idea, centre: .zero, text: "B\(n)", colour: Palette.branches[n])) }
        for k in kids { _ = b.reparent(k, under: c) }
        b.items[b.items.firstIndex { $0.id == kids[2] }!].colour = "red"
        b.items[b.items.firstIndex { $0.id == kids[3] }!].colour = "purple"
        XCTAssertEqual(b.oddBranches(), 2)
        XCTAssertEqual(b.oddBranches(OddBranches.colours(purpleAsked: true)), 1)
        XCTAssertEqual(OddBranches.count([b, Board(title: "plain")]).maps, 1)
        XCTAssertEqual(OddBranches.title(["red"]), "Recolour red branches?")
        XCTAssertEqual(OddBranches.line((1, 1), colours: ["red"]), "1 branch on 1 mind map is red. Red means late in Seedboard, and new branches skip it.")
        b.recolourBranches(["red"])                       // purple kept when only red was asked
        XCTAssertNotEqual(b.item(kids[2])?.colour, "red")
        XCTAssertEqual(b.item(kids[3])?.colour, "purple")
        b.recolourBranches()
        XCTAssertEqual(b.oddBranches(), 0)
        XCTAssertEqual(b.item(kids[0])?.colour, "pink")
    }
}
