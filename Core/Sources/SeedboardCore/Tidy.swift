import Foundation
import CoreGraphics

// Tidying several chosen things: Line up, Even gaps, Same size.
// Ideas that hang under another idea are left out — their mind map places them.

public extension Board {
    /// The chosen things that can be tidied, in the board's own order.
    func tidyable(_ ids: Set<UUID>) -> [Item] {
        items.filter { ids.contains($0.id) && !($0.kind == .idea && $0.parent != nil) && !isHidden($0.id) }
    }

    /// True when the things are spread more sideways than up and down: they make a row.
    /// Otherwise they make a column.
    func tidyIsRow(_ ids: Set<UUID>) -> Bool {
        let all = tidyable(ids)
        let xs = all.map { $0.x + $0.w / 2 }, ys = all.map { $0.y + $0.h / 2 }
        return (xs.max() ?? 0) - (xs.min() ?? 0) >= (ys.max() ?? 0) - (ys.min() ?? 0)
    }

    /// Moves one thing, with what it carries that was not chosen itself (a map's ideas, what lies in a frame).
    private mutating func tidyMove(_ id: UUID, by delta: CGSize, chosen: Set<UUID>) {
        guard delta != .zero else { return }
        let along = carried(by: [id]).filter { $0 == id || !chosen.contains($0) }
        move(along, by: delta)
    }

    /// Line up: puts the things on one line — a row keeps its places sideways and takes the average
    /// height of the middles; a column the other way round. Needs two or more.
    mutating func lineUp(_ ids: Set<UUID>) {
        let all = tidyable(ids)
        guard all.count >= 2 else { return }
        let chosen = Set(all.map(\.id))
        if tidyIsRow(ids) {
            let line = all.map { $0.y + $0.h / 2 }.reduce(0, +) / Double(all.count)
            for item in all { tidyMove(item.id, by: CGSize(width: 0, height: line - (item.y + item.h / 2)), chosen: chosen) }
        } else {
            let line = all.map { $0.x + $0.w / 2 }.reduce(0, +) / Double(all.count)
            for item in all { tidyMove(item.id, by: CGSize(width: line - (item.x + item.w / 2), height: 0), chosen: chosen) }
        }
    }

    /// Even gaps: along the row (or column) the two outer things stay, the ones between are moved
    /// so that every gap from edge to edge is the same. Needs three or more.
    mutating func evenGaps(_ ids: Set<UUID>) {
        let row = tidyIsRow(ids)
        func lo(_ item: Item) -> Double { row ? item.x : item.y }
        func length(_ item: Item) -> Double { row ? item.w : item.h }
        let all = tidyable(ids).sorted {
            (lo($0) + length($0) / 2, $0.id.uuidString) < (lo($1) + length($1) / 2, $1.id.uuidString)
        }
        guard all.count >= 3, let first = all.first, let last = all.last else { return }
        let chosen = Set(all.map(\.id))
        let between = all.dropFirst().dropLast()
        let room = lo(last) - (lo(first) + length(first)) - between.map(length).reduce(0, +)
        let gap = room / Double(all.count - 1)
        var at = lo(first) + length(first) + gap
        for item in between {
            let d = at - lo(item)
            tidyMove(item.id, by: row ? CGSize(width: d, height: 0) : CGSize(width: 0, height: d), chosen: chosen)
            at += length(item) + gap
        }
    }

    /// The chosen things whose size can be set: shapes, sticky notes and frames
    /// (an idea and free text are as big as their words).
    func sizeable(_ ids: Set<UUID>) -> [Item] {
        tidyable(ids).filter { $0.kind != .idea && $0.kind != .text && $0.kind != .drawing }
    }

    /// Same size: every thing takes the width and height of the largest; its middle stays where it is.
    /// Needs two or more.
    mutating func sameSize(_ ids: Set<UUID>) {
        let all = sizeable(ids)
        guard all.count >= 2, let largest = all.max(by: { ($0.w * $0.h, $0.w) < ($1.w * $1.h, $1.w) }) else { return }
        for item in all {
            guard let i = index(of: item.id) else { continue }
            items[i].x += (items[i].w - largest.w) / 2
            items[i].y += (items[i].h - largest.h) / 2
            items[i].w = largest.w
            items[i].h = largest.h
        }
    }
}
