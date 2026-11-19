import SwiftUI
import SeedboardCore

// 0.14, idea 25: typing in a table's cells and changing its rows and columns. The words of one cell are typed in
// place through the same typing as every other thing (BoardSession `cell`).

extension BoardSession {
    /// Two presses on a table: the cell under the press is typed in, in place.
    func beginCell(_ id: UUID, at point: CGPoint) {
        guard let item = board.item(id), item.kind == .table else { return }
        let l = TableLook.layout(of: item)
        cellWanted = TableRules.cell(at: CGPoint(x: point.x - CGFloat(item.x), y: point.y - CGFloat(item.y)), widths: l.widths, heights: l.heights)
        beginEdit(id)
    }

    /// Tab while typing in a cell: the words are kept and the next cell is typed in (the first of the next row after the
    /// last of a row). After the last cell the typing ends. False when no cell is being typed in.
    func nextCell() -> Bool {
        guard let id = editing, let spot = cell, board.item(id)?.kind == .table else { return false }
        commitEdit()
        if let cells = board.item(id)?.cells, let next = TableRules.next(after: spot, in: cells) {
            cellWanted = next
            beginEdit(id)
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
            case .addColumn: board.items[i].cells = TableRules.addingColumn(cells, after: spot?.column)
            case .removeRow: board.items[i].cells = TableRules.removingRow(cells, at: spot?.row)
            case .removeColumn: board.items[i].cells = TableRules.removingColumn(cells, at: spot?.column)
            }
        }
        if let item = board.item(id) { lastCell[id] = (spot ?? TableSpot(row: 0, column: 0)).clamped(to: item.cells) }
    }
}
