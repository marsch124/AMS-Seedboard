import Foundation

// 0.19, lane "list": the rules behind the home list — sort of Recent, the Due soon card, the done bar,
// the line where a search found its words, and the board made from the clipboard. No screen in here:
// every rule has a data test (List19Tests.swift).

// MARK: Sort of the Recent card (pick 3)

/// How the Recent card is ordered. Kept per device by the app (UserDefaults), not in a board.
public enum BoardSort: String, CaseIterable, Sendable {
    case changed, made, name

    /// The words in the small "Sort" menu.
    public var word: String {
        switch self {
        case .changed: return "Last changed"
        case .made: return "Date made"
        case .name: return "Name"
        }
    }

    /// The boards in this order: newest change first, newest first made, or by name (A to Z, no case or accents).
    public func sorted(_ boards: [Board]) -> [Board] {
        switch self {
        case .changed: return boards.sorted { $0.changed > $1.changed }
        case .made: return boards.sorted { $0.created > $1.created }
        case .name:
            return boards.sorted {
                let a = BoardSearch.plain($0.title), b = BoardSearch.plain($1.title)
                return a == b ? $0.created < $1.created : a < b
            }
        }
    }
}

// MARK: Due soon (pick 4)

/// One board on the Due soon card.
public struct DueSoonEntry: Equatable, Sendable {
    public let boardID: UUID
    /// Days from today to the due day; negative = past (late).
    public let days: Int
    public var late: Bool { days < 0 }

    /// "today", "tomorrow", "in 3 days", "1 day late", "3 days late".
    public var words: String {
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case 2...: return "in \(days) days"
        case -1: return "1 day late"
        default: return "\(-days) days late"
        }
    }
}

public enum DueSoon {
    /// How many days ahead count as soon (today included).
    public static let ahead = 7

    /// The boards whose due day is today or in the next 7 days, and those already past it, the nearest day first
    /// (the lateness first). Put-away boards are left out. Empty = no card.
    public static func entries(_ boards: [Board], today: Day = .today()) -> [DueSoonEntry] {
        boards.compactMap { board -> DueSoonEntry? in
            guard !board.isPutAway, let day = board.dueDay else { return nil }
            let days = day - today
            return days <= ahead ? DueSoonEntry(boardID: board.id, days: days) : nil
        }
        .sorted { $0.days < $1.days }
    }
}

// MARK: Done bar and late count (picks 5 and 8)

public extension Board {
    /// The things that count for the thin done bar: to-do boxes and timeline bars and milestones.
    /// `doneThings` = the to-dos PARAGON's note says are done (read back on this device).
    /// nil when the board has no such thing (the bar is hidden).
    func doneShare(doneThings: Set<UUID> = []) -> (done: Int, total: Int)? {
        var total = 0, done = 0
        for item in items {
            if item.span != nil {
                total += 1
                if timelineIsDone(item.id, also: doneThings) { done += 1 }
            } else if item.todo {
                total += 1
                if doneThings.contains(item.id) { done += 1 }
            }
        }
        return total == 0 ? nil : (done, total)
    }

    /// Timeline boards: how many bars and milestones are past their last day and not done (the same rule as
    /// the timeline's own "late"). 0 for other boards.
    func lateThings(doneThings: Set<UUID> = [], today: Day = .today()) -> Int {
        isTimeline ? timelineProgress(today: today, also: doneThings).late : 0
    }
}

// MARK: The line where the words were found (pick 2)

/// A found line, cut into pieces; the pieces that are the found words are bold.
public struct FoundLine: Equatable, Sendable {
    public struct Piece: Equatable, Sendable {
        public let text: String
        public let bold: Bool
    }
    public let pieces: [Piece]
    public var plain: String { pieces.map(\.text).joined() }
}

public extension Board {
    /// The line under the board's name for a search: the first line of its things (or arrows, or words read in
    /// pictures) that holds the most of the wanted words, with those words bold. nil with no words, or when only
    /// the name matched. A long line is cut round the first found word (about 70 characters) with "…".
    func foundLine(_ query: String) -> FoundLine? {
        let wanted = BoardSearch.words(query)
        guard !wanted.isEmpty, faceLock != true else { return nil }
        var lines: [String] = []
        for text in items.map(\.searchableWords) + links.map(\.text) + [pictureText] {
            for piece in text.components(separatedBy: .newlines) {
                let t = piece.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { lines.append(t) }
            }
        }
        func hits(_ line: String) -> Int {
            wanted.filter { line.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }.count
        }
        var best: (line: String, hits: Int)?
        for line in lines {
            let n = hits(line)
            if n > 0, n > (best?.hits ?? 0) { best = (line, n) }
        }
        guard let best else { return nil }
        var text = best.line
        var ranges: [Range<String.Index>] = []
        func find() {
            ranges = wanted.flatMap { word -> [Range<String.Index>] in
                var out: [Range<String.Index>] = []
                var from = text.startIndex
                while from < text.endIndex,
                      let r = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex) {
                    out.append(r)
                    from = r.upperBound
                }
                return out
            }.sorted { $0.lowerBound < $1.lowerBound }
        }
        find()
        let limit = 70
        if text.count > limit, let first = ranges.first {
            let at = text.distance(from: text.startIndex, to: first.lowerBound)
            let start = max(0, min(at - 15, text.count - limit))
            let a = text.index(text.startIndex, offsetBy: start)
            let b = text.index(a, offsetBy: min(limit, text.count - start))
            text = (start > 0 ? "…" : "") + text[a..<b] + (b < text.endIndex ? "…" : "")
            find()
        }
        // Merge overlapping ranges, then cut into pieces.
        var merged: [Range<String.Index>] = []
        for r in ranges {
            if let last = merged.last, r.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, r.upperBound)
            } else { merged.append(r) }
        }
        var pieces: [FoundLine.Piece] = []
        var at = text.startIndex
        for r in merged {
            if at < r.lowerBound { pieces.append(.init(text: String(text[at..<r.lowerBound]), bold: false)) }
            pieces.append(.init(text: String(text[r]), bold: true))
            at = r.upperBound
        }
        if at < text.endIndex { pieces.append(.init(text: String(text[at...]), bold: false)) }
        return FoundLine(pieces: pieces)
    }
}

// MARK: A board from the clipboard (pick 7)

public enum ClipboardBoard {
    /// The line when the clipboard holds no words.
    public static let nothing = "Nothing on the clipboard to make a board from."
    /// The line while the list is pulled down far enough.
    public static let release = "Release to make a board from the clipboard"

    /// How far (points) the list must be pulled down for a release to make the board.
    public static let pullDistance = 70.0

    /// A new mind map from the clipboard's lines (the app's outline reading: indents, bullets, headings).
    /// Named by its first line when there is one top line, else "From the clipboard". nil when there are no words.
    public static func board(from text: String?) -> Board? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let nodes = Outline.parse(text)
        guard let first = nodes.first else { return nil }
        // One top line is the map's centre and the board's name; several top lines hang under "From the clipboard".
        let name = nodes.count == 1 ? String(ParagonExport.oneLine(first.text).prefix(60)) : "From the clipboard"
        var board = Board(title: name.isEmpty ? "From the clipboard" : name)
        board.addMap(from: nodes, title: board.title, at: .zero)
        return board
    }
}
