import SwiftUI
import SeedboardCore

// 0.14, idea 25: a table on an ordinary board. Thin grid lines; every column as wide as its widest cell (at most 220,
// longer words wrap); the first row is the heading row, bold on a light band. The same painter draws the live board,
// the PDF and the picture that goes to PARAGON.

enum TableLook {
    /// Apple's text size for the words in a cell (the same as a shape's).
    static let size: CGFloat = 15

    private static func bold(_ row: Int) -> Bool { row == 0 }

    /// The width of every column and the height of every row, in board points.
    static func layout(of item: Item) -> (widths: [Double], heights: [Double]) {
        let cells = TableRules.squared(item.cells)
        // A column is as wide as its widest cell on one line (the heading row is bold, so a little wider).
        var widths = [Double](repeating: 0, count: TableRules.columnCount(cells))
        for (r, row) in cells.enumerated() {
            for (c, words) in row.enumerated() {
                let one = Double(Lettering.measure(words, size: size, bold: bold(r), maxWidth: 10_000).width)
                widths[c] = max(widths[c], one)
            }
        }
        // 0.19: a column the owner pulled has its own width (at least 40); the tick column is a narrow box.
        widths = widths.enumerated().map { c, w in
            TableRules.ownWidth(item.widths, column: c)
                ?? (c == item.tickColumn ? tickWidth : min(TableRules.maxColumn, max(TableRules.minColumn, w + 2 * TableRules.padX)))
        }
        let heights = cells.enumerated().map { r, row -> Double in
            var high = 0.0
            for (c, words) in row.enumerated() {
                high = max(high, Double(Lettering.measure(words, size: size, bold: bold(r), maxWidth: CGFloat(widths[c] - 2 * TableRules.padX)).height))
            }
            return high + 2 * TableRules.padY
        }
        return (widths, heights)
    }

    /// 0.19: the width of the tick column when nobody pulled it, and the room under the table for "3 of 8 done".
    static let tickWidth: Double = 38
    static let tickLineRoom: Double = 22

    static func size(of item: Item) -> CGSize {
        let l = layout(of: item)
        let line = TableRules.tickLine(item.cells, column: item.tickColumn) == nil ? 0 : tickLineRoom
        return CGSize(width: l.widths.reduce(0, +), height: l.heights.reduce(0, +) + line)
    }

    /// 0.19: how wide a column must be for its longest words to stand on one line (never under 40, never over 800).
    /// The tick column is its narrow self.
    static func fitWidth(of item: Item, column: Int) -> Double {
        if column == item.tickColumn { return tickWidth }
        let cells = TableRules.squared(item.cells)
        guard column >= 0, column < TableRules.columnCount(cells) else { return TableRules.minColumn }
        var widest = 0.0
        for (r, row) in cells.enumerated() {
            widest = max(widest, Double(Lettering.measure(row[column], size: size, bold: bold(r), maxWidth: 10_000).width))
        }
        return min(TableRules.mostWidth, max(TableRules.leastWidth, widest + 2 * TableRules.padX))
    }

    /// 0.19: the column whose right edge lies at this board point (within `reach`), only along the table's own height.
    static func edge(of item: Item, at p: CGPoint, reach: CGFloat) -> Int? {
        let l = layout(of: item)
        guard p.y >= CGFloat(item.y) - reach, p.y <= CGFloat(item.y + l.heights.reduce(0, +)) + reach else { return nil }
        var x = item.x
        for (c, w) in l.widths.enumerated() {
            x += w
            if abs(p.x - CGFloat(x)) <= reach { return c }
        }
        return nil
    }

    /// The box of one cell, in board points.
    static func box(of spot: TableSpot, in item: Item) -> CGRect {
        let l = layout(of: item)
        let spot = spot.clamped(to: item.cells)
        return CGRect(x: item.x + l.widths.prefix(spot.column).reduce(0, +), y: item.y + l.heights.prefix(spot.row).reduce(0, +),
                      width: l.widths[spot.column], height: l.heights[spot.row])
    }
}

