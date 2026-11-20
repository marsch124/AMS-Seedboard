import Foundation
import CoreGraphics

// 0.19, the `share` lane.
//  - 43: "Share Picture of This Frame" — the board that holds one frame and what lies in it (`Board.framePicture`);
//  - 44: the "Preview" on the Send page — the very text the hand-over writes (`ParagonExport.handoverText`,
//        `SendPreviewText`);
//  - 46: a checklist pasted from Apple Notes and others (`Checklist`, `Board.addChecklist`).

// MARK: 43 — a picture of one frame

public extension Board {
    /// A small board of its own that holds just this frame and what lies in it (the things whose middle lies
    /// inside it, with everything under an idea and the arrows between them), for a picture of the frame alone.
    /// Its title is the frame's words, else "Frame". nil: not a frame (or a board that places itself).
    func framePicture(of id: UUID) -> Board? {
        guard let frame = item(id), frame.kind == .frame, !placesItself else { return nil }
        var ids = Set(thingsInside(frame: id).map(\.id))
        ids.insert(frame.id)
        let copied = clip(of: ids)
        guard !copied.isEmpty else { return nil }
        var part = copied.asBoard()
        let name = frameName(id)
        part.title = name.isEmpty ? "Frame" : name
        part.colour = colour
        return part
    }
}

// MARK: 44 — the text of the hand-over

public extension ParagonExport {
    /// The text of a new note (`project` false) or project note: the very function Send writes the file with
    /// (`ParagonGate.send`) and the Preview on the Send page reads.
    static func handoverText(project: Bool, board: Board, title: String, picture: String?, now: Date,
                             choices: SendChoices = SendChoices()) -> Handover {
        project ? projectHandover(board: board, title: title, picture: picture, now: now, choices: choices)
                : noteHandover(board: board, title: title, picture: picture, now: now, choices: choices)
    }
}

/// How the Preview shows a text: the first lines, and how many more there are.
public struct SendPreviewText: Equatable, Sendable {
    /// How many lines show before "Show all".
    public static let shortLines = 8

    public var lines: [String]
    public init(_ text: String) {
        var all = text.components(separatedBy: "\n")
        while let last = all.last, last.trimmingCharacters(in: .whitespaces).isEmpty { all.removeLast() }
        lines = all
    }
    /// For tasks that go to the Inbox: one line each.
    public init(lines: [String]) { self.lines = lines }

    public func shown(all: Bool) -> String {
        (all ? lines : Array(lines.prefix(Self.shortLines))).joined(separator: "\n")
    }
    /// How many lines "Show all" would add.
    public var hidden: Int { max(lines.count - Self.shortLines, 0) }
}

// MARK: 46 — a checklist from outside

/// One line of a pasted checklist.
public struct ChecklistLine: Equatable, Sendable {
    public var words: String
    public var done: Bool
    public init(_ words: String, done: Bool = false) {
        self.words = words
        self.done = done
    }
}

public enum Checklist {
    /// Reads pasted words as a checklist, or nil when they are none. Every line (empty ones are skipped) must
    /// begin with a mark, and at least one line must begin with a box or a tick — bullets alone are no checklist.
    /// Open: "- [ ]", "* [ ]", "+ [ ]", "[ ]", "☐"; done: "- [x]", "* [x]", "+ [x]", "[x]", "☑", "☒", "✓", "✔";
    /// bullets "-", "*", "+", "•", "◦", "–" count as open. Marks may be indented; the words follow after a space.
    public static func parse(_ text: String) -> [ChecklistLine]? {
        var out: [ChecklistLine] = []
        var boxes = 0
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            guard let (done, box, rest) = read(line) else { return nil }
            let words = rest.trimmingCharacters(in: .whitespaces)
            if words.isEmpty { continue }
            if box { boxes += 1 }
            out.append(ChecklistLine(words, done: done))
        }
        return boxes > 0 && !out.isEmpty ? out : nil
    }

    /// (done, a box or tick and not a plain bullet, the words after the mark); nil: no mark.
    private static func read(_ line: String) -> (Bool, Bool, String)? {
        var rest = Substring(line)
        guard let first = rest.first else { return nil }
        // "- [ ] x", "* [x] x", "+ [X] x"; "- x" is a plain bullet.
        if "-*+".contains(first), rest.dropFirst().first == " " {
            rest = rest.dropFirst(2)
            return readBox(rest) ?? (false, false, String(rest))
        }
        if first == "[" { return readBox(rest) }
        guard rest.count > 1, rest.dropFirst().first?.isWhitespace == true else { return nil }
        let words = String(rest.dropFirst())
        switch first {
        case "☑", "☒", "✓", "✔": return (true, true, words)
        case "☐": return (false, true, words)
        case "•", "◦", "–": return (false, false, words)
        default: return nil
        }
    }

    private static func readBox(_ text: Substring) -> (Bool, Bool, String)? {
        let chars = Array(text.prefix(4))
        guard chars.count == 4, chars[0] == "[", chars[2] == "]", chars[3] == " " else { return nil }
        if chars[1] == " " { return (false, true, String(text.dropFirst(4))) }
        if chars[1] == "x" || chars[1] == "X" { return (true, true, String(text.dropFirst(4))) }
        return nil
    }
}

public extension Board {
    /// Pastes a checklist as ideas: each line one idea marked To do (`Item.todo`); a ticked line also carries
    /// `Item.doneDay` = `doneDay`, which draws as the green ring with its tick and the words greyed (as a done
    /// task read back from PARAGON). With an idea chosen (`under`) they hang under it; else they become a small
    /// map "Checklist" at the point (one line: one idea). Returns what can be chosen afterwards.
    @discardableResult
    mutating func addChecklist(_ lines: [ChecklistLine], under: UUID? = nil, at point: CGPoint, doneDay: String) -> Set<UUID> {
        guard !lines.isEmpty, canBeChanged, !placesItself else { return [] }
        let nodes = lines.map { OutlineNode($0.words) }
        var ideas: [UUID] = []
        var chosen: Set<UUID> = []
        if let under, item(under)?.kind == .idea {
            ideas = addIdeas(from: nodes, under: under)
            chosen = Set(ideas)
        } else if lines.count == 1 {
            let centre = addMap(from: nodes, title: nil, at: point)
            ideas = [centre]
            chosen = [centre]
        } else {
            let centre = addMap(from: nodes, title: "Checklist", at: point)
            ideas = children(of: centre).map(\.id)
            chosen = [centre]
        }
        for (id, line) in zip(ideas, lines) {
            guard let i = index(of: id) else { continue }
            items[i].todo = true
            if line.done { items[i].doneDay = doneDay }
        }
        return chosen
    }
}
