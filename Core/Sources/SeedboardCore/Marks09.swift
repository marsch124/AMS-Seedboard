import Foundation
import CoreGraphics

// Seedboard 0.9, "marks": vote dots, the colour legend, a tick list inside a sticky note, a web page's
// title under the words, pinning a thing in place, and the board's background. Rules only — no screen.

// MARK: Pinned in place

public extension Board {
    /// May this thing be moved, sized, nudged, lined up or tidied? A pinned thing (`locked`) may not; it can still
    /// be chosen, typed in, coloured and removed. (`move`, `resize` and `tidyable` ask this.)
    func mayMove(_ id: UUID) -> Bool { item(id).map { $0.locked != true } ?? false }

    /// Of these things the ones that may move.
    func movable(_ ids: Set<UUID>) -> Set<UUID> { ids.filter { mayMove($0) } }

    /// "Pin in place" when no chosen thing is pinned yet or only some are; "Unpin" when all are.
    func allPinned(_ ids: Set<UUID>) -> Bool {
        let list = ids.compactMap { item($0) }
        return !list.isEmpty && list.allSatisfy { $0.locked == true }
    }

    /// Pins (true) or frees (false) the things. The stored value is nil when free, so old files stay as they were.
    mutating func setPinned(_ ids: Set<UUID>, _ pinned: Bool) {
        for i in items.indices where ids.contains(items[i].id) {
            items[i].locked = pinned ? true : nil
        }
    }
}

// MARK: Vote dots

public enum Votes {
    /// Dots are drawn one by one up to this many; more are shown with a number.
    public static let drawn = 5
    /// The most dots one thing can hold.
    public static let most = 99
    /// Between two things of the sorted grid.
    public static let gap: Double = 16
}

public extension Board {
    /// Things that may carry dots: every ordinary thing that can be seen (not a mind map's hidden idea).
    func votable(_ ids: Set<UUID>) -> [Item] { items.filter { ids.contains($0.id) && !isHidden($0.id) } }

    func dots(of id: UUID) -> Int { item(id)?.votes ?? 0 }

    var hasDots: Bool { items.contains { ($0.votes ?? 0) > 0 } }

    /// "Vote": one more dot on each chosen thing.
    mutating func addDot(_ ids: Set<UUID>) {
        let ok = Set(votable(ids).map(\.id))
        for i in items.indices where ok.contains(items[i].id) {
            items[i].votes = min(Votes.most, (items[i].votes ?? 0) + 1)
        }
    }

    /// "Remove a dot": one dot less on each chosen thing; the last one leaves nothing stored.
    mutating func removeDot(_ ids: Set<UUID>) {
        for i in items.indices where ids.contains(items[i].id) {
            guard let n = items[i].votes, n > 0 else { continue }
            items[i].votes = n > 1 ? n - 1 : nil
        }
    }

    /// "Clear dots": all dots of the chosen things.
    mutating func clearDots(_ ids: Set<UUID>) {
        for i in items.indices where ids.contains(items[i].id) { items[i].votes = nil }
    }

    /// "Clear all dots": every dot of the board.
    mutating func clearAllDots() {
        for i in items.indices { items[i].votes = nil }
    }

