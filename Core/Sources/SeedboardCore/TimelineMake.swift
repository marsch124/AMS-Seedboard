import Foundation
import CoreGraphics

// 0.5, pick 15: from "what" to "when" without typing anything twice.
//
// "Make a timeline of it" makes a NEW timeline board from an ordinary board; the board itself stays as it
// is. It is the mirror of the project rule (ProjectPlan.swift), so the two can never disagree: whatever
// "As a project" would make a task becomes a bar, and whatever it would make a `###` heading becomes a phase.
//
//   - a main branch with ideas under it        → a phase with its name
//   - an idea that would become a task          → a bar under that phase, in the map's order, deeper ideas
//                                                 right after the idea they hang under
//   - a main branch with nothing under it, a ticked main branch with its ticked ideas,
//     a note or a text marked To do             → bars above the first phase
//   - a flow shape                              → a bar; an arrow between two shapes → "comes after"
//   - a lane of a frame with lanes              → a phase with the lane's shapes as bars
//
// The ticks decide exactly as for a project: nothing ticked → every idea and every shape; at least one
// idea ticked → only what is ticked. With things chosen, the choice decides instead: the chosen ideas with
// everything under them, the chosen shapes, notes and texts.
//
// Every bar is 7 days long and starts today. Inside a phase, and among the bars above the first phase, each
// bar comes after the one before it; shapes follow their arrows; the phases start together.
//
// Pasting a list onto a timeline uses the same bricks: one bar per line, 7 days each, in a chain; a line
// with indented lines under it is a phase.

/// What "Make a timeline of it" made.
public struct TimelineMade: Equatable, Sendable {
    /// The new timeline board, "<name> timeline".
    public var board: Board
    public var bars: Int
    public var phases: Int
    /// Ideas, shapes, notes and texts with words that did not become a bar or a phase and stay only on the board.
    public var stayed: Int
    /// The To do ticks decided what became a bar (at least one idea is ticked, and nothing was chosen).
    public var ticks = false

    /// "12 bars in 3 phases. Drag them to their days." — or, when something stayed behind,
    /// "12 bars in 3 phases. 5 things stayed on the board." — and when the ticks decided,
    /// "4 bars in 2 phases. 5 things without a tick stayed on the board."
    public var line: String {
        var words = bars == 1 ? "1 bar" : "\(bars) bars"
        if phases > 0 { words += phases == 1 ? " in 1 phase" : " in \(phases) phases" }
        if stayed == 0 { return words + (bars == 1 ? ". Drag it to its days." : ". Drag them to their days.") }
        let what = (stayed == 1 ? "1 thing" : "\(stayed) things") + (ticks ? " without a tick" : "")
        return "\(words). \(what) stayed on the board."
    }
}

/// What a pasted list became on a timeline.
public struct BarsPasted: Equatable, Sendable {
    /// The new bars, in the order of the list.
    public var bars: [UUID]
    public var phases: Int

    /// "5 bars pasted." / "7 bars in 2 phases pasted."
    public var line: String {
        var words = bars.count == 1 ? "1 bar" : "\(bars.count) bars"
        if phases > 0 { words += phases == 1 ? " in 1 phase" : " in \(phases) phases" }
        return words + " pasted."
    }
}

public extension Board {
    /// How long a bar is that was made from an idea, a shape or a pasted line.
    static let madeBarDays = 7

    /// The name a timeline made of this board gets.
    var timelineTitle: String { "\(title) timeline" }

    /// True when "Make a timeline of it" would make at least one bar.
    func canBecomeTimeline(chosen: Set<UUID> = []) -> Bool {
        timelineOfIt(chosen: chosen, today: Day(number: 0)) != nil
    }

