import Foundation
import CoreGraphics

// Better arrows (0.2). Where every arrow of a board runs, worked out for the whole board at once,
// because an arrow now depends on its neighbours: arrows that share a side of a shape stand apart,
// and an arrow whose way is blocked by another shape goes round it.
// Everything here is plain geometry (no screen), so the live board, the picture for PARAGON and
// the tests all get exactly the same line.

extension Direction: Codable {}

public extension Direction {
    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    /// The left and the right side: a line leaves them sideways.
    var isSideways: Bool { self == .left || self == .right }

    /// One point outward from this side.
    var out: CGVector {
        switch self {
        case .up: return CGVector(dx: 0, dy: -1)
        case .down: return CGVector(dx: 0, dy: 1)
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        }
    }
}

public extension Route {
    /// One piece of a drawn line.
    enum Piece: Equatable, Sendable {
        case move(CGPoint)
        case line(CGPoint)
        case quad(to: CGPoint, control: CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    }

    /// Where the words of an arrow sit: beside the line near its start.
    struct Words: Equatable, Sendable {
        /// The corner of the words' box that is nearest to the start of the line.
        public var at: CGPoint
        /// The words run to the right of the point (otherwise to the left).
        public var leading: Bool
        /// The words sit above the point (otherwise below).
        public var above: Bool
    }

    /// One arrow as it is drawn.
    struct Arrow: Equatable, Sendable {
        /// The corners of the line, start to end.
        public var points: [CGPoint]
        /// The side of the first item the line leaves from.
        public var leaves: Direction
        /// The side of the second item the line arrives at.
        public var arrives: Direction
        /// The line itself, with its rounded corners or its curve.
        public var pieces: [Piece]
        /// The line as short straight pieces, for finding it under a finger.
        public var outline: [CGPoint]
        public var words: Words
        /// The way a head at the start points (along the line, into the first item).
        public var startHeading: CGVector
        /// The way the head at the end points (along the line, into the second item).
        public var endHeading: CGVector
        /// The line goes round a shape that stood in its way.
        public var detour: Bool
    }

    /// One end of an arrow: the item's box, its kind, the side and how far from the side's middle.
    struct End: Equatable, Sendable {
        public var rect: CGRect
        public var kind: ItemKind
        public var side: Direction
        public var offset: Double

        public init(rect: CGRect, kind: ItemKind = .box, side: Direction, offset: Double = 0) {
            self.rect = rect
            self.kind = kind
            self.side = side
            self.offset = offset
        }
    }

    /// How far apart arrows stand that share a side.
    static let spread = 14.0
    /// The roundness of a right-angle corner.
    static let cornerRadius = 8.0
    /// How far a line that goes round a shape stays away from it.
    static let clearance = 12.0
    /// How far a line runs straight out of a side before it may turn.
    static let reach = 16.0

    // MARK: Sides and where a line meets them

    /// The sides an arrow uses when the owner has not chosen any (the rule of 0.1).
    static func sides(from a: CGRect, to b: CGRect) -> (leaves: Direction, arrives: Direction) {
        let dx = Double(b.midX - a.midX)
        let dy = Double(b.midY - a.midY)
        let apartAcross = a.maxX < b.minX || b.maxX < a.minX
        let apartDown = a.maxY < b.minY || b.maxY < a.minY
        let sideways: Bool
        if apartAcross && apartDown { sideways = abs(dx) >= abs(dy) }
        else if apartAcross { sideways = true }
        else if apartDown { sideways = false }
        else { sideways = abs(dx) >= abs(dy) }
        if sideways { return dx >= 0 ? (.right, .left) : (.left, .right) }
        return dy >= 0 ? (.down, .up) : (.up, .down)
    }

    /// The side of a box a point belongs to (the box cut into four by its diagonals).
    static func nearestSide(of rect: CGRect, to p: CGPoint) -> Direction {
        let dx = (Double(p.x) - Double(rect.midX)) / max(Double(rect.width) / 2, 1)
        let dy = (Double(p.y) - Double(rect.midY)) / max(Double(rect.height) / 2, 1)
        if abs(dx) >= abs(dy) { return dx >= 0 ? .right : .left }
        return dy >= 0 ? .down : .up
    }

    /// How far from the middle of a side each of `count` arrows stands: 14 apart round the middle,
    /// closer together when the side has no room for that.
    static func offsets(count: Int, room: Double, step: Double = Route.spread) -> [Double] {
        guard count > 1 else { return count == 1 ? [0] : [] }
        let gap = min(step, max(0, room) / Double(count - 1))
        return (0..<count).map { (Double($0) - Double(count - 1) / 2) * gap }
    }

