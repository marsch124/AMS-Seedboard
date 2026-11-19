import SwiftUI
import QuartzCore
import SeedboardCore

// 0.5, pick 3: things land, lift, leave, make room and fold softly. A small motion layer between the session
// and the painter: it remembers what a change set in motion (the rule: `Motion.plan` in the Core) and hands the
// painter the board AS IT SHOWS RIGHT NOW — things on their way stand between the old place and the new one,
// things that just left are still there for a moment. At rest it hands on the board itself and costs nothing.
// The board that is stored, sent to PARAGON, shared and drawn small never knows about any of this: those
// painters get the real board and no motion, so they always draw the end state.
// Off with "Reduce Motion", in screen tests and pictures (`Feel.moves`), on boards over 150 things, and on
// boards that place themselves.

/// What the painter needs besides the board: how strong and how big a thing on its way is drawn, and what is lifted.
struct MotionLooks {
    /// Things that land, leave, or slide into or out of a folded idea.
    var looks: [UUID: Motion.Look] = [:]
    /// Things in the hand (being dragged), and how far up they are (0 = lying still, 1 = up).
    var lifted: Set<UUID> = []
    var lift: Double = 0
}

/// The board as it shows right now.
struct MotionShow {
    var board: Board
    var facts: MapFacts
    var looks = MotionLooks()
}

/// The motion of one open board: the glide of its view (BoardGlide.swift) and the things on their way.
@MainActor
final class BoardMotion {
    /// Whether anything may move at all right now.
    static var on: Bool { Feel.moves || demo }

    #if DEBUG
    /// For pictures of a motion half-way: `-motionTry <what>` runs one change 0.8 s after the board shows (with
    /// `-sampleData` too), `-motionFreeze 0.5` holds every motion at that part of its time.
    static let demo = LaunchOptions.arguments.contains("-motionTry")
    static let frozen: Double? = LaunchOptions.value(for: "-motionFreeze").flatMap { Double($0) }
    var tried = false
    #else
    static let demo = false
    static let frozen: Double? = nil
    #endif

    // The view.
    var glide: (plan: Glide, began: Double)?
    /// A glide's own move is being made: moves inside it are plain moves.
    var inMove = false
    let clock = FrameClock()
    /// The time of the frame being drawn.
    var now = CACurrentMediaTime()

    // The things.
    private var lands: [UUID: Double] = [:]
    private var leaves: [(item: Item, began: Double)] = []
    private var moves: [UUID: (from: CGRect, began: Double)] = [:]
    private var closes: [UUID: (into: Motion.Into, began: Double)] = [:]
    private var opens: [UUID: (outOf: UUID, began: Double)] = [:]
    private var lifted: Set<UUID> = []
    private var liftFrom = 0.0
    private var liftTo = 0.0
    private var liftBegan = 0.0
    private var cached: MotionShow?

    /// How far through its time something is that began at `began` (1 or more: it has arrived).
    func part(since began: Double, of seconds: Double) -> Double {
        if let frozen = BoardMotion.frozen { return frozen }
        return seconds > 0 ? (now - began) / seconds : 1
    }

    /// Things stand between two places right now.
    var moving: Bool { !(moves.isEmpty && closes.isEmpty && opens.isEmpty) }

    private var onTheirWay: Bool { moving || !lands.isEmpty || !leaves.isEmpty }

    private var liftAmount: Double {
        liftFrom + (liftTo - liftFrom) * Glide.ease(part(since: liftBegan, of: Motion.lifts))
    }

    /// Something still needs the clock.
    var animating: Bool {
        onTheirWay || (!lifted.isEmpty && (liftTo == 0 || part(since: liftBegan, of: Motion.lifts) < 1))
    }

    func forget() { cached = nil }

    /// Lets go of what has arrived.
    func prune() {
        cached = nil
        lands = lands.filter { part(since: $0.value, of: Motion.lands) < 1 }
        leaves.removeAll { part(since: $0.began, of: Motion.leaves) >= 1 }
        moves = moves.filter { part(since: $0.value.began, of: Motion.makesRoom) < 1 }
        closes = closes.filter { part(since: $0.value.began, of: Motion.folds) < 1 }
        opens = opens.filter { part(since: $0.value.began, of: Motion.folds) < 1 }
        if liftTo == 0, part(since: liftBegan, of: Motion.lifts) >= 1 { lifted = [] }
    }

