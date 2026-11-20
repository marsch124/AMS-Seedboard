import Foundation
import CoreGraphics

// 0.19 (pick 38): "Shapes by hand". Draw a rough circle, box, triangle, line or arrow and keep the
// tip still at the end (the rest of `InkRest`): the line becomes a clean one. It stays INK — the
// same stroke, colour and thickness, only its points are the clean shape's. Nothing is stored
// that was not stored before. A line that is none of these stays as drawn.
//
// Before: "Tidy shapes" (InkShape.swift, off by default) swaps a loop for a real Box, Oval or
// Diamond thing and a line between two things for an arrow. Now: the same hold cleans plain ink
// too, with no switch. When "Tidy shapes" is on and would make a thing of the line, that wins.
//
// Pure rules, board points. The numbers are first guesses, to be tuned with a real Pencil.

public enum InkClean {
    public enum Kind: Equatable, Sendable { case line, arrow, box, ellipse, triangle, diamond }

    /// The shortest straight line or arrow, in board points.
    public static let leastLine: Double = 36
    /// A line is straight when no point strays further than this share of its length from the chord.
    public static let straight: Double = 0.07
    /// A loop fits a triangle when it lies no further than this share of the diagonal from the outline (both ways).
    public static let triangleFit: Double = 0.045
    /// An arrow's head: how long its barbs are (share of the shaft, kept between these board points) and how wide they open.
    public static let headShare: Double = 0.22
    public static let headLeast: Double = 12
    public static let headMost: Double = 40
    public static let headAngle: Double = 28

    /// What the line was meant as, and the clean points of it (the same colour and width go with them).
    public static func clean(_ points: [CGPoint]) -> (kind: Kind, points: [CGPoint])? {
        let pts = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard pts.count >= 3, let box = Ink.bounds(of: pts) else { return nil }
        if InkShape.closed(pts) {
            guard box.width >= InkShape.least.width, box.height >= InkShape.least.height else { return nil }
            let turned = InkShape.turns(InkShape.spread(pts, count: InkShape.samples))
            guard turned >= InkShape.leastTurn, turned <= InkShape.mostTurn else { return nil }
            if let found = InkShape.shape(of: pts) {
                switch found.kind {
                case .oval: return (.ellipse, InkShape.outline(.oval, in: found.frame))
                case .diamond: return (.diamond, InkShape.outline(.diamond, in: found.frame))
                default: return (.box, InkShape.outline(.box, in: found.frame))
                }
            }
            if let corners = triangle(of: pts) { return (.triangle, corners + [corners[0]]) }
            return nil
        }
        if let line = straightLine(pts) { return (.line, line) }
        if let arrow = arrow(of: pts) { return (.arrow, arrow) }
        return nil
    }

    /// The two ends of a line that runs straight enough.
    static func straightLine(_ pts: [CGPoint]) -> [CGPoint]? {
        guard let a = pts.first, let b = pts.last else { return nil }
        let way = Double(hypot(b.x - a.x, b.y - a.y))
        guard way >= leastLine, InkShape.length(of: pts) <= way * 1.25 else { return nil }
        var worst = 0.0
        for p in pts { worst = max(worst, side(of: p, from: a, to: b).magnitude) }
        return worst <= straight * way ? [a, b] : nil
    }

    /// How far to the left (positive) or right of the way from `a` to `b` the point lies.
    static func side(of p: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let dx = Double(b.x - a.x), dy = Double(b.y - a.y)
        let long = (dx * dx + dy * dy).squareRoot()
        guard long > 0 else { return 0 }
        return (dx * Double(p.y - a.y) - dy * Double(p.x - a.x)) / long
    }

    /// A shaft drawn straight to a tip, then a head: out to one side and back to the tip and out
    /// to the other, all in one line. Becomes the shaft and two barbs at the tip.
    static func arrow(of pts: [CGPoint]) -> [CGPoint]? {
        guard pts.count >= 6, let start = pts.first else { return nil }
        // The tip is the point farthest from the start.
        var tip = 0
        var far = 0.0
        for (i, p) in pts.enumerated() {
            let d = Double(hypot(p.x - start.x, p.y - start.y))
            if d > far { far = d; tip = i }
        }
        // The tip is visited twice (out along the shaft, then back from a barb): the FIRST arrival counts.
        let near = far - max(4, far * 0.04)
        for (i, p) in pts.enumerated() where Double(hypot(p.x - start.x, p.y - start.y)) >= near { tip = i; break }
        guard far >= leastLine, tip >= 2, tip < pts.count - 3 else { return nil }
        let shaft = Array(pts[0...tip])
        guard straightLine(shaft) != nil else { return nil }
        let point = pts[tip]
        // The head stays near the tip: no point of it is further than a third of the shaft away,
        // and it is no longer than the shaft itself.
        let head = Array(pts[tip...])
        guard InkShape.length(of: head) <= far * 0.9 else { return nil }
        var left = false, right = false
        for p in head {
            guard Double(hypot(p.x - point.x, p.y - point.y)) <= far / 3 else { return nil }
            let s = side(of: p, from: start, to: point)
            if s > far * 0.06 { left = true }
            if s < -far * 0.06 { right = true }
        }
        guard left && right else { return nil }
        let length = min(max(far * headShare, headLeast), headMost)
        let back = atan2(Double(start.y - point.y), Double(start.x - point.x))
        func barb(_ turn: Double) -> CGPoint {
            CGPoint(x: Double(point.x) + length * cos(back + turn), y: Double(point.y) + length * sin(back + turn))
        }
        let open = headAngle * .pi / 180
        return [start, point, barb(open), point, barb(-open)]
    }

    /// Three corners of a loop that is a triangle, or nil. The corners are the biggest triangle
    /// that can be drawn on the loop's points; the loop must lie on its outline, and the outline on the loop.
    static func triangle(of pts: [CGPoint]) -> [CGPoint]? {
        let even = InkShape.spread(pts, count: InkShape.samples)
        guard even.count >= 12 else { return nil }
        var best: (a: Int, b: Int, c: Int, area: Double)?
        let n = even.count
        var a = 0
        while a < n {
            var b = a + 1
            while b < n {
                for c in (b + 1)..<n {
                    let area = abs(Double((even[b].x - even[a].x) * (even[c].y - even[a].y) - (even[c].x - even[a].x) * (even[b].y - even[a].y))) / 2
                    if best == nil || area > best!.area { best = (a, b, c, area) }
                }
                b += 1
            }
            a += 1
        }
        guard let best, let box = Ink.bounds(of: pts) else { return nil }
        let corners = [even[best.a], even[best.b], even[best.c]]
        let outline = corners + [corners[0]]
        let diagonal = Double(hypot(box.width, box.height))
        guard diagonal > 0 else { return nil }
        let round = InkShape.spread(outline, count: InkShape.samples)
        var there = 0.0, back = 0.0
        for p in even { there += Route.distance(from: p, to: outline) }
        for p in round { back += Route.distance(from: p, to: even) }
        let far = max(there / Double(even.count), back / Double(round.count)) / diagonal
        return far <= triangleFit ? corners : nil
    }
}
