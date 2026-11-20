import Foundation
import CoreGraphics

// 0.19, table: column widths by hand (`Item.widths`), a tick column (`Item.tickColumn`), a count of ticks done, and
// sorting by a column. All plain rules; the app only draws and presses.

public extension TableRules {
    /// A column is never narrower than this by hand (board points), and never wider than `mostWidth`.
    static let leastWidth = 40.0
    static let mostWidth = 800.0

    /// The width the owner gave a column; nil for "as wide as its words" (no entry, or 0).
    static func ownWidth(_ widths: [Double]?, column: Int) -> Double? {
        guard let widths, widths.indices.contains(column), widths[column] > 0 else { return nil }
        return min(mostWidth, max(leastWidth, widths[column]))
    }

    /// The widths with column `column` set to `width` (clamped); the list grows to hold it, columns before it stay as they
    /// are (0 = by their words). `count` is how many columns the table has.
    static func settingWidth(_ widths: [Double]?, column: Int, to width: Double, count: Int) -> [Double] {
        var all = (widths ?? []) + Array(repeating: 0, count: max(0, max(count, column + 1) - (widths?.count ?? 0)))
        all[column] = min(mostWidth, max(leastWidth, width))
        return all
    }

    // MARK: Ticks

    /// A cell in a tick column is ticked when it holds "x".
    static func isTicked(_ words: String) -> Bool { words.trimmingCharacters(in: .whitespaces).lowercased() == "x" }

    /// How many boxes of the tick column are ticked, and how many boxes there are (the heading row has none).
    static func tickCount(_ cells: [[String]]?, column: Int?) -> (done: Int, total: Int) {
        let all = squared(cells)
        guard let column, column >= 0, column < columnCount(all), all.count > 1 else { return (0, 0) }
        let rows = all.dropFirst()
        return (rows.filter { isTicked($0[column]) }.count, rows.count)
    }

    /// "3 of 8 done"; nil when there is no tick column or no row under the heading.
    static func tickLine(_ cells: [[String]]?, column: Int?) -> String? {
        let n = tickCount(cells, column: column)
        return n.total == 0 ? nil : "\(n.done) of \(n.total) done"
    }

    // MARK: Sorting

    private static func number(_ words: String) -> Double? {
        let t = words.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return t.isEmpty ? nil : Double(t)
    }

    /// The rows under the heading sorted by one column: numbers by value, words ignoring case (and "2" before "10"
    /// inside words), numbers before words, empty cells last either way. The heading row stays on top; equal cells keep
    /// their order.
    static func sorted(_ cells: [[String]]?, column: Int, ascending: Bool) -> [[String]] {
        let all = squared(cells)
        guard all.count > 2, column >= 0, column < columnCount(all) else { return all }
        func before(_ a: String, _ b: String) -> Bool? {   // nil: equal
            let x = a.trimmingCharacters(in: .whitespaces), y = b.trimmingCharacters(in: .whitespaces)
            if x.isEmpty || y.isEmpty { return x.isEmpty == y.isEmpty ? nil : y.isEmpty }   // empty cells always last
            let order: ComparisonResult
            switch (number(x), number(y)) {
            case let (p?, q?): order = p < q ? .orderedAscending : (p > q ? .orderedDescending : .orderedSame)
            case (_?, nil): return ascending   // numbers before words (after them, the other way)
            case (nil, _?): return !ascending
            default: order = x.compare(y, options: [.caseInsensitive, .diacriticInsensitive, .numeric])
            }
            if order == .orderedSame { return nil }
            return (order == .orderedAscending) == ascending
        }
        let rows = all.dropFirst().enumerated().map { ($0.offset, $0.element) }
        let out = rows.sorted { a, b in
            if let r = before(a.1[column], b.1[column]) { return r }
            return a.0 < b.0
        }
        return [all[0]] + out.map(\.1)
    }

    /// Which way the next tap on a heading sorts: from "nothing sorted by this column" A→Z, then Z→A, then A→Z again.
    /// `now` is the column and way the table was last sorted by, when it still stands that way.
    static func nextSort(now: (column: Int, ascending: Bool)?, tapped column: Int) -> Bool {
        guard let now, now.column == column else { return true }
        return !now.ascending
    }
}

public extension Item {
    /// The tick column is on.
    var hasTickColumn: Bool { kind == .table && tickColumn != nil }

    /// A column added right of column `after` (nil: at the end); widths and the tick column move with it.
    mutating func tableAddColumn(after: Int?) {
        let before = TableRules.squared(cells)
        let new = TableRules.addingColumn(before, after: after)
        guard TableRules.columnCount(new) > TableRules.columnCount(before) else { return }
        let at = min(TableRules.columnCount(before), max(0, (after ?? (TableRules.columnCount(before) - 1)) + 1))
        tableInserted(at: at, cells: new)
    }

    /// A column taken away (nil: the last); the width list and the tick column follow (a removed tick column is gone).
    mutating func tableRemoveColumn(at column: Int?) {
        let before = TableRules.squared(cells)
        let new = TableRules.removingColumn(before, at: column)
        guard TableRules.columnCount(new) < TableRules.columnCount(before) else { return }
        let at = min(TableRules.columnCount(before) - 1, max(0, column ?? (TableRules.columnCount(before) - 1)))
        cells = new
        if var w = widths, w.indices.contains(at) { w.remove(at: at); widths = w.contains { $0 > 0 } ? w : nil }
        if let t = tickColumn { tickColumn = t == at ? nil : (t > at ? t - 1 : t) }
    }

    private mutating func tableInserted(at: Int, cells new: [[String]]) {
        cells = new
        if var w = widths { w.insert(0, at: min(at, w.count)); widths = w }
        if let t = tickColumn, t >= at { tickColumn = t + 1 }
    }

    /// The tick column on: a first column of empty tick boxes (nothing ticked). Not when it is on or the table is full.
    mutating func tableTickColumnOn() {
        guard kind == .table, tickColumn == nil, TableRules.columnCount(TableRules.squared(cells)) < TableRules.mostColumns else { return }
        tableInserted(at: 0, cells: TableRules.addingColumn(TableRules.squared(cells), after: -1))
        tickColumn = 0
    }

    /// The tick column off: the column goes (a table of one column keeps it as an ordinary column).
    mutating func tableTickColumnOff() {
        guard let t = tickColumn else { return }
        if TableRules.columnCount(TableRules.squared(cells)) > 1 { tableRemoveColumn(at: t) } else { tickColumn = nil }
    }

    /// A box of the tick column ticked or unticked ("x" / "").
    mutating func tableToggleTick(row: Int) {
        guard let t = tickColumn, row >= 1 else { return }
        var all = TableRules.squared(cells)
        guard row < all.count, t < TableRules.columnCount(all) else { return }
        all[row][t] = TableRules.isTicked(all[row][t]) ? "" : "x"
        cells = all
    }

    /// Sorted by a column (the heading row stays on top).
    mutating func tableSort(column: Int, ascending: Bool) {
        cells = TableRules.sorted(cells, column: column, ascending: ascending)
    }

    /// The width of one column set by hand.
    mutating func tableSetWidth(column: Int, to width: Double) {
        let count = TableRules.columnCount(TableRules.squared(cells))
        guard column >= 0, column < count else { return }
        widths = TableRules.settingWidth(widths, column: column, to: width, count: count)
    }

    /// One column back to as wide as its words.
    mutating func tableClearWidth(column: Int) {
        guard var w = widths, w.indices.contains(column) else { return }
        w[column] = 0
        widths = w.contains { $0 > 0 } ? w : nil
    }
}
