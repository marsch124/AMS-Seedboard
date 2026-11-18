import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#endif

// Falling in line on the board (the rules are in SeedboardCore: Snap, DotGrid, Tidy).
// Here: the pink guide lines, the dot grid behind the board, and the session's side of
// dragging, sizing and tidying. None of it is drawn by `BoardPainter`, so the picture that
// goes to PARAGON or is shared never has dots or guides in it.

extension Paint {
    private func hex(_ v: Int) -> Color {
        Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }

    /// The dots of the grid behind the board.
    var dot: Color { hex(night ? 0x2C2F36 : 0xD5DAE2) }
    /// The guide lines while a thing falls in line: pink by day, a lighter pink by night.
    var guide: Color { hex(night ? 0xF58FB2 : 0xE0457B) }
}

/// What is shown while a drag catches: the guide lines, and where a shape pulled out of a plus would land.
struct SnapShow {
    var guides: [Snap.Guide] = []
    var landing: CGRect?
    /// The frames and lanes the dragged things are over: they light up softly (pick 16).
    var over: [FrameSpot] = []

    /// The catch distance in board points: 6 screen points. Holding ⌘ on the Mac switches catching off.
    static func reach(_ scale: CGFloat) -> CGFloat {
        #if os(macOS)
        if NSEvent.modifierFlags.contains(.command) { return 0 }
        #endif
        return 6 / max(scale, 0.01)
    }

    /// For pictures: `-guides` shows the guide lines of the chosen things where they stand.
    private static let forPictures = LaunchOptions.arguments.contains("-guides")

    @MainActor
    func shown(for session: BoardSession) -> SnapShow {
        guard SnapShow.forPictures, guides.isEmpty, landing == nil, !session.selection.isEmpty else { return self }
        var copy = session.board
        return SnapShow(guides: copy.moveSnapped(copy.carried(by: session.selection), by: .zero, reach: 6 / max(session.scale, 0.01)))
    }

    /// Draws the guides. The context must be in board points; `scale` keeps the lines one screen point thin.
    func draw(_ ctx: GraphicsContext, paint: Paint, scale: CGFloat) {
        if let landing {
            let box = Path(roundedRect: landing, cornerRadius: 9)
            ctx.stroke(box, with: .color(paint.chosen), style: StrokeStyle(lineWidth: 1.5 / scale, dash: [5 / scale, 4 / scale]))
        }
        guard !guides.isEmpty else { return }
        var lines = Path()
        for guide in guides {
            let a = guide.from, b = guide.to
            let length = max(hypot(b.x - a.x, b.y - a.y), 0.001)
            let along = CGPoint(x: (b.x - a.x) / length, y: (b.y - a.y) / length)
            switch guide.kind {
            case .line:
                // A little past the outermost things, so the line reads as a line and not as an edge.
                let over = 10 / scale
                lines.move(to: CGPoint(x: a.x - along.x * over, y: a.y - along.y * over))
                lines.addLine(to: CGPoint(x: b.x + along.x * over, y: b.y + along.y * over))
            case .gap:
                // A small mark across the gap: a line with a tick at each end.
                let tick = 4 / scale
                let side = CGPoint(x: -along.y * tick, y: along.x * tick)
                lines.move(to: a); lines.addLine(to: b)
                for end in [a, b] {
                    lines.move(to: CGPoint(x: end.x - side.x, y: end.y - side.y))
                    lines.addLine(to: CGPoint(x: end.x + side.x, y: end.y + side.y))
                }
            }
        }
        ctx.stroke(lines, with: .color(paint.guide), style: StrokeStyle(lineWidth: 1 / scale, lineCap: .round))
    }

    /// The soft dot grid behind the board. The context is in screen points; only the dots in sight are drawn.
    static func grid(_ ctx: GraphicsContext, size: CGSize, offset: CGSize, scale: CGFloat, paint: Paint) {
        let strength = DotGrid.strength(scale: scale)
        guard strength > 0, scale > 0 else { return }
        let visible = CGRect(x: -offset.width / scale, y: -offset.height / scale, width: size.width / scale, height: size.height / scale)
        let d = DotGrid.dot
        var dots = Path()
        for p in DotGrid.dots(in: visible, scale: scale) {
            dots.addEllipse(in: CGRect(x: p.x * scale + offset.width - d / 2, y: p.y * scale + offset.height - d / 2, width: d, height: d))
        }
        ctx.fill(dots, with: .color(paint.dot.opacity(strength)))
    }
}

extension BoardSession {
    // MARK: Dragging and sizing with a catch

    /// Moves the dragged things (from where they were when the drag began) and lets them fall in line.
    func liveMove(_ ids: Set<UUID>, by delta: CGSize, reach: CGFloat) -> [Snap.Guide] {
        var found: [Snap.Guide] = []
        live { found = $0.moveSnapped(ids, by: delta, reach: reach) }
        return found
    }

    /// Sizes the thing and lets the edge that moves catch its neighbours' edges.
    func liveResize(_ id: UUID, to rect: CGRect, reach: CGFloat) -> [Snap.Guide] {
        var found: [Snap.Guide] = []
        live { found = $0.resizeSnapped(id, to: rect, reach: reach) }
        // Its words may have made it taller than asked: a guide the edge is not on is dropped.
        guard let now = board.item(id)?.frame else { return [] }
        return found.filter { $0.axis == .across || abs($0.from.y - now.maxY) < 0.01 || abs($0.from.y - now.minY) < 0.01 }
    }

    // MARK: Tidying several chosen things

    /// How many of the chosen things can be lined up (ideas held by a mind map are left out).
    var tidyCount: Int { selection.count > 1 && !board.placesItself ? board.tidyable(selection).count : 0 }
    /// How many of the chosen things can take another size.
    var sizeCount: Int { selection.count > 1 && !board.placesItself ? board.sizeable(selection).count : 0 }

    func lineUp() {
        let ids = selection
        guard editing == nil else { return }
        change { $0.lineUp(ids) }
    }

    func evenGaps() {
        let ids = selection
        guard editing == nil else { return }
        change { $0.evenGaps(ids) }
    }

    func sameSize() {
        let ids = selection
        guard editing == nil else { return }
        change { $0.sameSize(ids) }
    }
}
