import Foundation
import CoreGraphics

// Falling in line. While a thing is dragged, sized or pulled out of a plus, it catches the
// left / middle / right and top / middle / bottom of its neighbours, and the place where the
// gap to its neighbours is the same as the gap between them. The nearest catch wins; sideways
// and up-down are worked out by themselves. Nothing here knows about the screen: the catch
// distance comes in board points (6 screen points divided by the zoom).

public enum Snap {
    /// The direction a catch corrected: `.across` moved the thing sideways, `.down` up or down.
    public enum Axis: Sendable { case across, down }

    /// A line to show while a catch holds.
    public struct Guide: Equatable, Sendable {
        public enum Kind: Sendable {
            /// A line through the edges or middles that are in line.
            case line
            /// A mark across one of the gaps that are the same.
            case gap
        }
        public var kind: Kind
        public var axis: Axis
        public var from: CGPoint
        public var to: CGPoint

        public init(kind: Kind, axis: Axis, from: CGPoint, to: CGPoint) {
            self.kind = kind
            self.axis = axis
            self.from = from
            self.to = to
        }
    }

    /// Something a moved thing can fall in line with.
    public struct Target: Equatable, Sendable {
        public var rect: CGRect
        /// A frame: caught by its edges only — not by its middle, and not as a neighbour for equal gaps.
        public var edgesOnly: Bool

        public init(_ rect: CGRect, edgesOnly: Bool = false) {
            self.rect = rect
            self.edgesOnly = edgesOnly
        }
    }

    public struct Move: Equatable, Sendable {
        /// The move, corrected.
        public var delta: CGSize
        public var guides: [Guide]
    }

    public struct Size: Equatable, Sendable {
        /// The new size, corrected.
        public var rect: CGRect
        public var guides: [Guide]
    }

    /// Two numbers are "the same" when they differ by less than this.
    static let same: CGFloat = 0.01

    // MARK: Moving

    /// The things in `moving` are being moved by `delta`. Returns the move corrected so that the box
    /// round them falls in line with the nearest target within `reach`, and the guide lines to show.
    /// - `middles`: false when a frame is among the moved things (frames catch by their edges only).
    /// - `favour`: a rect whose middle wins over every other catch (the shape a new one is pulled from,
    ///   so the arrow between them is one straight piece).
    public static func move(_ moving: [CGRect], by delta: CGSize, targets: [Target], reach: CGFloat,
                            middles: Bool = true, favour: CGRect? = nil) -> Move {
        guard reach > 0, let first = moving.first else { return Move(delta: delta, guides: []) }
        let start = moving.dropFirst().reduce(first) { $0.union($1) }
        let box = start.offsetBy(dx: delta.width, dy: delta.height)

        let dx = shift(.across, box, targets, reach, middles, favour)
        let dy = shift(.down, box, targets, reach, middles, favour)
        let landed = box.offsetBy(dx: dx ?? 0, dy: dy ?? 0)

        var guides: [Guide] = []
        if dx != nil { guides += lines(.across, landed, targets, middles, favour) + gaps(.across, landed, targets) }
        if dy != nil { guides += lines(.down, landed, targets, middles, favour) + gaps(.down, landed, targets) }
        return Move(delta: CGSize(width: delta.width + (dx ?? 0), height: delta.height + (dy ?? 0)), guides: guides)
    }

    // MARK: Sizing

