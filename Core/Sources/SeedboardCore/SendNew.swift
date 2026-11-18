import Foundation

// 0.5, the `send` lane: the lines that go to PARAGON's waiting list.
//
//  - "Only the to-do boxes": a timeline's bar keeps its days, and every to-do ends with its way back
//    to the board (the switch "Say where they come from").
//  - "Add what is new": when the board already is a note or a project in PARAGON, the things that have
//    become tasks since then go to the waiting list AIMED AT THAT NOTE. PARAGON files such a line
//    itself, at the end of the note's Tasks (its `Vault.capture`, `Note.append(task:)`); when the note is
//    not at its place, PARAGON's own rule puts the line into the Inbox — and Seedboard says so before.
//
// Seedboard still only adds lines to the waiting list. It never opens the note for writing.
//
// Read from PARAGON's code (build 340, Capture.swift and TaskParser.swift): a waiting line that is a task
// is written as `- [ ] <text>` after PARAGON's task reader has read it once — so a day in the text
// (` >2026-12-05`) becomes the task's day and is written at the END of the line. That is why the way
// back stands before the day here: the words Seedboard remembers are then the words PARAGON writes.

/// What a look at the note the board became finds. Reading only.
public enum NoteLook: Equatable, Sendable {
    /// The note is at its place and was read.
    case there(text: String)
    /// The note is at its place, but iCloud has not brought it to this device yet.
    case notFetched
    /// The note is not at its place any more (renamed, moved or removed in PARAGON).
    case gone

    public var isThere: Bool { self != .gone }
}

/// The lines of one sending to PARAGON's waiting list.
public struct LinesToSend: Equatable, Sendable {
    /// The lines' words, in the order they are sent (one task each).
    public var lines: [String]
    /// The things that become a task, each with the words of its own line.
    public var tasks: [MadeTask]
    /// Things that were found in the note already (a board sent by 0.4 kept no list): remembered, not sent.
    public var there: [MadeTask] = []
    /// `SentTask.inbox` or `SentTask.note`.
    public var place: String
    /// The note the lines are aimed at ("Projects/Summer cabin.md"); nil = the Inbox.
    public var notePath: String?
}

/// What has become a task on the board since it went to PARAGON as a note or a project.
public struct NewTasks: Equatable, Sendable {
    /// The new task things, with their words.
    public var new: [MadeTask]
    /// Task things found in the note by their words (a board sent by 0.4): not new.
    public var there: [MadeTask]
    /// Things that are tasks in PARAGON under other words than they have now.
    public var renamed: Int
    /// Bars that are tasks in PARAGON with other days than they have now.
    public var moved: Int
}

public extension ParagonExport {
    // MARK: The way back

    /// What stands at the end of an Inbox to-do: a link that opens the board, or — when the board is a
    /// project in PARAGON — the project itself.
    enum WayBack: Equatable, Sendable {
        case board(title: String, id: UUID)
        case project(title: String)
    }

    /// The way back for this board's Inbox to-dos; nil when "Say where they come from" is off.
    static func wayBack(board: Board, look: NoteLook?, choices: SendChoices) -> WayBack? {
        guard choices.sayOrigin else { return nil }
        if let sent = board.sent, sent.kind == "project", look?.isThere == true,
           !sent.title.contains("["), !sent.title.contains("]") {
            return .project(title: sent.title)
        }
        return .board(title: board.title, id: board.id)
    }

    /// "Order timber [Summer cabin](seedboard://board/<id>)" or "Order timber — [[Summer cabin]]".
    /// A day at the end of the words stays at the end: "Permit (starts 1 Dec) [Plan](…) >2026-12-05".
    static func words(_ words: String, with way: WayBack?) -> String {
        guard let way else { return words }
        var body = words
        var day = ""
        if let found = words.range(of: #" >\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) {
            day = String(words[found])
            body = String(words[..<found.lowerBound])
        }
        switch way {
        case .board(let title, let id):
            // Square brackets would end the link's name early.
            var name = oneLine(title).replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
            if name.isEmpty { name = "Board" }
            return "\(body) [\(name)](\(boardLink(id)))\(day)"
        case .project(let title):
            return "\(body) — [[\(title)]]\(day)"
        }
    }

    // MARK: Only the to-do boxes

    /// What "Only the to-do boxes" sends: one task per to-do that is not in PARAGON yet, in board order, each
    /// with its way back; a timeline's bar with its days, and with its "Start: …" line before it when that switch is on.
    static func inboxSend(board: Board, look: NoteLook? = nil, choices: SendChoices = SendChoices()) -> LinesToSend {
        let way = wayBack(board: board, look: look, choices: choices)
        var out = LinesToSend(lines: [], tasks: [], place: SentTask.inbox, notePath: nil)
        for task in inboxTasks(board: board) {
            if choices.remindStarts, let item = board.item(task.id), let start = startWords(item) {
                out.lines.append(words(start, with: way))
            }
            let line = words(task.text, with: way)
            out.lines.append(line)
            out.tasks.append(MadeTask(id: task.id, words: line))
        }
        return out
    }

    // MARK: Add what is new

