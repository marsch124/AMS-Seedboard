import Foundation

// "As a project": which lines of a board become tasks in PARAGON, and which stay plain lines.
//
// Nothing ticked (no idea carries the To do tick): as it always was — every idea under a main
// branch and every flow shape becomes a task.
// At least one idea ticked: the ticks decide. A ticked idea or shape becomes a task, the others
// stay as plain lines in the same places.
//
// PARAGON hangs an indented task under the nearest task above it with less indent and passes over
// plain lines (TaskParser.parse(text:)). So a ticked idea is indented one step below the nearest
// TICKED idea above it in its branch, and stands at the left edge when there is none: it can
// never end up as a sub-task of a task it does not belong to.

extension ParagonExport {
    struct ProjectPlan {
        /// The ticks decide what becomes a task.
        var ticks = false
        /// Lines before the first heading: main branches with nothing under them, and ticked ones with their ideas.
        var loose: [String] = []
        /// One list per main branch that is a heading: the `###` line, then its ideas.
        var groups: [[String]] = []
        /// How many of the last `groups` are lanes (their lines are shapes, not ideas).
        var laneGroups = 0
        /// The flow shapes, in arrow order.
        var steps: [String] = []
        /// Notes and free text marked To do.
        var todo: [String] = []
        /// One list per named frame that holds such notes: the `###` line with the frame's name, then the notes in it.
        var framed: [[String]] = []
        /// The things that are tasks in these lines, and how many are plain lines because the Inbox has them.
        var made = Made()
    }

    /// True when at least one idea of the board carries the To do tick.
    public static func ticksDecide(_ board: Board) -> Bool {
        board.items.contains { $0.kind == .idea && $0.todo }
    }

    static func projectPlan(_ board: Board) -> ProjectPlan {
        var plan = ProjectPlan()
        // Every task line goes through `taskLine` (SendTasks.swift): it notes the thing down, and writes a
        // thing the Inbox already has as a plain line.
        // What stands before the first heading is noted down apart, so the list is in the text's order.
        var first = Made()
        var made = Made()
        plan.ticks = ticksDecide(board)
        for centre in board.mapCentres {
            // A ticked middle idea is a task as well as the project's outcome.
            if plan.ticks, centre.todo { plan.loose.append(taskLine(centre, label(centre), in: board, made: &first)) }
            for branch in board.children(of: centre.id) {
                let below = board.children(of: branch.id)
                if plan.ticks, branch.todo {
                    // A ticked main branch is a task, with its ideas below it.
                    let line = taskLine(branch, label(branch), in: board, made: &first)
                    plan.loose.append(line)
                    for idea in below {
                        plan.loose.append(contentsOf: mixedLines(of: idea, in: board, level: 1, taskLevel: isTaskLine(line) ? 1 : 0,
                                                                 ticks: true, made: &first))
                    }
                } else if below.isEmpty {
                    plan.loose.append(plan.ticks ? "- " + label(branch) : taskLine(branch, label(branch), in: board, made: &first))
                } else {
                    var group = ["### \(label(branch))"]
                    for idea in below {
                        group.append(contentsOf: mixedLines(of: idea, in: board, level: 0, taskLevel: 0, ticks: plan.ticks, made: &made))
                    }
                    plan.groups.append(group)
                }
            }
        }
        // A frame with lanes gives one group per lane; its shapes are then left out of the steps.
        let laned = laneTasks(board, ticks: plan.ticks, made: &made)
        plan.groups.append(contentsOf: laned.groups)
        plan.laneGroups = laned.groups.count
        // Notes and free text marked To do: those in a named frame under the frame's name, the others under "To do".
        let boxes = framed(board) { $0.todo && $0.kind != .idea && !$0.kind.isShape && !oneLine($0.text).isEmpty }
        for group in boxes.groups {
            var lines = ["### \(group.name)"]
            for thing in group.things { lines.append(taskLine(thing, oneLine(thing.text), in: board, made: &made)) }
            plan.framed.append(lines)
        }
        for shape in flowOrder(board) where !laned.used.contains(shape.id) {
            let words = oneLine(shape.text)
            if !words.isEmpty { plan.steps.append(plan.ticks && !shape.todo ? "- " + words : taskLine(shape, words, in: board, made: &made)) }
        }
        for thing in boxes.loose { plan.todo.append(taskLine(thing, oneLine(thing.text), in: board, made: &made)) }
        plan.made = Made(tasks: first.tasks + made.tasks, inInbox: first.inInbox + made.inInbox)
        return plan
    }

    /// An idea and everything under it. `ticks`: the ticks decide (only a ticked idea is a task); without, every
    /// idea is one. `level` is the indent of a plain line here, `taskLevel` the indent of a task here (one step
    /// below the nearest idea above that IS a task). An idea the Inbox already has is a plain line.
    private static func mixedLines(of item: Item, in board: Board, level: Int, taskLevel: Int, ticks: Bool,
                                   made: inout Made, depth: Int = 0) -> [String] {
        guard depth < 200 else { return [] }
        let wanted = !ticks || item.todo
        let task = wanted && !board.isInInbox(item.id)
        let mine = task ? taskLevel : level
        var lines = [wanted ? taskLine(item, label(item), in: board, indent: mine, made: &made)
                            : String(repeating: "  ", count: mine) + "- " + label(item)]
        for child in board.children(of: item.id) {
            lines.append(contentsOf: mixedLines(of: child, in: board, level: mine + 1,
                                                taskLevel: task ? mine + 1 : taskLevel, ticks: ticks, made: &made, depth: depth + 1))
        }
        return lines
    }

