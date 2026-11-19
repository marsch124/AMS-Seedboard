import SwiftUI
import SeedboardCore

// 0.9, "marks": how vote dots, the tick list of a note, the line with a web page's title, the pin mark and the
// background are drawn — and where a press lands on a tick box or on that line.

/// Where the lines of a sticky note with a tick list stand: the same numbers draw them and find a press.
enum TickLayout {
    /// The box, and from the left of the words to the words of a tick line.
    static let side: CGFloat = 12
    static let indent: CGFloat = 19
    static let size: CGFloat = 15

    struct Row {
        var line: Int
        var tick: TickList.Line?
        var words: String
        /// The whole row, in board points.
        var rect: CGRect
        var box: CGRect?
        var wordsWidth: CGFloat
    }

    static func rows(of item: Item) -> [Row] {
        let f = item.frame
        let wrap = Lettering.wrapWidth(for: item)
        var y = f.minY + 10
        var all: [Row] = []
        for (n, parsed) in TickList.lines(item.text).enumerated() {
            let words = parsed?.words ?? TickList.lineWords(item.text, n)
            let width = parsed == nil ? wrap : wrap - indent
            let height = Lettering.measure(words.isEmpty ? " " : words, size: size, bold: false, maxWidth: width).height
            let rect = CGRect(x: f.minX + 10, y: y, width: wrap, height: height)
            let box = parsed == nil ? nil : CGRect(x: rect.minX, y: y + (22 - side) / 2 - 2, width: side, height: side)
            all.append(Row(line: n, tick: parsed, words: words, rect: rect, box: box, wordsWidth: width))
            y += height
        }
        return all
    }

    /// The height the words of a note with tick lines need (nil when there is no tick line).
    static func height(of item: Item) -> CGFloat? {
        guard item.kind == .note, TickList.hasTicks(item.text) else { return nil }
        return rows(of: item).reduce(0) { $0 + $1.rect.height }
    }

    /// The tick line whose box (a generous press area) lies at this board point.
    static func box(of item: Item, at p: CGPoint) -> Int? {
        guard TickList.hasTicks(item.text) else { return nil }
        for row in rows(of: item) {
            guard row.tick != nil, let box = row.box else { continue }
            let area = CGRect(x: item.x, y: row.rect.minY - 2, width: box.maxX + 7 - item.x, height: max(row.rect.height, 20) + 4)
            if area.contains(p) { return row.line }
        }
        return nil
    }
}

/// The line under a thing's words with the title of the web page whose address they hold.
enum LinkLine {
    static let height: CGFloat = 17

    /// Where the line stands (board points), or nil when the thing holds no address.
    static func rect(for item: Item) -> CGRect? {
        guard item.kind != .picture, item.kind != .drawing, item.kind != .door, item.kind != .frame,
              !(item.kind == .bar || item.kind == .milestone || item.kind == .phase),
              WebAddress.first(in: item.text) != nil else { return nil }
        let f = item.frame
        return CGRect(x: f.minX, y: f.maxY + 2, width: max(f.width, 170), height: height)
    }

    static func caption(for item: Item) -> String? {
        WebAddress.first(in: item.text).map { WebAddress.caption(title: item.linkTitle, address: $0) }
    }

    /// The thing whose line lies at this board point.
    static func owner(in board: Board, at p: CGPoint) -> UUID? {
        guard !board.placesItself else { return nil }
        return board.items.last { item in
            !board.isHidden(item.id) && rect(for: item)?.contains(p) == true
        }?.id
    }
}

extension TickList {
    /// The words of line `n` as they stand in the text (for a line that is no tick line).
    static func lineWords(_ text: String, _ n: Int) -> String {
        let all = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        return all.indices.contains(n) ? all[n] : ""
    }
}

