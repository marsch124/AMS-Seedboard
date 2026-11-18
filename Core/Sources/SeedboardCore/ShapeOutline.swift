import Foundation
import CoreGraphics

// The outlines of the flow shapes: where the words go inside each, where an arrow meets it,
// and where its to-do tick sits. The painter draws from the same numbers, so the words always
// lie inside what is drawn. New in 0.2: Person, Document, Slanted box, Store.

public extension ItemKind {
    /// Every flow shape, in the order the plate shows them.
    static let flowShapes: [ItemKind] = [.box, .round, .oval, .diamond, .person, .document, .slanted, .store]

    /// The shape the Box tile of the tool pill adds, read from what the device remembers.
    /// Anything that is not a flow shape gives a Box; so does Diamond, which has a tile of its own.
    static func boxTile(stored word: String?) -> ItemKind {
        guard let word, let kind = ItemKind(rawValue: word), kind.isShape, kind != .diamond else { return .box }
        return kind
    }
}

public enum ShapeOutline {
    // MARK: The measures of the new shapes

    /// Person: the figure takes this part of the height, the words the rest under it.
    public static let figurePart = 0.62

    /// The head and shoulders of a Person.
    public struct Figure: Equatable, Sendable {
        /// The box round the head (a circle).
        public var head: CGRect
        /// The box round the oval whose upper half is the shoulders.
        public var shoulders: CGRect
        /// The line the shoulders stand on.
        public var base: CGFloat
    }

    public static func figure(in f: CGRect) -> Figure {
        let high = f.height * figurePart
        let r = high * 0.24
        let head = CGRect(x: f.midX - r, y: f.minY + 1, width: r * 2, height: r * 2)
        let top = head.maxY + high * 0.06
        let base = f.minY + high
        let wide = min(f.width - 4, high * 1.15)
        let rise = max(base - top, 1)
        return Figure(head: head, shoulders: CGRect(x: f.midX - wide / 2, y: top, width: wide, height: rise * 2), base: base)
    }

    /// Document: how far the wavy bottom edge swings up and down.
    public static func wave(_ f: CGRect) -> CGFloat { min(9, f.height * 0.14) }

    /// Where the wavy bottom edge of a Document lies at this place across: low in the left half, high in the right.
    public static func waveLine(_ f: CGRect, x: CGFloat) -> CGFloat {
        let a = wave(f)
        let t = max(0, min(1, (x - f.minX) / max(f.width, 1)))
        return f.maxY - a + a * CGFloat(sin(Double(t) * 2 * .pi))
    }

    /// Slanted box: how far the top edge is pushed to the right of the bottom edge.
    public static func slant(_ f: CGRect) -> CGFloat { min(18, f.width * 0.2) }

    /// Store: half the height of the oval at the top and at the bottom of the cylinder.
    public static func rim(_ f: CGRect) -> CGFloat { min(9, f.height * 0.14) }

    // MARK: Words

