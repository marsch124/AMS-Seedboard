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
        /// The flow shapes, in arrow order.
        var steps: [String] = []
        /// Notes and free text marked To do.
        var todo: [String] = []
    }

    /// True when at least one idea of the board carries the To do tick.
    public static func ticksDecide(_ board: Board) -> Bool {
        board.items.contains { $0.kind == .idea && $0.todo }
    }

    static func projectPlan(_ board: Board) -> ProjectPlan {
        var plan = ProjectPlan()
        plan.ticks = ticksDecide(board)
        for centre in board.mapCentres {
            // A ticked middle idea is a task as well as the project's outcome.
            if plan.ticks, centre.todo { plan.loose.append("- [ ] \(label(centre))") }
            for branch in board.children(of: centre.id) {
                let below = board.children(of: branch.id)
                if plan.ticks, branch.todo {
                    // A ticked main branch is a task, with its ideas below it.
                    plan.loose.append("- [ ] \(label(branch))")
                    for idea in below {
                        plan.loose.append(contentsOf: mixedLines(of: idea, in: board, level: 1, taskLevel: 1))
                    }
                } else if below.isEmpty {
                    plan.loose.append((plan.ticks ? "- " : "- [ ] ") + label(branch))
                } else {
                    var group = ["### \(label(branch))"]
                    for idea in below {
                        group.append(contentsOf: plan.ticks
                            ? mixedLines(of: idea, in: board, level: 0, taskLevel: 0)
                            : taskLines(of: idea, in: board, level: 0))
                    }
                    plan.groups.append(group)
                }
            }
        }
        // A frame with lanes gives one group per lane; its shapes are then left out of the steps.
        let laned = laneTasks(board, ticks: plan.ticks)
        plan.groups.append(contentsOf: laned.groups)
        for shape in flowOrder(board) where !laned.used.contains(shape.id) {
            let words = oneLine(shape.text)
            if !words.isEmpty { plan.steps.append((plan.ticks && !shape.todo ? "- " : "- [ ] ") + words) }
        }
        plan.todo = board.items.filter { $0.todo && $0.kind != .idea && !$0.kind.isShape && !oneLine($0.text).isEmpty }
            .map { "- [ ] \(oneLine($0.text))" }
        return plan
    }

    /// An idea and everything under it when the ticks decide. `level` is the indent of a plain line
    /// here, `taskLevel` the indent of a task here (one step below the nearest ticked idea above).
    private static func mixedLines(of item: Item, in board: Board, level: Int, taskLevel: Int, depth: Int = 0) -> [String] {
        guard depth < 200 else { return [] }
        let mine = item.todo ? taskLevel : level
        var lines = [String(repeating: "  ", count: mine) + (item.todo ? "- [ ] " : "- ") + label(item)]
        for child in board.children(of: item.id) {
            lines.append(contentsOf: mixedLines(of: child, in: board, level: mine + 1,
                                                taskLevel: item.todo ? mine + 1 : taskLevel, depth: depth + 1))
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
        func isTask(_ line: String) -> Bool { line.drop { $0 == " " }.hasPrefix("- [ ] ") }
        let ideas = plan.loose + plan.groups.flatMap { $0.dropFirst() }
        let ideaTasks = ideas.filter(isTask).count
        let shapeTasks = plan.steps.filter(isTask).count
        return ProjectTally(ticks: plan.ticks, ideaTasks: ideaTasks, ideaPlain: ideas.count - ideaTasks,
                            shapeTasks: shapeTasks, shapePlain: plan.steps.count - shapeTasks,
                            otherTasks: plan.todo.count, anyTick: board.items.contains { $0.todo })
    }

    /// One plain line for the Send page that says what "As a project" makes of this board:
    /// "3 ticked ideas become tasks, 9 stay as plain lines." or
    /// "Nothing is ticked: all 12 ideas become tasks." nil when the project would hold no such lines.
    public static func projectLine(board: Board) -> String? {
        if board.isSequence { return sequenceProjectLine(board) }
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