    /// A thing is being sized from `old` to `rect`. Every edge that moved catches the edges of the
    /// targets; per direction the nearest catch wins and only that edge is corrected.
    public static func resize(_ rect: CGRect, from old: CGRect, targets: [Target], reach: CGFloat) -> Size {
        guard reach > 0 else { return Size(rect: rect, guides: []) }
        var out = rect
        var guides: [Guide] = []
        for axis in [Axis.across, .down] {
            let now = Span(rect, along: axis), was = Span(old, along: axis)
            var best: (shift: CGFloat, low: Bool)?
            for (edge, low) in [(now.lo, true), (now.hi, false)] {
                guard abs(edge - (low ? was.lo : was.hi)) > same else { continue }
                for t in targets {
                    let ts = Span(t.rect, along: axis)
                    for v in [ts.lo, ts.hi] {
                        let s = v - edge
                        if abs(s) <= reach, abs(s) < abs(best?.shift ?? .infinity) { best = (s, low) }
                    }
                }
            }
            guard let best else { continue }
            var span = Span(out, along: axis)
            if best.low { span.lo += best.shift } else { span.hi += best.shift }
            guard span.hi - span.lo > 1 else { continue }
            out = span.put(into: out, along: axis)
            let edge = best.low ? span.lo : span.hi
            var extent = Span(out, along: axis.other)
            for t in targets {
                let ts = Span(t.rect, along: axis)
                guard abs(ts.lo - edge) < same || abs(ts.hi - edge) < same else { continue }
                let side = Span(t.rect, along: axis.other)
                extent.lo = min(extent.lo, side.lo)
                extent.hi = max(extent.hi, side.hi)
            }
            guides.append(line(axis, at: edge, from: extent.lo, to: extent.hi))
        }
        return Size(rect: out, guides: guides)
    }

    // MARK: The working

    /// One side of a rect: where it starts and ends along a direction.
    struct Span {
        var lo: CGFloat
        var hi: CGFloat
        var mid: CGFloat { (lo + hi) / 2 }
        var length: CGFloat { hi - lo }

        init(lo: CGFloat, hi: CGFloat) { self.lo = lo; self.hi = hi }

        init(_ r: CGRect, along axis: Axis) {
            switch axis {
            case .across: lo = r.minX; hi = r.maxX
            case .down: lo = r.minY; hi = r.maxY
            }
        }

        func put(into r: CGRect, along axis: Axis) -> CGRect {
            switch axis {
            case .across: return CGRect(x: lo, y: r.minY, width: hi - lo, height: r.height)
            case .down: return CGRect(x: r.minX, y: lo, width: r.width, height: hi - lo)
            }
        }

        /// How much two spans lie over each other (negative when they are apart).
        func overlap(_ other: Span) -> CGFloat { min(hi, other.hi) - max(lo, other.lo) }
    }

    /// The correction along one direction, or nil when nothing is within reach.
    private static func shift(_ axis: Axis, _ box: CGRect, _ targets: [Target], _ reach: CGFloat,
                              _ middles: Bool, _ favour: CGRect?) -> CGFloat? {
        let b = Span(box, along: axis)
        if let favour {
            let s = Span(favour, along: axis).mid - b.mid
            if abs(s) <= reach { return s }
        }
        var best: CGFloat?
        func offer(_ s: CGFloat) {
            if abs(s) <= reach, abs(s) < abs(best ?? .infinity) { best = s }
        }
        for t in targets {
            let ts = Span(t.rect, along: axis)
            for edge in [b.lo, b.hi] {
                offer(ts.lo - edge)
                offer(ts.hi - edge)
            }
            if middles, !t.edgesOnly { offer(ts.mid - b.mid) }
        }
        // The same gap as the neighbours. A neighbour stands in the same row (or column): it lies
        // over the box by more than the reach, so a catch the other way cannot take it out of the row.
        let row = neighbours(axis, box, targets, least: reach)
        let before = row.filter { $0.hi <= b.mid }.sorted { $0.hi > $1.hi }
        let after = row.filter { $0.lo >= b.mid }.sorted { $0.lo < $1.lo }
        if let l = before.first, let r = after.first, r.lo - l.hi >= b.length {
            offer((l.hi + r.lo - b.length) / 2 - b.lo)
        }
        if let near = before.first, let far = before.dropFirst().first(where: { $0.hi <= near.lo }) {
            offer(near.hi + (near.lo - far.hi) - b.lo)
        }
        if let near = after.first, let far = after.dropFirst().first(where: { $0.lo >= near.hi }) {
            offer(near.lo - (far.lo - near.hi) - b.hi)
        }
        return best
    }

    /// The targets in the box's row (for `.across`) or column (for `.down`), as spans along the direction.
    private static func neighbours(_ axis: Axis, _ box: CGRect, _ targets: [Target], least: CGFloat) -> [Span] {
        let side = Span(box, along: axis.other)
        return targets.filter { !$0.edgesOnly && Span($0.rect, along: axis.other).overlap(side) > least }
            .map { Span($0.rect, along: axis) }
    }

