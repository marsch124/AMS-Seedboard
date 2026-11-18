import Foundation
import CoreGraphics

// What the owner can do to an arrow and with the keys of a flow (0.2): the ends of an arrow
// (one way, both ways, none), dashes, moving an end to another side or another shape,
// and the next shape in the direction the flow is running.

/// The ends of an arrow. Stored as `head` (the far end) and `tail` (the near end).
public enum LinkEnds: String, CaseIterable, Sendable {
    case oneWay, bothWays, none

    public var word: String {
        switch self {
        case .oneWay: return "One way"
        case .bothWays: return "Both ways"
        case .none: return "No ends"
        }
    }
}

public extension Link {
    /// One way (a head at the far end), both ways, or a plain line.
    var ends: LinkEnds {
        get { head ? (tail == true ? .bothWays : .oneWay) : .none }
        set {
            head = newValue != .none
            tail = newValue == .bothWays ? true : nil
        }
    }

    /// Drawn with dashes.
    var isDashed: Bool {
        get { dashed == true }
        set { dashed = newValue ? true : nil }
    }
}

public extension ItemKind {
    /// The kind of the next shape in a flow: after a diamond (a question) or a round box (a start)
    /// comes a Box; everything else is followed by its own kind.
    var nextInFlow: ItemKind { self == .diamond || self == .round ? .box : self }
}

public extension Board {
    /// The word a new arrow out of this item gets by itself: the first out of a diamond says "Yes",
    /// the second "No" (or "Yes" when the first already says "No"); every other arrow has none.
    func wordForNewArrow(from id: UUID) -> String {
        guard item(id)?.kind == .diamond else { return "" }
        let out = links.filter { $0.from == id }
        switch out.count {
        case 0: return "Yes"
        case 1: return out[0].text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "no" ? "Yes" : "No"
        default: return ""
        }
    }

    /// The direction a flow is running at this shape: the way of the arrow that arrives at it
    /// (the oldest, when there are several); to the right when none arrives.
    /// A diamond whose side that way already has an arrow leaving sends the next one down
    /// (or to the right, when the flow runs down or up), so its second answer gets its own side.
    func flowDirection(at id: UUID) -> Direction {
        let all = arrows()
        var way: Direction = .right
        if let coming = links.first(where: { $0.to == id && all[$0.id] != nil }), let arrow = all[coming.id] {
            way = arrow.arrives.opposite
        }
        guard item(id)?.kind == .diamond else { return way }
        let taken = Set(links.filter { $0.from == id }.compactMap { all[$0.id]?.leaves })
        if taken.contains(way) {
            let other: Direction = way.isSideways ? .down : .right
            if !taken.contains(other) { return other }
        }
        return way
    }

    /// An end of an arrow was dragged and let go at the point.
    /// On (or within 30 points of) its own item: the end moves to the side nearest the point, and
    /// that side is kept — unless it is the side the app would find anyway; then nothing is stored
    /// and the arrow follows the shapes again. On another item: the end moves there and its side
    /// is found by the app. Refused (false): on a frame, on empty board, on the item at the other
    /// end, or when the same arrow already exists.
    @discardableResult
    mutating func moveEnd(of linkID: UUID, start: Bool, to point: CGPoint) -> Bool {
        guard let l = links.firstIndex(where: { $0.id == linkID }) else { return false }
        let link = links[l]
        let ownID = start ? link.from : link.to
        let otherID = start ? link.to : link.from
        guard let own = item(ownID), let other = item(otherID) else { return false }
        var target = hit(point)
        if let found = target, item(found)?.kind == .frame { target = nil }
        if target == nil, own.frame.insetBy(dx: -30, dy: -30).contains(point) { target = ownID }
        guard let target, target != otherID else { return false }
        if target == ownID {
            let side = Route.nearestSide(of: own.frame, to: point)
            let found = start ? Route.sides(from: own.frame, to: other.frame).leaves
                              : Route.sides(from: other.frame, to: own.frame).arrives
            let kept: Direction? = side == found ? nil : side
            if start { links[l].fromSide = kept } else { links[l].toSide = kept }
        } else {
            let from = start ? target : link.from
            let to = start ? link.to : target
            guard !links.contains(where: { $0.id != linkID && $0.from == from && $0.to == to }) else { return false }
            if start {
                links[l].from = target
                links[l].fromSide = nil
            } else {
                links[l].to = target
                links[l].toSide = nil
            }
        }
        return true
    }

    /// The item an end of an arrow would land on when let go at the point (nil: it would spring back).
    func endTarget(of linkID: UUID, start: Bool, at point: CGPoint) -> UUID? {
        var copy = self
        guard copy.moveEnd(of: linkID, start: start, to: point),
              let link = copy.links.first(where: { $0.id == linkID }) else { return nil }
        return start ? link.from : link.to
    }
}
