import Foundation
import CoreGraphics

/// 0.5: things land, lift, leave, make room and fold softly. The rules and the numbers live here; the app's
/// motion layer (BoardMotion.swift) only keeps the clock and hands the painter the board as it shows right now.
/// Nothing here is ever stored: the board file knows only the end state.
public enum Motion {
    /// A new thing grows from 92 % to 100 % and fades in.
    public static let lands = 0.16
    /// A removed thing fades out and shrinks to 94 %.
    public static let leaves = 0.12
    /// The shadow of a thing being dragged deepens, and goes back on the drop.
    public static let lifts = 0.10
    /// Things glide from the old place to the new one (a mind map laid out again, Line up, Even gaps, Same size, Undo, Redo).
    public static let makesRoom = 0.20
    /// The ideas under a folded idea slide into it and fade; unfolding is the reverse.
    public static let folds = 0.18

    /// Boards with more things than this stand still (no speed work is asked for).
    public static let most = 150

    /// Whether things on this board move softly at all: an ordinary board of at most 150 things.
    /// A timeline and a "Who does what" board place and draw their things themselves.
    public static func runs(on board: Board) -> Bool {
        !board.placesItself && board.items.count <= most
    }

    // MARK: Lands and leaves

    /// How a thing shows while it lands or leaves: its size (1 = its own) round its middle, and how strong it is drawn.
    public struct Look: Equatable, Sendable {
        public var size: Double
        public var strength: Double

        public init(size: Double = 1, strength: Double = 1) {
            self.size = size
            self.strength = strength
        }
    }

    /// A new thing, `part` of the way through its 0.16 s: from 92 % and unseen to 100 % and full.
    public static func landing(at part: Double) -> Look {
        let eased = Glide.ease(part)
        return Look(size: 0.92 + 0.08 * eased, strength: eased)
    }

    /// A removed thing, `part` of the way through its 0.12 s: from 100 % and full to 94 % and unseen.
    public static func leaving(at part: Double) -> Look {
        let eased = Glide.ease(part)
        return Look(size: 1 - 0.06 * eased, strength: 1 - eased)
    }

    // MARK: Lifts

    /// A shadow under a thing: how dark (0…1), how soft, how far down.
    public struct Shadow: Equatable, Sendable {
        public var dark: Double
        public var radius: Double
        public var down: Double

        public init(dark: Double, radius: Double, down: Double) {
            self.dark = dark
            self.radius = radius
            self.down = down
        }
    }

    /// A shape lying still, by day: black 6 %, radius 2, 1 down.
    public static let rest = Shadow(dark: 0.06, radius: 2, down: 1)
    /// A thing being dragged, by day: black 16 %, radius 8, 4 down.
    public static let lifted = Shadow(dark: 0.16, radius: 8, down: 4)
    /// By night shadows do not show on charcoal: the outline of a dragged thing is drawn 15 % lighter instead.
    public static let nightLift = 0.15

    /// The shadow of a thing that is `lift` of the way up (0 = lying still, 1 = in the hand).
    /// `rest`: the shadow it has lying still (nil: none). A shadow that is already darker stays as dark.
    public static func shadow(rest: Shadow?, lift: Double) -> Shadow {
        let from = rest ?? Shadow(dark: 0, radius: Motion.rest.radius, down: Motion.rest.down)
        let up = min(max(lift, 0), 1)
        let to = Shadow(dark: max(from.dark, lifted.dark), radius: max(from.radius, lifted.radius), down: max(from.down, lifted.down))
        return Shadow(dark: from.dark + (to.dark - from.dark) * up,
                      radius: from.radius + (to.radius - from.radius) * up,
                      down: from.down + (to.down - from.down) * up)
    }

    // MARK: Makes room

    /// Where a thing shows `part` of the way from its old place to its new one (ease-out).
    public static func between(_ from: CGRect, _ to: CGRect, at part: Double) -> CGRect {
        guard part < 1 else { return to }
        let eased = Glide.ease(part)
        func mix(_ a: CGFloat, _ b: CGFloat) -> Double { Double(a) + (Double(b) - Double(a)) * eased }
        return CGRect(x: mix(from.minX, to.minX), y: mix(from.minY, to.minY), width: mix(from.width, to.width), height: mix(from.height, to.height))
    }

    // MARK: What a change sets in motion

    /// An idea a fold just hid: the folded idea it slides into, and where it stood.
    public struct Into: Equatable, Sendable {
        public var idea: UUID
        public var stood: CGRect
    }

    /// What one change to the board sets in motion.
    public struct Plan: Equatable, Sendable {
        /// New things that show: they land.
        public var lands: Set<UUID> = []
        /// Things that are gone (as they were): they leave.
        public var leaves: [Item] = []
        /// Things that stand somewhere else or have another size: where each stood before.
        public var moves: [UUID: CGRect] = [:]
        /// Ideas a fold just hid.
        public var closes: [UUID: Into] = [:]
        /// Ideas an unfold just showed: the idea each slides out of.
        public var opens: [UUID: UUID] = [:]

        public init() {}

        public var isEmpty: Bool { lands.isEmpty && leaves.isEmpty && moves.isEmpty && closes.isEmpty && opens.isEmpty }
    }

    /// Compares the board before and after a change. `still`: things that must not glide (the one being typed in
    /// follows its typing field at once). Nothing moves on a board that is too big or places itself.
    public static func plan(from old: Board, to new: Board, still: Set<UUID> = []) -> Plan {
        var plan = Plan()
        guard runs(on: old), runs(on: new) else { return plan }
        let before = old.items.reduce(into: [UUID: Item]()) { $0[$1.id] = $1 }
        let after = new.items.reduce(into: [UUID: Item]()) { $0[$1.id] = $1 }
        let coveredBefore = covers(before), coveredAfter = covers(after)
        for item in new.items where !still.contains(item.id) {
            let cover = coveredAfter[item.id]
            guard let was = before[item.id] else {
                if cover == nil { plan.lands.insert(item.id) }
                continue
            }
            switch (coveredBefore[item.id], cover) {
            case (nil, nil):
                if differs(was.frame, item.frame) { plan.moves[item.id] = was.frame }
            case (nil, let into?):
                plan.closes[item.id] = Into(idea: into, stood: was.frame)
            case (let outOf?, nil):
                plan.opens[item.id] = outOf
            default:
                break
            }
        }
        for item in old.items where after[item.id] == nil && coveredBefore[item.id] == nil && !still.contains(item.id) {
            plan.leaves.append(item)
        }
        return plan
    }

    /// More than half a point apart in place or size.
    private static func differs(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) > 0.5 || abs(a.minY - b.minY) > 0.5 || abs(a.width - b.width) > 0.5 || abs(a.height - b.height) > 0.5
    }

    /// For every idea that a folded idea hides: the outermost folded idea above it (the one that still shows).
    private static func covers(_ items: [UUID: Item]) -> [UUID: UUID] {
        var out: [UUID: UUID] = [:]
        for item in items.values where item.kind == .idea && item.parent != nil {
            var cover: UUID?
            var up = item.parent
            var steps = 0
            while let id = up, let above = items[id], steps < 200 {
                if above.folded { cover = id }
                up = above.parent
                steps += 1
            }
            if let cover { out[item.id] = cover }
        }
        return out
    }
}
