import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// How a board is drawn. One painter draws the live board and the picture that goes to PARAGON,
// so the two can never differ.

/// The board's colours, by day and by night. Colour names come from the file (`Palette`).
struct Paint {
    let night: Bool

    init(_ scheme: ColorScheme) { night = scheme == .dark }
    init(night: Bool) { self.night = night }

    private typealias RGB = (Double, Double, Double)

    private static func rgb(_ v: Int) -> RGB {
        (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    private static func colour(_ c: RGB) -> Color { Color(red: c.0, green: c.1, blue: c.2) }

    private static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    private static let lines: [String: (Int, Int)] = [
        "pink": (0xC0399F, 0xE58AD0), "orange": (0xE07B1A, 0xF2A45C), "teal": (0x1E9C8E, 0x5CCBBE),
        "blue": (0x3572D6, 0x7FAEF5), "purple": (0x8E55D9, 0xB99AF0), "green": (0x2E8B57, 0x5FBF8A),
        "yellow": (0xC99A0A, 0xF0C850), "red": (0xD5485C, 0xF08A98), "grey": (0x7B8794, 0xA9B4C4),
    ]

    // By night a note stays bright paper with dark ink, only a little dimmer than by day.
    private static let notes: [String: (Int, Int)] = [
        "yellow": (0xFBE38A, 0xD9BC55), "pink": (0xF9C2D4, 0xD98AA8), "blue": (0xBFD9FA, 0x86AEDD),
        "green": (0xBFE8C8, 0x86C79A), "orange": (0xFBD0A0, 0xDDA066), "purple": (0xDCC9F7, 0xB39AE0),
    ]

    private func lineRGB(_ name: String) -> RGB {
        let pair = Paint.lines[name] ?? Paint.lines["grey"]!
        return Paint.rgb(night ? pair.1 : pair.0)
    }

    /// A line or an outline in the named colour.
    func line(_ name: String) -> Color { Paint.colour(lineRGB(name)) }

    /// A soft fill of the named colour, for a tinted shape or frame.
    func soft(_ name: String) -> Color {
        let base = Paint.rgb((Paint.lines[name] ?? Paint.lines["grey"]!).0)
        return Paint.colour(night ? Paint.mix(base, Paint.rgb(0x17181B), 0.72) : Paint.mix(base, (1, 1, 1), 0.84))
    }

    /// A sticky note's paper.
    func note(_ name: String) -> Color {
        let pair = Paint.notes[name] ?? Paint.notes["yellow"]!
        return Paint.colour(Paint.rgb(night ? pair.1 : pair.0))
    }

    /// The ink on a sticky note: dark by day and by night, the paper is always bright.
    static let noteInk = Color(red: 0.12, green: 0.14, blue: 0.19)

    var canvas: Color { Paint.colour(Paint.rgb(night ? 0x17181B : 0xF6F7F9)) }
    var plate: Color { Paint.colour(Paint.rgb(night ? 0x26282D : 0xFFFFFF)) }
    var edge: Color { Paint.colour(Paint.rgb(night ? 0x4A4E57 : 0xD5DAE2)) }
    var ink: Color { Paint.colour(Paint.rgb(night ? 0xECEEF2 : 0x1E2530)) }
    var faint: Color { Paint.colour(Paint.rgb(night ? 0x8A919C : 0x8B94A1)) }
    var arrow: Color { Paint.colour(Paint.rgb(night ? 0xA9B4C4 : 0x7B8794)) }
    var chosen: Color { Paint.colour(Paint.rgb(night ? 0x5FBF8A : 0x2E8B57)) }
}

/// Text sizes on the board, and how much room words need.
enum Lettering {
    static func style(for item: Item, depth: Int) -> (size: CGFloat, bold: Bool) {
        switch item.kind {
        case .idea: return depth == 0 ? (17, true) : (15, depth == 1)
        case .text: return (17, false)
        case .frame: return (13, true)
        default: return (15, false)
        }
    }

    static func font(size: CGFloat, bold: Bool) -> Font {
        .system(size: size, weight: bold ? .semibold : .regular)
    }

    /// The room the words take when they may be at most this wide.
    static func measure(_ text: String, size: CGFloat, bold: Bool, maxWidth: CGFloat) -> CGSize {
        let words = text.isEmpty ? " " : text
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        #else
        let font = UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        #endif
        let box = (words as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil)
        return CGSize(width: ceil(box.width) + 1, height: ceil(box.height) + 1)
    }

    /// The width the words of an item may take inside it.
    static func wrapWidth(for item: Item) -> CGFloat {
        switch item.kind {
        case .idea: return 240
        case .text: return 360
        default: return CGFloat(ShapeFit.wordsWidth(item.kind, w: item.w))
        }
    }

    /// Sizes every item so its words fit: ideas and free text take exactly the room of their
    /// words; shapes and notes only ever grow. Then the mind maps are laid out again.
    /// A shape in `widen` (its words are being typed, or its kind was just changed) grows wider
    /// first, round its middle, and only then taller; any other shape keeps the owner's width.
    static func fit(_ board: inout Board, facts: MapFacts, widen: Set<UUID> = []) {
        for i in board.items.indices {
            let item = board.items[i]
            let depth = facts.depth[item.id] ?? 0
            let look = style(for: item, depth: depth)
            let words = item.text.isEmpty && item.kind == .idea ? "Idea" : item.text
            let t = measure(words, size: look.size, bold: look.bold, maxWidth: wrapWidth(for: item))
            switch item.kind {
            case .idea:
                if depth == 0 {
                    board.items[i].w = Double(max(110, t.width + 32))
                    board.items[i].h = Double(max(44, t.height + 20))
                } else {
                    board.items[i].w = Double(max(36, t.width + 6))
                    board.items[i].h = Double(max(26, t.height + 8))
                }
            case .text:
                board.items[i].w = Double(max(40, t.width + 8))
                board.items[i].h = Double(max(26, t.height + 6))
            case .box, .round, .diamond, .oval, .person, .document, .slanted, .store:
                let size = ShapeFit.size(item.kind, w: item.w, h: item.h, widen: widen.contains(item.id)) { width in
                    Double(measure(words, size: look.size, bold: look.bold, maxWidth: CGFloat(width)).height)
                }
                board.items[i].x -= (size.w - item.w) / 2
                board.items[i].w = size.w
                board.items[i].h = size.h
            case .note:
                board.items[i].h = max(item.h, Double(t.height + 22))
            case .frame:
                break
            case .door:
                // 0.5 groundwork: a door keeps the size it was given (the door lane draws it for real).
                break
            case .bar, .milestone, .phase:
                break
            case .who, .message, .band, .section:
                // Who does what: the room of the words; the app places everything (SequenceDraw.swift).
                let size = SequenceLook.wordsSize(of: item)
                board.items[i].w = Double(size.width)
                board.items[i].h = Double(size.height)
            case .drawing:
                // As big as its lines (Ink.swift).
                break
            case .picture:
                // As big as the owner made it; it has no words.
                break
            }
        }
        board.layoutMaps()
    }
}

/// What the painter needs to know about every idea, worked out once per change.
struct MapFacts {
    var depth: [UUID: Int] = [:]
    var side: [UUID: Side] = [:]
    var colour: [UUID: String] = [:]
    var hidden: Set<UUID> = []
    var children: [UUID: Int] = [:]

    init() {}

    init(_ board: Board) {
        var kids: [UUID: [Item]] = [:]
        for item in board.items where item.kind == .idea {
            if let parent = item.parent { kids[parent, default: []].append(item) }
        }
        for key in kids.keys {
            kids[key]?.sort { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
        }
        for (key, list) in kids { children[key] = list.count }

        func walk(_ item: Item, depth d: Int, side s: Side, colour c: String, hidden h: Bool) {
            depth[item.id] = d
            side[item.id] = s
            colour[item.id] = c
            if h { hidden.insert(item.id) }
            guard d < 200 else { return }
            for child in kids[item.id] ?? [] {
                walk(child, depth: d + 1, side: s, colour: c, hidden: h || item.folded)
            }
        }

        for centre in board.items where centre.kind == .idea && centre.parent == nil {
            depth[centre.id] = 0
            side[centre.id] = .right
            let list = kids[centre.id] ?? []
            // A main branch stays on the side it remembers (the same rule as the layout).
            let sides = MindMap.sides(of: list, bothSides: centre.bothSides)
            for (n, branch) in list.enumerated() {
                let s = sides[n]
                walk(branch, depth: 1, side: s, colour: branch.colour.isEmpty ? "pink" : branch.colour, hidden: centre.folded)
            }
        }
    }
}

/// Draws a board. The context must already be in board points.
struct BoardPainter {
    let board: Board
    let facts: MapFacts
    let paint: Paint
    /// Screen points per board point, so handles keep their size when zoomed.
    var scale: CGFloat = 1
    var selection: Set<UUID> = []
    var selectedLink: UUID?
    /// The item being typed in: the text field shows its words.
    var editing: UUID?
    /// An idea being dragged to a new place: drawn where the finger is.
    var ghost: (id: UUID, offset: CGSize)?
    /// The idea a dragged idea would hang under.
    var dropTarget: UUID?
    var handles = true
    /// Frames and lanes that light up, and the lane whose name is being typed (LanesView.swift).
    var frames = FrameShow()
    /// 0.5: how each to-do thing stands (waiting, in PARAGON, done, cancelled) — `ParagonEcho.marks(for:)`.
    /// A thing that is not in here and is ticked "to do" counts as waiting.
    var todoStates: [UUID: TodoState] = [:]
    /// What lies behind the board (white for a picture). Not needed since 0.2: the words on an arrow have no patch behind them.
    var ground: Color?

    func draw(_ ctx: inout GraphicsContext) {
        // A timeline is drawn by its own painter (TimelineDraw.swift), whole, from the corner of its box.
        if board.isTimeline { TimelinePainter.whole(board, paint: paint, ground: ground).draw(&ctx); return }
        // So is a "Who does what" board (SequenceDraw.swift).
        if board.isSequence { SequencePainter.whole(board, paint: paint, ground: ground).draw(&ctx); return }
        let byID = board.items.reduce(into: [UUID: Item]()) { $0[$1.id] = $1 }

        for item in board.items where item.kind == .frame { drawFrame(item, &ctx) }

        // Mind-map branches.
        for item in board.items where item.kind == .idea && !facts.hidden.contains(item.id) {
            guard let parentID = item.parent, let parent = byID[parentID] else { continue }
            // 0.5: thick to thin, and (look B) the words on the line — BranchLook.swift.
            let look = BranchLook.current, depth = facts.depth[item.id] ?? 1
            let path = look.path(from: parent.frame, parentDepth: depth - 1, to: item.frame, side: facts.side[item.id] ?? .right)
            ctx.stroke(path, with: .color(paint.line(facts.colour[item.id] ?? "pink")),
                       style: StrokeStyle(lineWidth: look.weight(depth: depth), lineCap: .round, lineJoin: .round))
        }

        drawArrows(&ctx)

        for item in board.items where item.kind != .frame && !facts.hidden.contains(item.id) {
            if ghost?.id == item.id { continue }
            drawItem(item, &ctx)
        }
        drawArrowEnds(&ctx)

        if let ghost, let item = byID[ghost.id] {
            var moved = item
            moved.x += Double(ghost.offset.width)
            moved.y += Double(ghost.offset.height)
            var layer = ctx
            layer.opacity = 0.7
            drawItem(moved, &layer)
        }

        if let dropTarget, let item = byID[dropTarget] {
            let box = Path(roundedRect: item.frame.insetBy(dx: -6, dy: -5), cornerRadius: 9)
            ctx.stroke(box, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 2.5 / scale, dash: [6 / scale, 4 / scale]))
        }

        // The frame round what is chosen and its small controls lie over this drawing (ChosenFrame.swift).
    }

    // MARK: Pieces

    private func drawFrame(_ item: Item, _ ctx: inout GraphicsContext) {
        let name = item.colour.isEmpty ? "teal" : item.colour
        let box = Path(roundedRect: item.frame, cornerRadius: 14)
        ctx.fill(box, with: .color(paint.soft(name).opacity(paint.night ? 0.35 : 0.45)))
        ctx.stroke(box, with: .color(paint.line(name)), lineWidth: 1.6)
        drawLanes(item, &ctx)
        guard editing != item.id else { return }
        let words = item.text.isEmpty ? "Frame" : item.text
        let text = ctx.resolve(Text(words).font(Lettering.font(size: 13, bold: true)).foregroundColor(paint.line(name)))
        ctx.draw(text, at: CGPoint(x: item.frame.minX + 12, y: item.frame.minY + 15), anchor: .leading)
    }

    private func drawItem(_ item: Item, _ ctx: inout GraphicsContext) {
        let f = item.frame
        let depth = facts.depth[item.id] ?? 0
        let look = Lettering.style(for: item, depth: depth)
        var textColour = paint.ink
        // 0.5: how it stands as a to-do (TodoMark.swift); done or cancelled in PARAGON greys its words.
        let todo = TodoMark.state(of: item, in: todoStates)
        var align: TextAlignment = .center
        var anchorLeading = false
        var textBox = f

        switch item.kind {
        case .idea:
            if depth == 0 {
                let box = Path(roundedRect: f, cornerRadius: 11)
                ctx.fill(box, with: .color(paint.plate))
                ctx.stroke(box, with: .color(paint.edge), lineWidth: 1.4)
            } else {
                align = (facts.side[item.id] ?? .right) == .right ? .leading : .trailing
            }
        case .box, .round, .diamond, .oval, .door:
            // 0.5 groundwork: a door is drawn as a plain box until the door lane draws it for real.
            let shape: Path
            switch item.kind {
            case .round: shape = Path(roundedRect: f, cornerRadius: min(f.height, f.width) / 2)
            case .oval: shape = Path(ellipseIn: f)
            case .diamond:
                var p = Path()
                p.move(to: CGPoint(x: f.midX, y: f.minY)); p.addLine(to: CGPoint(x: f.maxX, y: f.midY))
                p.addLine(to: CGPoint(x: f.midX, y: f.maxY)); p.addLine(to: CGPoint(x: f.minX, y: f.midY)); p.closeSubpath()
                shape = p
            default: shape = Path(roundedRect: f, cornerRadius: 9)
            }
            // By day a shape lies a little above the board: a faint shadow, one point down.
            var body = ctx
            if !paint.night { body.addFilter(.shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)) }
            if item.colour.isEmpty {
                body.fill(shape, with: .color(paint.plate))
                ctx.stroke(shape, with: .color(paint.edge), lineWidth: 1.4)
            } else {
                body.fill(shape, with: .color(paint.soft(item.colour)))
                ctx.stroke(shape, with: .color(paint.line(item.colour)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            }
        case .person, .document, .slanted, .store:
            drawOutline(item, &ctx)
            textBox = ShapeOutline.textBox(item.kind, f)
        case .note:
            let paper = Path(roundedRect: f, cornerRadius: 4)
            var shade = ctx
            shade.addFilter(.shadow(color: .black.opacity(paint.night ? 0.35 : 0.14), radius: 3, x: 0, y: 1.5))
            shade.fill(paper, with: .color(paint.note(item.colour)))
            align = .leading
            anchorLeading = true
            textBox = f.insetBy(dx: 10, dy: 10)
            textColour = Paint.noteInk
        case .text:
            align = .leading
        case .frame:
            return
        case .bar, .milestone, .phase:
            return
        case .who, .message, .band, .section:
            return
        case .drawing:
            // Lines drawn by hand (InkDraw.swift): no words, no tick.
            drawInk(item, ctx)
            return
        case .picture:
            // The picture itself (PictureViews.swift): no words, no tick.
            drawPicture(item, ctx)
            return
        }

        if editing != item.id {
            let placeholder = item.text.isEmpty
            let words = placeholder ? (item.kind == .idea ? "Idea" : "") : item.text
            if !words.isEmpty {
                let text = ctx.resolve(Text(words)
                    .font(Lettering.font(size: look.size, bold: look.bold))
                    .foregroundColor(placeholder ? paint.faint : (TodoMark.greysWords(todo) ? (item.kind == .note ? textColour.opacity(0.45) : paint.faint) : textColour)))
                let wrap = Lettering.wrapWidth(for: item)
                let size = text.measure(in: CGSize(width: wrap, height: .greatestFiniteMagnitude))
                var origin: CGPoint
                if anchorLeading {
                    origin = CGPoint(x: textBox.minX, y: textBox.minY)
                } else {
                    switch align {
                    case .leading: origin = CGPoint(x: f.minX + 3, y: f.midY - size.height / 2)
                    case .trailing: origin = CGPoint(x: f.maxX - 3 - size.width, y: f.midY - size.height / 2)
                    default: origin = CGPoint(x: textBox.midX - size.width / 2, y: textBox.midY - size.height / 2)
                    }
                }
                if item.kind == .text { origin.x = f.minX + 4 }
                ctx.draw(text, in: CGRect(origin: origin, size: CGSize(width: size.width + 1, height: size.height + 1)))
            }
        }

        if let todo {
            // The small to-do mark at the top corner: a task for PARAGON, and how it stands there.
            let c = item.kind == .idea && depth > 0
                ? CGPoint(x: (facts.side[item.id] ?? .right) == .right ? f.maxX + 12 : f.minX - 12, y: f.midY)
                : ShapeOutline.tickSpot(item.kind, f)
            TodoMark.draw(todo, at: c, paint: paint, ground: ground ?? paint.canvas, &ctx)
        }

        if item.kind == .idea, item.folded, let count = facts.children[item.id], count > 0 {
            // Folded: a small dot with the number of ideas hidden under it.
            let right = (facts.side[item.id] ?? .right) == .right || depth == 0
            let c = CGPoint(x: right ? f.maxX + 14 : f.minX - 14, y: f.midY)
            let name = depth == 0 ? "grey" : (facts.colour[item.id] ?? "pink")
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(paint.line(name)))
            let n = ctx.resolve(Text("\(count)").font(.system(size: 11, weight: .bold)).foregroundColor(.white))
            ctx.draw(n, at: c, anchor: .center)
        }
    }
}
