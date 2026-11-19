import Foundation
import CoreGraphics

/// Rules for what reaches Seedboard from outside the app: a Shortcuts action that hands over words,
/// and the device's own search (Spotlight).
public enum Outside {
    /// A new board from words handed over by a Shortcuts action. The same rule as pasting onto a board:
    /// a list becomes a mind map, paragraphs one text, one line one sticky note; no words at all
    /// gives an empty board. The board's name is the title given, else the map's middle idea, else the
    /// first line of the words.
    public static func board(title: String?, text: String, now: Date = Date()) -> Board {
        let name = ParagonExport.oneLine(title ?? "")
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var board = Board(title: name.isEmpty ? "New board" : name, created: now)
        guard !clean.isEmpty else { return board }
        let nodes = Outline.parse(clean)
        if Outline.isList(clean), !nodes.isEmpty {
            let centre = board.addMap(from: nodes, title: name, at: .zero)
            if name.isEmpty, let words = board.item(centre)?.text { board.title = short(words) }
        } else {
            board.add(Outline.kindForWords(clean), centre: .zero, text: clean)
            if name.isEmpty { board.title = short(clean) }
        }
        return board
    }

    /// The first line, at most 40 letters: a name for a board that was given none.
    static func short(_ words: String) -> String {
        let line = words.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let name = String(ParagonExport.oneLine(line).prefix(40)).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "New board" : name
    }

    /// The first words on a board, for the device's search: every thing's words in the order they were
    /// made, each on one line, joined by " · ", cut at a whole word once `limit` letters are reached.
    public static func searchWords(of board: Board, limit: Int = 300) -> String {
        var out = ""
        for item in board.items {
            let words = ParagonExport.oneLine(item.searchableWords)
            guard !words.isEmpty else { continue }
            let next = out.isEmpty ? words : out + " · " + words
            if next.count > limit {
                let room = limit - out.count - (out.isEmpty ? 0 : 3)
                var cut = String(words.prefix(max(room, 0)))
                if let space = cut.lastIndex(of: " "), cut.count < words.count { cut = String(cut[..<space]) }
                if !cut.isEmpty { out = out.isEmpty ? cut : out + " · " + cut }
                return out + "…"
            }
            out = next
        }
        return out
    }

    /// What the device's search has to learn and to forget: `known` is what it was told last (each
    /// board with the time of its last change), `boards` is what is on the device now.
    public static func searchPlan(known: [UUID: Date], boards: [UUID: Date]) -> (learn: Set<UUID>, forget: Set<UUID>) {
        let learn = boards.filter { known[$0.key] != $0.value }.map(\.key)
        let forget = known.keys.filter { boards[$0] == nil }
        return (Set(learn), Set(forget))
    }

    /// Boards for a name that was typed or spoken: the exact name first, then names that begin with
    /// it, then names that hold it. Capitals do not matter. No words: every board, as given.
    public static func boards(named words: String, in boards: [Board]) -> [Board] {
        let asked = words.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !asked.isEmpty else { return boards }
        func rank(_ board: Board) -> Int? {
            let name = board.title.lowercased()
            if name == asked { return 0 }
            if name.hasPrefix(asked) { return 1 }
            if name.contains(asked) { return 2 }
            return nil
        }
        return boards.enumerated()
            .compactMap { entry in rank(entry.element).map { (rank: $0, at: entry.offset, board: entry.element) } }
            .sorted { ($0.rank, $0.at) < ($1.rank, $1.at) }
            .map(\.board)
    }
}
