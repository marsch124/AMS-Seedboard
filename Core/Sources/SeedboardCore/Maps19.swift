import Foundation
import CoreGraphics

// 0.19 (lane "maps"): bent arrows, tapered branch lines, mind map looks, numbered branches, a branch to the other
// side, and the rule for the words "Grow ideas from this" offers. Plain geometry and rules; no screen.

// MARK: Bent arrows (pick 13)

public extension Route {
    /// A bend smaller than this (points, either way) counts as none: the arrow is straight again.
    static let bendLeast = 4.0
    /// How near (points) a press must be to the middle knob of a chosen arrow to take it.
    static let knobReach = 13.0

    /// A smooth curve from `s` through `m` to `e`: two cubic pieces that meet at `m` with the same direction
    /// (the line there runs parallel to the line from `s` to `e`).
    static func bentPieces(from s: CGPoint, through m: CGPoint, to e: CGPoint) -> [Piece] {
        let tx = Double(e.x - s.x) / 5, ty = Double(e.y - s.y) / 5
        func at(_ a: CGPoint, _ b: CGPoint, _ f: Double) -> CGPoint {
            CGPoint(x: Double(a.x) + Double(b.x - a.x) * f, y: Double(a.y) + Double(b.y - a.y) * f)
        }
        return [.move(s),
                .curve(to: m, control1: at(s, m, 1.0 / 3), control2: CGPoint(x: Double(m.x) - tx, y: Double(m.y) - ty)),
                .curve(to: e, control1: CGPoint(x: Double(m.x) + tx, y: Double(m.y) + ty), control2: at(e, m, 1.0 / 3))]
    }

    /// The arrow, bent so that it runs through the plain line's middle moved by `bend` ([dx, dy]).
    /// Unchanged when there is no bend (or one under `bendLeast`).
    static func bent(_ arrow: Arrow, by bend: [Double]?) -> Arrow {
        guard let bend, bend.count == 2, hypot(bend[0], bend[1]) >= bendLeast,
              arrow.points.count >= 2, let s = arrow.points.first, let e = arrow.points.last else { return arrow }
        let plain = arrow.middle
        let m = CGPoint(x: Double(plain.x) + bend[0], y: Double(plain.y) + bend[1])
        let pieces = bentPieces(from: s, through: m, to: e)
        var out = arrow
        out.points = [s, m, e]
        out.pieces = pieces
        out.outline = flatten(pieces)
        out.plainMiddle = plain
        out.through = m
        out.detour = false
        if case .curve(_, let c1, _) = pieces[1], case .curve(_, _, let c4) = pieces[2] {
            let away = unit(from: s, to: c1), into = unit(from: c4, to: e)
            out.startHeading = CGVector(dx: -away.dx, dy: -away.dy)
            out.endHeading = into
        }
        return out
    }

    /// The bend that makes an arrow run through `knob`, given the plain line's middle. nil: straight (under `bendLeast`).
    static func bend(toReach knob: CGPoint, plainMiddle plain: CGPoint) -> [Double]? {
        let dx = Double(knob.x - plain.x), dy = Double(knob.y - plain.y)
        guard hypot(dx, dy) >= bendLeast else { return nil }
        return [max(-5000, min(5000, dx)), max(-5000, min(5000, dy))]
    }

    /// True when a press at `p` takes the knob (the distance is counted in board points; `reach` is already scaled).
    static func takesKnob(_ p: CGPoint, knob: CGPoint, reach: Double = knobReach) -> Bool {
        Double(hypot(p.x - knob.x, p.y - knob.y)) <= reach
    }
}

public extension Route.Arrow {
    /// The point the owner drags to bend the arrow: the middle of the line, or where a bent line runs through.
    var knob: CGPoint { through ?? middle }
    /// A bent arrow can be made straight again.
    var isBent: Bool { through != nil }
}

public extension Board {
    /// The chosen arrow's knob under the point (nil when that arrow has none there).
    func knobHit(of linkID: UUID, at p: CGPoint, reach: Double) -> Bool {
        guard let arrow = arrow(linkID), arrow.outline.count > 1 else { return false }
        return Route.takesKnob(p, knob: arrow.knob, reach: reach)
    }