    /// The lines through everything the landed box is in line with along one direction.
    private static func lines(_ axis: Axis, _ box: CGRect, _ targets: [Target], _ middles: Bool, _ favour: CGRect?) -> [Guide] {
        let b = Span(box, along: axis)
        let side = Span(box, along: axis.other)
        // Each line: where it is, and how far it reaches the other way.
        var found: [(at: CGFloat, reach: Span)] = []
        func add(_ at: CGFloat, _ other: Span) {
            if let i = found.firstIndex(where: { abs($0.at - at) < same }) {
                found[i].reach.lo = min(found[i].reach.lo, other.lo)
                found[i].reach.hi = max(found[i].reach.hi, other.hi)
            } else {
                found.append((at, Span(lo: min(side.lo, other.lo), hi: max(side.hi, other.hi))))
            }
        }
        if let favour, abs(Span(favour, along: axis).mid - b.mid) < same {
            add(b.mid, Span(favour, along: axis.other))
        }
        for t in targets {
            let ts = Span(t.rect, along: axis)
            let other = Span(t.rect, along: axis.other)
            for edge in [b.lo, b.hi] {
                if abs(ts.lo - edge) < same || abs(ts.hi - edge) < same { add(edge, other) }
            }
            if middles, !t.edgesOnly, abs(ts.mid - b.mid) < same { add(b.mid, other) }
        }
        return found.sorted { $0.at < $1.at }.map { line(axis, at: $0.at, from: $0.reach.lo, to: $0.reach.hi) }
    }

    private static func line(_ axis: Axis, at: CGFloat, from: CGFloat, to: CGFloat) -> Guide {
        switch axis {
        case .across: return Guide(kind: .line, axis: axis, from: CGPoint(x: at, y: from), to: CGPoint(x: at, y: to))
        case .down: return Guide(kind: .line, axis: axis, from: CGPoint(x: from, y: at), to: CGPoint(x: to, y: at))
        }
    }

    /// The marks across the gaps that are the same, for the landed box.
    private static func gaps(_ axis: Axis, _ box: CGRect, _ targets: [Target]) -> [Guide] {
        let b = Span(box, along: axis)
        let side = Span(box, along: axis.other)
        let row = targets.filter { !$0.edgesOnly && Span($0.rect, along: axis.other).overlap(side) > 0 }
        let before = row.filter { Span($0.rect, along: axis).hi <= b.mid }
            .sorted { Span($0.rect, along: axis).hi > Span($1.rect, along: axis).hi }
        let after = row.filter { Span($0.rect, along: axis).lo >= b.mid }
            .sorted { Span($0.rect, along: axis).lo < Span($1.rect, along: axis).lo }

        /// A mark across the gap between two rects, at the middle of where they lie side by side.
        func mark(_ a: CGRect, _ c: CGRect) -> Guide {
            let first = Span(a, along: axis), second = Span(c, along: axis)
            let sa = Span(a, along: axis.other), sc = Span(c, along: axis.other)
            let level = (max(sa.lo, sc.lo) + min(sa.hi, sc.hi)) / 2
            switch axis {
            case .across: return Guide(kind: .gap, axis: axis, from: CGPoint(x: first.hi, y: level), to: CGPoint(x: second.lo, y: level))
            case .down: return Guide(kind: .gap, axis: axis, from: CGPoint(x: level, y: first.hi), to: CGPoint(x: level, y: second.lo))
            }
        }

        var marks: [Guide] = []
        func add(_ guide: Guide) { if !marks.contains(guide) { marks.append(guide) } }

        if let l = before.first, let r = after.first {
            let ls = Span(l.rect, along: axis), rs = Span(r.rect, along: axis)
            let gap = b.lo - ls.hi
            if gap > same, abs(gap - (rs.lo - b.hi)) < same {
                add(mark(l.rect, box)); add(mark(box, r.rect))
            }
        }
        if let near = before.first {
            let ns = Span(near.rect, along: axis)
            if let far = before.dropFirst().first(where: { Span($0.rect, along: axis).hi <= ns.lo }) {
                let gap = ns.lo - Span(far.rect, along: axis).hi
                if gap > same, abs(gap - (b.lo - ns.hi)) < same {
                    add(mark(far.rect, near.rect)); add(mark(near.rect, box))
                }
            }
        }
        if let near = after.first {
            let ns = Span(near.rect, along: axis)
            if let far = after.dropFirst().first(where: { Span($0.rect, along: axis).lo >= ns.hi }) {
                let gap = Span(far.rect, along: axis).lo - ns.hi
                if gap > same, abs(gap - (ns.lo - b.hi)) < same {
                    add(mark(box, near.rect)); add(mark(near.rect, far.rect))
                }
            }
        }
        return marks
    }
}