    /// The board changed (not under a finger): what lands, leaves, makes room and folds starts now.
    func note(from old: Board, to new: Board, still: Set<UUID>) {
        cached = nil
        guard Motion.runs(on: new) else {
            lands = [:]; leaves = []; moves = [:]; closes = [:]; opens = [:]; lifted = []
            return
        }
        for id in still { moves[id] = nil }
        let plan = Motion.plan(from: old, to: new, still: still)
        guard !plan.isEmpty else { return }
        // A thing still on its way goes on from where it shows.
        var starts = plan.moves
        for (id, stood) in plan.moves {
            if let run = moves[id] { starts[id] = Motion.between(run.from, stood, at: part(since: run.began, of: Motion.makesRoom)) }
        }
        now = CACurrentMediaTime()
        for (id, from) in starts { moves[id] = (from, now) }
        for id in plan.lands { lands[id] = now }
        for item in plan.leaves {
            leaves.append((item, now))
            lands[item.id] = nil
            moves[item.id] = nil
        }
        for (id, into) in plan.closes {
            closes[id] = (into, now)
            opens[id] = nil
            moves[id] = nil
        }
        for (id, outOf) in plan.opens {
            opens[id] = (outOf, now)
            closes[id] = nil
        }
        if !leaves.isEmpty {
            // A thing that came back (Undo) is no longer leaving.
            let here = Set(new.items.map(\.id))
            leaves.removeAll { here.contains($0.item.id) }
        }
    }

    /// Under a finger: what the drag carries (it stands somewhere else than when the drag began, at the same size) is lifted.
    func lift(from base: Board, to board: Board) {
        guard Motion.runs(on: board), base.items.count == board.items.count else { return }
        var up: Set<UUID> = []
        for (was, item) in zip(base.items, board.items) where was.id == item.id {
            if (was.x != item.x || was.y != item.y) && was.w == item.w && was.h == item.h { up.insert(item.id) }
        }
        guard !up.isEmpty else { return }
        cached = nil
        // Where the shadow stands now is where it goes on from (a thing picked up again while it settles).
        let amount = lifted.isEmpty ? 0 : liftAmount
        lifted.formUnion(up)
        // In the hand a thing follows the finger at once.
        for id in up { moves[id] = nil }
        if liftTo != 1 {
            now = CACurrentMediaTime()
            liftFrom = amount
            liftTo = 1
            liftBegan = now
        }
    }

    /// The drag ended: the shadow goes back.
    func drop() {
        guard !lifted.isEmpty, liftTo != 0 else { return }
        let amount = liftAmount
        now = CACurrentMediaTime()
        liftFrom = amount
        liftTo = 0
        liftBegan = now
        cached = nil
    }

    /// The board as it shows at this frame. At rest: the board itself.
    func show(_ board: Board, _ facts: MapFacts) -> MotionShow {
        var looks = MotionLooks()
        if !lifted.isEmpty {
            looks.lifted = lifted
            looks.lift = liftAmount
        }
        guard onTheirWay else { return MotionShow(board: board, facts: facts, looks: looks) }
        if let cached { return cached }
        var copy = board
        var at: [UUID: Int] = [:]
        for (n, item) in copy.items.enumerated() { at[item.id] = n }
        func place(_ n: Int, _ box: CGRect) {
            copy.items[n].x = Double(box.minX)
            copy.items[n].y = Double(box.minY)
            copy.items[n].w = Double(box.width)
            copy.items[n].h = Double(box.height)
        }
        /// A box of this size round the middle of another thing.
        func inside(_ home: CGRect, size: CGSize) -> CGRect {
            CGRect(x: home.midX - size.width / 2, y: home.midY - size.height / 2, width: size.width, height: size.height)
        }
        for (id, run) in moves {
            guard let n = at[id] else { continue }
            place(n, Motion.between(run.from, copy.items[n].frame, at: part(since: run.began, of: Motion.makesRoom)))
        }
        for (id, began) in lands where at[id] != nil {
            looks.looks[id] = Motion.landing(at: part(since: began, of: Motion.lands))
        }
        for (id, run) in opens {
            guard let n = at[id], let home = at[run.outOf] else { continue }
            let part = part(since: run.began, of: Motion.folds)
            let own = copy.items[n].frame
            place(n, Motion.between(inside(copy.items[home].frame, size: own.size), own, at: part))
            looks.looks[id] = Motion.Look(size: 1, strength: Glide.ease(part))
        }
        for (id, run) in closes {
            guard let n = at[id], let home = at[run.into.idea] else { continue }
            let part = part(since: run.began, of: Motion.folds)
            // Until they are inside, the folded idea still shows what is under it.
            copy.items[home].folded = false
            place(n, Motion.between(run.into.stood, inside(copy.items[home].frame, size: run.into.stood.size), at: part))
            looks.looks[id] = Motion.Look(size: 1, strength: 1 - Glide.ease(part))
        }
        for run in leaves where at[run.item.id] == nil {
            copy.items.append(run.item)
            looks.looks[run.item.id] = Motion.leaving(at: part(since: run.began, of: Motion.leaves))
        }
        let show = MotionShow(board: copy, facts: MapFacts(copy), looks: looks)
        cached = show
        return show
    }
}

// MARK: The session's side

extension BoardSession {
    /// Called just before the board changes to `new` (`set` in BoardSession.swift). `live`: under a finger.
    func noteMotion(to new: Board, live: Bool) {
        motion.forget()
        guard !live, BoardMotion.on else { return }
        motion.note(from: board, to: new, still: editing.map { [$0] } ?? [])
        if motion.animating { startMotionClock() }
    }

