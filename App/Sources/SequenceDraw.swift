import SwiftUI
import SeedboardCore

// How a "Who does what" board is drawn. One painter draws the live board, the small picture on the
// home page and the picture that goes to PARAGON, so the three can never differ. Every place comes
// from `SequenceLayout` (the names from the left, the steps from the top).

/// The lettering of a "Who does what" board, and the room its words take.
enum SequenceLook {
    static let metrics = SequenceMetrics()

    /// The size of the words, whether they are bold, and how wide they may run before they wrap.
    static func style(_ kind: ItemKind) -> (size: CGFloat, bold: Bool, wrap: CGFloat) {
        switch kind {
        case .who: return (15, true, 180)
        case .band: return (13.5, false, 360)
        case .section: return (13.5, true, 420)
        default: return (14, false, 240)
        }
    }

    /// What stands in the place of words that are not there yet.
    static func placeholder(_ kind: ItemKind) -> String {
        switch kind {
        case .who: return "Name"
        case .band: return "Note"
        case .section: return "Section"
        default: return "Words"
        }
    }

    /// A block's tab: its word on a small plate at the top-left of the frame (a block without a
    /// word says "block").
    static func blockWord(_ block: Item) -> String {
        ParagonExport.blockTabWord(block)
    }

    static func blockTab(_ block: Item, in rect: CGRect) -> CGRect {
        let size = Lettering.measure(blockWord(block), size: 11, bold: true, maxWidth: 200)
        return CGRect(x: rect.minX + 10, y: rect.minY, width: size.width + 14, height: 16)
    }

    static func font(_ kind: ItemKind, scale: CGFloat = 1) -> Font {
        let look = style(kind)
        return .system(size: look.size * scale, weight: look.bold ? .semibold : .regular)
    }

    /// The room the words of a name, a message, a note or a section take. The layout is made from
    /// these (`Lettering.fit` writes them into the item's `w` and `h`). A message without words
    /// takes no width; everything else keeps the room of its stand-in word.
    static func wordsSize(of item: Item) -> CGSize {
        let look = style(item.kind)
        let empty = item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if empty, item.kind == .message { return CGSize(width: 0, height: CGFloat(metrics.lineHeight)) }
        return Lettering.measure(empty ? placeholder(item.kind) : item.text, size: look.size, bold: look.bold, maxWidth: look.wrap)
    }

    /// The colour a message is drawn in: its own, or the colour of the name it comes from.
    static func colourName(of message: Item, in board: Board) -> String {
        if !message.colour.isEmpty { return message.colour }
        guard let sender = message.from, board.item(sender)?.kind == .who else { return "grey" }
        return board.whoColour(sender)
    }
}

struct SequencePainter {
    let board: Board
    let paint: Paint
    let layout: SequenceLayout
    /// Screen points per board point, so rings and landing marks keep their size when zoomed.
    var scale: CGFloat = 1
    var selection: Set<UUID> = []
    /// The thing whose words are being typed: the text field shows them.
    var editing: UUID?
    /// What lies behind (white for a picture).
    var ground: Color?
    /// What is in sight, in board points (the open board only): the names stay at its top edge.
    var visible: CGRect?
    /// The room the pinned names keep from the top edge, in screen points.
    var pinInset: CGFloat = 8
    /// "Message to…": the name the message will come from.
    var linkFrom: UUID?
    /// The name a pulled line would land on.
    var dropWho: UUID?
    /// The line being pulled from a dashed line.
    var rubber: (from: CGPoint, to: CGPoint)?
    /// A step or a name being dragged to another place: drawn where the finger is.
    var lifted: (id: UUID, by: CGSize)?
    /// 0.19: while a message is dragged the other steps have made room, so the step itself stands at the place it would
    /// land (faint); the one under the finger is drawn from where it came from.
    var liftedOrigin: (row: SequenceLayout.Row, note: CGRect?)?

    init(board: Board, paint: Paint, layout: SequenceLayout? = nil) {
        self.board = board
        self.paint = paint
        self.layout = layout ?? board.sequenceLayout(SequenceLook.metrics)
    }

    private var m: SequenceMetrics { layout.metrics }
    private var back: Color { ground ?? paint.canvas }

    /// How far the names are moved down so they stay in sight.
    var shift: CGFloat {
        CGFloat(layout.pinShift(top: visible.map { Double($0.minY) }, inset: Double(pinInset / max(scale, 0.01))))
    }

