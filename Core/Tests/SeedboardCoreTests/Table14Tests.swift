import XCTest
@testable import SeedboardCore

/// 0.14, idea 25: a table on an ordinary board.
final class Table14Tests: XCTestCase {
    private func sample() -> [[String]] {
        [["Plan", "Price", "Space"], ["Small", "10", "1 room"], ["Big", "", "4 rooms"]]
    }

    func testANewTableIsThreeByThreeAndEmpty() {
        var board = Board()
        let id = board.add(.table, centre: CGPoint(x: 100, y: 100))
        let cells = board.item(id)?.cells
        XCTAssertEqual(cells?.count, 3)
        XCTAssertEqual(cells?.first?.count, 3)
        XCTAssertEqual(TableRules.words(cells), "")
        // It survives saving and opening.
        let data = try! JSONEncoder().encode(board)
        XCTAssertEqual(try! JSONDecoder().decode(Board.self, from: data).item(id)?.cells, cells)
    }

    func testAddAndRemoveRowsAndColumns() {
        var cells = sample()
        cells = TableRules.addingRow(cells, after: 0)
        XCTAssertEqual(cells.count, 4)
        XCTAssertEqual(cells[1], ["", "", ""])
        cells = TableRules.addingColumn(cells)
        XCTAssertEqual(TableRules.columnCount(cells), 4)
        cells = TableRules.removingRow(cells, at: 1)
        cells = TableRules.removingColumn(cells, at: 1)
        XCTAssertEqual(cells[0], ["Plan", "Space", ""])
        XCTAssertEqual(cells.count, 3)
        // The last row and the last column stay.
        var one = [["x"]]
        one = TableRules.removingRow(one); one = TableRules.removingColumn(one)
        XCTAssertEqual(one, [["x"]])
        XCTAssertFalse(TableRules.canRemoveRow(one))
    }

    func testSizeFollowsTheWordsAndColumnsStopAt220() {
        let cells = [["a", "long words"], ["bb", String(repeating: "x", count: 100)]]
        let widths = TableRules.columnWidths(cells) { Double($0.count) * 7 }
        XCTAssertEqual(widths[0], TableRules.minColumn)
        XCTAssertEqual(widths[1], TableRules.maxColumn)
        let heights = TableRules.rowHeights(cells, widths: widths) { words, wide in ceil(Double(words.count) * 7 / wide) * 18 }
        XCTAssertEqual(heights[0], 18 + 2 * TableRules.padY)
        XCTAssertEqual(heights[1], 18 * 4 + 2 * TableRules.padY)
        XCTAssertEqual(TableRules.cell(at: CGPoint(x: 70, y: 5), widths: widths, heights: heights)?.column, 1)
        XCTAssertNil(TableRules.cell(at: CGPoint(x: 900, y: 5), widths: widths, heights: heights))
    }

    func testSettingOneCell() {
        let cells = TableRules.setting("hi", at: TableSpot(row: 1, column: 2), in: TableRules.blank())
        XCTAssertEqual(cells[1][2], "hi")
        XCTAssertEqual(TableRules.words(cells), "hi")
    }

    func testTabGoesToTheNextCell() {
        let cells = sample()
        XCTAssertEqual(TableRules.next(after: TableSpot(row: 0, column: 0), in: cells)?.column, 1)
        XCTAssertEqual(TableRules.next(after: TableSpot(row: 0, column: 2), in: cells)?.row, 1)
        XCTAssertNil(TableRules.next(after: TableSpot(row: 2, column: 2), in: cells))
    }

    func testTheListForParagonAndSearch() {
        var board = Board()
        let id = board.add(.table, centre: .zero)
        board.items[board.index(of: id)!].cells = sample()
        XCTAssertEqual(TableRules.lines(sample()), ["- Plan", "  - Small — Price: 10", "  - Small — Space: 1 room", "  - Big — Space: 4 rooms"])
        XCTAssertTrue(board.holds("rooms"))
        XCTAssertTrue(ParagonExport.noteBullet(board.items[board.index(of: id)!], picture: true).contains("Small — Price: 10"))
        XCTAssertTrue(board.outlineText.contains("Big — Space: 4 rooms"))
        // It counts as one thing, and an empty table is not a thing with words.
        XCTAssertTrue(board.listLine().hasPrefix("1 idea"))
        var empty = Board()
        _ = empty.add(.table, centre: .zero)
        XCTAssertFalse(empty.holds("rooms"))
    }
}
