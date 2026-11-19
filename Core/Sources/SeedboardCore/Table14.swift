import Foundation
import CoreGraphics

// 0.14, idea 25: a table on an ordinary board. Its words are `Item.cells` (rows of columns); the first row is the
// heading row. Everything here is a plain rule: its size, adding and removing a row or a column, and the plain list
// PARAGON gets ("Row heading — Column heading: words").

/// One cell of a table: its row and its column (counted from 0; row 0 is the heading row).
public struct TableSpot: Equatable, Hashable, Sendable {
    public var row: Int
    public var column: Int
    public init(row: Int, column: Int) { self.row = row; self.column = column }

    /// The nearest cell that exists.
    public func clamped(to cells: [[String]]?) -> TableSpot {
        let all = TableRules.squared(cells)
        return TableSpot(row: min(max(0, row), all.count - 1), column: min(max(0, column), TableRules.columnCount(all) - 1))
    }
}

public enum TableRules {
    /// A new table: 3 columns and 3 rows, empty.
    public static let newRows = 3
    public static let newColumns = 3
    /// A column is at most this wide (board points); longer words wrap.
    public static let maxColumn: Double = 220
    public static let minColumn: Double = 56
    /// Room inside a cell round its words (left and right, top and bottom).
    public static let padX: Double = 8
    public static let padY: Double = 6
    /// A table keeps at least one row and one column, and stays within these.
    public static let mostRows = 60
    public static let mostColumns = 20

    public static func blank(rows: Int = newRows, columns: Int = newColumns) -> [[String]] {
        Array(repeating: Array(repeating: "", count: max(1, columns)), count: max(1, rows))
    }

    /// Every row as long as the longest one; at least 1 × 1.
    public static func squared(_ cells: [[String]]?) -> [[String]] {
        guard let cells, !cells.isEmpty else { return blank(rows: 1, columns: 1) }
        let width = max(1, cells.map(\.count).max() ?? 1)
        return cells.map { $0 + Array(repeating: "", count: width - $0.count) }
    }

    public static func rowCount(_ cells: [[String]]) -> Int { cells.count }
    public static func columnCount(_ cells: [[String]]) -> Int { cells.map(\.count).max() ?? 0 }

    // MARK: Size

    /// The width of every column: the widest of its cells, between `minColumn` and `maxColumn`, plus the room round the words.
    /// `wordsWidth` says how wide some words are when they stand on one line.
    public static func columnWidths(_ cells: [[String]], wordsWidth: (String) -> Double) -> [Double] {
        let cells = squared(cells)
        return (0..<columnCount(cells)).map { c in
            let widest = cells.map { wordsWidth($0[c]) }.max() ?? 0
            return min(maxColumn, max(minColumn, widest + 2 * padX))
        }
    }

    /// The height of every row: the highest of its cells once the words wrap at the column's width.
    /// `wordsHeight` says how high some words are when they may be that wide.
    public static func rowHeights(_ cells: [[String]], widths: [Double], wordsHeight: (String, Double) -> Double) -> [Double] {
        let cells = squared(cells)
        return cells.map { row in
            var high = 0.0
            for (c, words) in row.enumerated() where c < widths.count {
                high = max(high, wordsHeight(words, widths[c] - 2 * padX))
            }
            return high + 2 * padY
        }
    }

    /// The words of one cell set (the table grows to hold it if needed).
    public static func setting(_ words: String, at spot: TableSpot, in cells: [[String]]?) -> [[String]] {
        var all = squared(cells)
        let at = spot.clamped(to: all)
        all[at.row][at.column] = words
        return all
    }

    // MARK: Which cell

