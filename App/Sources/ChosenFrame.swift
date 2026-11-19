import SwiftUI
import SeedboardCore

// The frame round what is chosen and the small controls round one chosen thing (0.2, pick 7).
// The frame follows the thing's own outline with a 3-point gap; a shape, a note and a frame have a
// size knob on all four corners; a plus-handle is a small outline dot that grows and shows its plus
// under the pointer (it is always big on a touch screen), and there is none on a side that already
// has an arrow. The rules are in SeedboardCore (`Controls`); this layer lies over the board's own
// drawing, so the picture that goes to PARAGON never has any of it.

extension BoardSession {
    /// The boxes of the words on the arrows that pass near a thing, in board points.
    private func wordBoxes(near frame: CGRect, _ arrows: [UUID: Route.Arrow]) -> [CGRect] {
        let near = frame.insetBy(dx: -140, dy: -60)
        var boxes: [CGRect] = []
        for link in board.links where !link.text.isEmpty {
            guard let words = arrows[link.id]?.words, near.contains(words.at) else { continue }
            boxes.append(words.box(for: Lettering.measure(link.text, size: 13, bold: true, maxWidth: 1_000)))
        }
        return boxes
    }

    /// The small controls round the one chosen thing, in board points. None while words are typed,
    /// while the arrow tool is on, on a board that cannot be changed, or with several things chosen.
    func chosenControls() -> [Controls.Control] {
        guard !readOnly, editing == nil, laneTyping == nil, !linking, selection.count == 1,
              let id = selection.first, let item = shownThing(id), !facts.hidden.contains(id) else { return [] }
        var taken: Set<Direction> = []
        var words: [CGRect] = []
        if item.kind != .idea, !board.links.isEmpty {
            let arrows = ArrowCache.shared.arrows(of: board)
            taken = board.sidesWithArrows(of: id, arrows: arrows)
            words = wordBoxes(near: item.frame, arrows)
        }
        var round = Controls.round(item, side: facts.side[id] ?? .right, scale: scale, taken: taken, words: words)
        // 0.14: the grips follow a tilted thing: each box keeps its size and moves round the middle.
        if item.turn != 0 { round = round.map { Tilt14.moved($0, item) } }
        // 0.9: a pinned thing cannot be sized — it has no size knobs.
        return item.locked == true ? round.filter { if case .size = $0.kind { return false } else { return true } } : round
    }

    /// The control under a point of the board view (screen points). `finger`: a finger pressed —
    /// the press area is then at least 32 points; `onThing`: a thing lies exactly under the point.
    func control(at point: CGPoint, finger: Bool, onThing: Bool) -> Controls.Kind? {
        let all = chosenControls()
        guard !all.isEmpty else { return nil }
        let boxes = all.map { toScreen($0.box(grown: Finger.on)) }
        guard let i = Fingers.control(at: point, boxes: boxes, onThing: onThing, least: finger ? Fingers.control : 0) else { return nil }
        return all[i].kind
    }

    /// The chosen thing's box on screen with its controls — the bar stands beside it. Several chosen
    /// things: the box round all of them. A chosen arrow: the box round its line.
    var chosenBox: CGRect? {
        if let id = selectedLink {
            guard let arrow = ArrowCache.shared.arrows(of: board)[id], let first = arrow.outline.first else { return nil }
            var box = CGRect(origin: first, size: .zero)
            for p in arrow.outline { box = box.union(CGRect(origin: p, size: .zero)) }
            return toScreen(box).insetBy(dx: -6, dy: -6)
        }
        var all: CGRect?
        for id in selection where !facts.hidden.contains(id) {
            guard let thing = board.item(id) else { continue }
            let frame = Tilt.bounds(of: thing.frame, turnedBy: thing.turn)
            all = all.map { $0.union(frame) } ?? frame
        }
        guard let all else { return nil }
        var box = toScreen(all).insetBy(dx: -(Controls.frameGap + 2), dy: -(Controls.frameGap + 2))
        // Up and down the box reaches as far as the plus-handles do.
        for control in chosenControls() {
            let r = toScreen(control.grown)
            let top = min(box.minY, r.minY), bottom = max(box.maxY, r.maxY)
            box = CGRect(x: box.minX, y: top, width: box.width, height: bottom - top)
        }
        return box
    }

    /// Sizes a thing from one of its corners while the knob is dragged (between `liveStart` and
    /// `liveEnd`): the opposite corner stays where it was, also when the words inside push back.
    func liveSize(_ id: UUID, corner: Corner, from base: CGRect, by delta: CGSize, reach: CGFloat) -> [Snap.Guide] {
        // 0.15: a tilted thing is sized along its own edges, and its held corner stays put on the screen.
        let turn = board.item(id)?.turn ?? 0
        if turn != 0 {
            _ = straightSize(id, corner: corner, from: base, by: Tilt.along(delta, turnedBy: turn), reach: 0)
            guard let now = board.item(id)?.frame else { return [] }
            let slide = Tilt.slide(from: base, to: now, turnedBy: turn)
            if slide != .zero { live { $0.move([id], by: slide) } }
            return []
        }
        return straightSize(id, corner: corner, from: base, by: delta, reach: reach)
    }

