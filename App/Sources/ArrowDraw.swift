import SwiftUI
import SeedboardCore

// How arrows are drawn (0.2). Where each arrow runs comes from the rules (`Board.arrows()`):
// rounded corners, arrows side by side, the way round a shape, the ends, the dashes and the place
// of the words. The live board and the picture for PARAGON both draw through here.

/// The arrows of the board drawn last, kept until something that matters to them changes
/// (a shape's place, size or kind, an arrow's ends, sides or style) — so sliding and zooming
/// a big board does not work them out again for every frame.
final class ArrowCache: @unchecked Sendable {
    static let shared = ArrowCache()

    private let lock = NSLock()
    private var key: Int?
    private var kept: [UUID: Route.Arrow] = [:]

    func arrows(of board: Board) -> [UUID: Route.Arrow] {
        guard !board.links.isEmpty else { return [:] }
        var hasher = Hasher()
        for item in board.items {
            hasher.combine(item.id)
            hasher.combine(item.kind)
            hasher.combine(item.x)
            hasher.combine(item.y)
            hasher.combine(item.w)
            hasher.combine(item.h)
            hasher.combine(item.parent)
            hasher.combine(item.folded)
        }
        for link in board.links {
            hasher.combine(link.id)
            hasher.combine(link.from)
            hasher.combine(link.to)
            hasher.combine(link.style)
            hasher.combine(link.fromSide)
            hasher.combine(link.toSide)
        }
        let now = hasher.finalize()
        lock.lock()
        defer { lock.unlock() }
        if key != now {
            kept = board.arrows()
            key = now
        }
        return kept
    }
}

extension LinkEnds {
    /// The mark on the button for these ends.
    var mark: NewMark {
        switch self {
        case .oneWay: return .oneWay
        case .bothWays: return .bothWays
        case .none: return .noEnds
        }
    }
}

extension BoardPainter {
    /// The radius of the dot at each end of a chosen arrow, in board points.
    static func endDot(scale: CGFloat) -> CGFloat { 5 * min(1, max(scale, 0.55)) / scale }

    private static func line(_ pieces: [Route.Piece]) -> Path {
        var path = Path()
        for piece in pieces {
            switch piece {
            case .move(let p): path.move(to: p)
            case .line(let p): path.addLine(to: p)
            case .quad(let to, let control): path.addQuadCurve(to: to, control: control)
            case .curve(let to, let c1, let c2): path.addCurve(to: to, control1: c1, control2: c2)
            }
        }
        return path
    }

    /// Every arrow of the board: its line, its ends and its words.
    func drawArrows(_ ctx: inout GraphicsContext) {
        guard !board.links.isEmpty else { return }
        let all = ArrowCache.shared.arrows(of: board)
        for link in board.links {
            guard let arrow = all[link.id] else { continue }
            let colour = link.colour.isEmpty ? paint.arrow : paint.line(link.colour)
            let path = BoardPainter.line(arrow.pieces)
            if selectedLink == link.id {
                ctx.stroke(path, with: .color(paint.chosen.opacity(0.35)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            }
            // Dashes: 5 long with 6.5 between; the round caps make them look 7 and 4.
            ctx.stroke(path, with: .color(colour),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round, dash: link.isDashed ? [5, 6.5] : []))

            // One way: a head where the line arrives. Both ways: one at the start too. None: a plain line.
            var tips: [(CGPoint, CGVector)] = []
            let ends = link.ends
            if ends != .none, let tip = arrow.points.last { tips.append((tip, arrow.endHeading)) }
            if ends == .bothWays, let tip = arrow.points.first { tips.append((tip, arrow.startHeading)) }
            for (tip, heading) in tips {
                let corners = Route.head(tip: tip, heading: heading)
                var head = Path()
                head.move(to: corners[0])
                head.addLine(to: corners[1])
                head.addLine(to: corners[2])
                ctx.stroke(head, with: .color(colour), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }

            // The words stand beside the line near its start, straight on the board: no patch behind them.
            if !link.text.isEmpty, editing != link.id {
                let text = ctx.resolve(Text(link.text).font(.system(size: 13, weight: .medium))
                    .foregroundColor(link.colour.isEmpty ? paint.ink : colour))
                ctx.draw(text, at: arrow.words.at,
                         anchor: UnitPoint(x: arrow.words.leading ? 0 : 1, y: arrow.words.above ? 1 : 0))
            }
        }
    }

    /// A small dot at each end of the chosen arrow: drag one to another side or another shape.
    func drawArrowEnds(_ ctx: inout GraphicsContext) {
        guard handles, editing == nil, let id = selectedLink,
              let arrow = ArrowCache.shared.arrows(of: board)[id],
              let first = arrow.points.first, let last = arrow.points.last else { return }
        let r = BoardPainter.endDot(scale: scale)
        for p in [first, last] {
            let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(paint.plate))
            ctx.stroke(dot, with: .color(paint.chosen), lineWidth: 2 / scale)
        }
    }
}