    /// The length of a side that arrows may use.
    static func room(on rect: CGRect, kind: ItemKind, side: Direction) -> Double {
        let length = Double(side.isSideways ? rect.height : rect.width)
        // Near the tips of a diamond and the ends of an oval the outline runs away from the side.
        if kind == .diamond || kind == .oval { return length * 0.6 }
        return max(0, length - 16)
    }

    /// The point on the outline of an item where a line meets a side, `offset` from its middle.
    static func anchor(on rect: CGRect, kind: ItemKind = .box, side: Direction, offset: Double = 0) -> CGPoint {
        let half = Double(side.isSideways ? rect.height : rect.width) / 2
        let deep = Double(side.isSideways ? rect.width : rect.height) / 2
        let t = max(-half, min(half, offset))
        var inset = 0.0
        switch kind {
        case .diamond:
            inset = half > 0 ? deep * abs(t) / half : 0
        case .oval:
            let u = half > 0 ? t / half : 0
            inset = deep * (1 - (max(0, 1 - u * u)).squareRoot())
        case .box, .round:
            let least = Double(min(rect.width, rect.height)) / 2
            let radius = kind == .round ? least : min(9, least)
            let over = abs(t) - (half - radius)
            if over > 0 { inset = radius - (max(0, radius * radius - over * over)).squareRoot() }
        default:
            // Person, document, slanted box, store: the line ends on the real outline (ShapeOutline.swift).
            inset = Double(ShapeOutline.inset(kind, rect, side: side))
        }
        switch side {
        case .right: return CGPoint(x: Double(rect.maxX) - inset, y: Double(rect.midY) + t)
        case .left: return CGPoint(x: Double(rect.minX) + inset, y: Double(rect.midY) + t)
        case .down: return CGPoint(x: Double(rect.midX) + t, y: Double(rect.maxY) - inset)
        case .up: return CGPoint(x: Double(rect.midX) + t, y: Double(rect.minY) + inset)
        }
    }

    // MARK: Geometry

    /// True when the straight piece runs through the inside of the box (touching its edge is not enough).
    static func crosses(_ p: CGPoint, _ q: CGPoint, _ rect: CGRect) -> Bool {
        guard rect.width > 0, rect.height > 0 else { return false }
        var t0 = 0.0, t1 = 1.0
        let dx = Double(q.x - p.x), dy = Double(q.y - p.y)
        func clip(_ step: Double, _ room: Double) -> Bool {
            if step == 0 { return room > 0 }
            let t = room / step
            if step < 0 {
                if t > t1 { return false }
                if t > t0 { t0 = t }
            } else {
                if t < t0 { return false }
                if t < t1 { t1 = t }
            }
            return true
        }
        guard clip(-dx, Double(p.x - rect.minX)), clip(dx, Double(rect.maxX - p.x)),
              clip(-dy, Double(p.y - rect.minY)), clip(dy, Double(rect.maxY - p.y)) else { return false }
        return t1 - t0 > 1e-9
    }

    private static func length(_ a: CGPoint, _ b: CGPoint) -> Double {
        Double(hypot(b.x - a.x, b.y - a.y))
    }

    private static func unit(from a: CGPoint, to b: CGPoint) -> CGVector {
        let d = length(a, b)
        guard d > 0 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: Double(b.x - a.x) / d, dy: Double(b.y - a.y) / d)
    }

    /// A line with corners, drawn with each corner rounded: radius 8, or half the shorter leg
    /// beside the corner when that is less.
    static func rounded(_ points: [CGPoint], radius: Double = Route.cornerRadius) -> [Piece] {
        guard let first = points.first else { return [] }
        var pieces: [Piece] = [.move(first)]
        guard points.count > 1 else { return pieces }
        if points.count > 2 {
            for i in 1..<(points.count - 1) {
                let a = points[i - 1], corner = points[i], b = points[i + 1]
                let r = min(radius, length(a, corner) / 2, length(corner, b) / 2)
                if r < 0.5 {
                    pieces.append(.line(corner))
                    continue
                }
                let back = unit(from: corner, to: a), on = unit(from: corner, to: b)
                pieces.append(.line(CGPoint(x: Double(corner.x) + back.dx * r, y: Double(corner.y) + back.dy * r)))
                pieces.append(.quad(to: CGPoint(x: Double(corner.x) + on.dx * r, y: Double(corner.y) + on.dy * r), control: corner))
            }
        }
        pieces.append(.line(points[points.count - 1]))
        return pieces
    }

