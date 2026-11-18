import Foundation
import CoreGraphics

// The bar beside the chosen thing and the small controls round it (0.2, pick 7), and when a still
// press opens the menu (pick 18). Plain geometry, no screen.

// MARK: Where the bar goes

public enum BarPlace {
    /// Between the chosen thing's box and the bar, in screen points.
    public static let gap: CGFloat = 12
    /// Kept free between the bar and the edge of the board's visible room.
    public static let air: CGFloat = 8

    public struct Spot: Equatable, Sendable {
        /// The bar's top left corner.
        public var origin: CGPoint
        /// The bar stands above the box (otherwise below it).
        public var above: Bool
    }

    /// Where the bar for a chosen thing goes. `box`: the thing (with its controls) on screen;
    /// `bar`: the bar's size; `room`: the part of the board that can be seen. The bar stands `gap`
    /// above the box, in the middle over it; below the box when there is no room above; and it is
    /// always pushed back inside the room with `air` to every edge — also when the box is bigger
    /// than the room or has slid out of sight.
    public static func spot(box: CGRect, bar: CGSize, room: CGRect, gap: CGFloat = gap, air: CGFloat = air) -> Spot {
        let inner = room.insetBy(dx: air, dy: air)
        let x = min(max(box.midX - bar.width / 2, inner.minX), max(inner.maxX - bar.width, inner.minX))
        let lowest = max(inner.maxY - bar.height, inner.minY)
        let over = box.minY - gap - bar.height
        if over >= inner.minY { return Spot(origin: CGPoint(x: x, y: min(over, lowest)), above: true) }
        let under = box.maxY + gap
        if under <= lowest { return Spot(origin: CGPoint(x: x, y: max(under, inner.minY)), above: false) }
        // No room above and none below (the thing fills the view): at the top edge of the room.
        return Spot(origin: CGPoint(x: x, y: inner.minY), above: true)
    }
}

// MARK: Sizing from a corner

