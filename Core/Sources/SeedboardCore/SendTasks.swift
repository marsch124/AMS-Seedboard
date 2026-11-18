import Foundation

// 0.5, the `send` lane: what a hand-over to PARAGON makes a TASK of, thing by thing.
//
// Every note, project and Inbox text is built so that each task line is written through ONE place
// (`taskLine`), which also notes down which thing of the board the line belongs to and the words
// that were sent. So the list the board keeps (`Board.sentTasks`) can never differ from the text.
//
// The same place holds the rule for a box that already went to the Inbox: in a note or a project it
// is a plain line, "- Permit (already in the Inbox)", never a second task.

/// One thing of the board that a hand-over makes a task of, with the task's words as they are sent
/// (without the box in front).
public struct MadeTask: Equatable, Sendable {
    public var id: UUID
    public var words: String

    public init(id: UUID, words: String) {
        self.id = id
        self.words = words
    }
}

/// The text of a note or project and what became a task in it.
public struct Handover: Equatable, Sendable {
    public var text: String
    /// The things that are tasks in the text, in the text's order.
    public var tasks: [MadeTask]
    /// How many things are written as a plain line because they are in the Inbox already.
    public var inInbox: Int
}

/// The switches of the Send page.
public struct SendChoices: Equatable, Sendable {
    /// "Say where they come from": every Inbox to-do ends with its way back to the board.
    public var sayOrigin: Bool
    /// "Also remind me when a bar starts" (a timeline): a bar longer than 3 days gets a "Start: …" task.
    public var remindStarts: Bool

    public init(sayOrigin: Bool = true, remindStarts: Bool = false) {
        self.sayOrigin = sayOrigin
        self.remindStarts = remindStarts
    }
}

public extension Board {
    /// The thing went to PARAGON's Inbox as a task of its own. A board that was never sent as a note or
    /// a project and still carries a tick from 0.4 (which kept no words) counts too: the Inbox was the
    /// only place such a tick could come from.
    func isInInbox(_ id: UUID) -> Bool {
        if let task = sentTask(id) { return task.place == SentTask.inbox }
        return sent == nil && sentTodos.contains(id)
    }

    /// Remembers every thing a hand-over made a task of. A thing that is in the Inbox keeps that entry
    /// when `place` is the Inbox again or when it is not among `tasks`.
    mutating func noteSent(_ tasks: [MadeTask], place: String) {
        for task in tasks { noteSent(task.id, words: task.words, place: place) }
    }
}

extension ParagonExport {
    /// What is noted down while a text is built.
    struct Made {
        var tasks: [MadeTask] = []
        var inInbox = 0
    }

    /// What stands behind a thing that is not written as a task because the Inbox has it.
    static let inInboxWords = "(already in the Inbox)"

    /// The line of a thing that is to become a task: "- [ ] words", noted down in `made` — or, when the
    /// thing already went to the Inbox, the plain line "- name (already in the Inbox)".
    /// `plain`: the thing's name without its days, for the plain line (a timeline bar).
    static func taskLine(_ item: Item, _ words: String, plain: String? = nil, in board: Board,
                         indent: Int = 0, made: inout Made) -> String {
        let pad = String(repeating: "  ", count: max(indent, 0))
        if board.isInInbox(item.id) {
            made.inInbox += 1
            return pad + "- \(plain ?? words) \(inInboxWords)"
        }
        made.tasks.append(MadeTask(id: item.id, words: words))
        return pad + "- [ ] " + words
    }

    static func isTaskLine(_ line: String) -> Bool { line.drop { $0 == " " }.hasPrefix("- [ ] ") }

    // MARK: A note, a project

    /// The whole text of a new note for Resources/ and the things that are tasks in it.
    public static func noteHandover(board: Board, title: String, picture: String?, now: Date,
                                    choices: SendChoices = SendChoices()) -> Handover {
        var made = Made()
        let text: String
        if board.isTimeline {
            text = timelineNoteText(board: board, title: title, picture: picture, now: now, choices: choices, made: &made)
        } else if board.isSequence {
            text = sequenceNoteText(board: board, title: title, picture: picture, now: now, made: &made)
        } else {
            text = plainNote(board: board, title: title, picture: picture, now: now, made: &made)
        }
        return Handover(text: text, tasks: made.tasks, inInbox: made.inInbox)
    }