    /// The timeline of this board (see the top of this file). nil for a board that is a timeline or a
    /// "Who does what" board already, and when nothing would become a bar.
    func timelineOfIt(chosen: Set<UUID> = [], today: Day, now: Date = Date()) -> TimelineMade? {
        guard !placesItself else { return nil }

        // With things chosen the choice decides: the chosen ideas with all that hangs under them, and the
        // chosen shapes, notes and texts.
        func canBeBar(_ item: Item) -> Bool { item.kind == .idea || item.kind.isShape || item.kind == .note || item.kind == .text }
        var only: Set<UUID>?
        let picked = chosen.filter { item($0).map(canBeBar) ?? false }
        if !picked.isEmpty {
            var all = picked
            for id in picked where item(id)?.kind == .idea { all.formUnion(descendants(of: id)) }
            only = all
        }
        let ticks = only == nil && ParagonExport.ticksDecide(self)
        func wanted(_ item: Item) -> Bool {
            if let only { return only.contains(item.id) }
            return !ticks || item.todo
        }

        /// An idea and everything under it, the idea first, each idea followed by what hangs under it.
        func deep(_ item: Item, depth: Int = 0) -> [Item] {
            guard depth < 200 else { return [] }
            return [item] + children(of: item.id).flatMap { deep($0, depth: depth + 1) }
        }

        // What becomes what, in the project's own order.
        var loose: [Item] = []
        var groups: [(name: String, colour: String, source: UUID?, bars: [Item])] = []
        for centre in mapCentres {
            // A ticked middle idea is a task of the project, so it is a bar here.
            if ticks, centre.todo { loose.append(centre) }
            for branch in children(of: centre.id) {
                let below = children(of: branch.id)
                if below.isEmpty {
                    if wanted(branch) { loose.append(branch) }
                } else if ticks, branch.todo {
                    loose.append(branch)
                    loose.append(contentsOf: below.flatMap { deep($0) }.filter(wanted))
                } else {
                    let bars = below.flatMap { deep($0) }.filter(wanted)
                    if !bars.isEmpty {
                        groups.append((ParagonExport.oneLine(branch.text), branchColour(of: branch.id), branch.id, bars))
                    }
                }
            }
        }
        // A frame with lanes gives one phase per lane; its shapes are then not listed again as steps.
        var laned = Set<UUID>()
        for list in ParagonExport.laneLists(self) {
            for lane in list.lanes {
                let shapes = lane.things.filter { $0.kind.isShape }
                guard !shapes.isEmpty else { continue }
                laned.formUnion(shapes.map(\.id))
                let bars = shapes.filter(wanted)
                if !bars.isEmpty {
                    groups.append((list.frame.isEmpty ? lane.name : "\(list.frame): \(lane.name)", "", nil, bars))
                }
            }
        }
        let steps = ParagonExport.flowOrder(self).filter {
            !laned.contains($0.id) && !ParagonExport.oneLine($0.text).isEmpty && wanted($0)
        }
        // Notes and free text: the ones marked To do — or, with a choice, the chosen ones.
        loose.append(contentsOf: items.filter { item in
            (item.kind == .note || item.kind == .text) && !ParagonExport.oneLine(item.text).isEmpty
                && (only.map { $0.contains(item.id) } ?? item.todo)
        })

        // The new board: the bars above the first phase, then the steps, then the phases.
        var made = Board.timeline(title: timelineTitle, created: now)
        var barOf: [UUID: UUID] = [:]
        func bar(_ source: Item, colour: String, into board: inout Board) -> UUID {
            let id = board.addBar(ParagonExport.oneLine(source.text), start: today, days: Board.madeBarDays, colour: colour)
            if source.todo, let i = board.index(of: id) { board.items[i].todo = true }
            barOf[source.id] = id
            return id
        }
        func chain(_ sources: [Item], colour: (Item) -> String, into board: inout Board) {
            var last: UUID?
            for source in sources {
                let id = bar(source, colour: colour(source), into: &board)
                if let last { board.comesAfter(id, after: last) }
                last = id
            }
        }
        chain(loose, colour: { $0.kind == .idea ? self.branchColour(of: $0.id) : $0.colour }, into: &made)
        for step in steps { _ = bar(step, colour: step.colour, into: &made) }
        var headings = Set<UUID>()
        for group in groups {
            made.addPhase(group.name, colour: group.colour)
            if let source = group.source { headings.insert(source) }
            if group.source == nil {
                // A lane's shapes follow their arrows, like every shape.
                for shape in group.bars { _ = bar(shape, colour: shape.colour, into: &made) }
            } else {
                chain(group.bars, colour: { _ in group.colour }, into: &made)
            }
        }
        // An arrow from one shape to another: the second comes after the first. A shape that did not become
        // a bar is passed over, so the order it stood in is kept.
        for shape in ParagonExport.flowOrder(self) {
            guard let follower = barOf[shape.id] else { continue }
            var seen: Set<UUID> = [shape.id]
            var work = links.filter { $0.to == shape.id }.map(\.from)
            while let id = work.popLast() {
                guard seen.insert(id).inserted, let before = item(id), before.kind.isShape else { continue }
                if let forerunner = barOf[id] {
                    made.comesAfter(follower, after: forerunner)
                } else {
                    work.append(contentsOf: links.filter { $0.to == id }.map(\.from))
                }
            }
        }

        guard !barOf.isEmpty else { return nil }
        // What stayed behind: ideas, shapes, notes and texts with words that are neither a bar nor a phase
        // (the middle idea is the board's subject and is not counted). With a choice: only among the chosen.
        let stayed = items.filter { item in
            canBeBar(item) && !ParagonExport.oneLine(item.text).isEmpty && barOf[item.id] == nil
                && !headings.contains(item.id) && !(item.kind == .idea && item.parent == nil)
                && (only.map { $0.contains(item.id) } ?? true)
        }.count
        return TimelineMade(board: made, bars: barOf.count, phases: groups.count, stayed: stayed, ticks: ticks)
    }