    // MARK: Counts, for the Send page

    /// How many lines of a project become tasks and how many stay plain.
    public struct ProjectTally: Equatable, Sendable {
        /// At least one idea is ticked: the ticks decide.
        public var ticks: Bool
        /// Ideas that become tasks / stay as plain lines.
        public var ideaTasks: Int
        public var ideaPlain: Int
        /// Flow shapes that become tasks / stay as plain lines.
        public var shapeTasks: Int
        public var shapePlain: Int
        /// Notes and free text marked To do (always tasks).
        public var otherTasks: Int
        /// Something on the board is ticked, whatever it is.
        public var anyTick: Bool
    }

    public static func projectTally(board: Board) -> ProjectTally {
        let plan = projectPlan(board)
        func isTask(_ line: String) -> Bool { isTaskLine(line) }
        // The ideas stand in the loose lines and the branch groups; the lanes hold shapes, as the steps do.
        let ideas = plan.loose + plan.groups.dropLast(plan.laneGroups).flatMap { $0.dropFirst() }
        let shapes = plan.steps + plan.groups.suffix(plan.laneGroups).flatMap { $0.dropFirst() }
        let ideaTasks = ideas.filter(isTask).count
        let shapeTasks = shapes.filter(isTask).count
        return ProjectTally(ticks: plan.ticks, ideaTasks: ideaTasks, ideaPlain: ideas.count - ideaTasks,
                            shapeTasks: shapeTasks, shapePlain: shapes.count - shapeTasks,
                            otherTasks: (plan.todo + plan.framed.flatMap { $0.dropFirst() }).filter(isTask).count, anyTick: board.items.contains { $0.todo })
    }

    /// One plain line for the Send page that says what "As a project" makes of this board:
    /// "3 ticked ideas become tasks, 9 stay as plain lines." or
    /// "Nothing is ticked: all 12 ideas become tasks." nil when the project would hold no such lines.
    public static func projectLine(board: Board) -> String? {
        if board.isSequence { return sequenceProjectLine(board) }
        if board.isTimeline { return timelineProjectLine(board) }
        let t = projectTally(board: board)
        if t.ticks {
            let tasks = t.ideaTasks + t.shapeTasks + t.otherTasks
            let plain = t.ideaPlain + t.shapePlain
            let what = t.shapeTasks + t.otherTasks == 0 ? "idea" : "thing"
            var line = tasks == 1 ? "1 ticked \(what) becomes a task" : "\(tasks) ticked \(what)s become tasks"
            if plain == 1 { line += ", 1 stays as a plain line" }
            if plain > 1 { line += ", \(plain) stay as plain lines" }
            return line + "."
        }
        var parts: [String] = []
        if t.ideaTasks > 0 { parts.append(t.ideaTasks == 1 ? "1 idea" : "\(t.ideaTasks) ideas") }
        if t.shapeTasks > 0 { parts.append(t.shapeTasks == 1 ? "1 shape" : "\(t.shapeTasks) shapes") }
        guard !parts.isEmpty else { return nil }
        let start = t.anyTick ? "No idea is ticked" : "Nothing is ticked"
        if t.ideaTasks + t.shapeTasks == 1 { return "\(start): the \(parts[0]) becomes a task." }
        return "\(start): all \(parts.joined(separator: " and ")) become tasks."
    }
}

// Sending one branch only.

public extension Board {
    /// The words of an idea as one line; empty when it has none.
    func branchName(_ id: UUID) -> String { ParagonExport.oneLine(item(id)?.text ?? "") }

    /// A board that holds just one idea and everything under it, as a small map of its own, for
    /// sending that branch alone. It keeps the board's identity (the link back opens the whole
    /// board) and the list of ticks already sent; it carries no "sent" mark. The idea becomes the
    /// middle, the ideas under it keep the colour their branch had, the name is the idea's words.
    func branchOnly(_ id: UUID) -> Board? {
        guard let root = item(id), root.kind == .idea else { return nil }
        let keep = Set(descendants(of: id)).union([id])
        var part = self
        let name = branchName(id)
        if !name.isEmpty { part.title = name }
        part.sent = nil
        // A tick kept by 0.4 on a board that went to PARAGON as a note or a project may stand in that note. In
        // the branch (which carries no "sent" mark) it must not be taken for an Inbox one (`isInInbox`).
        if sent != nil {
            for id in sentTodos where keep.contains(id) && sentTask(id) == nil {
                part.sentTasks.append(SentTask(id: id, words: "", place: SentTask.note))
            }
        }
        part.items = items.filter { keep.contains($0.id) }
        part.links = links.filter { keep.contains($0.from) && keep.contains($0.to) }
        if root.parent != nil, let r = part.index(of: id) {
            let colour = branchColour(of: id)
            part.items[r].parent = nil
            part.items[r].colour = ""
            part.items[r].side = nil
            part.items[r].bothSides = false
            for child in part.children(of: id) {
                guard let c = part.index(of: child.id) else { continue }
                part.items[c].side = nil
                if part.items[c].colour.isEmpty { part.items[c].colour = colour }
            }
        }
        part.layoutMaps()
        return part
    }
}
