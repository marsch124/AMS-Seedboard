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
        widths = widths.map { min(TableRules.maxColumn, max(TableRules.minColumn, $0 + 2 * TableRules.padX)) }
        let heights = cells.enumerated().map { r, row -> Double in
            var high = 0.0
            for (c, words) in row.enumerated() {
                high = max(high, Double(Lettering.measure(words, size: size, bold: bold(r), maxWidth: CGFloat(widths[c] - 2 * TableRules.padX)).height))
            }
            return high + 2 * TableRules.padY
        }
        return (widths, heights)
    }

    static func size(of item: Item) -> CGSize {
        let l = layout(of: item)
        return CGSize(width: l.widths.reduce(0, +), height: l.heights.reduce(0, +))
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
                guard !words.isEmpty else { continue }
                let text = ctx.resolve(Text(words).font(Lettering.font(size: TableLook.size, bold: r == 0)).foregroundColor(paint.ink))
                let size = text.measure(in: CGSize(width: l.widths[c] - 2 * TableRules.padX, height: .greatestFiniteMagnitude))
                ctx.draw(text, in: CGRect(x: left + TableRules.padX, y: top + TableRules.padY, width: size.width + 1, height: size.height + 1))
            }
            top += l.heights[r]
        }
        // The cell being typed in: a ring.
        if editing == item.id, let spot = editingCell {
            ctx.stroke(Path(TableLook.box(of: spot, in: item).insetBy(dx: 1, dy: 1)), with: .color(paint.chosen), lineWidth: 2)
        }
    }
}