    /// The drawn line as short straight pieces.
    static func flatten(_ pieces: [Piece]) -> [CGPoint] {
        var out: [CGPoint] = []
        var here = CGPoint.zero
        for piece in pieces {
            switch piece {
            case .move(let p), .line(let p):
                out.append(p)
                here = p
            case .quad(let to, let c):
                for i in 1...6 {
                    let t = Double(i) / 6, u = 1 - t
                    out.append(CGPoint(x: u * u * Double(here.x) + 2 * u * t * Double(c.x) + t * t * Double(to.x),
                                       y: u * u * Double(here.y) + 2 * u * t * Double(c.y) + t * t * Double(to.y)))
                }
                here = to
            case .curve(let to, let c1, let c2):
                for i in 1...12 {
                    let t = Double(i) / 12, u = 1 - t
                    let x = u * u * u * Double(here.x) + 3 * u * u * t * Double(c1.x) + 3 * u * t * t * Double(c2.x) + t * t * t * Double(to.x)
                    let y = u * u * u * Double(here.y) + 3 * u * u * t * Double(c1.y) + 3 * u * t * t * Double(c2.y) + t * t * t * Double(to.y)
                    out.append(CGPoint(x: x, y: y))
                }
                here = to
            }
        }
        return out
    }

    /// The three points of an arrow head: 9 long, 5.5 to each side, its tip on the item.
    static func head(tip: CGPoint, heading v: CGVector, length: Double = 9, half: Double = 5.5) -> [CGPoint] {
        let back = CGPoint(x: Double(tip.x) - v.dx * length, y: Double(tip.y) - v.dy * length)
        let n = CGVector(dx: -v.dy, dy: v.dx)
        return [CGPoint(x: Double(back.x) + n.dx * half, y: Double(back.y) + n.dy * half), tip,
                CGPoint(x: Double(back.x) - n.dx * half, y: Double(back.y) - n.dy * half)]
    }

    /// Where the words sit beside a piece of line that starts at `s` and heads the way of `d`.
    /// A level piece: above it; below when the arrow is the lower one of several on its side, or
    /// when the line then climbs. An upright piece: to its right; to the left when the arrow is
    /// the left one of several. A straight or curved line runs slanted, so there the words stand
    /// on the side the line moves away from (when it moves more than 20 to one side).
    static func words(start s: CGPoint, heading d: CGVector, end e: CGPoint, offset: Double, elbow: Bool) -> Words {
        if abs(d.dx) >= abs(d.dy) {
            let right = d.dx >= 0
            let rise = Double(s.y) - Double(e.y)
            let below: Bool
            if elbow { below = offset > 0.5 || (abs(offset) <= 0.5 && rise > 1) }
            else { below = abs(rise) > 20 ? rise > 0 : offset > 0.5 }
            return Words(at: CGPoint(x: Double(s.x) + (right ? 12 : -12), y: Double(s.y) + (below ? 4 : -4)),
                         leading: right, above: !below)
        }
        let down = d.dy >= 0
        let drift = Double(e.x) - Double(s.x)
        let left: Bool
        if elbow { left = offset < -0.5 }
        else { left = abs(drift) > 20 ? drift > 0 : offset < -0.5 }
        return Words(at: CGPoint(x: Double(s.x) + (left ? -8 : 8), y: Double(s.y) + (down ? 10 : -10)),
                     leading: !left, above: !down)
    }

    /// The words of an arrow. They stand beside its first piece, on the outside of the side it
    /// leaves — unless that piece is short (under 48) and the line turns to the very side the words
    /// would stand on; then they stand beside the first long piece after it.
    static func words(along points: [CGPoint], leaves: Direction, offset: Double, elbow: Bool) -> Words {
        guard points.count > 1, let e = points.last else { return Words(at: points.first ?? .zero, leading: true, above: true) }
        let s = points[0]
        let found = words(start: s, heading: leaves.out, end: elbow ? e : points[1], offset: offset, elbow: elbow)
        guard points.count > 2, length(s, points[1]) < 48 else { return found }
        let intoWords = leaves.isSideways ? (points[2].y > points[1].y) == !found.above : (points[2].x > points[1].x) == found.leading
        guard intoWords else { return found }
        for i in 1..<(points.count - 1) where length(points[i], points[i + 1]) >= 48 {
            return words(start: points[i], heading: unit(from: points[i], to: points[i + 1]), end: e, offset: 0, elbow: elbow)
        }
        return found
    }

    // MARK: Right-angle lines

