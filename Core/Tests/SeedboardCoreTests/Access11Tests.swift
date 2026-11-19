import XCTest
@testable import SeedboardCore

final class Access11Tests: XCTestCase {
    func testSpokenSentenceAndOrder() {
        var board = Board(title: "Plan")
        var roof = Item(kind: .idea, text: "Roof", x: 0, y: 0)
        roof.doneDay = "2026-12-01"
        roof.votes = 2
        let walls = Item(kind: .idea, text: "Walls", x: 100, y: 0, parent: roof.id)
        let note = Item(kind: .note, text: "Call Alex", x: 0, y: 300)
        board.items = [note, walls, roof]
        board.links = [Link(from: roof.id, to: note.id)]
        let said = board.spokenThings.map(\.sentence)
        XCTAssertEqual(said[0], "Idea: Roof, done, 2 votes")
        XCTAssertEqual(said[1], "Idea: Walls")
        XCTAssertEqual(said[2], "Sticky note: Call Alex")
        XCTAssertEqual(said[3], "Arrow from Roof to Call Alex")
        XCTAssertFalse(board.spokenThings[0].canMove)
        XCTAssertTrue(board.spokenThings[2].canMove)
    }
}
