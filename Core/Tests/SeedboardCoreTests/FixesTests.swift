import XCTest
@testable import SeedboardCore

/// 0.3 small fixes: a message with a missing name, and the project tally of shapes in lanes.
final class FixesTests: XCTestCase {
    func testAMessageWithAMissingNameIsNotCountedNotWrittenAndNotNumberedButStaysInTheFile() {
        var board = Board.sequenceStart()
        let anna = board.whos[0].id
        let bank = board.whos[1].id
        // A file from elsewhere: a message to somebody who is not on the board, and one with no names at all.
        var lost = Item(kind: .message, text: "Ghost", w: 40, h: 17)
        lost.from = anna
        lost.to = UUID()
        lost.order = 0.5
        var bare = Item(kind: .message, text: "Bare", w: 40, h: 17)
        bare.order = 0.6
        board.items.append(lost)
        board.items.append(bare)
        _ = bank

        XCTAssertEqual(board.messageNumbers.count, 3)
        XCTAssertNil(board.messageNumbers[lost.id])
        XCTAssertEqual(board.messageNumbers[board.steps.first { $0.text == "Ask for loan" }!.id], 1)
        XCTAssertEqual(board.sequenceCountLine, "3 people · 3 messages")
        XCTAssertFalse(board.sequenceText.contains("Ghost"))
        XCTAssertFalse(board.sequenceText.contains("Bare"))
        XCTAssertEqual(board.sequenceLayout().rows.count, 3)
        XCTAssertEqual(ParagonExport.sequenceTaskLines(board).tasks, 3)
        XCTAssertFalse(ParagonExport.sequenceList(board).joined().contains("Ghost"))
        // Ticked, but not drawn: it does not decide what becomes a task.
        board.items[board.items.count - 2].todo = true
        XCTAssertFalse(ParagonExport.sequenceTicksDecide(board))
        // Nothing was removed from the file.
        XCTAssertEqual(board.items.filter { $0.kind == .message }.count, 5)
    }

    func testShapesInLanesAreCountedAsShapesNotAsIdeas() {
        var board = Board()
        let frame = board.add(.frame, centre: CGPoint(x: 220, y: 150), text: "Loan")
        board.setLanes(frame, way: .rows, count: 2)
        _ = board.add(.box, centre: CGPoint(x: 100, y: 70), text: "Ask")
        _ = board.add(.box, centre: CGPoint(x: 100, y: 200), text: "Decide")
        let tally = ParagonExport.projectTally(board: board)
        XCTAssertEqual(tally.ideaTasks + tally.ideaPlain, 0)
        XCTAssertEqual(tally.shapeTasks, 2)
        XCTAssertEqual(ParagonExport.projectLine(board: board), "Nothing is ticked: all 2 shapes become tasks.")
    }
}
