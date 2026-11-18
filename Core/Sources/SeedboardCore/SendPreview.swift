import Foundation

// 0.5, the `send` lane: the box "What PARAGON gets" on the Send page.
//
// Its rows are read out of the very text Send writes (the note, the project, the waiting lines), so the
// box cannot show anything else than what arrives. The count line under it is counted from the same rows.

/// One row of the box "What PARAGON gets".
public struct PreviewRow: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The board's picture (a note and a project begin with it).
        case picture
        /// A heading; `level` 2 is a part of the note ("Tasks"), 3 a heading inside it ("Food").
        case heading(level: Int)
        /// A task, drawn with its box.
        case task
        /// Any other line, drawn grey.
        case plain
    }

    public var kind: Kind
    /// The words as PARAGON shows them: a link is its name, a day is taken out.
    public var words: String
    /// A task's day in short words, "12 Dec" (drawn at the right in purple); nil without one.
    public var day: String?
    /// The day itself, for the count line's "last day".
    public var date: Day?
    /// How far the line is set in (a sub-task, an idea under an idea).
    public var indent: Int

    public init(kind: Kind, words: String, day: String? = nil, date: Day? = nil, indent: Int = 0) {
        self.kind = kind
        self.words = words
        self.day = day
        self.date = date
        self.indent = indent
    }
}

public extension ParagonExport {
    /// The rows of a note or project text: the picture, the headings, the tasks with their days, the plain
    /// lines. The head (title, kind, date), the note's own title line and the link back are left out.
    static func preview(ofNote text: String) -> [PreviewRow] {
        var rows: [PreviewRow] = []
        var inHead = false
        var first = true
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if first, line == "---" { inHead = true; first = false; continue }
            first = false
            if inHead { if line == "---" { inHead = false }; continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("# ") { continue }
            if trimmed.hasPrefix("![") { rows.append(PreviewRow(kind: .picture, words: "")); continue }
            if trimmed.hasPrefix("[Open the board in Seedboard](") { continue }
            if trimmed.hasPrefix("### ") { rows.append(PreviewRow(kind: .heading(level: 3), words: shown(String(trimmed.dropFirst(4))))); continue }
            if trimmed.hasPrefix("## ") { rows.append(PreviewRow(kind: .heading(level: 2), words: shown(String(trimmed.dropFirst(3))))); continue }
            let indent = line.prefix { $0 == " " }.count / 2
            if trimmed.hasPrefix("- [ ] ") {
                rows.append(taskRow(String(trimmed.dropFirst(6)), indent: indent))
            } else if trimmed.hasPrefix("- ") {
                rows.append(PreviewRow(kind: .plain, words: shown(String(trimmed.dropFirst(2))), indent: indent))
            } else if trimmed.hasPrefix("> ") {
                rows.append(PreviewRow(kind: .plain, words: shown(String(trimmed.dropFirst(2))), indent: indent))
            } else {
                rows.append(PreviewRow(kind: .plain, words: shown(trimmed), indent: indent))
            }
        }
        return rows
    }

    /// The rows of the tasks that go to the waiting list (`LinesToSend.lines`).
    static func preview(ofTasks lines: [String]) -> [PreviewRow] {
        lines.map { taskRow($0, indent: 0) }
    }

    private static func taskRow(_ words: String, indent: Int) -> PreviewRow {
        var body = words
        var date: Day?
        if let found = body.range(of: #"(?<!\S)>\d{4}-\d{2}-\d{2}(?!\S)"#, options: .regularExpression) {
            date = Day(iso: String(body[found].dropFirst()))
            body.removeSubrange(found)
        }
        return PreviewRow(kind: .task, words: shown(body), day: date?.short, date: date, indent: indent)
    }

    /// Words as PARAGON shows them: "[name](address)" is its name, "[[Title]]" the title, "**bold**" plain.
    private static func shown(_ words: String) -> String {
        var out = words.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\[\[([^\]]*)\]\]"#, with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: "**", with: "")
        return out.split(separator: " ").joined(separator: " ")
    }

    /// The line under the box: "13 tasks · 3 headings · 1 already in the Inbox · last day 20 Feb".
    /// Headings are the ones inside the note's parts (`###`); a part with nothing to count is left out.
    static func countLine(_ rows: [PreviewRow], inInbox: Int = 0) -> String {
        let tasks = rows.filter { $0.kind == .task }.count
        let headings = rows.filter { $0.kind == .heading(level: 3) }.count
        var parts = [tasks == 0 ? "No tasks" : (tasks == 1 ? "1 task" : "\(tasks) tasks")]
        if headings > 0 { parts.append(headings == 1 ? "1 heading" : "\(headings) headings") }
        if inInbox > 0 { parts.append("\(inInbox) already in the Inbox") }
        if let last = rows.compactMap(\.date).max() { parts.append("last day \(last.short)") }
        return parts.joined(separator: " · ")
    }
}
