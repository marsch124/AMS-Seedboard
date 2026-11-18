import Foundation
import CoreGraphics

// Putting ideas in another order by dragging: what a dragged idea does where it is let go
// (lands between two sisters, hangs under another idea, becomes its own map, or springs back),
// and where the thin line is drawn that shows the place it will land.

/// A place among the sisters of one side: before one of them, or after the last one.
public struct IdeaSlot: Equatable, Sendable {
    public var parent: UUID
    public var side: Side
    /// The sister the idea lands before; nil = after the last one on that side.
    public var before: UUID?

    public init(parent: UUID, side: Side, before: UUID?) {
        self.parent = parent
        self.side = side
        self.before = before
    }
}

/// What a dragged idea does where it is let go.
public enum IdeaDrop: Equatable, Sendable {
    /// Nothing changes: it goes back to where it was.
    case springBack
    /// It hangs under this idea, with everything below it.
    case hang(under: UUID)
    /// It lands in another place among its sisters.
    case reorder(IdeaSlot)
    /// It becomes the middle of a map of its own.
    case tearOff
}

public extension MindMap {
    /// How far from its family (its sisters' column) an idea must be dragged to be torn off.
    static let tearOff: Double = 120
    /// The upper and the lower part of a sister (this share of its height each) count as the
    /// gap beside it; only the part between them means "hang it under this one".
    static let sisterEdge: Double = 0.25
    /// The shortest landing line.
    static let shortestLine: Double = 40
}

public extension Board {
    /// The sisters of an idea on its own side, from the top, the idea itself among them.
    func sistersOnSide(of id: UUID) -> [Item] {
        guard let parentID = item(id)?.parent else { return [] }
        let mine = side(of: id)
        return children(of: parentID).filter { side(of: $0.id) == mine }
    }

    /// The idea's place among the sisters of its side, counted from 1, and how many they are.
    func place(of id: UUID) -> (at: Int, of: Int)? {
        let column = sistersOnSide(of: id)
        guard let at = column.firstIndex(where: { $0.id == id }) else { return nil }
        return (at + 1, column.count)
    }

    /// True when Move up (or Move down) would change something.
    func canShiftIdea(_ id: UUID, down: Bool) -> Bool {
        guard let me = item(id), me.kind == .idea, let parentID = me.parent, let parent = item(parentID),
              let place = place(of: id) else { return false }
        // A main branch of a both-sides map crosses to the other side at the end of its own.
        if parent.parent == nil && parent.bothSides { return true }
        return down ? place.at < place.of : place.at > 1
    }

    /// The place the idea has now.
    func slot(of id: UUID) -> IdeaSlot? {
        guard let parentID = item(id)?.parent else { return nil }
        let column = sistersOnSide(of: id)
        guard let at = column.firstIndex(where: { $0.id == id }) else { return nil }
        return IdeaSlot(parent: parentID, side: side(of: id), before: at + 1 < column.count ? column[at + 1].id : nil)
    }

    /// Puts an idea into a place among its own sisters. A main branch of a both-sides map takes
    /// the side of the place. False when the place belongs to another parent.
    @discardableResult
    mutating func placeIdea(_ id: UUID, in slot: IdeaSlot) -> Bool {
        guard let me = item(id), me.kind == .idea, me.parent == slot.parent, let parent = item(slot.parent) else { return false }
        let twoSided = parent.parent == nil && parent.bothSides
        if twoSided { settleSides(of: slot.parent) }
        var order = children(of: slot.parent).map(\.id).filter { $0 != id }
        var at = order.count
        if let before = slot.before, let found = order.firstIndex(of: before) {
            at = found
        } else if twoSided, let last = order.lastIndex(where: { item($0)?.side == slot.side }) {
            // After the last one on that side, wherever the other side's branches stand in the order.
            at = last + 1
        }
        order.insert(id, at: at)
        for (n, each) in order.enumerated() {
            if let i = index(of: each) { items[i].order = Double(n + 1) }
        }
        if twoSided, let i = index(of: id) { items[i].side = slot.side }
        return true
    }

    /// What an idea dragged to this point does when it is let go there.
    ///  1. Over another idea (not itself, not one below it): it hangs under that idea. Over a
    ///     sister only the middle part counts; its upper and lower part are the gap beside it.
    ///     Over the idea it already hangs under: nothing changes.
    ///  2. Within `reach` of its sisters' column: it lands between the two sisters the point
    ///     lies between (above the middle of a sister = before it). A main branch of a
    ///     both-sides map can land in the other side's column as well. Its own place: nothing.
    ///  3. Further away: it is torn off and becomes its own map.
    /// A centre is not an idea of a family: it is moved, never dropped this way.
    func ideaDrop(_ id: UUID, at point: CGPoint, reach: Double = MindMap.tearOff) -> IdeaDrop {
        guard let me = item(id), me.kind == .idea, let parentID = me.parent, let parent = item(parentID) else { return .springBack }
        let skip = Set(descendants(of: id)).union([id])
        if let over = idea(at: point, notIn: skip), let target = item(over) {
            if over == parentID { return .springBack }
            let edge = target.h * MindMap.sisterEdge
            let middle = Double(point.y) >= target.y + edge && Double(point.y) <= target.y + target.h - edge
            if target.parent != parentID || middle { return .hang(under: over) }
        }
        let mySide = side(of: id)
        var sides = [mySide]
        if parent.parent == nil && parent.bothSides { sides.append(mySide == .right ? .left : .right) }
        let all = children(of: parentID)
        for side in sides {
            let column = all.filter { self.side(of: $0.id) == side }
            guard let first = column.first else { continue }
            let box = column.dropFirst().reduce(first.frame) { $0.union($1.frame) }
            guard box.insetBy(dx: -reach, dy: -reach).contains(point) else { continue }
            let before = column.first { $0.id != id && Double(point.y) < $0.y + $0.h / 2 }?.id
            let slot = IdeaSlot(parent: parentID, side: side, before: before)
            return slot == self.slot(of: id) ? .springBack : .reorder(slot)
        }
        return .tearOff
    }

    /// The thin line that shows where a dragged idea will land: in the gap between the two
    /// sisters, as long as the idea is wide, starting at the edge the sisters share.
    func landingLine(for slot: IdeaSlot, moving id: UUID) -> (from: CGPoint, to: CGPoint)? {
        guard let me = item(id) else { return nil }
        let column = children(of: slot.parent).filter { $0.id != id && side(of: $0.id) == slot.side }
        guard !column.isEmpty else { return nil }
        let belowAt = slot.before.flatMap { before in column.firstIndex { $0.id == before } }
        let below = belowAt.map { column[$0] }
        let above: Item?
        if let belowAt { above = belowAt > 0 ? column[belowAt - 1] : nil } else { above = column.last }
        let y: Double
        switch (above, below) {
        case let (a?, b?): y = (a.y + a.h + b.y) / 2
        case let (nil, b?): y = b.y - MindMap.gapDown / 2
        case let (a?, nil): y = a.y + a.h + MindMap.gapDown / 2
        default: return nil
        }
        guard let beside = below ?? above else { return nil }
        let length = max(me.w, MindMap.shortestLine)
        let from = slot.side == .right ? beside.x : beside.x + beside.w - length
        return (CGPoint(x: from, y: y), CGPoint(x: from + length, y: y))
    }
}
