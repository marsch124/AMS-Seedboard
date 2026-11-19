import XCTest
@testable import SeedboardCore

final class Extras11Tests: XCTestCase {
    // 30. The legend's word for a colour: in the bar and after the note in PARAGON's note
    func testLegendWordShowsForNoteAndInParagonNote() throws {
        var board = Board(title: "Plan")
        let note = board.add(.note, centre: .zero, text: "Call Alex")
        board.setLegend(["yellow": "Question"])
        XCTAssertEqual(board.legendWord(ofNote: note), "Question")
        XCTAssertNil(board.legendWord(forColour: "green"))
        XCTAssertEqual(ParagonExport.namedBullet(try XCTUnwrap(board.item(note)), in: board, picture: false), "- Call Alex (Question)")
        board.setLegend([:])
        XCTAssertEqual(ParagonExport.namedBullet(try XCTUnwrap(board.item(note)), in: board, picture: false), "- Call Alex")
    }

    // 33. Main branches only, then open all
    func testMainBranchesOnlyFoldsFirstLevelAndOpensAll() throws {
        var board = Board(title: "Plan")
        let centre = board.addCentre(at: .zero, text: "Alex")
        let a = try XCTUnwrap(board.addChild(of: centre, text: "A"))
        let b = try XCTUnwrap(board.addChild(of: a, text: "B"))
        _ = board.addChild(of: b, text: "C")
        let d = try XCTUnwrap(board.addChild(of: centre, text: "D"))
        XCTAssertFalse(board.showsMainBranchesOnly(centre))
        XCTAssertTrue(board.toggleMainBranchesOnly(centre))
        XCTAssertEqual(board.item(a)?.folded, true)
        XCTAssertEqual(board.item(d)?.folded, false)   // nothing below it: nothing to fold
        XCTAssertTrue(board.showsMainBranchesOnly(centre))
        XCTAssertTrue(board.toggleMainBranchesOnly(centre))
        XCTAssertFalse(board.hasFolded)
    }

    // 43. Five boards opened last, newest first, no board twice
    func testRecentBoardsKeepFiveNewestFirst() {
        let ids = (0..<7).map { _ in UUID() }
        var list: [UUID] = []
        for id in ids { list = RecentBoards.opened(id, in: list) }
        XCTAssertEqual(list, Array(ids.reversed().prefix(5)))
        list = RecentBoards.opened(ids[3], in: list)
        XCTAssertEqual(list.first, ids[3])
        XCTAssertEqual(list.count, 5)
        XCTAssertEqual(Set(list).count, 5)
    }
}