extension BoardPainter {
    func drawTable(_ item: Item, _ ctx: inout GraphicsContext) {
        let cells = TableRules.squared(item.cells)
        let l = TableLook.layout(of: item)
        let f = CGRect(x: item.x, y: item.y, width: l.widths.reduce(0, +), height: l.heights.reduce(0, +))
        let sorted = TableSortMemory.shared.sortOf(item)
        let name = item.colour.isEmpty ? "grey" : item.colour
        let outer = Path(roundedRect: f, cornerRadius: 6)
        ctx.fill(outer, with: .color(paint.plate))
        // The heading row: a light band of the table's colour.
        var band = ctx
        band.clip(to: outer)
        band.fill(Path(CGRect(x: f.minX, y: f.minY, width: f.width, height: l.heights[0])),
                  with: .color(paint.soft(name).opacity(paint.night ? 0.9 : 1)))
        // Thin grid lines.
        let lineColour = item.colour.isEmpty ? paint.edge : paint.line(name).opacity(0.6)
        var grid = Path()
        var x = f.minX
        for w in l.widths.dropLast() { x += w; grid.move(to: CGPoint(x: x, y: f.minY)); grid.addLine(to: CGPoint(x: x, y: f.maxY)) }
        var y = f.minY
        for h in l.heights.dropLast() { y += h; grid.move(to: CGPoint(x: f.minX, y: y)); grid.addLine(to: CGPoint(x: f.maxX, y: y)) }
        ctx.stroke(grid, with: .color(lineColour), lineWidth: 1)
        ctx.stroke(outer, with: .color(lineColour), lineWidth: 1.2)
        // The words of every cell (the one being typed in is shown by the text field).
        var top = f.minY
        for (r, row) in cells.enumerated() {
            var left = f.minX
            for (c, words) in row.enumerated() {
                defer { left += l.widths[c] }
                if editing == item.id, editingCell == TableSpot(row: r, column: c) { continue }
                // 0.19: a tick column's boxes; the heading row of that column has none.
                if c == item.tickColumn, r >= 1 {
                    TickBoxLook.draw(ticked: TableRules.isTicked(words), at: CGPoint(x: left + l.widths[c] / 2, y: top + l.heights[r] / 2), paint: paint, &ctx)
                    continue
                }
                guard !words.isEmpty else { continue }
                let text = ctx.resolve(Text(words).font(Lettering.font(size: TableLook.size, bold: r == 0)).foregroundColor(paint.ink))
                let size = text.measure(in: CGSize(width: l.widths[c] - 2 * TableRules.padX, height: .greatestFiniteMagnitude))
                ctx.draw(text, in: CGRect(x: left + TableRules.padX, y: top + TableRules.padY, width: size.width + 1, height: size.height + 1))
            }
            top += l.heights[r]
        }
        // 0.19: a small chevron in the heading of the column it is sorted by.
        if let sorted, sorted.column < l.widths.count {
            let cx = f.minX + l.widths.prefix(sorted.column + 1).reduce(0, +) - 4.5, cy = f.minY + l.heights[0] / 2
            var chevron = Path()
            let dy: CGFloat = sorted.ascending ? -1.8 : 1.8
            chevron.move(to: CGPoint(x: cx - 3, y: cy - dy)); chevron.addLine(to: CGPoint(x: cx, y: cy + dy)); chevron.addLine(to: CGPoint(x: cx + 3, y: cy - dy))
            ctx.stroke(chevron, with: .color(paint.faint), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        // 0.19: under a table with a tick column: how many boxes are ticked.
        if let line = TableRules.tickLine(item.cells, column: item.tickColumn) {
            let counts = TableRules.tickCount(item.cells, column: item.tickColumn)
            let text = ctx.resolve(Text(line).font(.system(size: 12, weight: .medium))
                .foregroundColor(counts.done == counts.total ? TickBoxLook.green(paint) : paint.faint))
            ctx.draw(text, at: CGPoint(x: f.minX + 2, y: f.maxY + TableLook.tickLineRoom / 2), anchor: .leading)
        }
        // 0.19: a chosen table shows where a column's right edge can be pulled.
        if selection.contains(item.id), handles, editing != item.id {
            var x = f.minX
            for w in l.widths {
                x += w
                ctx.fill(Path(roundedRect: CGRect(x: x - 1.5, y: f.minY + l.heights[0] / 2 - 7, width: 3, height: 14), cornerRadius: 1.5),
                         with: .color(paint.chosen.opacity(0.85)))
            }
        }
        // The cell being typed in: a ring.
        if editing == item.id, let spot = editingCell {
            ctx.stroke(Path(TableLook.box(of: spot, in: item).insetBy(dx: 1, dy: 1)), with: .color(paint.chosen), lineWidth: 2)
        }
    }
}
