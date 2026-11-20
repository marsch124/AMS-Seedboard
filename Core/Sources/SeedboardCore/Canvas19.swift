import Foundation
import CoreGraphics

// 0.19, the bar beside the chosen thing (picks 10, 12, 14, 15): the colours used last come first in the colour
// row; "Stack" lays free things in one column; sticky notes in two sizes; "Put in a frame".

public enum Canvas19 {
    /// The gap between two things of a stack.
    public static let stackGap: Double = 10
    /// The air between the chosen things and the frame grown round them.
    public static let frameAir: Double = 24
    /// A small sticky note (quick tags): 96 x 64.
    public static let smallNote = CGSize(width: 96, height: 64)
    /// How many last-used colours come first in the colour row.
    public static let recentShown = 3

    /// The colour row in its order: the last colours used (newest first, at most three, only those the row offers,
    /// no doubles) first, then the rest in their usual order. "" (no colour) keeps the place it had.
    public static func colourRow(_ offered: [String], recent: [String]) -> [String] {
        var first: [String] = []
        for name in recent where !name.isEmpty && offered.contains(name) && !first.contains(name) {
            first.append(name)
            if first.count == recentShown { break }
        }
        let none = offered.filter(\.isEmpty)
        return none + first + offered.filter { !$0.isEmpty && !first.contains($0) }
    }

    /// The last colours used, newest first, with this one put in front (kept to a handful).
    public static func remembered(_ name: String, in recent: [String]) -> [String] {
        guard !name.isEmpty else { return recent }
        return Array(([name] + recent.filter { $0 != name }).prefix(6))
    }
}

public extension Board {
    private var canvasIsFree: Bool { canBeChanged && !placesItself }

    // MARK: Stack (pick 12)

    /// The chosen things a stack is made of: free sticky notes, boxes and other shapes, and texts — not ideas of a
    /// mind map, frames, pictures or sketches; not pinned or hidden things.
    func stackable(_ ids: Set<UUID>) -> [Item] {
        guard canvasIsFree else { return [] }
        return items.filter { ids.contains($0.id) && ($0.kind == .note || $0.kind.isShape || $0.kind == .text) && $0.locked != true && !isHidden($0.id) }
    }

    /// One neat column under the top-left thing (reading order: top first, then left): left edges lined up with it,
    /// 10 points between. Returns false when fewer than two things can be stacked.
    @discardableResult
    mutating func stack(_ ids: Set<UUID>) -> Bool {
        let all = Thinking.readingOrder(stackable(ids))
        guard all.count >= 2, let first = all.first else { return false }
        var y = first.y + first.h + Canvas19.stackGap
        for item in all.dropFirst() {
            guard let i = index(of: item.id) else { continue }
            items[i].x = first.x
            items[i].y = y
            y += items[i].h + Canvas19.stackGap
        }
        return true
    }

    // MARK: Two sizes of sticky note (pick 14)

    /// The chosen sticky notes.
    func noteIDs(_ ids: Set<UUID>) -> [UUID] {
        guard canvasIsFree else { return [] }
        return items.filter { ids.contains($0.id) && $0.kind == .note && $0.locked != true }.map(\.id)
    }

    /// Small (96 x 64, text one style smaller) or normal (150 x 110) sticky notes; the top-left corner stays.
    mutating func setNoteSize(_ ids: Set<UUID>, small: Bool) {
        for id in noteIDs(ids) {
            guard let i = index(of: id) else { continue }
            items[i].textSize = small ? TextSize.small : nil
            let size = small ? Canvas19.smallNote : ItemKind.note.defaultSize
            items[i].w = Double(size.width)
            items[i].h = Double(size.height)
        }
    }

    // MARK: Put in a frame (pick 15)

    /// The things that a frame round the chosen things must surround, or nil when it cannot be made: nothing
    /// chosen that can be framed, or an idea chosen without its map's centre (the map would be cut in two).
    /// A chosen centre brings its whole map.
    private func framedItems(_ ids: Set<UUID>) -> [Item]? {
        guard canvasIsFree else { return nil }
        var all: Set<UUID> = []
        for item in items where ids.contains(item.id) && !isHidden(item.id) {
            switch item.kind {
            case .idea:
                guard item.parent == nil else {
                    // An idea of a map: fine only when its centre is chosen too.
                    var top = item.id, n = 0
                    while let up = self.item(top)?.parent, n < 10_000 { top = up; n += 1 }
                    if ids.contains(top) { continue }
                    return nil
                }
                all.insert(item.id)
                for d in descendants(of: item.id) where !isHidden(d) { all.insert(d) }
            case .bar, .milestone, .phase, .who, .message, .band, .section, .block:
                return nil
            default:
                all.insert(item.id)
            }
        }
        let found = items.filter { all.contains($0.id) }
        return found.isEmpty ? nil : found
    }

    /// True when "Put in a frame" can be done with these chosen things.
    func canFrame(_ ids: Set<UUID>) -> Bool { framedItems(ids) != nil }

    /// A frame grown round the chosen things: 24 points of air on every side, empty name, lying under them.
    /// Returns the new frame.
    @discardableResult
    mutating func putInFrame(_ ids: Set<UUID>) -> UUID? {
        guard let found = framedItems(ids), var rect = found.first?.reach else { return nil }
        for item in found.dropFirst() { rect = rect.union(item.reach) }
        rect = rect.insetBy(dx: -Canvas19.frameAir, dy: -Canvas19.frameAir)
        let made = add(.frame, centre: CGPoint(x: rect.midX, y: rect.midY))
        resize(made, to: rect)
        return made
    }
}
