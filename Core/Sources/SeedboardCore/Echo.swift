import Foundation

// 0.5, pick 16, the reading half: what PARAGON's note says about the tasks a board handed over.
// Pure text in, facts out: no files, no screens. Seedboard only ever READS the note.
//
// Read from PARAGON's own code (TaskParser.swift, TaskTime.swift, Note.swift, Frontmatter.swift), build 340:
// - a task line is `^(\s*)([-*+])\s+\[([ xX>\-])\](?:\s+(.*))?$`; `x` or `X` = done, `-` = cancelled,
//   a blank or `>` = still to do; lines inside a fenced block (``` or ~~~) are not tasks;
// - when PARAGON ticks a task it rewrites the line in its own order: the words first, then its marks
//   (`!!`, `~45m`, `>2026-12-05`, `@repeat(…)`, `@since(…)`, `@deadline(…)`, `@done(…)`, `^t3fa2c1`).
//   So a line is compared by its WORDS: both the words Seedboard sent and the line in the note have
//   those marks lifted out and the spaces squeezed, exactly the way PARAGON finds a task's title;
// - a note's title is the `title:` line of its head, else its file name;
// - a project's own count leaves cancelled tasks out (Note.progress), and so does the count here.
// Seedboard never writes a `^t…` id of its own: those belong to PARAGON's Reminders sync.

public enum ParagonRead {

    // MARK: Task lines

    /// How one task line stands in PARAGON.
    public enum Mark: Equatable, Sendable { case open, done, cancelled }

    /// One task line of a note: how it stands, and its words without PARAGON's own marks.
    public struct TaskLine: Equatable, Sendable {
        public var mark: Mark
        public var words: String
        /// 0.9: the task's due day as PARAGON has it now ("2026-12-05"); nil when it has none.
        public var due: String? = nil
    }

    /// 0.9: the day written in a task line's words as PARAGON writes it: `>2026-12-05`, also with a time
    /// (`>2026-12-05T09:00`). Only the first one counts, as in PARAGON. nil: no day, or a day that is none.
    public static func dueDay(_ line: String) -> String? {
        let ns = line as NSString
        guard let match = dayRule.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let iso = ns.substring(with: match.range(at: 1))
        return Day(iso: iso) == nil ? nil : iso
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants copied from PARAGON; a wrong one fails every test at once.
        (try? NSRegularExpression(pattern: pattern)) ?? NSRegularExpression()
    }

