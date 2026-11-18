import Foundation
import CoreGraphics

// 0.9 views: Focus on a frame, Show frames one by one, Tidy into a grid, and the small map in the corner
// of a big board. Only rules here — nothing knows about the screen.

public extension Board {
    /// The frames that can be shown, by position: the top row first, then left to right.
    /// Rows are told as in `Thinking.readingOrder`.
    func showOrder() -> [UUID] {
        Thinking.readingOrder(items.filter { $0.kind == .frame && !isHidden($0.id) }).map(\.id)
    }

    /// What "Tidy into a grid" works on. With things chosen: those (pinned ones left out). With nothing chosen:
    /// every sticky note that lies loose on the board (not in a frame), pinned ones left out.
    func gridMembers(_ ids: Set<UUID>) -> [Item] {
        if ids.isEmpty {
            let frames = items.filter { $0.kind == .frame }
            return items.filter { item in
                item.kind == .note && item.locked != true && !isHidden(item.id)
                    && !frames.contains { Board.frame($0, holds: item) }
            }
        }
        return gridable(ids).filter { $0.locked != true }
    }

    /// Tidy into a grid: columns about the square root of the count, a gap of 16 between, reading order kept
    /// (top left to bottom right), starting at the top left of the group. Pinned things stay where they are.
    /// Returns false when there were fewer than two things to tidy.
    @discardableResult
    mutating func tidyIntoGrid(_ ids: Set<UUID>, gap: Double = 16) -> Bool {
        let members = gridMembers(ids)
        guard canBeChanged, !placesItself, members.count >= 2 else { return false }
        let chosen = Set(members.map(\.id))
        let ordered = Thinking.readingOrder(members)
        let columns = Int(Double(ordered.count).squareRoot().rounded(.up))
        let rows = (ordered.count + columns - 1) / columns
        var widths = Array(repeating: 0.0, count: columns), heights = Array(repeating: 0.0, count: rows)
        for (n, item) in ordered.enumerated() {
            widths[n % columns] = max(widths[n % columns], item.w)
            heights[n / columns] = max(heights[n / columns], item.h)
        }
        let left = members.map(\.x).min() ?? 0, top = members.map(\.y).min() ?? 0
        var xs: [Double] = [], ys: [Double] = []
        var at = left
        for w in widths { xs.append(at); at += w + gap }
        at = top
        for h in heights { ys.append(at); at += h + gap }
        for (n, item) in ordered.enumerated() {
            let delta = CGSize(width: xs[n % columns] - item.x, height: ys[n / columns] - item.y)
            guard delta != .zero else { continue }
            let along = carried(by: [item.id]).filter { $0 == item.id || !chosen.contains($0) }
            move(along, by: delta)
        }
        return true
    }
}

public extension Viewport {
    /// Zooms to a box of the board (a frame) with air round it: `air` points on every side, the tool rows
    /// `top` and `bottom` points of the screen kept free. Never smaller than 5 % nor bigger than 3 times life.
    mutating func show(_ box: CGRect, air: Double = 40, top: Double = 0, bottom: Double = 0) {
        guard size.width > 10, size.height > 10, box.width > 0, box.height > 0 else { return }
        let roomW = max(Double(size.width) - 2 * air, 40), roomH = max(Double(size.height) - top - bottom - 2 * air, 40)
        let s = min(max(min(roomW / Double(box.width), roomH / Double(box.height)), 0.05), 3)
        zoom(to: 1)  // marks the view as moved by the owner and forgets a typing zoom
        scale = s
        offset = CGSize(width: Double(size.width) / 2 - Double(box.midX) * s,
                        height: top + (Double(size.height) - top - bottom) / 2 - Double(box.midY) * s)
    }

    /// The part of the board on screen.
    var visibleBoard: CGRect {
        guard size.width > 0, scale > 0 else { return .zero }
        let a = toBoard(.zero), b = toBoard(CGPoint(x: size.width, y: size.height))
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }
}

/// The small map in the corner of a big board.
public struct BoardMap: Equatable, Sendable {
    /// What the map shows: the things and the visible part, with a little margin.
    public var world: CGRect
    public var size: CGSize
    public var scale: Double
    /// Where the world's top left sits inside the map (the world is centred).
    public var origin: CGPoint

    /// The things spread wider or taller than about twice the visible area.
    public static func isNeeded(content: CGRect?, visible: CGRect) -> Bool {
        guard let content, visible.width > 0, visible.height > 0 else { return false }
        return content.width > 2 * visible.width || content.height > 2 * visible.height
    }

    public init(content: CGRect, visible: CGRect, size: CGSize) {
        let all = content.union(visible).insetBy(dx: -20, dy: -20)
        self.world = all
        self.size = size
        let s = min(Double(size.width) / max(Double(all.width), 1), Double(size.height) / max(Double(all.height), 1))
        self.scale = s
        self.origin = CGPoint(x: (Double(size.width) - Double(all.width) * s) / 2, y: (Double(size.height) - Double(all.height) * s) / 2)
    }

    public func toMap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: Double(origin.x) + (Double(p.x) - Double(world.minX)) * scale, y: Double(origin.y) + (Double(p.y) - Double(world.minY)) * scale)
    }

    public func toMap(_ r: CGRect) -> CGRect {
        let a = toMap(r.origin)
        return CGRect(x: a.x, y: a.y, width: Double(r.width) * scale, height: Double(r.height) * scale)
    }

    /// A press on the map (clamped into it) is this point of the board.
    public func toBoard(_ p: CGPoint) -> CGPoint {
        let x = min(max(Double(p.x), 0), Double(size.width)), y = min(max(Double(p.y), 0), Double(size.height))
        return CGPoint(x: Double(world.minX) + (x - Double(origin.x)) / scale, y: Double(world.minY) + (y - Double(origin.y)) / scale)
    }
}