    /// Where the line of a side lies (x for the left and right side, y for the top and bottom).
    static func edge(_ r: CGRect, _ d: Direction) -> Double {
        switch d {
        case .right: return Double(r.maxX)
        case .left: return Double(r.minX)
        case .down: return Double(r.maxY)
        case .up: return Double(r.minY)
        }
    }

    /// The point straight out of a side, `m` away from the item's box.
    private static func stub(_ p: CGPoint, _ end: End, _ m: Double) -> CGPoint {
        switch end.side {
        case .right: return CGPoint(x: Double(end.rect.maxX) + m, y: Double(p.y))
        case .left: return CGPoint(x: Double(end.rect.minX) - m, y: Double(p.y))
        case .down: return CGPoint(x: Double(p.x), y: Double(end.rect.maxY) + m)
        case .up: return CGPoint(x: Double(p.x), y: Double(end.rect.minY) - m)
        }
    }

    /// Tidies a right-angle line: points that repeat and points in the middle of a straight run go.
    /// nil when a piece is slanted or the line turns back on itself.
    static func squared(_ raw: [CGPoint]) -> [CGPoint]? {
        var out: [CGPoint] = []
        for p in raw {
            if let last = out.last, abs(last.x - p.x) < 0.01, abs(last.y - p.y) < 0.01 { continue }
            out.append(p)
        }
        var i = 1
        while i < out.count - 1 {
            let a = out[i - 1], b = out[i], c = out[i + 1]
            let level = abs(a.y - b.y) < 0.01 && abs(b.y - c.y) < 0.01
            let upright = abs(a.x - b.x) < 0.01 && abs(b.x - c.x) < 0.01
            if level {
                if (b.x - a.x) * (c.x - b.x) < 0 { return nil }
                out.remove(at: i)
            } else if upright {
                if (b.y - a.y) * (c.y - b.y) < 0 { return nil }
                out.remove(at: i)
            } else {
                i += 1
            }
        }
        guard out.count > 1 else { return nil }
        for n in 1..<out.count where abs(out[n].x - out[n - 1].x) >= 0.01 && abs(out[n].y - out[n - 1].y) >= 0.01 { return nil }
        return out
    }

    private static func cost(_ path: [CGPoint]) -> Double {
        var sum = 0.0
        for i in 1..<path.count { sum += length(path[i - 1], path[i]) }
        return sum + 24 * Double(path.count - 2)
    }

    /// True when the line touches neither a shape in its way nor (beyond its first and last piece)
    /// the two items it joins.
    private static func clear(_ path: [CGPoint], _ a: CGRect, _ b: CGRect, _ blocks: [CGRect]) -> Bool {
        let n = path.count - 1
        guard n >= 1 else { return false }
        let ownA = a.insetBy(dx: 1, dy: 1), ownB = b.insetBy(dx: 1, dy: 1)
        for i in 0..<n {
            let p = path[i], q = path[i + 1]
            if i > 0, crosses(p, q, ownA) { return false }
            if i < n - 1, crosses(p, q, ownB) { return false }
            for r in blocks where crosses(p, q, r) { return false }
        }
        return true
    }

    private static func blocked(_ path: [CGPoint], by blocks: [CGRect]) -> Bool {
        guard path.count > 1 else { return false }
        for i in 1..<path.count {
            for r in blocks where crosses(path[i - 1], path[i], r) { return true }
        }
        return false
    }

    private static func add(_ value: Double, to list: inout [Double]) {
        if !list.contains(where: { abs($0 - value) < 0.5 }) { list.append(value) }
    }

    /// The simple ways from one stub to the other: straight on, two corners in one channel, one corner.
    private static func simpleWays(_ s1: CGPoint, _ e1: CGPoint, _ xs: [Double], _ ys: [Double]) -> [[CGPoint]] {
        var list: [[CGPoint]] = [[]]
        for x in xs { list.append([CGPoint(x: x, y: Double(s1.y)), CGPoint(x: x, y: Double(e1.y))]) }
        for y in ys { list.append([CGPoint(x: Double(s1.x), y: y), CGPoint(x: Double(e1.x), y: y)]) }
        list.append([CGPoint(x: e1.x, y: s1.y)])
        list.append([CGPoint(x: s1.x, y: e1.y)])
        return list
    }