    /// The arrow is bent so that it runs through `knob`; near the plain line it becomes straight. False when nothing changed.
    @discardableResult
    mutating func bendLink(_ id: UUID, to knob: CGPoint) -> Bool {
        guard let l = links.firstIndex(where: { $0.id == id }), let arrow = arrow(id) else { return false }
        let wanted = Route.bend(toReach: knob, plainMiddle: arrow.plainMiddle ?? arrow.middle)
        guard links[l].bend != wanted else { return false }
        links[l].bend = wanted
        return true
    }

    /// "Straighten": the arrow runs as the plain line again. False when it was not bent.
    @discardableResult
    mutating func straightenLink(_ id: UUID) -> Bool {
        guard let l = links.firstIndex(where: { $0.id == id }), links[l].bend != nil else { return false }
        links[l].bend = nil
        return true
    }
}

// MARK: Branch lines thick near the middle (pick 20)

public extension Route {
    /// How thick the line TO an idea of this depth is at its two ends: near the middle idea and at the far end
    /// (the end of the idea's underline). A main branch runs 5 to 3.4; the second level takes up where that ends
    /// (3.4 to 2.4), the third 2.4 to 1.8, deeper ones stay 1.8. The far ends are `branchWeight`.
    static func branchTaper(depth: Int) -> (near: Double, far: Double) {
        let far = branchWeight(depth: depth)
        let near = depth <= 1 ? 5.0 : branchWeight(depth: depth - 1)
        return (near, far)
    }

    /// A branch line as short straight pieces: a smooth curve from the parent to the child's foot (`curves`), or a
    /// straight line (`lines`), and on under the child's words.
    static func branchPoints(_ line: (start: CGPoint, near: CGPoint, end: CGPoint), look: MapLook) -> [CGPoint] {
        var points: [CGPoint] = [line.start]
        if look == .curves {
            let midX = Double(line.start.x + line.near.x) / 2
            let steps = 14
            for i in 1...steps {
                let t = Double(i) / Double(steps), u = 1 - t
                let x = u * u * u * Double(line.start.x) + 3 * u * u * t * midX + 3 * u * t * t * midX + t * t * t * Double(line.near.x)
                let y = u * u * u * Double(line.start.y) + 3 * u * u * t * Double(line.start.y) + 3 * u * t * t * Double(line.near.y)
                    + t * t * t * Double(line.near.y)
                points.append(CGPoint(x: x, y: y))
            }
        } else {
            points.append(line.near)
        }
        points.append(line.end)
        return points
    }

    /// The outline of a line whose width runs from `near` to `far` along its length: the points along one side,
    /// then back along the other. Round ends are drawn by the caller.
    static func taperedOutline(_ points: [CGPoint], near: Double, far: Double) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        var lengths: [Double] = [0]
        for i in 1..<points.count { lengths.append(lengths[i - 1] + Double(hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))) }
        let total = max(lengths[lengths.count - 1], 0.001)
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in points.indices {
            let a = points[max(0, i - 1)], b = points[min(points.count - 1, i + 1)]
            let d = hypot(Double(b.x - a.x), Double(b.y - a.y))
            let nx = d > 0 ? -Double(b.y - a.y) / d : 0, ny = d > 0 ? Double(b.x - a.x) / d : 1
            let w = (near + (far - near) * lengths[i] / total) / 2
            left.append(CGPoint(x: Double(points[i].x) + nx * w, y: Double(points[i].y) + ny * w))
            right.append(CGPoint(x: Double(points[i].x) - nx * w, y: Double(points[i].y) - ny * w))
        }
        return left + right.reversed()
    }

    /// The line of an idea in the `boxes` look: out of the middle of the parent's side, across, up or down, and into
    /// the middle of the child's near side, with right-angle corners.
    static func boxLine(from parent: CGRect, to child: CGRect, side: Side) -> [CGPoint] {
        let right = side == .right
        let s = CGPoint(x: right ? parent.maxX : parent.minX, y: parent.midY)
        let e = CGPoint(x: right ? child.minX : child.maxX, y: child.midY)
        if abs(Double(s.y - e.y)) < 0.5 { return [s, e] }
        let mid = (s.x + e.x) / 2
        return [s, CGPoint(x: mid, y: s.y), CGPoint(x: mid, y: e.y), e]
    }
}

// MARK: The look of a mind map (pick 24)

/// How a mind map is drawn. Stored as the board's `mapLook`; nothing stored means `curves` (what 0.18 drew).
public enum MapLook: String, CaseIterable, Sendable {
    case lines, curves, boxes

