import SwiftUI
import SeedboardCore

// 0.14, idea 25: typing in a table's cells and changing its rows and columns. The words of one cell are typed in
// place through the same typing as every other thing (BoardSession `cell`).

extension BoardSession {
    /// Two presses on a table: the cell under the press is typed in, in place.
    func beginCell(_ id: UUID, at point: CGPoint) {
        guard let item = board.item(id), item.kind == .table else { return }
        let spot = tableSpot(id, at: point)
        // 0.19: a box of the tick column is ticked, not typed in.
        if let spot, spot.row >= 1, spot.column == item.tickColumn { return }
        cellWanted = spot
        beginEdit(id)
    }

    /// Tab while typing in a cell: the words are kept and the next cell is typed in (the first of the next row after the
    /// last of a row). After the last cell the typing ends. False when no cell is being typed in.
    func nextCell() -> Bool {
        guard let id = editing, let spot = cell, board.item(id)?.kind == .table else { return false }
        commitEdit()
        let tick = board.item(id)?.tickColumn
        // 0.19: Tab skips the boxes of a tick column (below the heading).
        var at = spot
        while let cells = board.item(id)?.cells, let next = TableRules.next(after: at, in: cells) {
            at = next
            if next.column == tick, next.row >= 1 { continue }
            cellWanted = next
            beginEdit(id)
            break
        }
        return true
    }

    enum TableStep { case addRow, addColumn, removeRow, removeColumn }

    /// The row or column the bar's buttons act on: the one of the cell typed in last, else the last.
    func tableStep(_ id: UUID, _ step: TableStep) {
        guard !readOnly, board.item(id)?.kind == .table else { return }
        if editing != nil { commitEdit() }
        let spot = lastCell[id]
        change { board in
            guard let i = board.index(of: id) else { return }
            let cells = TableRules.squared(board.items[i].cells)
            switch step {
            case .addRow: board.items[i].cells = TableRules.addingRow(cells, after: spot?.row)
            case .addColumn: board.items[i].tableAddColumn(after: spot?.column)
            case .removeRow: board.items[i].cells = TableRules.removingRow(cells, at: spot?.row)
            case .removeColumn: board.items[i].tableRemoveColumn(at: spot?.column)
            }
        }
        if let item = board.item(id) { lastCell[id] = (spot ?? TableSpot(row: 0, column: 0)).clamped(to: item.cells) }
    }
}

// 0.19: column widths by hand, a tick column, sorting by a heading.
extension BoardSession {
    /// The cell of a table under a board point; nil outside the table.
    func tableSpot(_ id: UUID, at point: CGPoint) -> TableSpot? {
        guard let item = board.item(id), item.kind == .table else { return nil }
        let l = TableLook.layout(of: item)
        return TableRules.cell(at: CGPoint(x: point.x - CGFloat(item.x), y: point.y - CGFloat(item.y)), widths: l.widths, heights: l.heights)
    }

    /// A tap on a table: a tick box under the heading ticks or unticks; a heading sorts by its column (first A to Z,
    /// then Z to A, then A to Z again). False when the tap does neither (or the board cannot be changed).
    func pressTable(_ id: UUID, _ spot: TableSpot) -> Bool {
        guard !readOnly, editing == nil, let item = board.item(id), item.kind == .table else { return false }
        if item.tickColumn == spot.column, spot.row >= 1 {
            if !TableRules.isTicked(TableRules.squared(item.cells)[spot.row][spot.column]) { TickSound.play() }
            change { board in board.items[board.index(of: id)!].tableToggleTick(row: spot.row) }
            return true
        }
        guard spot.row == 0 else { return false }
        let ascending = TableRules.nextSort(now: TableSortMemory.shared.sortOf(item), tapped: spot.column)
        change { board in board.items[board.index(of: id)!].tableSort(column: spot.column, ascending: ascending) }
        TableSortMemory.shared.remember((spot.column, ascending), of: id)
        return true
    }

    /// "Tick Column" on a chosen table: a first column of tick boxes, or the column taken away again.
    func toggleTickColumn(_ id: UUID) {
        guard !readOnly, board.item(id)?.kind == .table else { return }
        if editing != nil { commitEdit() }
        change { board in
            guard let i = board.index(of: id) else { return }
            if board.items[i].tickColumn == nil { board.items[i].tableTickColumnOn() } else { board.items[i].tableTickColumnOff() }
        }
        lastCell[id] = nil
    }

    /// Two presses on a column's right edge: as wide as its longest words.
    func fitColumn(_ id: UUID, _ column: Int) {
        guard !readOnly, let item = board.item(id), item.kind == .table else { return }
        let width = TableLook.fitWidth(of: item, column: column)
        change { board in
            guard let i = board.index(of: id) else { return }
            if column == board.items[i].tickColumn { board.items[i].tableClearWidth(column: column) } else { board.items[i].tableSetWidth(column: column, to: width) }
        }
    }
}