    /// The longer ways: three corners in two channels.
    private static func longWays(_ s1: CGPoint, _ e1: CGPoint, _ xs: [Double], _ ys: [Double]) -> [[CGPoint]] {
        var list: [[CGPoint]] = []
        for x in xs {
            for y in ys {
                list.append([CGPoint(x: x, y: Double(s1.y)), CGPoint(x: x, y: y), CGPoint(x: Double(e1.x), y: y)])
                list.append([CGPoint(x: Double(s1.x), y: y), CGPoint(x: x, y: y), CGPoint(x: x, y: Double(e1.y))])
            }
        }
        return list
    }

    /// The corners of a right-angle arrow. Without anything in its way it runs as in 0.1 (straight
    /// when the ends line up, else one bend half way); a shape in its way is passed 12 points off.
    /// When no way round is found the plain line is kept.
    static func elbow(from a: End, to b: End, obstacles: [CGRect] = []) -> (points: [CGPoint], detour: Bool) {
        let s = anchor(on: a.rect, kind: a.kind, side: a.side, offset: a.offset)
        let e = anchor(on: b.rect, kind: b.kind, side: b.side, offset: b.offset)
        var outA = reach, outB = reach
        var xs: [Double] = [], ys: [Double] = []
        var direct: [[CGPoint]] = []
        var facing = false
        if a.side == b.side.opposite {
            // The two sides face each other: the bend lies half way between them. Arrows that
            // run side by side bend one after the other, so they never share a piece.
            let sign: Double = (a.side == .right || a.side == .down) ? 1 : -1
            let from = edge(a.rect, a.side)
            let dist = (edge(b.rect, b.side) - from) * sign
            if dist > 0 {
                facing = true
                let cross = a.side.isSideways ? Double(e.y - s.y) : Double(e.x - s.x)
                if abs(cross) < 1 { direct.append([s, e]) }
                let least = min(8, dist / 2)
                let turn: Double = cross > 0 ? 1 : -1
                let bend = max(least, min(dist - least, dist / 2 - (a.offset + b.offset) / 2 * turn))
                outA = min(reach, bend)
                outB = min(reach, dist - bend)
                if a.side.isSideways { xs.append(from + sign * bend) } else { ys.append(from + sign * bend) }
            }
        }
        let s1 = stub(s, a, outA), e1 = stub(e, b, outB)
        if xs.isEmpty { xs.append(Double(s1.x + e1.x) / 2) }
        if ys.isEmpty { ys.append(Double(s1.y + e1.y) / 2) }
        let ra = a.rect, rb = b.rect
        if ra.maxX < rb.minX { add(Double(ra.maxX + rb.minX) / 2, to: &xs) } else if rb.maxX < ra.minX { add(Double(rb.maxX + ra.minX) / 2, to: &xs) }
        if ra.maxY < rb.minY { add(Double(ra.maxY + rb.minY) / 2, to: &ys) } else if rb.maxY < ra.minY { add(Double(rb.maxY + ra.minY) / 2, to: &ys) }
        add(Double(min(ra.minX, rb.minX)) - reach, to: &xs)
        add(Double(max(ra.maxX, rb.maxX)) + reach, to: &xs)
        add(Double(min(ra.minY, rb.minY)) - reach, to: &ys)
        add(Double(max(ra.maxY, rb.maxY)) + reach, to: &ys)

        /// The shortest of these ways (a corner counts as 24 points) that touches nothing.
        /// The simple ways are tried first: a line with fewer corners is easier to follow.
        func best(_ xs: [Double], _ ys: [Double], near: [CGRect], all: [CGRect]) -> [CGPoint]? {
            for tier in 0..<2 {
                var found: [(cost: Double, path: [CGPoint])] = tier == 0 ? direct.map { (cost: cost($0), path: $0) } : []
                for mids in tier == 0 ? simpleWays(s1, e1, xs, ys) : longWays(s1, e1, xs, ys) {
                    if let path = squared([s, s1] + mids + [e1, e]) { found.append((cost(path), path)) }
                }
                let order = found.indices.sorted { (found[$0].cost, $0) < (found[$1].cost, $1) }
                for i in order where clear(found[i].path, ra, rb, near) && !blocked(found[i].path, by: all) {
                    return found[i].path
                }
            }
            return nil
        }

        // The line as it runs with nothing in its way. Two sides that face each other (nearly every
        // arrow) need no search: straight, or one bend. When nothing can be drawn at all, the line of 0.1.
        var plain: [CGPoint] = []
        if let straight = direct.first {
            plain = straight
        } else if facing, let bent = squared([s, s1, a.side.isSideways ? CGPoint(x: xs[0], y: Double(s1.y)) : CGPoint(x: Double(s1.x), y: ys[0]),
                                              a.side.isSideways ? CGPoint(x: xs[0], y: Double(e1.y)) : CGPoint(x: Double(e1.x), y: ys[0]), e1, e]),
                  clear(bent, ra, rb, []) {
            plain = bent
        }
        if plain.isEmpty {
            if let found = best(xs, ys, near: [], all: []) {
                plain = found
            } else if a.side.isSideways {
                let mid = Double(s.x + e.x) / 2
                plain = abs(s.y - e.y) < 1 ? [s, e] : [s, CGPoint(x: mid, y: Double(s.y)), CGPoint(x: mid, y: Double(e.y)), e]
            } else {
                let mid = Double(s.y + e.y) / 2
                plain = abs(s.x - e.x) < 1 ? [s, e] : [s, CGPoint(x: Double(s.x), y: mid), CGPoint(x: Double(e.x), y: mid), e]
            }
        }
        let grown = obstacles.map { $0.insetBy(dx: -2, dy: -2) }
        guard blocked(plain, by: grown) else { return (plain, false) }

        // Round the shapes in the way: channels 12 points off their edges. Only the six nearest
        // are tried, so a crowded board stays fast.
        var region = ra.union(rb)
        for p in plain { region = region.union(CGRect(x: p.x, y: p.y, width: 0, height: 0)) }
        region = region.insetBy(dx: -60, dy: -60)
        let middle = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
        let near = obstacles.filter { $0.intersects(region) }
            .sorted { length(CGPoint(x: $0.midX, y: $0.midY), middle) < length(CGPoint(x: $1.midX, y: $1.midY), middle) }
            .prefix(6)
        for r in near {
            add(Double(r.minX) - clearance, to: &xs)
            add(Double(r.maxX) + clearance, to: &xs)
            add(Double(r.minY) - clearance, to: &ys)
            add(Double(r.maxY) + clearance, to: &ys)
        }
        if let round = best(xs, ys, near: near.map { $0.insetBy(dx: -2, dy: -2) }, all: grown) {
            return (round, true)
        }
        return (plain, false)
    }