    /// The whole text of a new project note for Projects/ and the things that are tasks in it.
    public static func projectHandover(board: Board, title: String, picture: String?, now: Date,
                                       choices: SendChoices = SendChoices()) -> Handover {
        var made = Made()
        let text: String
        if board.isTimeline {
            text = timelineProjectText(board: board, title: title, picture: picture, now: now, choices: choices, made: &made)
        } else if board.isSequence {
            text = sequenceProjectText(board: board, title: title, picture: picture, now: now, made: &made)
        } else {
            text = plainProject(board: board, title: title, picture: picture, now: now, made: &made)
        }
        return Handover(text: text, tasks: made.tasks, inInbox: made.inInbox)
    }

    // MARK: A timeline

    /// A bar's task without the box: "Foundation (starts 1 Dec) >2026-12-14".
    static func timelineWords(_ item: Item) -> String {
        let line = timelineTask(item)
        return line.hasPrefix("- [ ] ") ? String(line.dropFirst(6)) : line
    }

    /// "Start: Foundation >2026-12-08" for a bar longer than 3 days; nil for a shorter bar and a milestone.
    static func startWords(_ item: Item) -> String? {
        guard item.kind == .bar, let span = item.span, span.end - span.start + 1 > 3 else { return nil }
        return "Start: \(label(item)) >\(span.start.iso)"
    }

    /// The lines of one bar or milestone that is to become a task: its "Start: …" line first when the
    /// switch is on, then the task with its days.
    static func barLines(_ item: Item, in board: Board, choices: SendChoices, made: inout Made) -> [String] {
        let line = taskLine(item, timelineWords(item), plain: label(item), in: board, made: &made)
        guard choices.remindStarts, isTaskLine(line), let start = startWords(item) else { return [line] }
        return ["- [ ] " + start, line]
    }

