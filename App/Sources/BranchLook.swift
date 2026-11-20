import SwiftUI
import SeedboardCore

// 0.5 (pick 8, the owner's pick B): a mind map's branches run thick to thin, and an idea's words sit ON its line —
// the branch runs on under the words as an underline, and the ideas under it start from the end of that underline.
// The rule is in Core (Looks.swift: `Route.branchLine`, `Route.branchWeight`); this is its drawing. One painter
// (CanvasDraw.swift) draws the live board, the small pictures, the shared picture and PARAGON's picture.

enum BranchLook {
    /// How thick the line TO an idea of this depth is: a main branch 3.4, the second level 2.4, deeper 1.8.
    static func weight(depth: Int) -> CGFloat { CGFloat(Route.branchWeight(depth: depth)) }

    /// The line from `parent` to `child` and on under the child's words. `parentDepth` 0 = the middle idea.
    static func path(from parent: CGRect, parentDepth: Int, to child: CGRect, side: Side) -> Path {
        let line = Route.branchLine(from: parent, parentDepth: parentDepth, to: child, side: side)
        var path = Path()
        path.move(to: line.start)
        let midX = (line.start.x + line.near.x) / 2
        path.addCurve(to: line.near, control1: CGPoint(x: midX, y: line.start.y), control2: CGPoint(x: midX, y: line.near.y))
        // …and runs on under the words.
        path.addLine(to: line.end)
        return path
    }

    // MARK: 0.19: thick near the middle (pick 20) and the look of a map (pick 24)

    /// How far a box stands out round an idea's words in the `boxes` look.
    static let boxInset = CGSize(width: 5, height: 2)

    /// The box round an idea's words (the `boxes` look).
    static func box(of idea: CGRect) -> CGRect { idea.insetBy(dx: -boxInset.width, dy: -boxInset.height) }

    /// One branch line in the board's look. `lines` and `curves`: a line that runs thick near the middle and thinner
    /// to the far end (5 → 3.4 for a main branch, thinner deeper), on under the idea's words. `boxes`: a thin
    /// right-angle line between the two boxes.
    static func draw(_ ctx: GraphicsContext, look: MapLook, parent: CGRect, parentDepth: Int, child: CGRect, depth: Int,
                     side: Side, colour: Color) {
        if look == .boxes {
            let p = parentDepth == 0 ? parent : box(of: parent)
            let points = Route.boxLine(from: p, to: box(of: child), side: side)
            var path = Path()
            for piece in Route.rounded(points, radius: 8) {
                switch piece {
                case .move(let a): path.move(to: a)
                case .line(let a): path.addLine(to: a)
                case .quad(let to, let c): path.addQuadCurve(to: to, control: c)
                case .curve(let to, let c1, let c2): path.addCurve(to: to, control1: c1, control2: c2)
                }
            }
            ctx.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            return
        }
        let line = Route.branchLine(from: parent, parentDepth: parentDepth, to: child, side: side)
        let width = Route.branchTaper(depth: depth)
        let points = Route.branchPoints(line, look: look)
        let outline = Route.taperedOutline(points, near: width.near, far: width.far)
        guard let first = outline.first else { return }
        var shape = Path()
        shape.move(to: first)
        for q in outline.dropFirst() { shape.addLine(to: q) }
        shape.closeSubpath()
        ctx.fill(shape, with: .color(colour))
        // Round ends, as the strokes before had.
        for (p, w) in [(points[0], width.near), (points[points.count - 1], width.far)] {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - w / 2, y: p.y - w / 2, width: w, height: w)), with: .color(colour))
        }
    }
}