    private static let lineRule = regex(#"^(\s*)([-*+])\s+\[([ xX>\-])\](?:\s+(.*))?$"#)
    /// PARAGON's marks that are lifted out wherever they stand (every one of them).
    private static let markRules = [
        regex(#"(?<!\S)\^(t[0-9a-f]{4,12})(?!\S)"#),
        regex(#"(?<!\S)@done\(([^)]*)\)"#),
        regex(#"(?<!\S)@repeat\(([^)]*)\)"#),
        regex(#"(?<!\S)@since\((\d{4}-\d{2}-\d{2})\)"#),
        regex(#"(?<!\S)@deadline\((\d{4}-\d{2}-\d{2})\)"#)
    ]
    /// The day: only the first one written counts in PARAGON, a second one stays in the words.
    private static let dayRule = regex(#"(?<!\S)>(\d{4}-\d{2}-\d{2})(?:T(\d{1,2}:\d{2}))?(?!\S)"#)
    private static let priorityRule = regex(#"(?<!\S)(!{1,3})(?!\S)"#)
    /// `~45m`, `~1h`, `~1h30m`. A bare `~` and a time of nothing are left alone, as in PARAGON.
    private static let timeRule = regex(#"(?<!\S)~(?:(\d{1,2})h)?(?:(\d{1,3})m)?(?!\S)"#)

    /// The words of a task without PARAGON's own marks, the spaces squeezed: what two lines are compared by.
    /// "Permit (starts 1 Dec) >2026-12-05" and "Permit (starts 1 Dec) >2026-12-05 @done(2026-12-04) ^t3fa2c1"
    /// both give "Permit (starts 1 Dec)".
    public static func words(_ line: String) -> String {
        var rest = line
        for rule in markRules { rest = lift(rule, from: rest) }
        let ns = rest as NSString
        if let day = dayRule.firstMatch(in: rest, range: NSRange(location: 0, length: ns.length)) {
            rest = ns.replacingCharacters(in: day.range, with: " ")
        }
        rest = lift(priorityRule, from: rest)
        rest = lift(timeRule, from: rest) { match, text in
            func number(_ at: Int) -> Int? {
                match.range(at: at).location == NSNotFound ? nil : Int(text.substring(with: match.range(at: at)))
            }
            let hours = number(1), minutes = number(2)
            return (hours != nil || minutes != nil) && (hours ?? 0) * 60 + (minutes ?? 0) > 0
        }
        return rest.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }

    private static func lift(_ rule: NSRegularExpression, from text: String,
                             when counts: (NSTextCheckingResult, NSString) -> Bool = { _, _ in true }) -> String {
        let ns = text as NSString
        var out = ns
        for match in rule.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() where counts(match, ns) {
            out = out.replacingCharacters(in: match.range, with: " ") as NSString
        }
        return out as String
    }

    /// Every task line of a note, in the note's order, read by PARAGON's own rule.
    public static func taskLines(in note: String) -> [TaskLine] {
        var found: [TaskLine] = []
        var fenced = false
        let text = note.replacingOccurrences(of: "\r\n", with: "\n")
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fenced.toggle()
                continue
            }
            if fenced { continue }
            let ns = String(line) as NSString
            guard let match = lineRule.firstMatch(in: ns as String, range: NSRange(location: 0, length: ns.length)) else { continue }
            let box = ns.substring(with: match.range(at: 3)).lowercased()
            let rest = match.range(at: 4).location == NSNotFound ? "" : ns.substring(with: match.range(at: 4))
            found.append(TaskLine(mark: box == "x" ? .done : (box == "-" ? .cancelled : .open), words: words(rest), due: dueDay(rest)))
        }
        return found
    }

    // MARK: The note itself

    /// Does this note hold the way back to the board (`seedboard://board/<id>`)? Every note and project
    /// Seedboard makes carries it, so a note that was renamed or moved to the Archive is still known by it.
    public static func holdsLink(_ note: String, to board: UUID) -> Bool {
        note.range(of: ParagonExport.boardLink(board), options: .caseInsensitive) != nil
    }

    /// The note's title as PARAGON shows it and opens it by: the `title:` line of its head, else its file name.
    public static func title(of note: String, fileName: String) -> String {
        var name = fileName
        if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }
        var text = note.replacingOccurrences(of: "\r\n", with: "\n")
        if text.hasPrefix("\u{FEFF}") { text = String(text.dropFirst()) }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else { return name }
        for line in lines[1..<end] where line.hasPrefix("title:") {
            var value = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
                    .replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
            } else if value.count >= 2, value.hasPrefix("'"), value.hasSuffix("'") {
                value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
            }
            if !value.isEmpty { return value }
        }
        return name
    }

    // MARK: The board's things in the note

    /// What a note says about a board's things.
    public struct Reading: Equatable, Sendable, Codable {
        /// Thing → how its task stands in the note: `.inParagon` (still to do there), `.done`, `.cancelled`.
        /// A thing whose task is not found by its words (re-worded or taken out in PARAGON) is not in here.
        public var states: [UUID: TodoState]
        /// How many of the board's things are tasks in the note; cancelled ones are left out, as PARAGON does.
        public var found: Int
        /// How many of those are ticked off.
        public var done: Int
        /// 0.9: thing → the due day of its task as PARAGON has it now ("2026-12-05"). Read each time, never
        /// stored in the board.
        public var due: [UUID: String]

        public init(states: [UUID: TodoState] = [:], found: Int = 0, done: Int = 0, due: [UUID: String] = [:]) {
            self.states = states
            self.found = found
            self.done = done
            self.due = due
        }

        // Kept on the device as plain words: thing id → "inParagon", "done" or "cancelled".
        enum CodingKeys: String, CodingKey { case states, found, done, due }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kept = (try? c.decode([String: String].self, forKey: .states)) ?? [:]
            states = kept.reduce(into: [:]) { out, pair in
                if let id = UUID(uuidString: pair.key), let state = TodoState(rawValue: pair.value) { out[id] = state }
            }
            found = (try? c.decode(Int.self, forKey: .found)) ?? 0
            done = (try? c.decode(Int.self, forKey: .done)) ?? 0
            let days = (try? c.decode([String: String].self, forKey: .due)) ?? [:]
            due = days.reduce(into: [:]) { out, pair in
                if let id = UUID(uuidString: pair.key) { out[id] = pair.value }
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(states.reduce(into: [String: String]()) { $0[$1.key.uuidString] = $1.value.rawValue }, forKey: .states)
            try c.encode(found, forKey: .found)
            try c.encode(done, forKey: .done)
            try c.encode(due.reduce(into: [String: String]()) { $0[$1.key.uuidString] = $1.value }, forKey: .due)
        }
    }

    /// Matches the task lines of `note` to the things of `board` by the words that were sent.
    /// - The words are those kept at Send (`board.sentTasks`): first the things that went into the note, then
    ///   those that went to the Inbox (one of them filed into the note by hand is then found there too).
    /// - A board that keeps no words of a thing in the note (it was sent by 0.4) is matched by the task lines
    ///   it would send now, as a `kind` ("note" or "project").
    /// - Two things with the same words take the lines with those words in the note's order.
    /// - Only things that are still on the board count.
    public static func reading(board: Board, note: String, kind: String? = nil) -> Reading {
        var lines: [String: [(mark: Mark, due: String?)]] = [:]
        for line in taskLines(in: note) where !line.words.isEmpty { lines[line.words, default: []].append((line.mark, line.due)) }
        let here = Set(board.items.map(\.id))
        let inNote = board.sentTasks.filter { $0.place == SentTask.note }
        var asked: [(id: UUID, words: String)] = (inNote + board.sentTasks.filter { $0.place != SentTask.note })
            .map { ($0.id, $0.words) }
        if inNote.isEmpty {
            let known = Set(board.sentTasks.map(\.id))
            asked += tasksItWouldSend(board, kind: kind ?? board.sent?.kind ?? "note").filter { !known.contains($0.id) }
        }
        var reading = Reading()
        for thing in asked where here.contains(thing.id) && reading.states[thing.id] == nil {
            let key = words(thing.words)
            guard var waiting = lines[key], !waiting.isEmpty else { continue }
            let (mark, due) = waiting.removeFirst()
            lines[key] = waiting
            if let due, mark != .cancelled { reading.due[thing.id] = due }
            switch mark {
            case .open:
                reading.states[thing.id] = .inParagon
                reading.found += 1
            case .done:
                reading.states[thing.id] = .done
                reading.found += 1
                reading.done += 1
            case .cancelled:
                reading.states[thing.id] = .cancelled
            }
        }
        return reading
    }

    /// The things of a board that would become tasks if it were sent now as a `kind` ("project", else a note),
    /// each with the words of its task line — for a board sent by 0.4, which kept no words.
    public static func tasksItWouldSend(_ board: Board, kind: String) -> [(id: UUID, words: String)] {
        let never = Date(timeIntervalSince1970: 0)
        let text = kind == "project"
            ? ParagonExport.project(board: board, title: board.title, picture: nil, now: never)
            : ParagonExport.note(board: board, title: board.title, picture: nil, now: never)
        var waiting: [String: Int] = [:]
        for line in taskLines(in: text) { waiting[line.words, default: 0] += 1 }
        var out: [(id: UUID, words: String)] = []
        for item in board.items {
            guard let line = taskWords(of: item, in: board) else { continue }
            let key = words(line)
            guard !key.isEmpty, let left = waiting[key], left > 0 else { continue }
            waiting[key] = left - 1
            out.append((item.id, line))
        }
        return out
    }

    /// The words a thing has when it is written as a task; nil for a thing that never is one.
    private static func taskWords(of item: Item, in board: Board) -> String? {
        if board.isTimeline {
            guard item.kind == .bar || item.kind == .milestone else { return nil }
            return String(ParagonExport.timelineTask(item).dropFirst("- [ ] ".count))
        }
        if board.isSequence {
            return item.kind == .message ? ParagonExport.messageLine(item, in: board) : nil
        }
        switch item.kind {
        case .frame, .drawing, .picture, .door, .bar, .milestone, .phase, .who, .message, .band, .section, .table, .block: return nil
        case .idea, .box, .round, .diamond, .oval, .note, .text, .person, .document, .slanted, .store:
            return ParagonExport.label(item)
        }
    }

    // MARK: Words on screen

    /// "5 of 13 done"; nil when the note holds no task of the board.
    public static func doneWords(found: Int, done: Int) -> String? {
        found > 0 ? "\(done) of \(found) done" : nil
    }

    /// The small line under the board's top bar: "Project “Summer cabin” · 5 of 13 done · checked 14:02".
    /// `checked` nil: the note is not on this device yet. `gone`: no note holds the board's link any more.
    public static func line(kind: String, title: String, found: Int, done: Int, checked: String?, gone: Bool = false) -> String {
        let name = "\(kind == "project" ? "Project" : "Note") “\(title)”"
        if gone { return "\(name) · no longer in PARAGON's notes" }
        guard let checked else { return "\(name) · not checked on this device yet" }
        return ([name, doneWords(found: found, done: done), "checked \(checked)"] as [String?])
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// When the note was read, for the line: "14:02" on the same day, else "17 Nov 14:02".
    public static func checkedWords(_ date: Date, now: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let words = KeptRules.dayTime(date, now: now, timeZone: timeZone)
        guard calendar.isDate(date, inSameDayAs: now), let time = words.split(separator: " ").last else { return words }
        return String(time)
    }
}
