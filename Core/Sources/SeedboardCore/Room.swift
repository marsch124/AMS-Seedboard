import Foundation
import CoreGraphics

// Making room. When a mind map grows (a new idea, longer words, a branch hung on, an unfolding),
// the things it would now cover — notes, shapes, free text, other maps — step aside by just
// what is needed. Things the owner put on top of a map on purpose are left alone.

public extension Board {
    private struct MapShape {
        /// The frames of the map's ideas that can be seen.
        var frames: [CGRect] = []
        /// Every idea of the map, hidden ones too.
        var members: [UUID] = []
    }

    /// Every map by its centre.
    private func mapShapes() -> [UUID: MapShape] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var out: [UUID: MapShape] = [:]
        for item in items where item.kind == .idea {
            var here = item
            var hidden = false
            var steps = 0
            while let up = here.parent, let upItem = byID[up], steps < 10_000 {
                if upItem.folded { hidden = true }
                here = upItem
                steps += 1
            }
            out[here.id, default: MapShape()].members.append(item.id)
            if !hidden { out[here.id, default: MapShape()].frames.append(item.frame) }
        }
        return out
    }

    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    private static func overlaps(_ a: [CGRect], _ b: [CGRect]) -> Bool {
        a.contains { one in b.contains { overlaps(one, $0) } }
    }

    /// How far the boxes must go in the direction to stand clear of everything in the way, with the gap between.
    internal static func step(_ boxes: [CGRect], clearOf inTheWay: [CGRect], _ direction: Direction, gap: Double) -> Double {
        var shift = 0.0
        for _ in 0..<200 {
            var more = 0.0
            for box in boxes {
                var b = box.insetBy(dx: -gap, dy: -gap)
                switch direction {
                case .right: b.origin.x += shift
                case .left: b.origin.x -= shift
                case .down: b.origin.y += shift
                case .up: b.origin.y -= shift
                }
                for other in inTheWay where overlaps(b, other) {
                    let need: Double
                    switch direction {
                    case .right: need = Double(other.maxX - b.minX)
                    case .left: need = Double(b.maxX - other.minX)
                    case .down: need = Double(other.maxY - b.minY)
                    case .up: need = Double(b.maxY - other.minY)
                    }
                    more = max(more, need)
                }
            }
            if more <= 0 { return shift }
            shift += more
        }
        return shift
    }

    private static func delta(_ direction: Direction, _ amount: Double) -> CGSize {
        switch direction {
        case .right: return CGSize(width: amount, height: 0)
        case .left: return CGSize(width: -amount, height: 0)
        case .down: return CGSize(width: 0, height: amount)
        case .up: return CGSize(width: 0, height: -amount)
        }
    }

    /// Call after a change, with the board as it was before it. Every map that changed its shape
    /// while its centre stayed put pushes away what it newly covers: a thing that stood clear of the
    /// map before and was not itself moved by the change. Each goes the shortest way out (sideways
    /// or up/down), and takes along what it would then run into.
    mutating func makeRoom(since before: Board, gap: Double = 8) {
        let was = before.mapShapes()
        let wasItem = Dictionary(before.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let nowShapes = mapShapes()
        // The maps that changed their shape without being moved.
        let grown = mapCentres.map(\.id).filter { id in
            guard let old = wasItem[id], old.kind == .idea, old.parent == nil, let me = item(id), old.x == me.x, old.y == me.y,
                  let then = was[id]?.frames, let now = nowShapes[id]?.frames else { return false }
            return then != now
        }
        guard !grown.isEmpty else { return }

        var budget = 60
        for centreID in grown {
            let shapes = mapShapes()
            guard let then = was[centreID]?.frames, let now = shapes[centreID]?.frames, let centre = item(centreID) else { continue }

            /// The shortest way out for these boxes: away from the centre first when two ways are as short.
            func wayOut(_ boxes: [CGRect]) -> (Direction, Double) {
                let all = boxes.dropFirst().reduce(boxes[0]) { $0.union($1) }
                let across: [Direction] = Double(all.midX) >= Double(centre.centre.x) ? [.right, .left] : [.left, .right]
                let down: [Direction] = Double(all.midY) >= Double(centre.centre.y) ? [.down, .up] : [.up, .down]
                var best: (Direction, Double) = (across[0], .infinity)
                for direction in [across[0], down[0], across[1], down[1]] {
                    let amount = Board.step(boxes, clearOf: now, direction, gap: gap)
                    if amount < best.1 - 0.001 { best = (direction, amount) }
                }
                return best
            }

            // Notes, shapes and free text.
            var pushed: [(id: UUID, from: CGRect, direction: Direction)] = []
            for thing in items where thing.kind != .idea && thing.kind != .frame {
                guard let old = wasItem[thing.id], old.frame == thing.frame,
                      Board.overlaps([thing.reach], now), !Board.overlaps([old.reach], then) else { continue }
                let (direction, amount) = wayOut([thing.reach])
                guard amount > 0, amount.isFinite else { continue }
                move([thing.id], by: Board.delta(direction, amount))
                pushed.append((thing.id, thing.reach, direction))
            }
            // What a pushed thing now runs into goes the same way.
            var done = Set(pushed.map(\.id))
            while !pushed.isEmpty, budget > 0 {
                let (id, from, direction) = pushed.removeFirst()
                guard let mover = item(id) else { continue }
                for other in items where other.kind != .idea && other.kind != .frame && !done.contains(other.id) {
                    guard Board.overlaps(other.reach, mover.reach), !Board.overlaps(other.reach, from) else { continue }
                    let amount = Board.step([other.reach], clearOf: [mover.reach], direction, gap: gap)
                    guard amount > 0 else { continue }
                    move([other.id], by: Board.delta(direction, amount))
                    done.insert(other.id)
                    pushed.append((other.id, other.reach, direction))
                    budget -= 1
                }
            }
            // Other maps go as a whole.
            for (otherID, shape) in shapes where otherID != centreID && !shape.frames.isEmpty {
                guard let old = wasItem[otherID], old.kind == .idea, old.parent == nil, let me = item(otherID),
                      old.x == me.x, old.y == me.y, let before = was[otherID]?.frames,
                      Board.overlaps(shape.frames, now), !Board.overlaps(before, then) else { continue }
                let (direction, amount) = wayOut(shape.frames)
                guard amount > 0, amount.isFinite else { continue }
                move(Set(shape.members), by: Board.delta(direction, amount))
            }
        }
    }
}
