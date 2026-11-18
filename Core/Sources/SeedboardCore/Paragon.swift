import Foundation

// The rules by which a board is handed over to PARAGON. Pure text in, text out: no files, no screens.
// Every rule below was read from PARAGON's own code (see the notes beside each one).

public enum ParagonExport {

    // MARK: Names

    /// PARAGON's own file-name rule (Vault.sanitizeFileName): `/ \ : * ? " < > |`, line breaks, tabs and
    /// control characters become a space, spaces are squeezed, dots and spaces are trimmed at both ends,
    /// and a name may not pass 180 bytes. Seedboard keeps well under that.
    private static let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t").union(.controlCharacters)
    private static let longestTitle = 100

    /// A note title PARAGON accepts, made from a board title (its forbidden characters replaced, trimmed, never empty).
    public static func noteTitle(for boardTitle: String) -> String {
        var cleaned = clean(boardTitle)
        if cleaned.count > longestTitle {
            cleaned = String(cleaned.prefix(longestTitle)).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        }
        // PARAGON reads "(conflict 2026-11-16 0752)" at the end of a name as a conflict copy.
        cleaned = cleaned.replacingOccurrences(of: "(conflict", with: "(clash")
        if cleaned.isEmpty { return "Board" }
        // `amspara://capture` and `amspara://timeblock` are PARAGON's own addresses, not note titles.
        if ["capture", "timeblock"].contains(cleaned.lowercased()) { return cleaned + " (board)" }
        return cleaned
    }

    private static func clean(_ text: String) -> String {
        let spaced = text.unicodeScalars.map { forbidden.contains($0) ? " " : Character($0) }
        return String(spaced).split(separator: " ").joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    }

    /// A title not in `taken` (compare case-insensitively). Never produces a name PARAGON or iCloud would read as a
    /// conflict copy (no bare " 2"): use "Title (board 2)", "Title (board 3)" …
    public static func freeTitle(_ wanted: String, taken: Set<String>) -> String {
        let used = Set(taken.map { $0.lowercased() })
        // PARAGON's Safety check calls "Name 2" a stray copy when "Name" is also there (a single digit, 2 to 9).
        func isFree(_ title: String) -> Bool {
            if used.contains(title.lowercased()) { return false }
            if let space = title.lastIndex(of: " ") {
                let tail = title[title.index(after: space)...]
                if tail.count == 1, let n = Int(tail), n >= 2,
                   used.contains(String(title[title.startIndex..<space]).lowercased()) { return false }
            }
            return true
        }
        let base = wanted.trimmingCharacters(in: .whitespaces).isEmpty ? "Board" : wanted
        if isFree(base) { return base }
        var n = 2
        while !isFree("\(base) (board \(n))") { n += 1 }
        return "\(base) (board \(n))"
    }

    /// File name for the board's picture inside Pictures/, e.g. "Seedboard Summer cabin 2026-11-18 0812.png" (safe characters, date from `now`).
    public static func pictureName(for boardTitle: String, now: Date) -> String {
        var safe = ""
        for ch in clean(boardTitle) {
            safe.append(ch.isLetter || ch.isNumber || ch == " " || ch == "-" || ch == "_" || ch == "." || ch == "," ? ch : " ")
        }
        var part = safe.split(separator: " ").joined(separator: " ")
        if part.count > 60 { part = String(part.prefix(60)) }
        part = part.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if part.isEmpty { part = "board" }
        return "Seedboard \(part) \(stamp(now, "yyyy-MM-dd HHmm")).png"
    }

    /// "seedboard://board/<uuid>"
    public static func boardLink(_ id: UUID) -> String { "seedboard://board/\(id.uuidString)" }

    // MARK: Whole notes

    /// The whole text of a new note for Resources/: front matter as PARAGON needs it (type resource), "# Title", the picture line,
    /// a line that links back to the board, then Outline, Flow, Notes and Tasks (a section with nothing in it is left out).
    public static func note(board: Board, title: String, picture: String?, now: Date) -> String {
        if board.isTimeline { return timelineNote(board: board, title: title, picture: picture, now: now) }
        if board.isSequence { return sequenceNote(board: board, title: title, picture: picture, now: now) }
        var out = frontMatter(title: title, type: "resource", status: nil, now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)

        var outline: [String] = []
        for centre in board.mapCentres {
            outline.append(contentsOf: bullets(of: centre, in: board, level: 0))
        }
        section("Outline", outline, into: &out)

        var flow: [String] = []
        for link in board.links {
            guard let a = board.item(link.from), let b = board.item(link.to) else { continue }
            var line = "- \(label(a)) → \(label(b))"
            let words = oneLine(link.text)
            if !words.isEmpty { line += " (\(words))" }
            flow.append(line)
        }
        section("Flow", flow, into: &out)
        out += laneText(board)

        section("Notes", noteBullets(board, picture: picture != nil), into: &out)

        let tasks = board.items.filter { $0.todo && !oneLine($0.text).isEmpty }.map { "- [ ] \(oneLine($0.text))" }
        section("Tasks", tasks, into: &out)
        return out
    }

