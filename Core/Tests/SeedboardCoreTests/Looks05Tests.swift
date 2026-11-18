import XCTest
@testable import SeedboardCore

/// 0.5, the look the owner picked: branches thick to thin with the words on the line, and the strip's order.
final class Looks05Tests: XCTestCase {
    func testBranchesRunThickToThin() {
        XCTAssertEqual(Route.branchWeight(depth: 1), 3.4)
        XCTAssertEqual(Route.branchWeight(depth: 2), 2.4)
        XCTAssertEqual(Route.branchWeight(depth: 3), 1.8)
        XCTAssertEqual(Route.branchWeight(depth: 9), 1.8)
    }

    func testABranchArrivesAtTheFootAndRunsOnUnderTheWords() {
        let centre = CGRect(x: 0, y: 0, width: 150, height: 46)
        let branch = CGRect(x: 200, y: 60, width: 80, height: 27)
        let twig = CGRect(x: 330, y: 100, width: 60, height: 27)
        // From the middle idea: out of the middle of its side, to the foot of the branch, on to the words' end.
        let first = Route.branchLine(from: centre, parentDepth: 0, to: branch, side: .right)
        XCTAssertEqual(first.start, CGPoint(x: 150, y: 23))
        XCTAssertEqual(first.near, CGPoint(x: 200, y: 85))
        XCTAssertEqual(first.end, CGPoint(x: 280, y: 85))
        // The next idea starts where that underline ends.
        let second = Route.branchLine(from: branch, parentDepth: 1, to: twig, side: .right)
        XCTAssertEqual(second.start, first.end)
        XCTAssertEqual(second.end, CGPoint(x: 390, y: 125))
    }

    func testOnTheLeftTheUnderlineRunsTheOtherWay() {
        let centre = CGRect(x: 0, y: 0, width: 150, height: 46)
        let branch = CGRect(x: -130, y: 60, width: 80, height: 27)
        let twig = CGRect(x: -240, y: 100, width: 60, height: 27)
        let first = Route.branchLine(from: centre, parentDepth: 0, to: branch, side: .left)
        XCTAssertEqual(first.start, CGPoint(x: 0, y: 23))
        XCTAssertEqual(first.near, CGPoint(x: -50, y: 85))
        XCTAssertEqual(first.end, CGPoint(x: -130, y: 85))
        let second = Route.branchLine(from: branch, parentDepth: 1, to: twig, side: .left)
        XCTAssertEqual(second.start, first.end)
        XCTAssertEqual(second.near, CGPoint(x: -180, y: 125))
        XCTAssertEqual(second.end, CGPoint(x: -240, y: 125))
    }

    func testTheStripAlwaysBeginsWithTheBlankBoard() {
        var shelf = StarterShelf()
        XCTAssertEqual(shelf.strip.map(\.id), shelf.shown.map(\.id))
        XCTAssertEqual(shelf.strip.first?.id, "blank")
        // The owner moves the Blank board to the end: the chooser follows him, the strip still begins with it.
        shelf.move("blank", to: shelf.shown.count - 1, now: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertNotEqual(shelf.shown.first?.id, "blank")
        XCTAssertEqual(shelf.strip.first?.id, "blank")
        XCTAssertEqual(shelf.strip.dropFirst().map(\.id), shelf.shown.filter { $0.id != "blank" }.map(\.id))
    }
}