    /// A step of a drag was drawn: what it carries is lifted.
    func motionLift(since base: Board?) {
        guard BoardMotion.on, let base else { return }
        motion.lift(from: base, to: board)
        if motion.animating { startMotionClock() }
    }

    /// The drag ended.
    func motionDrop() {
        motion.drop()
        if motion.animating { startMotionClock() }
    }

    /// The board as it shows right now — what the live painter draws.
    var shownNow: MotionShow { motion.show(board, facts) }

    /// A thing where it shows right now (the frame round a chosen thing and its knobs follow it on its way).
    func shownThing(_ id: UUID) -> Item? {
        motion.moving ? shownNow.board.item(id) : board.item(id)
    }

    #if DEBUG
    /// For pictures: `-motionTry zoom | fit | add | child | remove | fold | move | lift` (with `-pick <word>` where a
    /// thing must be chosen), once, 0.8 s after the board shows.
    func motionTryOnce() {
        guard BoardMotion.demo, !motion.tried, let what = LaunchOptions.value(for: "-motionTry") else { return }
        motion.tried = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            let chosen = self.board.carried(by: self.selection)
            switch what {
            case "zoom": self.zoomStep(by: 1.25)
            case "fit":
                self.zoom(to: 2)
                self.fit()
            case "add": self.change { _ = $0.add(.box, centre: self.visibleCentre) }
            case "child": if let id = self.selection.first { self.addChild(of: id) }
            case "remove": self.deleteSelection()
            case "fold": self.toggleFold()
            case "move": self.change { $0.move(chosen, by: CGSize(width: 160, height: 90)) }
            case "lift":
                self.liveStart()
                _ = self.liveMove(chosen, by: CGSize(width: 60, height: 40), reach: 0)
            default: break
            }
        }
    }
    #endif
}

// MARK: The painter's side

extension BoardPainter {
    /// How far up a thing is (0 = lying still).
    private func lift(of item: Item) -> Double {
        motion.lift > 0 && motion.lifted.contains(item.id) ? motion.lift : 0
    }

    /// Things that have a body to lift (words alone, a sketch's lines and a frame have none).
    private func hasBody(_ item: Item) -> Bool {
        switch item.kind {
        case .box, .round, .diamond, .oval, .door, .person, .document, .slanted, .store, .note, .picture: return true
        case .idea: return (facts.depth[item.id] ?? 0) == 0
        default: return false
        }
    }

    /// The shadow a shape or a sticky note draws under itself: its own lying still, deeper in the hand.
    func liftShadow(of item: Item, rest: Motion.Shadow) -> GraphicsContext.Filter {
        let ownShadow = item.kind == .box || item.kind == .round || item.kind == .diamond || item.kind == .oval || item.kind == .note
        let s = Motion.shadow(rest: rest, lift: ownShadow ? lift(of: item) : 0)
        return .shadow(color: .black.opacity(s.dark), radius: s.radius, x: 0, y: s.down)
    }

    /// The context for a thing that lands, leaves or folds: fainter, and smaller round its middle.
    func motionLayer(_ ctx: GraphicsContext, for item: Item) -> GraphicsContext {
        guard let look = motion.looks[item.id] else { return ctx }
        var layer = ctx
        layer.opacity *= look.strength
        if look.size != 1 {
            let c = item.centre
            layer.translateBy(x: c.x, y: c.y)
            layer.scaleBy(x: look.size, y: look.size)
            layer.translateBy(x: -c.x, y: -c.y)
        }
        return layer
    }

    /// Draws one thing as it shows right now.
    func drawInMotion(_ item: Item, _ ctx: inout GraphicsContext) {
        var layer = turned(motionLayer(ctx, for: item), item)
        let up = lift(of: item)
        guard up > 0, hasBody(item) else { drawItem(item, &layer); return }
        if paint.night {
            // Shadows do not show on charcoal: the outline is drawn 15 % lighter instead. No glow.
            drawItem(item, &layer)
            let outline = item.kind == .door ? Path(roundedRect: item.frame, cornerRadius: 9)
                : ChosenOutline.path(of: item, depth: facts.depth[item.id] ?? 0, gap: 0)
            layer.stroke(outline, with: .color(.white.opacity(Motion.nightLift * up)),
                         style: StrokeStyle(lineWidth: item.colour.isEmpty ? 1.4 : 1.8, lineJoin: .round))
        } else if item.kind == .box || item.kind == .round || item.kind == .diamond || item.kind == .oval || item.kind == .note {
            // These deepen the shadow they already have (`liftShadow`).
            drawItem(item, &layer)
        } else {
            // A thing without a shadow of its own gets one while it is in the hand.
            let s = Motion.shadow(rest: nil, lift: up)
            var shaded = layer
            shaded.addFilter(.shadow(color: .black.opacity(s.dark), radius: s.radius, x: 0, y: s.down))
            shaded.drawLayer { inner in drawItem(item, &inner) }
        }
    }
}