    /// The cell at this point inside the table (the table's own top-left corner is 0, 0); nil outside.
    public static func cell(at point: CGPoint, widths: [Double], heights: [Double]) -> TableSpot? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        var x = 0.0, column: Int?
        for (c, w) in widths.enumerated() { if Double(point.x) < x + w { column = c; break }; x += w }
        var y = 0.0, row: Int?
        for (r, h) in heights.enumerated() { if Double(point.y) < y + h { row = r; break }; y += h }
        guard let column, let row else { return nil }
        return TableSpot(row: row, column: column)
    }

    /// Tab: the next cell to the right, then the first of the next row; nil after the last cell.
    public static func next(after spot: TableSpot, in cells: [[String]]) -> TableSpot? {
        let rows = cells.count, columns = columnCount(cells)
        guard rows > 0, columns > 0 else { return nil }
        if spot.column + 1 < columns { return TableSpot(row: spot.row, column: spot.column + 1) }
        if spot.row + 1 < rows { return TableSpot(row: spot.row + 1, column: 0) }
        return nil
    }

    // MARK: Rows and columns

    /// A row added under row `after` (nil: at the end).
    public static func addingRow(_ cells: [[String]], after: Int? = nil) -> [[String]] {
        var cells = squared(cells)
        guard cells.count < mostRows else { return cells }
        let row = Array(repeating: "", count: columnCount(cells))
        let at = min(cells.count, max(0, (after ?? (cells.count - 1)) + 1))
        cells.insert(row, at: at)
        return cells
    }

    /// A column added right of column `after` (nil: at the end).
    public static func addingColumn(_ cells: [[String]], after: Int? = nil) -> [[String]] {
        var cells = squared(cells)
        guard columnCount(cells) < mostColumns else { return cells }
        let at = min(columnCount(cells), max(0, (after ?? (columnCount(cells) - 1)) + 1))
        for r in cells.indices { cells[r].insert("", at: at) }
        return cells
    }

    public static func canRemoveRow(_ cells: [[String]]) -> Bool { cells.count > 1 }
    public static func canRemoveColumn(_ cells: [[String]]) -> Bool { columnCount(cells) > 1 }

    /// A row taken away (nil: the last). The last row left stays.
    public static func removingRow(_ cells: [[String]], at row: Int? = nil) -> [[String]] {
        var cells = squared(cells)
        guard canRemoveRow(cells) else { return cells }
        cells.remove(at: min(cells.count - 1, max(0, row ?? (cells.count - 1))))
        return cells
    }

    /// A column taken away (nil: the last). The last column left stays.
    public static func removingColumn(_ cells: [[String]], at column: Int? = nil) -> [[String]] {
        var cells = squared(cells)
        guard canRemoveColumn(cells) else { return cells }
        let at = min(columnCount(cells) - 1, max(0, column ?? (columnCount(cells) - 1)))
        for r in cells.indices { cells[r].remove(at: at) }
        return cells
    }

    // MARK: Words

    /// Every word in the table, one cell per line (for search).
    public static func words(_ cells: [[String]]?) -> String {
        (cells ?? []).flatMap { $0 }.map { ParagonExport.oneLine($0) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// The table as the plain list PARAGON gets: a heading line, then "Row heading — Column heading: words" for every
    /// cell with words that is not a heading. The heading is the table's top-left cell, else "A table".
    /// A table of one row has only its headings; one of one column lists its cells under their row headings.
    public static func lines(_ cells: [[String]]?) -> [String] {
        let cells = squared(cells)
        func one(_ s: String) -> String { ParagonExport.oneLine(s) }
        let corner = one(cells[0][0])
        var out = ["- " + (corner.isEmpty ? "A table" : corner)]
        let columns = columnCount(cells)
        if cells.count == 1 {
            let heads = cells[0].dropFirst(corner.isEmpty ? 0 : 1).map(one).filter { !$0.isEmpty }
            if !heads.isEmpty { out.append("  - " + heads.joined(separator: ", ")) }
            return out
        }
        for r in 1..<cells.count {
            let rowName = one(cells[r][0]).isEmpty ? "Row \(r)" : one(cells[r][0])
            if columns == 1 {
                if !one(cells[r][0]).isEmpty { out.append("  - " + one(cells[r][0])) }
                continue
            }
            for c in 1..<columns {
                let words = one(cells[r][c])
                guard !words.isEmpty else { continue }
                let columnName = one(cells[0][c]).isEmpty ? "Column \(c)" : one(cells[0][c])
                out.append("  - \(rowName) — \(columnName): \(words)")
            }
        }
        return out
    }
}

public extension Item {
    /// The words that can be searched on this thing: its words, and every cell of a table.
    var searchableWords: String {
        guard kind == .table else { return text }
        return [text, TableRules.words(cells)].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