    /// The whole text of a new PROJECT note for Projects/. Branches of a mind map become `###` headings under
    /// `## Tasks`, the ideas under them become tasks, deeper ideas become indented sub-tasks (PARAGON reads both:
    /// it finds `- [ ]` lines anywhere in the note and nests them by two spaces of indent). A main branch with no
    /// ideas under it is one task by itself, listed before the headings. Flow shapes in arrow order go under
    /// "### Steps", other to-do items under "### To do".
    /// When at least one idea carries the To do tick, the ticks decide: only ticked ideas and ticked shapes
    /// become tasks, the others stay as plain lines in the same places (see ProjectPlan.swift).
    public static func project(board: Board, title: String, picture: String?, now: Date) -> String {
        if board.isTimeline { return timelineProject(board: board, title: title, picture: picture, now: now) }
        if board.isSequence { return sequenceProject(board: board, title: title, picture: picture, now: now) }
        var out = frontMatter(title: title, type: "project", status: "active", now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)

        let outcomeText = board.mapCentres.map { oneLine($0.text) }.first { !$0.isEmpty } ?? title
        out += "## Outcome\n\n\(outcomeText)\n\n"

        let plan = projectPlan(board)
        var groups = plan.groups
        if !plan.steps.isEmpty { groups.append(["### Steps"] + plan.steps) }
        if !plan.todo.isEmpty { groups.append(["### To do"] + plan.todo) }

        out += "## Tasks\n\n"
        if !plan.loose.isEmpty { out += plan.loose.joined(separator: "\n") + "\n\n" }
        for group in groups { out += group.joined(separator: "\n") + "\n\n" }

        out += "## Notes\n\n"
        let notes = noteBullets(board, picture: picture != nil)
        if !notes.isEmpty { out += notes.joined(separator: "\n") + "\n\n" }

        out += "## Log\n\n- \(stamp(now, "yyyy-MM-dd")): Project created from a Seedboard board\n"
        return out
    }

    // MARK: Inbox

    /// The to-do items not yet in `board.sentTodos`, as (id, one-line text) in board order; empty texts skipped.
    public static func inboxTasks(board: Board) -> [(id: UUID, text: String)] {
        let sent = Set(board.sentTodos)
        return board.items.compactMap { item in
            guard item.todo, !sent.contains(item.id) else { return nil }
            let words = oneLine(item.text)
            return words.isEmpty ? nil : (item.id, words)
        }
    }

    /// amspara://capture?… for ONE Inbox task, or for one Inbox NOTE line when `asNote` is true.
    /// PARAGON joins line breaks in `text` into one line, so one URL is always one task.
    public static func captureURL(text: String, asNote: Bool) -> URL? {
        let words = oneLine(text)
        guard !words.isEmpty else { return nil }
        var string = "amspara://capture?text=\(encode(words))&target=inbox"
        if asNote { string += "&note=1" }
        return URL(string: string)
    }