    public var word: String {
        switch self {
        case .lines: return "Lines"
        case .curves: return "Curves"
        case .boxes: return "Boxes"
        }
    }
}

public extension Board {
    /// The look of the board's mind maps (nothing stored: curves).
    var look: MapLook { mapLook.flatMap(MapLook.init(rawValue:)) ?? .curves }

    /// Sets the look. Curves, the look of before, is kept as "nothing stored" so old boards stay as they were.
    /// False when it is the look already.
    @discardableResult
    mutating func setMapLook(_ new: MapLook) -> Bool {
        guard new != look else { return false }
        mapLook = new == .curves ? nil : new.rawValue
        return true
    }
}

// MARK: Numbered branches (pick 21)

public extension Board {
    /// The number of each main branch that can be seen, per map in reading order: the right side from top to
    /// bottom, then the left side from top to bottom. Empty unless the board numbers its branches.
    func branchNumbers() -> [UUID: Int] {
        guard numberBranches == true, !placesItself else { return [:] }
        var out: [UUID: Int] = [:]
        for centre in mapCentres where !centre.folded {
            let sides = MindMap.sides(of: children(of: centre.id), bothSides: centre.bothSides)
            let list = Array(zip(children(of: centre.id), sides))
            func top(_ a: Item, _ b: Item) -> Bool { (a.y, a.x, a.id.uuidString) < (b.y, b.x, b.id.uuidString) }
            let ordered = list.filter { $0.1 != .left }.map(\.0).sorted(by: top) + list.filter { $0.1 == .left }.map(\.0).sorted(by: top)
            for (n, branch) in ordered.enumerated() { out[branch.id] = n + 1 }
        }
        return out
    }

    /// The words of a main branch with its number in front ("2. Food") — for the text that leaves the app.
    func numberedWords(of id: UUID, in numbers: [UUID: Int]) -> String {
        let words = item(id)?.text ?? ""
        guard let n = numbers[id] else { return words }
        return "\(n). \(words)"
    }
}

// MARK: A branch to the other side (pick 22)

public extension Board {
    /// A main branch of a map that has both sides can go to the other one.
    func canMoveToOtherSide(_ id: UUID) -> Bool {
        guard let me = item(id), me.kind == .idea, let parentID = me.parent, let parent = item(parentID) else { return false }
        return parent.kind == .idea && parent.parent == nil && parent.bothSides
    }

    /// The branch (with everything under it) goes to the other side and stands last there.
    @discardableResult
    mutating func moveToOtherSide(_ id: UUID) -> Bool {
        guard canMoveToOtherSide(id), let parentID = item(id)?.parent, let i = index(of: id) else { return false }
        settleSides(of: parentID)
        let now = side(of: id)
        items[i].side = now == .right ? .left : .right
        items[i].order = (children(of: parentID).map(\.order).max() ?? 0) + 1
        return true
    }
}

// MARK: Grow ideas from this (pick 25)

public enum GrowIdeas {
    /// Most words offered at once.
    public static let most = 3
    /// The longest a suggested idea may be.
    public static let longest = 40

    /// One word or short phrase, tidied: bullets, numbers, quotes and the dots at the end go; spaces are trimmed.
    public static func tidy(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = s.first, "-•*–—·".contains(first) || first.isNumber && s.dropFirst().first.map({ ".):".contains($0) }) == true {
            s = String(s.dropFirst(first.isNumber ? 2 : 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’«»`*_.,;:!"))
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func key(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The words to offer: trimmed, no doubles (capitals and accents do not count), not the idea's own words, not a
    /// word that already hangs under it, nothing empty or too long, at most three. The order stays.
    public static func clean(_ suggestions: [String], idea: String, children: [String]) -> [String] {
        var taken = Set(([idea] + children).map(key))
        var out: [String] = []
        for raw in suggestions {
            let word = tidy(raw)
            guard !word.isEmpty, word.count <= longest, taken.insert(key(word)).inserted else { continue }
            out.append(word)
            if out.count == most { break }
        }
        return out
    }
}

public extension Board {
    /// The words of the ideas hanging directly under this one.
    func childWords(of id: UUID) -> [String] { children(of: id).map(\.text) }

    /// Each word becomes a new idea under this one, last. The new ideas' ids, in order.
    @discardableResult
    mutating func addIdeas(_ words: [String], under id: UUID) -> [UUID] {
        words.compactMap { addChild(of: id, text: $0) }
    }
}
