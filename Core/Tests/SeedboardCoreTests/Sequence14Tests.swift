import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.14: blocks in a "Who does what" board — one small data test per rule.
final class Sequence14Tests: XCTestCase {
    private func sketch() -> (board: Board, m: [UUID]) {
        let board = Board.sequenceStart()
        return (board, board.steps.map(\.id))
    }

    func testABlockSurroundsFromItsFirstToItsLastMessageAndFollowsThemWhenTheyMove() throws {
        var (board, m) = sketch()
        let id = try XCTUnwrap(board.addBlock(round: [m[2], m[0]], word: "repeat"))
        let block = try XCTUnwrap(board.item(id))
        XCTAssertEqual(block.from, m[0])
        XCTAssertEqual(block.to, m[2])
        XCTAssertEqual(block.text, "repeat")
        let layout = board.sequenceLayout()
        let place = try XCTUnwrap(layout.blocks.first)
        // Round all three names' lines and from the first row's top to the last row's bottom.
        for line in layout.x.values { XCTAssertTrue(place.rect.minX < CGFloat(line) && CGFloat(line) < place.rect.maxX) }
        let first = try XCTUnwrap(layout.row(m[0])), last = try XCTUnwrap(layout.row(m[2]))
        XCTAssertLessThan(place.rect.minY, CGFloat(first.top))
        XCTAssertGreaterThan(place.rect.maxY, CGFloat(last.bottom))
        // Only the first two: the third message stands outside.
        var two = sketch().board
        two.addBlock(round: [two.steps[0].id, two.steps[1].id], word: "if")
        let small = two.sequenceLayout()
        XCTAssertLessThan(small.blocks[0].rect.maxY, CGFloat(small.row(two.steps[2].id)!.bottom))
        // The first message moves to the bottom: the block follows the order, not its old place.
        board.moveStep(m[0], to: 2)
        let after = board.sequenceLayout().blocks[0].rect
        XCTAssertEqual(after.minY, board.sequenceLayout().blocks[0].rect.minY)
        XCTAssertNotEqual(after, place.rect)
        // Only messages count: nothing chosen, no block.
        XCTAssertNil(board.addBlock(round: [], word: "if"))
        XCTAssertEqual(board.blocks.count, 1)
    }

    func testABlockInsideAnotherOneGetsLessMarginAndBothComeBackFromAFile() throws {
        var (board, m) = sketch()
        board.addBlock(round: [m[0], m[2]], word: "repeat")
        board.addBlock(round: [m[1]], word: "if")
        let layout = board.sequenceLayout()
        XCTAssertEqual(layout.blocks.map(\.level), [1, 0])
        XCTAssertTrue(layout.blocks[0].rect.contains(layout.blocks[1].rect))
        XCTAssertGreaterThan(layout.blocks[1].rect.minX - layout.blocks[0].rect.minX, 0)
        let back = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board))
        XCTAssertEqual(back, board)
        XCTAssertEqual(back.sequenceCountLine, "3 people · 3 messages · 2 blocks")
    }

    func testABlockShrinksWhenItsEndsAreRemovedAndGoesWhenNothingIsLeft() throws {
        var (board, m) = sketch()
        let id = try XCTUnwrap(board.addBlock(round: [m[0], m[2]], word: "repeat"))
        board.removeFromSequence([m[0]])
        XCTAssertEqual(board.item(id)?.from, m[1])
        XCTAssertEqual(board.item(id)?.to, m[2])
        board.removeFromSequence([m[2]])
        XCTAssertEqual(board.item(id)?.from, m[1])
        XCTAssertEqual(board.item(id)?.to, m[1])
        board.removeFromSequence([m[1]])
        XCTAssertNil(board.item(id))
        // The frame alone is removed: the messages stay.
        var (again, n) = sketch()
        let frame = try XCTUnwrap(again.addBlock(round: [n[0], n[1]], word: "if"))
        again.removeFromSequence([frame])
        XCTAssertEqual(again.steps.count, 3)
        XCTAssertTrue(again.blocks.isEmpty)
        // A name taking its messages along shrinks the block too.
        var (names, k) = sketch()
        let b = try XCTUnwrap(names.addBlock(round: [k[0], k[2]], word: "maybe"))
        names.removeFromSequence([names.whos[2].id])
        XCTAssertEqual(names.item(b)?.to, k[1])
    }

    func testMessagesInsideABlockAreWrittenIndentedUnderItsWord() throws {
        var (board, m) = sketch()
        board.addBlock(round: [m[1], m[2]], word: "repeat")
        XCTAssertEqual(board.sequenceText, """
            Who: Alex, Bank, Builder

            1. Alex → Bank: Ask for loan
            Repeat:
               2. Bank answers Alex: Yes
               3. Alex → Builder: Order the build
            """)
        let list = ParagonExport.sequenceList(board)
        XCTAssertEqual(list, ["1. Alex → Bank: Ask for loan", "Repeat:", "   2. Bank answers Alex: Yes", "   3. Alex → Builder: Order the build"])
        board.addBlock(round: [m[2]], word: "")
        XCTAssertTrue(ParagonExport.sequenceList(board).contains("   Block:"))
        XCTAssertTrue(ParagonExport.sequenceList(board).contains("      3. Alex → Builder: Order the build"))
    }
}