    // MARK: Straight and curved lines

    /// A straight or curved line whose way is blocked goes round the shape in its way, 12 points off:
    /// past one corner when that keeps it 6 points clear of everything, else along one side
    /// (two corners), else past one corner however close. Empty: nothing in the way, or no way round.
    static func wayRound(_ s: CGPoint, _ e: CGPoint, _ obstacles: [CGRect]) -> [CGPoint] {
        let blockers = obstacles.filter { crosses(s, e, $0.insetBy(dx: -2, dy: -2)) }
        guard !blockers.isEmpty else { return [] }
        func free(_ path: [CGPoint], _ margin: Double) -> Bool {
            !blocked(path, by: obstacles.map { $0.insetBy(dx: -margin, dy: -margin) })
        }
        var corners: [[CGPoint]] = []
        var sides: [[CGPoint]] = []
        for r in blockers.prefix(4) {
            let g = r.insetBy(dx: -clearance, dy: -clearance)
            let ring = [CGPoint(x: g.minX, y: g.minY), CGPoint(x: g.maxX, y: g.minY),
                        CGPoint(x: g.maxX, y: g.maxY), CGPoint(x: g.minX, y: g.maxY)]
            for (i, p) in ring.enumerated() {
                corners.append([p])
                let q = ring[(i + 1) % 4]
                sides.append(length(s, p) <= length(s, q) ? [p, q] : [q, p])
            }
        }
        for (list, margin) in [(corners, 6.0), (sides, 6.0), (corners, 2.0)] {
            var best: (length: Double, via: [CGPoint])?
            for via in list {
                let path = [s] + via + [e]
                var way = 0.0
                for i in 1..<path.count { way += length(path[i - 1], path[i]) }
                if let best, best.length <= way { continue }
                if free(path, margin) { best = (way, via) }
            }
            if let best { return best.via }
        }
        return []
    }

    /// The two pull points of a curved arrow: each end leaves its side straight out.
    private static func pulls(_ s: CGPoint, _ leaves: Direction, _ e: CGPoint, _ arrives: Direction) -> (CGPoint, CGPoint) {
        let so = leaves.out, eo = arrives.out
        let ahead = Double(e.x - s.x) * so.dx + Double(e.y - s.y) * so.dy
        let back = Double(s.x - e.x) * eo.dx + Double(s.y - e.y) * eo.dy
        var k1 = ahead / 2, k2 = back / 2
        // Sides that do not face each other: the curve still leaves each side clearly.
        if !(leaves == arrives.opposite && ahead > 0) {
            k1 = max(k1, 40)
            k2 = max(k2, 40)
        }
        return (CGPoint(x: Double(s.x) + so.dx * k1, y: Double(s.y) + so.dy * k1),
                CGPoint(x: Double(e.x) + eo.dx * k2, y: Double(e.y) + eo.dy * k2))
    }