    /// The part of a shape its words may fill. They are set in the middle of it.
    public static func textBox(_ kind: ItemKind, _ f: CGRect) -> CGRect {
        switch kind {
        case .box, .round:
            return f.insetBy(dx: min(12, f.width / 2), dy: min(11, f.height / 2))
        case .diamond:
            let w = f.width * 0.56, h = max((f.height - 20) / 2, 0)
            return CGRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h)
        case .oval:
            let w = f.width * 0.72, h = max((f.height - 16) / 1.4, 0)
            return CGRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h)
        case .person:
            let top = f.minY + f.height * figurePart + 4
            return CGRect(x: f.minX + 4, y: top, width: max(f.width - 8, 0), height: max(f.maxY - 2 - top, 0))
        case .document:
            return CGRect(x: f.minX + 12, y: f.minY + 9, width: max(f.width - 24, 0), height: max(f.height - 13 - 2 * wave(f), 0))
        case .slanted:
            let s = slant(f)
            return CGRect(x: f.minX + s + 6, y: f.minY + 11, width: max(f.width - 2 * s - 12, 0), height: max(f.height - 22, 0))
        case .store:
            let r = rim(f)
            return CGRect(x: f.minX + 10, y: f.minY + 2 * r + 3, width: max(f.width - 20, 0), height: max(f.height - 3 * r - 6, 0))
        default:
            return f
        }
    }

    /// The height a new kind of shape needs so that words this high fit its text box.
    public static func height(_ kind: ItemKind, words: Double) -> Double {
        switch kind {
        case .person: return ((words + 6) / (1 - figurePart)).rounded(.up)
        case .document: return words + 32
        case .store: return words + 34
        default: return words + 22
        }
    }

    // MARK: The outline itself

    /// True when the point lies inside the drawn outline (for a Person: the figure or the words under it).
    public static func holds(_ kind: ItemKind, _ f: CGRect, _ p: CGPoint) -> Bool {
        guard f.insetBy(dx: -0.01, dy: -0.01).contains(p) else { return false }
        switch kind {
        case .diamond:
            let dx = abs(p.x - f.midX) / max(f.width / 2, 1), dy = abs(p.y - f.midY) / max(f.height / 2, 1)
            return dx + dy <= 1
        case .oval:
            let dx = (p.x - f.midX) / max(f.width / 2, 1), dy = (p.y - f.midY) / max(f.height / 2, 1)
            return dx * dx + dy * dy <= 1
        case .person:
            let fig = figure(in: f)
            if p.y >= fig.base { return true }
            let hx = p.x - fig.head.midX, hy = p.y - fig.head.midY, r = fig.head.width / 2
            if hx * hx + hy * hy <= r * r { return true }
            let sx = (p.x - fig.shoulders.midX) / max(fig.shoulders.width / 2, 1)
            let sy = (p.y - fig.base) / max(fig.shoulders.height / 2, 1)
            return sx * sx + sy * sy <= 1
        case .document:
            return p.y <= waveLine(f, x: p.x)
        case .slanted:
            let s = slant(f), h = max(f.height, 1)
            let left = f.minX + s * (f.maxY - p.y) / h
            let right = f.maxX - s * (p.y - f.minY) / h
            return p.x >= left && p.x <= right
        case .store:
            let r = rim(f)
            let t = (p.x - f.midX) / max(f.width / 2, 1)
            let bulge = r * CGFloat(sqrt(max(0, 1 - Double(t * t))))
            return p.y >= f.minY + r - bulge && p.y <= f.maxY - r + bulge
        default:
            return true
        }
    }

    // MARK: Arrows and the tick

    /// How far inside the box round a shape its real outline lies at the middle of one side. An arrow
    /// ends there, not on the box: half way up the slanted sides of a Slanted box, on the wave under
    /// a Document, at the shoulders of a Person. 0 where the outline touches the box.
    public static func inset(_ kind: ItemKind, _ f: CGRect, side: Direction) -> CGFloat {
        let sideways = side == .left || side == .right
        switch kind {
        case .slanted:
            return sideways ? slant(f) / 2 : 0
        case .document:
            return side == .down ? wave(f) : 0
        case .person:
            guard sideways else { return 0 }
            let fig = figure(in: f)
            let rise = max(fig.shoulders.height / 2, 1)
            let up = min(max((fig.base - f.midY) / rise, 0), 1)
            let half = max(fig.shoulders.width / 2 * CGFloat(sqrt(Double(1 - up * up))), 8)
            return max(f.width / 2 - half, 0)
        default:
            return 0
        }
    }

    /// The middle of the small to-do ring: the top right corner; for a Person beside the head.
    public static func tickSpot(_ kind: ItemKind, _ f: CGRect) -> CGPoint {
        if kind == .person {
            let fig = figure(in: f)
            return CGPoint(x: fig.shoulders.maxX - 3, y: f.minY + 6)
        }
        return CGPoint(x: f.maxX - 3, y: f.minY + 3)
    }
}

public extension Route.Path {
    /// The same line with its two ends on the real outlines of the things it joins (`ShapeOutline.inset`):
    /// each end is pulled in along its own direction, so a straight piece stays straight. The words on
    /// the arrow sit in the middle of what is left. Between two plain boxes nothing changes.
    func meeting(_ a: Item, _ b: Item) -> Route.Path {
        guard points.count > 1 else { return self }
        let first = ShapeOutline.inset(a.kind, a.frame, side: leaves)
        let last = ShapeOutline.inset(b.kind, b.frame, side: arrives)
        guard first > 0 || last > 0 else { return self }
        func pulled(_ p: CGPoint, _ side: Direction, by d: CGFloat) -> CGPoint {
            switch side {
            case .left: return CGPoint(x: p.x + d, y: p.y)
            case .right: return CGPoint(x: p.x - d, y: p.y)
            case .up: return CGPoint(x: p.x, y: p.y + d)
            case .down: return CGPoint(x: p.x, y: p.y - d)
            }
        }
        var out = self
        out.points[0] = pulled(points[0], leaves, by: first)
        out.points[points.count - 1] = pulled(points[points.count - 1], arrives, by: last)
        out.label = Route.middle(of: out.points)
        return out
    }
}