extension Snap.Axis {
    var other: Snap.Axis { self == .across ? .down : .across }
}

// MARK: On a board

public extension Board {
    /// What a moved thing can fall in line with: everything that can be seen and is not moving
    /// itself — except the ideas a mind map lays out (only a map's centre idea counts).
    func snapTargets(without moving: Set<UUID> = []) -> [Snap.Target] {
        items.compactMap { item in
            guard !moving.contains(item.id) else { return nil }
            if item.kind == .idea, item.parent != nil { return nil }
            guard item.parent == nil || !isHidden(item.id) else { return nil }
            return Snap.Target(item.frame, edgesOnly: item.kind == .frame)
        }
    }

    /// Moves the items (use `carried(by:)` first) and lets them fall in line. Returns the guide lines.
    /// A reach of 0 moves them plainly.
    @discardableResult
    mutating func moveSnapped(_ ids: Set<UUID>, by delta: CGSize, reach: CGFloat) -> [Snap.Guide] {
        // Ideas that hang under another are placed by their map: only the centre counts.
        let own = items.filter { ids.contains($0.id) && !($0.kind == .idea && $0.parent != nil) }
        let result = Snap.move(own.map(\.frame), by: delta, targets: snapTargets(without: ids), reach: reach,
                               middles: !own.contains { $0.kind == .frame })
        move(ids, by: result.delta)
        return result.guides
    }

    /// Sizes an item and lets the edge that moves catch its neighbours' edges. Returns the guide lines.
    @discardableResult
    mutating func resizeSnapped(_ id: UUID, to rect: CGRect, reach: CGFloat) -> [Snap.Guide] {
        guard let item = item(id) else { return [] }
        // What a frame carries is not a neighbour of its own edge.
        let inside: Set<UUID> = item.kind == .frame ? carried(by: [id]) : [id]
        let result = Snap.resize(rect, from: item.frame, targets: snapTargets(without: inside), reach: reach)
        resize(id, to: result.rect)
        // The smallest size may have held the edge back: a guide the edge is not on is dropped.
        guard let now = self.item(id)?.frame else { return [] }
        return result.guides.filter { guide in
            switch guide.axis {
            case .across: return abs(guide.from.x - now.minX) < Snap.same || abs(guide.from.x - now.maxX) < Snap.same
            case .down: return abs(guide.from.y - now.minY) < Snap.same || abs(guide.from.y - now.maxY) < Snap.same
            }
        }
    }

    /// Where a shape pulled out of a plus would land.
    struct Landing: Equatable, Sendable {
        public var centre: CGPoint
        public var frame: CGRect
        public var guides: [Snap.Guide]
    }

    /// A shape is pulled out of the plus of `id` and let go at the point. Returns where the new shape
    /// lands — in line with its neighbours when one is near, the shape it comes from first, so the
    /// arrow is one straight piece. nil when no new shape would be made there (an idea adds an idea;
    /// over another thing the two are joined instead).
    func landing(from id: UUID, at point: CGPoint, reach: CGFloat) -> Landing? {
        guard let source = item(id), source.kind != .idea, source.kind != .frame else { return nil }
        if let over = hit(point), over != id, item(over)?.kind != .frame { return nil }
        let size = source.kind.defaultSize
        let box = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        let result = Snap.move([box], by: .zero, targets: snapTargets(), reach: reach, favour: source.frame)
        let landed = box.offsetBy(dx: result.delta.width, dy: result.delta.height)
        return Landing(centre: CGPoint(x: landed.midX, y: landed.midY), frame: landed, guides: result.guides)
    }
}