public enum Corner: String, CaseIterable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight

    public var opposite: Corner {
        switch self {
        case .topLeft: return .bottomRight
        case .topRight: return .bottomLeft
        case .bottomLeft: return .topRight
        case .bottomRight: return .topLeft
        }
    }

    public var isLeft: Bool { self == .topLeft || self == .bottomLeft }
    public var isTop: Bool { self == .topLeft || self == .topRight }

    /// This corner of a box.
    public func point(in r: CGRect) -> CGPoint {
        CGPoint(x: isLeft ? r.minX : r.maxX, y: isTop ? r.minY : r.maxY)
    }

    /// The box that results when this corner of `base` is dragged by `delta`. The opposite corner
    /// stays exactly where it is, and the box never gets smaller than `least`.
    public func rect(from base: CGRect, by delta: CGSize, least: CGSize) -> CGRect {
        var minX = base.minX, maxX = base.maxX, minY = base.minY, maxY = base.maxY
        if isLeft { minX = min(minX + delta.width, maxX - least.width) } else { maxX = max(maxX + delta.width, minX + least.width) }
        if isTop { minY = min(minY + delta.height, maxY - least.height) } else { maxY = max(maxY + delta.height, minY + least.height) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The same box moved so that the corner opposite this one lies on `anchor`.
    public func holding(_ anchor: CGPoint, _ r: CGRect) -> CGRect {
        let has = opposite.point(in: r)
        return r.offsetBy(dx: anchor.x - has.x, dy: anchor.y - has.y)
    }
}

public extension Board {
    /// The smallest a thing may be made by its size knobs.
    func leastSize(of id: UUID) -> CGSize {
        guard let item = item(id) else { return CGSize(width: 44, height: 28) }
        return item.kind == .frame ? item.leastFrameSize : CGSize(width: 44, height: 28)
    }

    /// A thing is sized from one of its four corners: `base` is its box when the drag began, `delta`
    /// how far the corner was dragged. The edges that move catch their neighbours' edges; the
    /// opposite corner never moves. Returns the guide lines.
    @discardableResult
    mutating func size(_ id: UUID, corner: Corner, from base: CGRect, by delta: CGSize, reach: CGFloat) -> [Snap.Guide] {
        guard item(id) != nil else { return [] }
        let asked = corner.rect(from: base, by: delta, least: leastSize(of: id))
        let guides = resizeSnapped(id, to: asked, reach: reach)
        guard let i = index(of: id) else { return guides }
        // A catch or the smallest size may have pushed the box: the corner that stays is put back.
        let held = corner.holding(corner.opposite.point(in: base), items[i].frame)
        guard held != items[i].frame else { return guides }
        items[i].frame = held
        return []
    }
}

// MARK: The small controls round one chosen thing

public enum Controls {
    /// A plus-handle at rest: a small outline dot. Screen points at 100 %.
    public static let dot: CGFloat = 10
    /// The same handle under the pointer, and always on a touch screen: it carries its plus sign.
    public static let plus: CGFloat = 18
    /// From the thing's box to the middle of a plus-handle.
    public static let reach: CGFloat = 17
    /// A size knob.
    public static let knob: CGFloat = 9
    /// Between a chosen thing's outline and the frame drawn round it.
    public static let frameGap: CGFloat = 3

    public enum Kind: Equatable, Sendable {
        case plus(Direction)
        case size(Corner)
    }

    /// One control, in board points.
    public struct Control: Equatable, Sendable {
        public var kind: Kind
        /// As it is drawn at rest.
        public var rest: CGRect
        /// As it is drawn under the pointer or on a touch screen (a knob is the same in both).
        public var grown: CGRect

        public func box(grown big: Bool) -> CGRect { big ? grown : rest }
    }

    /// Handles keep their size on screen when zoomed in and shrink a little when zoomed out.
    public static func shrink(_ scale: CGFloat) -> CGFloat { min(1, max(scale, 0.55)) }

    /// The sides of a thing that may carry a plus-handle at all.
    public static func plusSides(of item: Item, side: Side) -> [Direction] {
        switch item.kind {
        case .idea: return [item.parent == nil || side == .right ? .right : .left]
        case .frame, .bar, .milestone, .phase: return []
        case .text: return [.right, .down]
        default: return item.kind.isShape || item.kind == .note ? [.right, .down, .left, .up] : []
        }
    }

    /// The corners of a thing that carry a size knob: all four of a shape, a note, a frame and a sketch.
    /// Ideas and free text take the size of their words.
    public static func knobCorners(of kind: ItemKind) -> [Corner] {
        kind.isShape || kind == .note || kind == .frame || kind == .drawing ? Corner.allCases : []
    }

    private static func square(_ c: CGPoint, _ side: CGFloat) -> CGRect {
        CGRect(x: c.x - side / 2, y: c.y - side / 2, width: side, height: side)
    }

    /// The controls round one chosen thing, in board points. `scale`: screen points per board point.
    /// `taken`: the sides where an arrow already leaves or arrives — they get no plus-handle (a flow
    /// shape or note only; an idea keeps its one handle). `words`: the boxes of the words on arrows —
    /// a plus-handle never sits on one.
    public static func round(_ item: Item, side: Side, scale: CGFloat, taken: Set<Direction> = [], words: [CGRect] = []) -> [Control] {
        guard scale > 0 else { return [] }
        let k = shrink(scale) / scale
        let f = item.frame
        var found: [Control] = []
        for d in plusSides(of: item, side: side) {
            if item.kind != .idea, taken.contains(d) { continue }
            let c: CGPoint
            switch d {
            case .right: c = CGPoint(x: f.maxX + reach * k, y: f.midY)
            case .left: c = CGPoint(x: f.minX - reach * k, y: f.midY)
            case .down: c = CGPoint(x: f.midX, y: f.maxY + reach * k)
            case .up: c = CGPoint(x: f.midX, y: f.minY - reach * k)
            }
            let grown = square(c, plus * k)
            if words.contains(where: { $0.intersects(grown) }) { continue }
            found.append(Control(kind: .plus(d), rest: square(c, dot * k), grown: grown))
        }
        // The knobs sit on the corners of the frame drawn round the thing.
        let outer = f.insetBy(dx: -frameGap / scale, dy: -frameGap / scale)
        for corner in knobCorners(of: item.kind) {
            let box = square(corner.point(in: outer), knob * k)
            found.append(Control(kind: .size(corner), rest: box, grown: box))
        }
        return found
    }
}

public extension Board {
    /// The sides of a thing where an arrow already leaves or arrives.
    func sidesWithArrows(of id: UUID, arrows all: [UUID: Route.Arrow]? = nil) -> Set<Direction> {
        let all = all ?? arrows()
        var sides: Set<Direction> = []
        for link in links {
            guard let arrow = all[link.id] else { continue }
            if link.from == id { sides.insert(arrow.leaves) }
            if link.to == id { sides.insert(arrow.arrives) }
        }
        return sides
    }
}

public extension Route.Words {
    /// The box the words of an arrow fill, given their size.
    func box(for size: CGSize) -> CGRect {
        CGRect(x: leading ? at.x : at.x - size.width, y: above ? at.y - size.height : at.y, width: size.width, height: size.height)
    }
}

// MARK: Press and hold

public extension Fingers {
    /// A finger that rests this long without moving opens the menu of the thing under it.
    static let hold: Double = 0.5
    /// "Without moving": no further than this from where it landed (a press that moves is a drag).
    static let still: Double = 4
    /// With the menu open and the finger still down: moving further than this closes the menu and
    /// the press goes on as a drag.
    static let letGo: Double = 10

    /// True when a press that has lasted `seconds` and strayed `points` from its landing opens the menu.
    static func opensMenu(moved points: Double, after seconds: Double) -> Bool {
        seconds >= hold && points <= still
    }

    /// True when a finger that opened the menu has moved far enough to mean a drag after all.
    static func leavesMenu(moved points: Double) -> Bool { points > letGo }
}
