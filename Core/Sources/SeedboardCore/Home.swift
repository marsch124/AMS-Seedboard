import Foundation

// What the home page and the boards list need to know about a board:
// does it hold the words that are looked for, and how long ago was it changed, in plain words.

public enum BoardSearch {
    /// Upper and lower case and accents make no difference when looking for words.
    static func plain(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// The words that are looked for, each one by itself.
    public static func words(_ query: String) -> [String] {
        plain(query).components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    /// The boards that hold every word of the query, in the order they came in.
    /// An empty query finds every board.
    public static func find(_ query: String, in boards: [Board]) -> [Board] {
        let wanted = words(query)
        guard !wanted.isEmpty else { return boards }
        // 0.9: words read inside a board's pictures count too (`BoardSearch.way` says which it was).
        return boards.filter { $0.holds(wanted) || $0.holdsWithPictures(wanted) }
    }
}

public extension Board {
    /// Everything that can be read on the board: its name, then the words on its things and on its arrows.
    var readableText: String {
        ([title] + items.map(\.searchableWords) + links.map(\.text)).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// True when every word of the query is found in the board's name or in the words on it.
    /// A word may be the beginning or a part of a longer one ("timb" finds "timber").
    func holds(_ query: String) -> Bool { holds(BoardSearch.words(query)) }

    internal func holds(_ words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let all = BoardSearch.plain(readableText)
        return words.allSatisfy { all.contains($0) }
    }

    /// When the board was last changed, in plain words: "Changed just now", "Changed 2 days ago".
    func changedWords(now: Date = Date(), calendar: Calendar = .current) -> String {
        "Changed " + Board.ago(from: changed, to: now, calendar: calendar)
    }

    /// How long ago, in plain words. A time that lies ahead (another device's clock) counts as now.
    static func ago(from then: Date, to now: Date, calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(then)
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: then), to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days) days ago" }
        if days < 14 { return "last week" }
        if days < 60 { return "\(days / 7) weeks ago" }
        if days < 365 { return "\(days / 30) months ago" }
        let years = days / 365
        return years == 1 ? "a year ago" : "\(years) years ago"
    }

    /// The colour name a thing or an arrow shows now, for the ring in the colour row ("" = no colour).
    /// An idea shows its branch's colour, a plain note is yellow, a plain frame teal.
    func colourInUse(of id: UUID) -> String? {
        if let item = item(id) {
            switch item.kind {
            case .idea: return branchColour(of: id)
            case .note: return item.colour.isEmpty ? "yellow" : item.colour
            case .frame: return item.colour.isEmpty ? "teal" : item.colour
            case .drawing: return item.sketchColour
            default: return item.colour
            }
        }
        return links.first { $0.id == id }?.colour
    }
}
