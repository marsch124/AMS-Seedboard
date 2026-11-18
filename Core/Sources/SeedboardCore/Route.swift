import Foundation
import CoreGraphics

// Where an arrow runs. It leaves the middle of one side of the first item and arrives at the
// middle of a side of the second, so it also meets the tips of a diamond and an oval.

public enum Route {
    public struct Path: Equatable, Sendable {
        /// The corners of the line, start to end.
        public var points: [CGPoint]
        /// Where the words on the arrow sit.
        public var label: CGPoint
        /// The side of the first item the line leaves from.
        public var leaves: Direction
        /// The side of the second item the line arrives at.
        public var arrives: Direction
    }

    public static func path(from a: CGRect, to b: CGRect, style: LinkStyle) -> Path {
        let dx = Double(b.midX - a.midX)
        let dy = Double(b.midY - a.midY)
        let apartAcross = a.maxX < b.minX || b.maxX < a.minX
        let apartDown = a.maxY < b.minY || b.maxY < a.minY

        // Sideways when the items stand side by side (or mostly so); otherwise up/down.
        let sideways: Bool
        if apartAcross && apartDown { sideways = abs(dx) >= abs(dy) }
        else if apartAcross { sideways = true }
        else if apartDown { sideways = false }
        else { sideways = abs(dx) >= abs(dy) }

        let leaves: Direction
        let arrives: Direction
        let start: CGPoint
        let end: CGPoint
        if sideways {
            if dx >= 0 {
                leaves = .right; arrives = .left
                start = CGPoint(x: a.maxX, y: a.midY); end = CGPoint(x: b.minX, y: b.midY)
            } else {
                leaves = .left; arrives = .right
                start = CGPoint(x: a.minX, y: a.midY); end = CGPoint(x: b.maxX, y: b.midY)
            }
        } else {
            if dy >= 0 {
                leaves = .down; arrives = .up
                start = CGPoint(x: a.midX, y: a.maxY); end = CGPoint(x: b.midX, y: b.minY)
            } else {
                leaves = .up; arrives = .down
                start = CGPoint(x: a.midX, y: a.minY); end = CGPoint(x: b.midX, y: b.maxY)
            }
        }

        var points: [CGPoint]
        switch style {
        case .straight, .curve:
            points = [start, end]
        case .elbow:
            if sideways {
                if abs(start.y - end.y) < 1 {
                    points = [start, end]
                } else {
                    let midX = (start.x + end.x) / 2
                    points = [start, CGPoint(x: midX, y: start.y), CGPoint(x: midX, y: end.y), end]
                }
            } else {
                if abs(start.x - end.x) < 1 {
                    points = [start, end]
                } else {
                    let midY = (start.y + end.y) / 2
                    points = [start, CGPoint(x: start.x, y: midY), CGPoint(x: end.x, y: midY), end]
                }
            }
        }
        return Path(points: points, label: middle(of: points), leaves: leaves, arrives: arrives)
    }

    /// The point half way along the line.
    public static func middle(of points: [CGPoint]) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        var lengths: [Double] = []
        for i in 1..<points.count {
            lengths.append(Double(hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)))
        }
        var left = lengths.reduce(0, +) / 2
        for (i, length) in lengths.enumerated() {
            if left <= length, length > 0 {
                let t = CGFloat(left / length)
                return CGPoint(x: points[i].x + (points[i + 1].x - points[i].x) * t,
                               y: points[i].y + (points[i + 1].y - points[i].y) * t)
            }
            left -= length
        }
        return points[points.count - 1]
    }

    /// How far a point is from the line.
    public static func distance(from p: CGPoint, to points: [CGPoint]) -> Double {
        guard points.count > 1 else { return .infinity }
        var best = Double.infinity
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let vx = Double(b.x - a.x), vy = Double(b.y - a.y)
            let wx = Double(p.x - a.x), wy = Double(p.y - a.y)
            let len2 = vx * vx + vy * vy
            let t = len2 == 0 ? 0 : max(0, min(1, (wx * vx + wy * vy) / len2))
            let cx = Double(a.x) + vx * t, cy = Double(a.y) + vy * t
            best = min(best, hypot(Double(p.x) - cx, Double(p.y) - cy))
        }
        return best
    }

    /// The two ends of a mind-map branch: from the parent's side to the child's near side.
    public static func branch(from parent: CGRect, to child: CGRect, side: Side) -> (start: CGPoint, end: CGPoint) {
        switch side {
        case .right: return (CGPoint(x: parent.maxX, y: parent.midY), CGPoint(x: child.minX, y: child.midY))
        case .left: return (CGPoint(x: parent.minX, y: parent.midY), CGPoint(x: child.maxX, y: child.midY))
        }
    }
}