    /// The things "Sort by dots" lines up: every thing with dots that may move (not pinned, not an idea under another),
    /// the most dots first; the same number of dots keeps the board's own order.
    func sortableByDots() -> [Item] {
        let all = items.filter { ($0.votes ?? 0) > 0 && $0.locked != true && !($0.kind == .idea && $0.parent != nil) && !isHidden($0.id) }
        return all.enumerated().sorted { a, b in
            let (x, y) = (a.element.votes ?? 0, b.element.votes ?? 0)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    /// "Sort by dots": the things with dots stand in a neat row (up to five side by side, then more rows), the most dots
    /// first, left to right and top to bottom, 16 points apart, starting where the first of them (in the board's own
    /// order) stood. Returns how many things were lined up.
    @discardableResult
    mutating func sortByDots() -> Int {
        let order = sortableByDots()
        guard order.count >= 2 else { return order.count }
        let start = items.first { item in order.contains { $0.id == item.id } }!
        let across = Thinking.across(order.count)
        var widths = Array(repeating: 0.0, count: across)
        var heights = Array(repeating: 0.0, count: (order.count + across - 1) / across)
        for (n, item) in order.enumerated() {
            widths[n % across] = max(widths[n % across], item.w)
            heights[n / across] = max(heights[n / across], item.h)
        }
        let chosen = Set(order.map(\.id))
        for (n, item) in order.enumerated() {
            let column = n % across, row = n / across
            let x = start.x + widths[..<column].reduce(0, +) + Votes.gap * Double(column)
            let y = start.y + heights[..<row].reduce(0, +) + Votes.gap * Double(row)
            let along = carried(by: [item.id]).filter { $0 == item.id || !chosen.contains($0) }
            move(along, by: CGSize(width: x - item.x, height: y - item.y))
        }
        return order.count
    }
}

// MARK: Colour legend

public extension Board {
    /// The sticky-note colours in use on the board, in the palette's order (a note with no colour is yellow).
    var legendColours: [String] {
        let used = Set(items.filter { $0.kind == .note }.map { $0.colour.isEmpty ? "yellow" : $0.colour })
        return Palette.notes.filter { used.contains($0) }
    }

    /// What the legend says: only colours that are in use and have words, in the palette's order.
    var legendRows: [(colour: String, words: String)] {
        guard let legend else { return [] }
        return legendColours.compactMap { name in
            let words = (legend[name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return words.isEmpty ? nil : (name, words)
        }
    }

    var hasLegend: Bool { !legendRows.isEmpty }

    /// Saves the words of the legend page: words trimmed to one line of at most 40 letters, empty ones left out; nothing
    /// left = no legend (nil). Words of colours not on the board now are kept as they were.
    mutating func setLegend(_ words: [String: String]) {
        var clean: [String: String] = [:]
        for (name, text) in words where Palette.notes.contains(name) {
            let one = text.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !one.isEmpty { clean[name] = String(one.prefix(40)) }
        }
        legend = clean.isEmpty ? nil : clean
    }
}

// MARK: A tick list inside a sticky note

public enum TickList {
    public struct Line: Equatable, Sendable {
        /// The words after the box.
        public var words: String
        public var ticked: Bool
    }

    private static func split(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    /// One line of words as a tick line: it starts with "[ ] " (not ticked) or "[x] " / "[X] " (ticked). nil for any other line.
    public static func parse(_ line: String) -> Line? {
        for (mark, ticked) in [("[ ]", false), ("[x]", true), ("[X]", true)] where line.hasPrefix(mark) {
            let rest = line.dropFirst(3)
            if rest.isEmpty { return Line(words: "", ticked: ticked) }
            if rest.first == " " { return Line(words: String(rest.dropFirst()), ticked: ticked) }
        }
        return nil
    }

    /// The tick line for these words.
    public static func line(_ words: String, ticked: Bool) -> String { (ticked ? "[x] " : "[ ] ") + words }

    /// Every line of the words, a tick line parsed or nil.
    public static func lines(_ text: String) -> [Line?] { split(text).map(parse) }

    public static func hasTicks(_ text: String) -> Bool { split(text).contains { parse($0) != nil } }

    /// The words with the box of line `n` (counted from 0, as the lines stand in the words) ticked or unticked.
    /// A line that is no tick line leaves the words as they were.
    public static func toggled(_ text: String, line n: Int) -> String {
        var all = split(text)
        guard all.indices.contains(n), let one = parse(all[n]) else { return text }
        all[n] = line(one.words, ticked: !one.ticked)
        return all.joined(separator: "\n")
    }

    /// "Tick list": every non-empty line becomes a tick line; when every non-empty line already is one, they all go back
    /// to plain lines. Empty words become one empty tick line.
    public static func turned(_ text: String) -> String {
        let all = split(text)
        let worded = all.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if worded.isEmpty { return "[ ] " }
        if worded.allSatisfy({ parse($0) != nil }) {
            return all.map { parse($0)?.words ?? $0 }.joined(separator: "\n")
        }
        return all.map { one in
            one.trimmingCharacters(in: .whitespaces).isEmpty || parse(one) != nil ? one : line(one, ticked: false)
        }.joined(separator: "\n")
    }

    /// How a note's words go to PARAGON: one "- " line each; a tick line stays "- [ ] words" / "- [x] words"; an empty line is left out.
    public static func bullets(_ text: String) -> [String] {
        split(text).compactMap { one in
            if let tick = parse(one) { return tick.words.isEmpty ? nil : "- " + (tick.ticked ? "[x] " : "[ ] ") + tick.words }
            let plain = one.split(separator: " ").joined(separator: " ")
            return plain.isEmpty ? nil : "- " + plain
        }
    }
}

// MARK: A web address in the words

public enum WebAddress {
    /// The first http or https address in the words, without the dot, comma or bracket that ended a sentence. nil if none.
    public static func first(in text: String) -> String? {
        guard text.contains("http"), let range = text.range(of: #"https?://[^\s<>"']+"#, options: .regularExpression) else { return nil }
        var found = String(text[range])
        while let last = found.last, ".,;:!?)]}".contains(last) { found.removeLast() }
        guard let url = URL(string: found), url.host?.isEmpty == false else { return nil }
        return found
    }

    /// The address to open.
    public static func url(in text: String) -> URL? { first(in: text).flatMap { URL(string: $0) } }

    /// A short, tidy form to show when there is no title: "example.com/page", without the scheme and "www.", at most 40 letters.
    public static func tidy(_ address: String) -> String {
        var s = address
        for scheme in ["https://", "http://"] where s.hasPrefix(scheme) { s.removeFirst(scheme.count) }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        while s.hasSuffix("/") { s.removeLast() }
        return s.count > 40 ? String(s.prefix(39)) + "…" : s
    }

    /// What is written under the words: the page's title, or the tidy address while there is none; at most 60 letters.
    public static func caption(title: String?, address: String) -> String {
        let one = (title ?? "").components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let text = one.isEmpty ? tidy(address) : one
        return text.count > 60 ? String(text.prefix(59)) + "…" : text
    }
}

public extension Board {
    /// The things whose title has to be fetched: they hold an address that is not the one fetched before.
    /// `fetched` is what the app remembers (thing → address it fetched the title for).
    func linksToFetch(fetched: [UUID: String]) -> [(id: UUID, address: String)] {
        items.compactMap { item in
            guard item.kind != .picture, item.kind != .drawing, item.kind != .door, let address = WebAddress.first(in: item.text) else { return nil }
            if let before = fetched[item.id] { return before == address ? nil : (item.id, address) }
            return item.linkTitle == nil ? (item.id, address) : nil
        }
    }
}

// MARK: Background

public enum Backdrop: String, CaseIterable, Sendable {
    case plain, dots, squares

    public var word: String {
        switch self {
        case .plain: return "Plain"
        case .dots: return "Dots"
        case .squares: return "Squares"
        }
    }

    /// Board points between two lines of the squares at this zoom: 48, 96 … never closer than 24 screen points.
    public static func squareStep(scale: CGFloat) -> CGFloat { DotGrid.step(scale: scale) * 2 }
}

public extension Board {
    /// The background. Nothing stored (nil) is the soft dots every board has always had; "plain" is stored when chosen.
    var backdropKind: Backdrop {
        get { backdrop.flatMap(Backdrop.init(rawValue:)) ?? .dots }
        set { backdrop = newValue == .dots ? nil : newValue.rawValue }
    }
}