    // MARK: One arrow

    /// One arrow between two ends, in the given style, round the shapes in its way.
    static func arrow(from a: End, to b: End, style: LinkStyle, obstacles: [CGRect] = []) -> Arrow {
        let s = anchor(on: a.rect, kind: a.kind, side: a.side, offset: a.offset)
        let e = anchor(on: b.rect, kind: b.kind, side: b.side, offset: b.offset)
        var points: [CGPoint]
        var pieces: [Piece]
        var detour = false
        // The points next to the two ends on the drawn line: they give the heads their direction.
        var afterStart: CGPoint
        var beforeEnd: CGPoint
        switch style {
        case .elbow:
            let found = elbow(from: a, to: b, obstacles: obstacles)
            points = found.points
            detour = found.detour
            pieces = rounded(points)
            afterStart = points[1]
            beforeEnd = points[points.count - 2]
        case .straight:
            let via = wayRound(s, e, obstacles)
            points = [s] + via + [e]
            detour = !via.isEmpty
            pieces = rounded(points)
            afterStart = points[1]
            beforeEnd = points[points.count - 2]
        case .curve:
            let pull = pulls(s, a.side, e, b.side)
            let sweep: [Piece] = [.move(s), .curve(to: e, control1: pull.0, control2: pull.1)]
            if blocked(flatten(sweep), by: obstacles.map { $0.insetBy(dx: -2, dy: -2) }) {
                // Something stands in the curve's way: it becomes a line with wide, soft corners
                // round the shape (or a plain straight line, when that is free).
                let via = wayRound(s, e, obstacles)
                points = [s] + via + [e]
                detour = true
                pieces = rounded(points, radius: 24)
                afterStart = points[1]
                beforeEnd = points[points.count - 2]
            } else {
                points = [s, e]
                pieces = sweep
                afterStart = pull.0
                beforeEnd = pull.1
            }
        }
        if length(s, afterStart) < 0.01 { afterStart = e }
        if length(e, beforeEnd) < 0.01 { beforeEnd = s }
        let away = unit(from: s, to: afterStart)
        var label = words(along: points, leaves: a.side, offset: a.offset, elbow: style == .elbow)
        if style == .straight, abs(a.offset) > 0.5 {
            // A slanted line that shares its side: where its words keep clear of the line they would
            // touch the neighbour, so they stand 28 further along the line.
            let towardsNeighbour = a.side.isSideways ? label.above == (a.offset > 0) : label.leading == (a.offset < 0)
            if towardsNeighbour {
                let along = unit(from: s, to: points[1])
                label.at = CGPoint(x: Double(label.at.x) + along.dx * 28, y: Double(label.at.y) + along.dy * 28)
            }
        }
        return Arrow(points: points, leaves: a.side, arrives: b.side, pieces: pieces, outline: flatten(pieces),
                     words: label,
                     startHeading: CGVector(dx: -away.dx, dy: -away.dy), endHeading: unit(from: beforeEnd, to: e),
                     detour: detour)
    }
}

// MARK: The whole board