    /// The words of every task line of a note, as a set: the box, PARAGON's own marks behind a task
    /// (`^t1a2b3c`, `@done(…)`, `@since(…)`) and doubled spaces taken away.
    static func taskWords(inNote text: String) -> Set<String> {
        var found = Set<String>()
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.drop { $0 == " " || $0 == "\t" }
            guard let mark = line.first, "-*+".contains(mark) else { continue }
            let rest = line.dropFirst().drop { $0 == " " }
            guard rest.count >= 3, rest.first == "[", rest.dropFirst(2).first == "]",
                  " xX>-".contains(rest.dropFirst().first ?? "?") else { continue }
            var words = String(rest.dropFirst(3))
            for pattern in [#"(?<!\S)\^t[0-9a-f]{4,12}(?!\S)"#, #"(?<!\S)@done\([^)]*\)"#, #"(?<!\S)@since\([^)]*\)"#] {
                words = words.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
            }
            words = squeezed(words)
            if !words.isEmpty { found.insert(words) }
        }
        return found
    }

    private static func squeezed(_ text: String) -> String {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }

    /// A task's name without its days: "Permit (starts 1 Dec) >2026-12-05" → "Permit".
    private static func nameOnly(_ words: String) -> String {
        var name = words.replacingOccurrences(of: #" >\d{4}-\d{2}-\d{2}$"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #" \(starts [^)]*\)$"#, with: "", options: .regularExpression)
        return name
    }

    /// What has become a task since the board went to PARAGON as a note or a project; nil when the board
    /// was never sent so, or when it cannot be told safely.
    ///
    /// A board sent by 0.5 knows every thing that became a task (`sentTasks`): what is not on that list is
    /// new. A board sent by 0.4 kept only its ticks, so there the note itself is asked (reading only): a
    /// thing whose words stand in the note as a task is not new. When that note cannot be read, nothing
    /// is offered — better no row than the same tasks a second time.
    static func newTasks(board: Board, look: NoteLook?) -> NewTasks? {
        guard let sent = board.sent, let look else { return nil }
        let would = sent.kind == "project"
            ? projectHandover(board: board, title: sent.title, picture: nil, now: sent.when)
            : noteHandover(board: board, title: sent.title, picture: nil, now: sent.when)
        // 0.6: a bar marked done after the sending is not offered as a new (open) task.
        let unknown = would.tasks.filter { board.sentTask($0.id) == nil && !board.sentTodos.contains($0.id)
            && board.item($0.id)?.isDone != true }
        var result = NewTasks(new: unknown, there: [], renamed: 0, moved: 0)

        if !board.sentTasks.contains(where: { $0.place == SentTask.note }) {
            guard case .there(let text) = look else { return nil }
            let inNote = taskWords(inNote: text)
            result.new = unknown.filter { !inNote.contains(squeezed($0.words)) }
            // Every task of the board that stands in the note is remembered from now on.
            result.there = would.tasks.filter { board.sentTask($0.id) == nil && inNote.contains(squeezed($0.words)) }
        }

        for old in board.sentTasks where old.place == SentTask.note {
            guard let item = board.item(old.id), let now = would.tasks.first(where: { $0.id == old.id }),
                  now.words != old.words else { continue }
            if item.kind.isTimeline, nameOnly(now.words) == nameOnly(old.words) { result.moved += 1 } else { result.renamed += 1 }
        }
        return result
    }

    /// What "Add what is new" sends; nil when there is nothing new (or it cannot be told safely).
    /// The note is at its place: the lines are aimed at it, as they stand in a note. It is gone: the lines go
    /// to the Inbox, each with its way back to the board.
    static func addSend(board: Board, look: NoteLook?, choices: SendChoices = SendChoices()) -> LinesToSend? {
        guard let sent = board.sent, let look, let found = newTasks(board: board, look: look), !found.new.isEmpty else { return nil }
        let way = look.isThere ? nil : wayBack(board: board, look: look, choices: choices)
        var out = LinesToSend(lines: [], tasks: [], there: found.there,
                              place: look.isThere ? SentTask.note : SentTask.inbox,
                              notePath: look.isThere ? sent.path : nil)
        for task in found.new {
            if choices.remindStarts, let item = board.item(task.id), let start = startWords(item) {
                out.lines.append(words(start, with: way))
            }
            let line = words(task.words, with: way)
            out.lines.append(line)
            out.tasks.append(MadeTask(id: task.id, words: line))
        }
        return out
    }

    /// The words under the row "Add what is new to “…”".
    static func addRowWords(count: Int, sentAs kind: String, noteThere: Bool) -> String {
        let what = kind == "project" ? "project" : "note"
        if noteThere {
            return (count == 1 ? "1 new task goes" : "\(count) new tasks go") + " into the \(what). Nothing that is there is touched."
        }
        return "The \(what) is not where it was: " + (count == 1 ? "the task goes" : "the \(count) tasks go") + " to the Inbox."
    }

    /// "2 things were renamed and 1 bar moved since 18 Nov. PARAGON keeps the old ones." nil when nothing was.
    static func cannotFollowLine(renamed: Int, moved: Int, since: Date) -> String? {
        var parts: [String] = []
        if renamed > 0 { parts.append(renamed == 1 ? "1 thing was renamed" : "\(renamed) things were renamed") }
        if moved > 0 { parts.append(moved == 1 ? "1 bar moved" : "\(moved) bars moved") }
        guard !parts.isEmpty else { return nil }
        return "\(parts.joined(separator: " and ")) since \(Day(since).short). PARAGON keeps the old \(renamed + moved == 1 ? "one" : "ones")."
    }

    // MARK: The waiting lines

    /// One task per line, one second apart in their order (PARAGON files them oldest first), aimed at a note
    /// (`notePath`, e.g. "Projects/Summer cabin.md") or, without one, at the Inbox.
    static func waitingLines(_ texts: [String], notePath: String?, now: Date) -> [WaitingLine] {
        texts.enumerated().map { n, text in
            WaitingLine(text: text, target: notePath.map { .note(path: $0) } ?? .inbox, asTask: true,
                        createdAt: now.addingTimeInterval(Double(n)))
        }
    }
}