    /// Sizing as for a straight thing: the opposite corner of the straight box stays where it was.
    private func straightSize(_ id: UUID, corner: Corner, from base: CGRect, by delta: CGSize, reach: CGFloat) -> [Snap.Guide] {
        var found: [Snap.Guide] = []
        live { found = $0.size(id, corner: corner, from: base, by: delta, reach: reach) }
        guard var now = board.item(id)?.frame else { return [] }
        let anchor = corner.opposite.point(in: base)
        let has = corner.opposite.point(in: now)
        if abs(has.x - anchor.x) > 0.01 || abs(has.y - anchor.y) > 0.01 {
            // Its words made it bigger than asked: it grows towards the corner that is dragged.
            let fix = CGSize(width: anchor.x - has.x, height: anchor.y - has.y)
            live { board in
                board.size(id, corner: corner, from: base, by: delta, reach: reach)
                board.move([id], by: fix)
            }
            found = []
            now = board.item(id)?.frame ?? now
        }
        // A guide the edge is not on (the smallest size held it back) is dropped.
        return found.filter { guide in
            switch guide.axis {
            case .across: return abs(guide.from.x - now.minX) < 0.01 || abs(guide.from.x - now.maxX) < 0.01
            case .down: return abs(guide.from.y - now.minY) < 0.01 || abs(guide.from.y - now.maxY) < 0.01
            }
        }
    }
}

// MARK: Drawing

/// The frame round a chosen thing: its own outline, a little further out.
enum ChosenOutline {
    /// `gap`: how far outside the thing the frame runs, in board points.
    static func path(of item: Item, depth: Int, gap g: CGFloat) -> Path {
        let f = item.frame
        let out = f.insetBy(dx: -g, dy: -g)
        switch item.kind {
        case .box:
            return Path(roundedRect: out, cornerRadius: 9 + g)
        case .round:
            return Path(roundedRect: out, cornerRadius: min(out.height, out.width) / 2)
        case .oval:
            return Path(ellipseIn: out)
        case .diamond:
            // Every edge is pushed straight out by the gap, so the frame runs alongside the diamond.
            let a = max(f.width / 2, 1), b = max(f.height / 2, 1)
            let grow = 1 + g * (a * a + b * b).squareRoot() / (a * b)
            var p = Path()
            p.move(to: CGPoint(x: f.midX, y: f.midY - b * grow))
            p.addLine(to: CGPoint(x: f.midX + a * grow, y: f.midY))
            p.addLine(to: CGPoint(x: f.midX, y: f.midY + b * grow))
            p.addLine(to: CGPoint(x: f.midX - a * grow, y: f.midY))
            p.closeSubpath()
            return p
        case .person, .document, .slanted, .store:
            return ShapePaths.outline(item.kind, out).body
        case .note:
            return Path(roundedRect: out, cornerRadius: 4 + g)
        case .door:
            return Path(roundedRect: out, cornerRadius: 10 + g)
        case .frame:
            return Path(roundedRect: out, cornerRadius: 14 + g)
        case .idea where depth == 0:
            return Path(roundedRect: out, cornerRadius: 11 + g)
        default:
            // Words without a box of their own (an idea on a branch, free text) and anything newer.
            return Path(roundedRect: f.insetBy(dx: -5, dy: -4), cornerRadius: 9)
        }
    }
}

/// Lies over the board's drawing: the frames round what is chosen, the size knobs, the plus-handles.
struct ChosenLayer: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = BarDesk.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let paint = Paint(scheme)
        let scale = session.scale
        let hot = desk.hot
        Canvas { ctx, _ in
            var sheet = ctx
            sheet.translateBy(x: session.offset.width, y: session.offset.height)
            sheet.scaleBy(x: scale, y: scale)
            let gap = Controls.frameGap / scale
            for id in session.selection {
                guard let item = session.shownThing(id), !session.facts.hidden.contains(id) else { continue }
                var frame = ChosenOutline.path(of: item, depth: session.facts.depth[id] ?? 0, gap: gap)
                // 0.14: the frame turns with a tilted thing.
                if item.turn != 0 { frame = frame.applying(Tilt14.turn(item)) }
                sheet.stroke(frame, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 2 / scale, lineJoin: .round))
            }
            for control in session.chosenControls() {
                switch control.kind {
                case .plus:
                    let big = Finger.on || hot == control.kind
                    let box = control.box(grown: big)
                    let circle = Path(ellipseIn: box)
                    if big {
                        sheet.fill(circle, with: .color(paint.chosen))
                        let c = CGPoint(x: box.midX, y: box.midY)
                        let arm = box.width * 0.26
                        var plus = Path()
                        plus.move(to: CGPoint(x: c.x - arm, y: c.y)); plus.addLine(to: CGPoint(x: c.x + arm, y: c.y))
                        plus.move(to: CGPoint(x: c.x, y: c.y - arm)); plus.addLine(to: CGPoint(x: c.x, y: c.y + arm))
                        sheet.stroke(plus, with: .color(.white), style: StrokeStyle(lineWidth: 1.9 / scale, lineCap: .round))
                    } else {
                        sheet.fill(circle, with: .color(paint.plate))
                        sheet.stroke(circle, with: .color(paint.chosen), lineWidth: 1.6 / scale)
                    }
                case .size:
                    let knob = Path(roundedRect: control.rest, cornerRadius: 2.5 / scale)
                    sheet.fill(knob, with: .color(paint.plate))
                    sheet.stroke(knob, with: .color(paint.chosen), lineWidth: (hot == control.kind ? 2.6 : 1.8) / scale)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
