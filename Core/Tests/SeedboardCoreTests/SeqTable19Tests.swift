import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.19: dragging a message (rooms and blocks), a message's note, a table's widths, tick column and sorting.
final class SeqTable19Tests: XCTestCase {
    func testDraggingAMessageMakesRoomAndEveryOtherOneMovesByItsHeight() throws {
        let board = Board.sequenceStart()
        let m = board.steps.map(\.id)
        let before = board.sequenceLayout()
        let (after, room) = board.sequenceRoom(moving: m[2], to: 0, before: before)
        XCTAssertEqual(after.index(of: m[2]), 0)
        let h = try XCTUnwrap(before.row(m[2])).height
        XCTAssertEqual(room.rows[m[0]] ?? 0, h, accuracy: 0.01)
        XCTAssertEqual(room.rows[m[1]] ?? 0, h, accuracy: 0.01)
        XCTAssertLessThan(room.rows[m[2]] ?? 0, 0)
        let shifted = before.shifted(rows: room.rows, blockTop: room.blockTop, blockBottom: room.blockBottom, after: after)
        XCTAssertEqual(try XCTUnwrap(shifted.row(m[2])).top, try XCTUnwrap(after.row(m[2])).top, accuracy: 0.01)
    }

    func testABlockKeepsTheMessagesItHeldWhenOneIsDraggedAway() throws {
        var board = Board.sequenceStart()
        let m = board.steps.map(\.id)
        let block = try XCTUnwrap(board.addBlock(round: [m[0], m[1]], word: "if"))
        // The second message goes below the third: it leaves the block, which keeps the first.
        board.moveStep(m[1], to: 2)
        XCTAssertEqual(board.messages(in: block), [m[0]])
        // Dragged back between the block's messages, a message is held.
        var two = Board.sequenceStart()
        let n = two.steps.map(\.id)
        let b2 = try XCTUnwrap(two.addBlock(round: [n[0], n[2]], word: "repeat"))
        two.moveStep(n[1], to: 0)   // n[1] goes above n[0]: outside
        XCTAssertEqual(two.messages(in: b2), [n[0], n[2]])
        two.moveStep(n[1], to: 1)   // between them again
        XCTAssertEqual(two.messages(in: b2), [n[0], n[1], n[2]])
    }

    func testANoteBelongsToAMessageAndMakesItsRowRoomForTheBox() throws {
        var board = Board.sequenceStart()
        let id = board.steps[0].id
        let plain = board.sequenceLayout()
        XCTAssertFalse(board.setNote("   ", of: id))
        XCTAssertTrue(board.setNote("  Needs a signature  ", of: id))
        XCTAssertEqual(board.item(id)?.note, "Needs a signature")
        let layout = board.sequenceLayout()
        let box = try XCTUnwrap(layout.notes[id])
        let row = try XCTUnwrap(layout.row(id))
        XCTAssertGreaterThan(box.minX, CGFloat(max(row.fromX, row.toX)))
        XCTAssertLessThanOrEqual(box.maxX, CGFloat(layout.right))
        XCTAssertGreaterThanOrEqual(row.height, Double(box.height))
        XCTAssertGreaterThanOrEqual(layout.size.height, plain.size.height)
        XCTAssertTrue(board.setNote("", of: id))
        XCTAssertNil(board.item(id)?.note)
        XCTAssertTrue(board.sequenceLayout().notes.isEmpty)
    }

    func testAColumnWidthByHandIsAtLeast40AndFollowsAddedAndRemovedColumns() {
        var table = Item(kind: .table)
        table.cells = TableRules.blank()
        table.tableSetWidth(column: 1, to: 10)
        XCTAssertEqual(table.widths, [0, 40, 0])
        XCTAssertNil(TableRules.ownWidth(table.widths, column: 0))
        XCTAssertEqual(TableRules.ownWidth(table.widths, column: 1), 40)
        table.tableAddColumn(after: 0)
        XCTAssertEqual(table.widths, [0, 0, 40, 0])
        table.tableRemoveColumn(at: 2)
        XCTAssertNil(table.widths)
    }

    func testTheTickColumnCountsTickedBoxesUnderTheHeading() {
        var table = Item(kind: .table)
        table.cells = [["Task", "Who"], ["a", "x"], ["b", ""], ["c", ""]]
        table.tableTickColumnOn()
        XCTAssertEqual(table.tickColumn, 0)
        XCTAssertEqual(table.cells?[1], ["", "a", "x"])
        XCTAssertEqual(TableRules.tickLine(table.cells, column: table.tickColumn), "0 of 3 done")
        table.tableToggleTick(row: 1)
        table.tableToggleTick(row: 3)
        XCTAssertEqual(TableRules.tickLine(table.cells, column: table.tickColumn), "2 of 3 done")
        table.tableToggleTick(row: 1)
        XCTAssertEqual(TableRules.tickCount(table.cells, column: 0).done, 1)
        table.tableToggleTick(row: 0)   // the heading has no box
        XCTAssertEqual(table.cells?[0][0], "")
        table.tableAddColumn(after: -1)
        XCTAssertEqual(table.tickColumn, 1)
        table.tableTickColumnOff()
        XCTAssertNil(table.tickColumn)
        XCTAssertEqual(TableRules.columnCount(table.cells ?? []), 3)
        XCTAssertNil(TableRules.tickLine(table.cells, column: nil))
    }

    func testSortingKeepsTheHeadingOnTopNumbersByValueWordsWithoutCase() {
        let cells = [["Name", "Qty"], ["pear", "10"], ["Apple", "9"], ["fig", ""], ["banana", "2"]]
        XCTAssertEqual(TableRules.sorted(cells, column: 0, ascending: true).map { $0[0] }, ["Name", "Apple", "banana", "fig", "pear"])
        XCTAssertEqual(TableRules.sorted(cells, column: 0, ascending: false).map { $0[0] }, ["Name", "pear", "fig", "banana", "Apple"])
        XCTAssertEqual(TableRules.sorted(cells, column: 1, ascending: true).map { $0[1] }, ["Qty", "2", "9", "10", ""])
        XCTAssertEqual(TableRules.sorted(cells, column: 1, ascending: false).map { $0[1] }, ["Qty", "10", "9", "2", ""])
        XCTAssertTrue(TableRules.nextSort(now: nil, tapped: 0))
        XCTAssertFalse(TableRules.nextSort(now: (0, true), tapped: 0))
        XCTAssertTrue(TableRules.nextSort(now: (0, false), tapped: 0))
        XCTAssertTrue(TableRules.nextSort(now: (1, false), tapped: 0))
    }
}