    /// The URL that opens a note in PARAGON by its title: `amspara://<title>`, the title percent-encoded in the host place.
    public static func openURL(noteTitle: String) -> URL? {
        let words = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return nil }
        return URL(string: "amspara://\(encode(words))")
    }

    // MARK: PARAGON's waiting list

    /// One line of PARAGON's waiting list (`capture-outbox.jsonl`), written exactly the way PARAGON's own
    /// Share button writes it: PARAGON reads each line as its `CaptureItem` (id, text, target, asTask,
    /// createdAt; its `url` and `files` are optional and left out). A test decodes these lines with a
    /// copy of that reader, so a change here that PARAGON could not read fails the tests.
    public struct WaitingLine: Codable, Equatable, Sendable {
        /// The same three cases as PARAGON's `CaptureTarget`, so the line reads the same there.
        public enum Target: Codable, Equatable, Sendable { case inbox, today, note(path: String) }
        public var id: UUID
        public var text: String
        public var target: Target
        public var asTask: Bool
        public var createdAt: Date

        public init(id: UUID = UUID(), text: String, target: Target = .inbox, asTask: Bool, createdAt: Date) {
            self.id = id
            self.text = text
            self.target = target
            self.asTask = asTask
            self.createdAt = createdAt
        }
    }

    /// One Inbox task per line, one second apart in board order (PARAGON files them oldest first).
    public static func taskLines(_ tasks: [(id: UUID, text: String)], now: Date) -> [WaitingLine] {
        tasks.enumerated().map { n, task in
            WaitingLine(text: task.text, asTask: true, createdAt: now.addingTimeInterval(Double(n)))
        }
    }

    /// The Inbox line that points to a note made from a board.
    public static func noteLine(title: String, now: Date) -> WaitingLine {
        WaitingLine(text: "[[\(title)]] — a board from Seedboard", asTask: false, createdAt: now)
    }

    /// The lines as they go into the file: JSON, one per line, dates as ISO 8601.
    public static func waitingData(_ lines: [WaitingLine]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = Data()
        for line in lines {
            data.append(try encoder.encode(line))
            data.append(0x0A)
        }
        return data
    }

    // MARK: PARAGON's folder

    /// Is a folder holding these things (names at its top, plus ".ams-para/config.json" when that file is
    /// there) PARAGON's notes folder IN USE? PARAGON keeps its settings in `.ams-para/config.json` and its
    /// Inbox in `Inbox.md`; a file iCloud has not fetched yet shows as ".<name>.icloud". A folder with only
    /// a `Projects` folder in it does not count: that can be a folder PARAGON never used.
    public static func looksLikeParagonFolder(_ names: Set<String>) -> Bool {
        let signs = ["Inbox.md", ".Inbox.md.icloud", ".ams-para/config.json", ".ams-para/.config.json.icloud"]
        return signs.contains { names.contains($0) }
    }

    // MARK: Pieces

    static func frontMatter(title: String, type: String, status: String?, now: Date) -> String {
        var out = "---\ntitle: \(yaml(title))\ntype: \(type)\n"
        if let status { out += "status: \(status)\n" }
        out += "created: \(stamp(now, "yyyy-MM-dd"))\n---\n"
        return out
    }

    /// A value PARAGON's front-matter reader takes as written; one that starts like a list or a quote is quoted.
    private static func yaml(_ value: String) -> String {
        guard let first = value.first, "[{\"'".contains(first) else { return value }
        return "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// The picture line and the way back to the board. A picture sits in `Pictures/`, one folder above the note's folder,
    /// so it is written relative to the note, with `%20` for spaces, as a plain `![…](…)` line (PARAGON's `Pictures.matches`).
    static func head(board: Board, picture: String?) -> String {
        var out = ""
        if let picture, !picture.isEmpty { out += "![Picture](../Pictures/\(encode(picture)))\n\n" }
        out += "[Open the board in Seedboard](\(boardLink(board.id)))\n\n"
        return out
    }

    static func section(_ name: String, _ lines: [String], into out: inout String) {
        guard !lines.isEmpty else { return }
        out += "## \(name)\n\n" + lines.joined(separator: "\n") + "\n\n"
    }

    private static func noteBullets(_ board: Board, picture: Bool = true) -> [String] {
        // A drawing has no words: one plain line stands in its place.
        board.items.filter { (($0.kind == .note || $0.kind == .text) && !oneLine($0.text).isEmpty) || $0.kind == .drawing }
            .map { $0.kind == .drawing ? "- " + sketchLine(picture: picture) : "- \(oneLine($0.text))" }
    }

    /// What a note or project says where a drawing is.
    public static func sketchLine(picture: Bool = true) -> String {
        picture ? "A sketch (see the picture)" : "A sketch (on the board)"
    }

    static func label(_ item: Item) -> String {
        let words = oneLine(item.text)
        if item.kind == .drawing { return "A sketch" }
        return words.isEmpty ? "(empty)" : words
    }

    /// Line breaks become spaces, runs of spaces become one.
    static func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: " ").joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func bullets(of item: Item, in board: Board, level: Int, depth: Int = 0) -> [String] {
        guard depth < 200 else { return [] }
        var lines = [String(repeating: "  ", count: level) + "- " + label(item)]
        for child in board.children(of: item.id) {
            lines.append(contentsOf: bullets(of: child, in: board, level: level + 1, depth: depth + 1))
        }
        return lines
    }

    static func taskLines(of item: Item, in board: Board, level: Int, depth: Int = 0) -> [String] {
        guard depth < 200 else { return [] }
        var lines = [String(repeating: "  ", count: level) + "- [ ] " + label(item)]
        for child in board.children(of: item.id) {
            lines.append(contentsOf: taskLines(of: child, in: board, level: level + 1, depth: depth + 1))
        }
        return lines
    }

    /// The flow shapes in arrow order: those nothing points at first, each followed along its arrows; any left over after.
    static func flowOrder(_ board: Board) -> [Item] {
        let shapes = board.items.filter { $0.kind.isShape }
        let ids = Set(shapes.map(\.id))
        var pointedAt = Set<UUID>()
        for link in board.links where ids.contains(link.from) && ids.contains(link.to) { pointedAt.insert(link.to) }
        var seen = Set<UUID>()
        var result: [Item] = []
        func walk(_ item: Item) {
            guard seen.insert(item.id).inserted else { return }
            result.append(item)
            for link in board.links where link.from == item.id {
                if ids.contains(link.to), let next = board.item(link.to) { walk(next) }
            }
        }
        for shape in shapes where !pointedAt.contains(shape.id) { walk(shape) }
        for shape in shapes { walk(shape) }
        return result
    }

    /// Letters, digits and `- . _ ~` stay; everything else (spaces, `&`, `?`, `#`, `(`, `)`, å ä ö …) is %-encoded UTF-8.
    private static func encode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        // `alphanumerics` also holds non-ASCII letters; those must be encoded, so keep ASCII only.
        let ascii = allowed.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(128)))
        return text.addingPercentEncoding(withAllowedCharacters: ascii) ?? text
    }

    static func stamp(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = format
        return f.string(from: date)
    }
}