    /// A timeline as a note: as `timelineNote` (Timeline.swift), with every task through `taskLine`.
    static func timelineNoteText(board: Board, title: String, picture: String?, now: Date,
                                 choices: SendChoices, made: inout Made) -> String {
        var out = frontMatter(title: title, type: "resource", status: nil, now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        section("Timeline", timelineBullets(board), into: &out)
        section("Comes after", timelineOrder(board), into: &out)
        var tasks: [String] = []
        for item in board.timelineRows where item.todo && item.kind != .phase {
            tasks.append(contentsOf: barLines(item, in: board, choices: choices, made: &made))
        }
        section("Tasks", tasks, into: &out)
        return out
    }

    /// The bars and milestones as tasks, as `timelineTaskGroups` (Timeline.swift): those above the first
    /// phase first, then each phase as a `###` heading; inside each group in date order.
    static func timelineGroups(_ board: Board, choices: SendChoices, made: inout Made) -> (loose: [String], groups: [[String]]) {
        func inOrder(_ items: [Item]) -> [Item] {
            items.enumerated().sorted { a, b in
                let x = a.element.span, y = b.element.span
                return (x?.start.number ?? Int.max, x?.end.number ?? Int.max, a.offset)
                    < (y?.start.number ?? Int.max, y?.end.number ?? Int.max, b.offset)
            }.map(\.element)
        }
        var loose: [Item] = []
        var groups: [(String, [Item])] = []
        for item in board.timelineRows {
            if item.kind == .phase {
                groups.append((label(item), []))
            } else if groups.isEmpty {
                loose.append(item)
            } else {
                groups[groups.count - 1].1.append(item)
            }
        }
        var looseLines: [String] = []
        for item in inOrder(loose) { looseLines.append(contentsOf: barLines(item, in: board, choices: choices, made: &made)) }
        var groupLines: [[String]] = []
        for group in groups {
            var lines = ["### \(group.0)"]
            for item in inOrder(group.1) { lines.append(contentsOf: barLines(item, in: board, choices: choices, made: &made)) }
            groupLines.append(lines)
        }
        return (looseLines, groupLines)
    }

    /// A timeline as a project: as `timelineProject` (Timeline.swift), with every task through `taskLine`.
    static func timelineProjectText(board: Board, title: String, picture: String?, now: Date,
                                    choices: SendChoices, made: inout Made) -> String {
        var out = frontMatter(title: title, type: "project", status: "active", now: now)
        if let last = board.items.compactMap({ $0.span?.end }).max(), out.hasSuffix("---\n") {
            out.removeLast(4)
            out += "due: \(last.iso)\n---\n"
        }
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        out += "## Outcome\n\n\(title)\n\n"
        let tasks = timelineGroups(board, choices: choices, made: &made)
        out += "## Tasks\n\n"
        if !tasks.loose.isEmpty { out += tasks.loose.joined(separator: "\n") + "\n\n" }
        for group in tasks.groups { out += group.joined(separator: "\n") + "\n\n" }
        out += "## Notes\n\n"
        let order = timelineOrder(board)
        if !order.isEmpty { out += order.joined(separator: "\n") + "\n\n" }
        out += "## Log\n\n- \(stamp(now, "yyyy-MM-dd")): Project created from a Seedboard timeline\n"
        return out
    }

    /// "All 8 bars and 1 milestone become tasks with their days." — what "As a project" makes of a timeline.
    static func timelineProjectLine(_ board: Board) -> String? {
        let bars = board.items.filter { $0.kind == .bar }.count
        let stones = board.items.filter { $0.kind == .milestone }.count
        guard bars + stones > 0 else { return nil }
        if bars + stones == 1 { return bars == 1 ? "The bar becomes a task with its days." : "The milestone becomes a task with its day." }
        var parts: [String] = []
        if bars > 0 { parts.append(bars == 1 ? "1 bar" : "\(bars) bars") }
        if stones > 0 { parts.append(stones == 1 ? "1 milestone" : "\(stones) milestones") }
        return "All \(parts.joined(separator: " and ")) become tasks with their days."
    }

    // MARK: "Who does what"

    /// A "Who does what" board as a note: as `sequenceNote` (Sequence.swift), with every task through `taskLine`.
    static func sequenceNoteText(board: Board, title: String, picture: String?, now: Date, made: inout Made) -> String {
        var out = frontMatter(title: title, type: "resource", status: nil, now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        section("Who", people(board), into: &out)
        section("Who does what", sequenceList(board), into: &out)
        let numbers = board.messageNumbers
        var tasks: [String] = []
        for step in board.steps where step.kind == .message && step.todo && numbers[step.id] != nil {
            tasks.append(taskLine(step, messageLine(step, in: board), in: board, made: &made))
        }
        section("Tasks", tasks, into: &out)
        return out
    }

    /// A "Who does what" board as a project: as `sequenceProject` (Sequence.swift), with every task through `taskLine`.
    static func sequenceProjectText(board: Board, title: String, picture: String?, now: Date, made: inout Made) -> String {
        var out = frontMatter(title: title, type: "project", status: "active", now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        out += "## Outcome\n\n\(title)\n\n"
        out += "## Tasks\n\n"
        let ticks = sequenceTicksDecide(board)
        let numbers = board.messageNumbers
        var lines: [String] = []
        for step in board.steps {
            switch step.kind {
            case .message:
                guard numbers[step.id] != nil else { continue }
                let words = messageLine(step, in: board)
                lines.append(!ticks || step.todo ? taskLine(step, words, in: board, made: &made) : "- " + words)
            case .section:
                lines.append(contentsOf: ["", "### " + label(step), ""])
            default:
                continue
            }
        }
        let tasks = tidy(lines)
        if !tasks.isEmpty { out += tasks.joined(separator: "\n") + "\n\n" }
        out += "## Notes\n\n"
        let who = people(board)
        if !who.isEmpty { out += "Who: " + who[0] + "\n\n" }
        let notes = bandBullets(board)
        if !notes.isEmpty { out += notes.joined(separator: "\n") + "\n\n" }
        out += "## Log\n\n- \(stamp(now, "yyyy-MM-dd")): Project created from a Seedboard “Who does what” board\n"
        return out
    }
}