extension BoardPainter {
    /// Words of a note that holds tick lines: each line by itself, a hand-drawn box before the tick lines.
    func drawTickWords(_ item: Item, _ ctx: inout GraphicsContext, ink: Color, greyed: Bool) {
        for row in TickLayout.rows(of: item) {
            let ticked = row.tick?.ticked == true
            let colour = ink.opacity(greyed || ticked ? 0.5 : 1)
            var x = row.rect.minX
            if let box = row.box {
                let frame = Path(roundedRect: box, cornerRadius: 3)
                ctx.stroke(frame, with: .color(ink.opacity(0.75)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                if ticked {
                    var tick = Path()
                    tick.move(to: CGPoint(x: box.minX + 2.4, y: box.midY + 0.4))
                    tick.addLine(to: CGPoint(x: box.minX + 5.2, y: box.maxY - 3))
                    tick.addLine(to: CGPoint(x: box.maxX - 1.5, y: box.minY + 1.6))
                    ctx.stroke(tick, with: .color(ink), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                }
                x += TickLayout.indent
            }
            guard !row.words.isEmpty else { continue }
            let text = ctx.resolve(Text(row.words).font(Lettering.font(size: TickLayout.size, bold: false)).foregroundColor(colour))
            ctx.draw(text, in: CGRect(x: x, y: row.rect.minY, width: row.wordsWidth + 1, height: row.rect.height + 1))
        }
    }

    /// Over everything: vote dots, the title of a web page, the pin mark of a chosen pinned thing.
    func drawMarks(_ ctx: inout GraphicsContext) {
        let unit = min(max(1 / max(scale, 0.01), 0.6), 2.4)
        for item in board.items where !facts.hidden.contains(item.id) && item.kind != .door {
            // 0.14: the marks of a tilted thing turn with it.
            var layer = turned(ctx, item)
            if let n = item.votes, n > 0 { drawDots(n, of: item, unit: unit, &layer) }
            if let line = LinkLine.rect(for: item), let words = LinkLine.caption(for: item) { drawLinkLine(words, in: line, &layer) }
            if item.locked == true, selection.contains(item.id) { drawPin(on: item, unit: unit, &layer) }
        }
    }

    private func drawDots(_ n: Int, of item: Item, unit: CGFloat, _ ctx: inout GraphicsContext) {
        let d = 8 * unit, gap = 3 * unit
        let shown = min(n, Votes.drawn)
        let f = item.frame
        let colour = paint.line("orange")
        var x = f.maxX - 4 * unit - d
        let y = f.minY - d / 2
        for _ in 0..<shown {
            let dot = CGRect(x: x, y: y, width: d, height: d)
            // A thin ring in the board's own colour keeps a dot readable on a note or a frame, by day and by night.
            ctx.fill(Path(ellipseIn: dot.insetBy(dx: -1.2 * unit, dy: -1.2 * unit)), with: .color(ground ?? paint.canvas))
            ctx.fill(Path(ellipseIn: dot), with: .color(colour))
            x -= d + gap
        }
        if n > Votes.drawn {
            let words = ctx.resolve(Text("\(n)").font(.system(size: 11 * unit, weight: .bold)).foregroundColor(colour))
            ctx.draw(words, at: CGPoint(x: x - 1 * unit, y: y + d / 2), anchor: .trailing)
        }
    }

    private func drawLinkLine(_ words: String, in line: CGRect, _ ctx: inout GraphicsContext) {
        let colour = paint.line("blue")
        // A tiny hand-drawn arrow pointing out to the upper right.
        var arrow = Path()
        let a = CGPoint(x: line.minX + 3, y: line.midY + 3.5)
        arrow.move(to: a)
        arrow.addLine(to: CGPoint(x: a.x + 7, y: a.y - 7))
        arrow.move(to: CGPoint(x: a.x + 2, y: a.y - 7))
        arrow.addLine(to: CGPoint(x: a.x + 7, y: a.y - 7))
        arrow.addLine(to: CGPoint(x: a.x + 7, y: a.y - 2))
        ctx.stroke(arrow, with: .color(colour), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        // The words, shortened to fit the line.
        let room = line.width - 16
        var shown = words
        if Lettering.measure(shown, size: 12, bold: false, maxWidth: 4000).width > room {
            var kept = words
            while kept.count > 3, Lettering.measure(kept + "…", size: 12, bold: false, maxWidth: 4000).width > room { kept.removeLast() }
            shown = kept + "…"
        }
        let text = ctx.resolve(Text(shown).font(.system(size: 12)).foregroundColor(colour))
        ctx.draw(text, at: CGPoint(x: line.minX + 14, y: line.midY), anchor: .leading)
    }

    /// A tiny drawn pin at the top left corner: a round head and a short stem.
    private func drawPin(on item: Item, unit: CGFloat, _ ctx: inout GraphicsContext) {
        let f = item.frame
        let c = CGPoint(x: f.minX + 2 * unit, y: f.minY - 5 * unit)
        var pin = Path()
        pin.addEllipse(in: CGRect(x: c.x - 3 * unit, y: c.y - 3 * unit, width: 6 * unit, height: 6 * unit))
        pin.move(to: CGPoint(x: c.x, y: c.y + 3 * unit))
        pin.addLine(to: CGPoint(x: c.x, y: c.y + 8 * unit))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4.2 * unit, y: c.y - 4.2 * unit, width: 8.4 * unit, height: 8.4 * unit)), with: .color(ground ?? paint.canvas))
        ctx.stroke(pin, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 1.7 * unit, lineCap: .round))
    }
}

/// The board's background: soft dots (as before), small squares, or nothing. Drawn behind everything, in screen points.
enum BackdropShow {
    static func draw(_ ctx: GraphicsContext, kind: Backdrop, size: CGSize, offset: CGSize, scale: CGFloat, paint: Paint) {
        switch kind {
        case .plain:
            return
        case .dots:
            SnapShow.grid(ctx, size: size, offset: offset, scale: scale, paint: paint)
        case .squares:
            let strength = DotGrid.strength(scale: scale)
            guard strength > 0, scale > 0 else { return }
            let step = Backdrop.squareStep(scale: scale)
            let visible = CGRect(x: -offset.width / scale, y: -offset.height / scale, width: size.width / scale, height: size.height / scale)
            var lines = Path()
            var x = (visible.minX / step).rounded(.up) * step
            while x <= visible.maxX {
                let sx = x * scale + offset.width
                lines.move(to: CGPoint(x: sx, y: 0)); lines.addLine(to: CGPoint(x: sx, y: size.height))
                x += step
            }
            var y = (visible.minY / step).rounded(.up) * step
            while y <= visible.maxY {
                let sy = y * scale + offset.height
                lines.move(to: CGPoint(x: 0, y: sy)); lines.addLine(to: CGPoint(x: size.width, y: sy))
                y += step
            }
            ctx.stroke(lines, with: .color(paint.dot.opacity(strength * 0.9)), lineWidth: 1)
        }
    }
}