    // MARK: Drawing

    func draw(_ ctx: inout GraphicsContext) {
        let items = board.items.reduce(into: [UUID: Item]()) { $0[$1.id] = $1 }

        // The dashed lines, each in its name's colour.
        for id in layout.whos {
            guard let x = layout.x[id], let who = items[id] else { continue }
            var line = Path()
            line.move(to: CGPoint(x: x, y: layout.boxBottom))
            line.addLine(to: CGPoint(x: x, y: layout.lineBottom))
            ctx.stroke(line, with: .color(paint.line(colourName(who)).opacity(0.65)),
                       style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [5, 5]))
        }

        // Blocks lie under everything but the dashed lines: a thin frame, its word in a small tab.
        for place in layout.blocks {
            guard let block = items[place.id] else { continue }
            drawBlock(block, place.rect, &ctx)
        }

        // Sections and notes lie under the messages.
        for row in layout.rows where row.kind != .message {
            guard let item = items[row.id] else { continue }
            var layer = ctx
            if lifted?.id == row.id { layer.opacity = 0.3 }
            drawRow(row, item, &layer)
        }
        for row in layout.rows where row.kind == .message {
            guard let item = items[row.id] else { continue }
            var layer = ctx
            if lifted?.id == row.id { layer.opacity = 0.3 }
            drawRow(row, item, &layer)
        }
        for row in layout.rows where selection.contains(row.id) { drawChosen(row, &ctx) }
        for place in layout.blocks where selection.contains(place.id) {
            if let block = items[place.id] { ring(SequenceLook.blockTab(block, in: place.rect).insetBy(dx: -3, dy: -3), radius: 8, &ctx) }
            ring(place.rect.insetBy(dx: -3, dy: -3), radius: 12, &ctx)
        }

        // The names. Slid up, they stay at the top edge, on a strip of the board's own colour.
        let down = shift
        if down > 0, let visible {
            let strip = CGRect(x: visible.minX, y: visible.minY, width: visible.width,
                               height: CGFloat(layout.boxBottom) + down + 7 / scale - visible.minY)
            ctx.fill(Path(strip), with: .color(back))
            var edge = Path()
            edge.move(to: CGPoint(x: strip.minX, y: strip.maxY))
            edge.addLine(to: CGPoint(x: strip.maxX, y: strip.maxY))
            ctx.stroke(edge, with: .color(paint.edge.opacity(0.8)), lineWidth: 1 / scale)
        }
        for id in layout.whos {
            guard let box = layout.boxes[id]?.offsetBy(dx: 0, dy: down), let who = items[id] else { continue }
            var layer = ctx
            if lifted?.id == id { layer.opacity = 0.3 }
            drawName(who, box, &layer)
            drawSends(who, box, &layer)
            if selection.contains(id) { ring(box.insetBy(dx: -4, dy: -4), radius: 12, &ctx) }
            if linkFrom == id || dropWho == id { ring(box.insetBy(dx: -4, dy: -4), radius: 12, dashed: true, &ctx) }
        }

        // What is being dragged, where the finger is.
        if let lifted {
            var layer = ctx
            layer.opacity = 0.8
            layer.translateBy(x: lifted.by.width, y: lifted.by.height)
            if let origin = liftedOrigin, let item = items[lifted.id] {
                drawRow(origin.row, item, &layer, note: origin.note)
            } else if let row = layout.row(lifted.id), let item = items[lifted.id] {
                drawRow(row, item, &layer)
            } else if let box = layout.boxes[lifted.id]?.offsetBy(dx: 0, dy: down), let who = items[lifted.id] {
                drawName(who, box, &layer)
            }
        }