    /// A list pasted onto a timeline: one bar per line, 7 days each, each coming after the one before; a
    /// line with indented lines under it is a phase, and every line under it a bar of that phase.
    /// With a row chosen the bars go right under it — and when that row is a bar or a milestone, the chain
    /// goes on from it (the first new bar comes after it, as Return does). Without, they go under the last
    /// row and start today. New phases go where they split no phase that is there: after the rows of the
    /// chosen row's phase. nil when there is nothing to paste.
    @discardableResult
    mutating func pasteBars(_ nodes: [OutlineNode], under chosen: UUID? = nil, today: Day) -> BarsPasted? {
        guard isTimeline, canBeChanged else { return nil }
        func name(_ node: OutlineNode) -> String { ParagonExport.oneLine(node.text) }
        func deep(_ node: OutlineNode, depth: Int = 0) -> [OutlineNode] {
            guard depth < 200 else { return [] }
            return [node] + node.children.flatMap { deep($0, depth: depth + 1) }
        }
        let lines = nodes.filter { $0.children.isEmpty && !name($0).isEmpty }
        let groups = nodes.filter { !$0.children.isEmpty }
        guard !lines.isEmpty || !groups.isEmpty else { return nil }

        let anchor = chosen.flatMap { item($0) }
        let first = anchor?.span.map { $0.end + 1 } ?? today
        var row = chosen.flatMap { timelineRow(of: $0) }.map { $0 + 1 }
        var bars: [UUID] = []
        var last = anchor?.span == nil ? nil : anchor?.id
        for line in lines {
            let id = addBar(name(line), start: first, days: Board.madeBarDays, atRow: row)
            if let last { comesAfter(id, after: last) }
            last = id
            bars.append(id)
            row = row.map { $0 + 1 }
        }
        // The phases: after the rows of the phase the bars went into (or at the very end).
        var at: Int?
        if let row {
            let rows = timelineRows
            at = rows.indices.first { $0 >= row && rows[$0].kind == .phase } ?? rows.count
        }
        for group in groups {
            let phase = addPhase(name(group), atRow: at)
            at = at.map { $0 + 1 }
            let colour = item(phase)?.colour ?? ""
            var before: UUID?
            for line in group.children.flatMap({ deep($0) }) where !name(line).isEmpty {
                let id = addBar(name(line), start: first, days: Board.madeBarDays, atRow: at, colour: colour)
                if let before { comesAfter(id, after: before) }
                before = id
                bars.append(id)
                at = at.map { $0 + 1 }
            }
        }
        return BarsPasted(bars: bars, phases: groups.count)
    }
}