public extension Board {
    /// Where every arrow of the board runs. Arrows with an end that is missing or folded away are left out.
    func arrows() -> [UUID: Route.Arrow] {
        guard !links.isEmpty else { return [:] }
        var byID: [UUID: Item] = [:]
        for item in items where byID[item.id] == nil { byID[item.id] = item }
        func seen(_ item: Item) -> Bool { item.kind != .idea || item.parent == nil || !isHidden(item.id) }

        struct Wire {
            let link: Link
            let a: Item
            let b: Item
            let leaves: Direction
            let arrives: Direction
            var startOffset = 0.0
            var endOffset = 0.0
        }
        /// The middles of two sides that face each other line up: the arrow is one straight piece.
        func runsStraight(_ w: Wire) -> Bool {
            guard w.leaves == w.arrives.opposite else { return false }
            let sign: Double = (w.leaves == .right || w.leaves == .down) ? 1 : -1
            guard (Route.edge(w.b.frame, w.arrives) - Route.edge(w.a.frame, w.leaves)) * sign > 0 else { return false }
            return abs(Double(w.leaves.isSideways ? w.b.centre.y - w.a.centre.y : w.b.centre.x - w.a.centre.x)) < 1
        }
        var wires: [Wire] = []
        for link in links {
            guard link.from != link.to, let a = byID[link.from], let b = byID[link.to], seen(a), seen(b) else { continue }
            let found = Route.sides(from: a.frame, to: b.frame)
            wires.append(Wire(link: link, a: a, b: b, leaves: link.fromSide ?? found.leaves, arrives: link.toSide ?? found.arrives))
        }

        // Arrows that share a side of an item stand apart, in the order of where they go to,
        // so they do not cross. There-and-back between two items gives two lines side by side.
        struct Slot: Hashable {
            let item: UUID
            let side: Direction
        }
        struct Place {
            let wire: Int
            let start: Bool
            let key: Double
        }
        var slots: [Slot: [Place]] = [:]
        for (i, w) in wires.enumerated() {
            slots[Slot(item: w.a.id, side: w.leaves), default: []]
                .append(Place(wire: i, start: true, key: Double(w.leaves.isSideways ? w.b.centre.y : w.b.centre.x)))
            slots[Slot(item: w.b.id, side: w.arrives), default: []]
                .append(Place(wire: i, start: false, key: Double(w.arrives.isSideways ? w.a.centre.y : w.a.centre.x)))
        }
        for (slot, list) in slots where list.count > 1 {
            guard let item = byID[slot.item] else { continue }
            let sorted = list.sorted { ($0.key, $0.wire) < ($1.key, $1.wire) }
            let room = Route.room(on: item.frame, kind: item.kind, side: slot.side)
            var offsets = Route.offsets(count: sorted.count, room: room)
            // One arrow that runs dead straight keeps the middle of the side (and the tip of a diamond);
            // the others stand beside it.
            let straight = sorted.indices.filter { runsStraight(wires[sorted[$0].wire]) }
            if straight.count == 1 {
                let k = straight[0]
                let step = min(Route.spread, room / 2 / Double(max(k, sorted.count - 1 - k)))
                offsets = sorted.indices.map { Double($0 - k) * step }
            }
            for (n, place) in sorted.enumerated() {
                if place.start { wires[place.wire].startOffset = offsets[n] } else { wires[place.wire].endOffset = offsets[n] }
            }
        }

        // An arrow that is alone on a straight side slides along it to meet its other end, which had
        // to make room for others: the line stays straight instead of making a small step.
        for i in wires.indices {
            let w = wires[i]
            guard w.leaves == w.arrives.opposite else { continue }
            let startAlone = slots[Slot(item: w.a.id, side: w.leaves)]?.count == 1
            let endAlone = slots[Slot(item: w.b.id, side: w.arrives)]?.count == 1
            guard startAlone != endAlone else { continue }
            let free = startAlone ? w.a : w.b
            guard free.kind != .diamond, free.kind != .oval else { continue }
            let ca = Double(w.leaves.isSideways ? w.a.centre.y : w.a.centre.x)
            let cb = Double(w.leaves.isSideways ? w.b.centre.y : w.b.centre.x)
            let need = startAlone ? cb + w.endOffset - ca : ca + w.startOffset - cb
            guard abs(need) <= Route.room(on: free.frame, kind: free.kind, side: startAlone ? w.leaves : w.arrives) / 2 else { continue }
            if startAlone { wires[i].startOffset = need } else { wires[i].endOffset = need }
        }

        // What an arrow goes round: shapes, sticky notes and ideas. Free text and frames are passed over.
        let blocks: [(id: UUID, rect: CGRect)] = items
            .filter { ($0.kind.isShape || $0.kind == .note || $0.kind == .idea) && seen($0) }
            .map { ($0.id, $0.frame) }
        var all: [UUID: Route.Arrow] = [:]
        for w in wires {
            let ra = w.a.frame, rb = w.b.frame
            let region = ra.union(rb).insetBy(dx: -400, dy: -400)
            var obstacles: [CGRect] = []
            for block in blocks where block.rect.intersects(region) && block.id != w.a.id && block.id != w.b.id {
                // Something that lies on one of the two ends is not in the way: there is no way round it.
                if !block.rect.intersects(ra), !block.rect.intersects(rb) { obstacles.append(block.rect) }
            }
            all[w.link.id] = Route.arrow(from: Route.End(rect: ra, kind: w.a.kind, side: w.leaves, offset: w.startOffset),
                                         to: Route.End(rect: rb, kind: w.b.kind, side: w.arrives, offset: w.endOffset),
                                         style: w.link.style, obstacles: obstacles)
        }
        return all
    }

    /// Where one arrow runs.
    func arrow(_ id: UUID) -> Route.Arrow? { arrows()[id] }
}