        if let rubber {
            var line = Path()
            line.move(to: rubber.from)
            line.addLine(to: rubber.to)
            ctx.stroke(line, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 2.2 / scale, lineCap: .round, dash: [7 / scale, 5 / scale]))
            if abs(rubber.to.x - rubber.from.x) > 12 / scale {
                head(at: rubber.to, pointingRight: rubber.to.x > rubber.from.x, open: false, colour: paint.chosen, size: 1 / scale, &ctx)
            }
        }
    }

    /// The colour of a name: its own, else one by its place in the row (`Board.whoColour`).
    private func colourName(_ who: Item) -> String { board.whoColour(who.id) }

    /// A name box: a soft plate in its colour with the name in the middle.
    private func drawName(_ who: Item, _ box: CGRect, _ ctx: inout GraphicsContext) {
        let name = colourName(who)
        let shape = Path(roundedRect: box, cornerRadius: 9)
        var body = ctx
        if !paint.night && !PaperPictures.onPaper { body.addFilter(.shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)) }
        // The board's colour first, so the dashed line never shows through the soft plate.
        body.fill(shape, with: .color(back))
        ctx.fill(shape, with: .color(paint.soft(name)))
        ctx.stroke(shape, with: .color(paint.line(name)), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
        guard editing != who.id else { return }
        let empty = who.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let look = SequenceLook.style(.who)
        let text = ctx.resolve(Text(empty ? SequenceLook.placeholder(.who) : who.text)
            .font(SequenceLook.font(.who)).foregroundColor(empty ? paint.faint : paint.ink))
        let size = text.measure(in: CGSize(width: look.wrap, height: .greatestFiniteMagnitude))
        ctx.draw(text, in: CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width + 1, height: size.height + 1))
    }

    /// 0.9: a small "sends 4" under a name (the messages it sends; answers count too), on a patch of the board's
    /// colour so the dashed line does not run through it. Nothing for a name that sends none.
    private func drawSends(_ who: Item, _ box: CGRect, _ ctx: inout GraphicsContext) {
        let count = board.sendCount(of: who.id)
        guard count > 0, editing != who.id else { return }
        let text = ctx.resolve(Text("sends \(count)").font(.system(size: 10, weight: .medium)).foregroundColor(paint.line(colourName(who))))
        let size = text.measure(in: CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
        let at = CGPoint(x: box.midX, y: box.maxY + 8)
        ctx.fill(Path(roundedRect: CGRect(x: at.x - size.width / 2 - 3, y: at.y - size.height / 2 - 1, width: size.width + 6, height: size.height + 2),
                      cornerRadius: 4), with: .color(back))
        ctx.draw(text, at: at, anchor: .center)
    }

    /// The line of a message: level from one dashed line to the other, or a small loop back to its own.
    private func linePath(_ row: SequenceLayout.Row, short: CGFloat = 0) -> Path {
        var path = Path()
        let y = CGFloat(row.lineY)
        if row.loop {
            let x = CGFloat(row.fromX), out = CGFloat(m.loopWidth), tall = CGFloat(m.loopHeight)
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + out - 7, y: y))
            path.addArc(tangent1End: CGPoint(x: x + out, y: y), tangent2End: CGPoint(x: x + out, y: y + tall / 2), radius: 7)
            path.addArc(tangent1End: CGPoint(x: x + out, y: y + tall), tangent2End: CGPoint(x: x + out - 7, y: y + tall), radius: 7)
            path.addLine(to: CGPoint(x: x + short, y: y + tall))
        } else {
            let way: CGFloat = row.toX >= row.fromX ? 1 : -1
            path.move(to: CGPoint(x: row.fromX, y: y))
            path.addLine(to: CGPoint(x: CGFloat(row.toX) - way * short, y: y))
        }
        return path
    }

    /// Where a message's arrow arrives, and whether it points to the right there.
    private func tip(_ row: SequenceLayout.Row) -> (at: CGPoint, right: Bool) {
        row.loop ? (CGPoint(x: row.fromX, y: row.lineY + m.loopHeight), false)
                 : (CGPoint(x: row.toX, y: row.lineY), row.toX >= row.fromX)
    }

    /// An arrow head: filled for a message, two open strokes for an answer.
    private func head(at tip: CGPoint, pointingRight: Bool, open: Bool, colour: Color, size: CGFloat = 1, _ ctx: inout GraphicsContext) {
        let way: CGFloat = pointingRight ? 1 : -1
        let back = tip.x - way * 9.5 * size
        var shape = Path()
        shape.move(to: CGPoint(x: back, y: tip.y - 4.6 * size))
        shape.addLine(to: tip)
        shape.addLine(to: CGPoint(x: back, y: tip.y + 4.6 * size))
        if open {
            ctx.stroke(shape, with: .color(colour), style: StrokeStyle(lineWidth: 1.8 * size, lineCap: .round, lineJoin: .round))
        } else {
            shape.closeSubpath()
            ctx.fill(shape, with: .color(colour))
        }
    }

    private func drawRow(_ row: SequenceLayout.Row, _ item: Item, _ ctx: inout GraphicsContext, note: CGRect? = nil) {
        let empty = item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let look = SequenceLook.style(item.kind)
        func words(_ colour: Color, centred: Bool = false) {
            guard editing != item.id, !(empty && item.kind == .message) else { return }
            let text = ctx.resolve(Text(empty ? SequenceLook.placeholder(item.kind) : item.text)
                .font(SequenceLook.font(item.kind)).foregroundColor(empty ? paint.faint : colour))
            let size = text.measure(in: CGSize(width: look.wrap, height: .greatestFiniteMagnitude))
            let x = centred ? row.words.midX - size.width / 2 : row.words.minX
            ctx.draw(text, in: CGRect(x: x, y: row.words.midY - size.height / 2, width: size.width + 1, height: size.height + 1))
        }

        switch item.kind {
        case .message:
            let colour = paint.line(SequenceLook.colourName(of: item, in: board))
            let end = tip(row)
            // A solid line stops inside its filled head; a dashed one runs up to its open head.
            ctx.stroke(linePath(row, short: item.isAnswer ? 1.5 : 7), with: .color(colour),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: item.isAnswer ? .butt : .round, lineJoin: .round, dash: item.isAnswer ? [6, 4] : []))
            head(at: end.at, pointingRight: end.right, open: item.isAnswer, colour: colour, &ctx)
            // A small dot where it starts, on the line of the name it comes from.
            ctx.fill(Path(ellipseIn: CGRect(x: row.fromX - 2.6, y: row.lineY - 2.6, width: 5.2, height: 5.2)), with: .color(colour))

            // The number and the words stand on a patch of the board's colour, so a dashed line
            // they cross does not run through the letters.
            var patch = row.box.insetBy(dx: -4, dy: -1)
            // 0.5: the to-do mark by how it stands (TodoMark.swift).
            let todo = TodoMark.state(of: item, in: TodoMark.marks(for: board))
            if todo != nil { patch.size.width += 20 }
            ctx.fill(Path(roundedRect: patch, cornerRadius: 6), with: .color(back))
            if let centre = row.badge {
                let r = CGFloat(m.badge) / 2
                ctx.fill(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)), with: .color(colour))
                let number = ctx.resolve(Text("\(row.number ?? 0)").font(.system(size: (row.number ?? 0) > 99 ? 8.5 : 10.5, weight: .bold))
                    .foregroundColor(paint.night ? Color(red: 0.09, green: 0.09, blue: 0.11) : .white))
                ctx.draw(number, at: centre, anchor: .center)
            }
            words(TodoMark.greysWords(todo) ? paint.faint : paint.ink)
            if let todo, let centre = row.badge {
                TodoMark.draw(todo, at: CGPoint(x: row.box.maxX + 11, y: centre.y), radius: 7, paint: paint, ground: back, &ctx)
            }
            // 0.19: the grey note box beside the message.
            if let box = note ?? layout.notes[row.id], let words = SequenceNote.words(item.note) { drawNote(words, box, &ctx) }
        case .band:
            let name = item.colour.isEmpty ? "yellow" : item.colour
            let shape = Path(roundedRect: row.box, cornerRadius: 8)
            ctx.fill(shape, with: .color(back))
            ctx.fill(shape, with: .color(paint.soft(name)))
            ctx.stroke(shape, with: .color(paint.line(name).opacity(0.5)), lineWidth: 1)
            words(paint.ink, centred: true)
        case .section:
            let colour = item.colour.isEmpty ? paint.faint : paint.line(item.colour)
            var line = Path()
            line.move(to: CGPoint(x: row.fromX, y: row.lineY))
            line.addLine(to: CGPoint(x: row.toX, y: row.lineY))
            ctx.stroke(line, with: .color(colour.opacity(0.7)), lineWidth: 1.2)
            ctx.fill(Path(roundedRect: row.box, cornerRadius: 5), with: .color(back))
            words(item.colour.isEmpty ? paint.ink : colour)
        default:
            break
        }
    }

    /// 0.19: a message's note: a small grey box with a folded top right corner, the words in caption size.
    private func drawNote(_ words: String, _ box: CGRect, _ ctx: inout GraphicsContext) {
        let fold: CGFloat = 9
        var shape = Path()
        shape.move(to: CGPoint(x: box.minX + 3, y: box.minY))
        shape.addLine(to: CGPoint(x: box.maxX - fold, y: box.minY))
        shape.addLine(to: CGPoint(x: box.maxX, y: box.minY + fold))
        shape.addLine(to: CGPoint(x: box.maxX, y: box.maxY - 3))
        shape.addQuadCurve(to: CGPoint(x: box.maxX - 3, y: box.maxY), control: CGPoint(x: box.maxX, y: box.maxY))
        shape.addLine(to: CGPoint(x: box.minX + 3, y: box.maxY))
        shape.addQuadCurve(to: CGPoint(x: box.minX, y: box.maxY - 3), control: CGPoint(x: box.minX, y: box.maxY))
        shape.addLine(to: CGPoint(x: box.minX, y: box.minY + 3))
        shape.addQuadCurve(to: CGPoint(x: box.minX + 3, y: box.minY), control: CGPoint(x: box.minX, y: box.minY))
        shape.closeSubpath()
        ctx.fill(shape, with: .color(back))
        ctx.fill(shape, with: .color(paint.soft("grey")))
        ctx.stroke(shape, with: .color(paint.line("grey").opacity(0.55)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        // The folded corner.
        var corner = Path()
        corner.move(to: CGPoint(x: box.maxX - fold, y: box.minY))
        corner.addLine(to: CGPoint(x: box.maxX - fold, y: box.minY + fold))
        corner.addLine(to: CGPoint(x: box.maxX, y: box.minY + fold))
        corner.closeSubpath()
        ctx.fill(corner, with: .color(paint.line("grey").opacity(0.3)))
        ctx.stroke(corner, with: .color(paint.line("grey").opacity(0.55)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        let text = ctx.resolve(Text(words).font(.system(size: 11)).foregroundColor(paint.ink))
        let wide = box.width - 2 * CGFloat(SequenceNote.pad)
        let size = text.measure(in: CGSize(width: wide, height: .greatestFiniteMagnitude))
        ctx.draw(text, in: CGRect(x: box.minX + CGFloat(SequenceNote.pad), y: box.minY + CGFloat(SequenceNote.pad),
                                  width: min(wide, size.width + 1), height: size.height + 1))
    }

    /// A block: a thin rounded frame in its colour (grey with none) and its word in a tab on the
    /// top edge. Nothing is filled, so the dashed lines and the messages show through.
    private func drawBlock(_ block: Item, _ rect: CGRect, _ ctx: inout GraphicsContext) {
        let name = block.colour.isEmpty ? "grey" : block.colour
        let line = paint.line(name)
        ctx.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(line.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))
        let tab = SequenceLook.blockTab(block, in: rect)
        let shape = Path(roundedRect: tab, cornerRadius: 6)
        ctx.fill(shape, with: .color(back))
        ctx.fill(shape, with: .color(paint.soft(name)))
        ctx.stroke(shape, with: .color(line), lineWidth: 1.1)
        guard editing != block.id else { return }
        let text = ctx.resolve(Text(SequenceLook.blockWord(block)).font(.system(size: 11, weight: .semibold)).foregroundColor(paint.ink))
        ctx.draw(text, at: CGPoint(x: tab.midX, y: tab.midY), anchor: .center)
    }

    private func ring(_ box: CGRect, radius: CGFloat, dashed: Bool = false, _ ctx: inout GraphicsContext) {
        ctx.stroke(Path(roundedRect: box, cornerRadius: radius), with: .color(paint.chosen),
                   style: StrokeStyle(lineWidth: (dashed ? 2.4 : 2) / scale, dash: dashed ? [6 / scale, 4 / scale] : []))
    }

    /// What is chosen: a soft glow along a message's line and a ring round its words;
    /// a ring round a note or a section.
    private func drawChosen(_ row: SequenceLayout.Row, _ ctx: inout GraphicsContext) {
        if row.kind == .message {
            ctx.stroke(linePath(row), with: .color(paint.chosen.opacity(0.32)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            ring(row.box.insetBy(dx: -6, dy: -3), radius: 8, &ctx)
        } else {
            ring(row.box.insetBy(dx: -3, dy: -3), radius: 10, &ctx)
        }
    }
}

extension SequencePainter {
    /// A "Who does what" board drawn whole, for its picture: the diagram's own box starts at (0, 0).
    static func whole(_ board: Board, paint: Paint, ground: Color?) -> SequencePainter {
        var painter = SequencePainter(board: board, paint: paint)
        painter.ground = ground
        return painter
    }
}
