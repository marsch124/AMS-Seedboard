import Foundation

// 0.19, timelines: a note on a milestone (27), the dates read out while a bar is held (28), group by colour (30),
// repeat a bar (31) and who does it (32). The rules live here; the screens only ask.

/// How often a repeated bar comes again (pick 31).
public enum BarRepeat: String, CaseIterable, Sendable {
    case day, week, twoWeeks, month

    public var word: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .twoWeeks: return "2 Weeks"
        case .month: return "Month"
        }
    }

    /// How many times a bar may come in all (the bar itself counts as the first time).
    public static let fewest = 2
    public static let most = 12
    /// "Every week, 6 times" is what the page opens with.
    public static let standard: (every: BarRepeat, times: Int) = (.week, 6)

    public static func clean(times: Int) -> Int { min(max(times, fewest), most) }

    /// The first day of the bar's `n`-th time (n = 0 is the bar itself). A month keeps the day of the month,
    /// or the last day of a shorter month (31 Jan → 28 Feb).
    public func start(of n: Int, from first: Day) -> Day {
        switch self {
        case .day: return first + n
        case .week: return first + 7 * n
        case .twoWeeks: return first + 14 * n
        case .month:
            let p = first.parts
            let index = p.year * 12 + (p.month - 1) + n
            let year = index / 12, month = index % 12 + 1
            let length = Day(year: month == 12 ? year + 1 : year, month: month % 12 + 1, day: 1) - Day(year: year, month: month, day: 1)
            return Day(year: year, month: month, day: min(p.day, length))
        }
    }
}

public extension Item {
    /// "1 Dec – 12 Dec · 12 days" as read out over a bar that is held or dragged. The year is written only when a
    /// day is not in the year of `today`. One day: "1 Dec · 1 day"; a milestone: just its day.
    func spanCallout(today: Day = .today()) -> String {
        guard let span else { return "" }
        let year = today.parts.year
        func word(_ day: Day) -> String { day.parts.year == year ? day.short : day.long }
        if kind == .milestone { return word(span.start) }
        if span.start == span.end { return "\(word(span.start)) · 1 day" }
        return "\(word(span.start)) – \(word(span.end)) · \(dayCount) days"
    }

    /// The initials as they are kept: letters only, at most three, in capitals; nil when none are left.
    static func cleanInitials(_ text: String) -> String? {
        let letters = String(text.filter { $0.isLetter }.prefix(3)).uppercased()
        return letters.isEmpty ? nil : letters
    }

    /// The most letters a note may have.
    static let longestNote = 280

    /// A note as it is kept: trimmed and cut at `longestNote`; nil when it is empty.
    static func cleanNote(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : String(t.prefix(longestNote))
    }
}

public extension Board {
    /// The colour a timeline row is drawn in: its own, or the one a new row of its kind starts with.
    func timelineColour(of item: Item) -> String {
        if !item.colour.isEmpty { return item.colour }
        switch item.kind {
        case .milestone: return TimelineColours.milestone
        case .phase: return "teal"
        default: return "blue"
        }
    }

    /// A note on a bar or a milestone, or none (empty words). Returns whether anything changed.
    @discardableResult
    mutating func setNote(_ id: UUID, _ text: String) -> Bool {
        guard let i = index(of: id), items[i].span != nil else { return false }
        let new = Item.cleanNote(text)
        guard items[i].note != new else { return false }
        items[i].note = new
        return true
    }

    /// Who does a bar (1 to 3 letters), or nobody (empty). Returns whether anything changed.
    @discardableResult
    mutating func setInitials(_ id: UUID, _ text: String) -> Bool {
        guard let i = index(of: id), items[i].kind == .bar else { return false }
        let new = Item.cleanInitials(text)
        guard items[i].initials != new else { return false }
        items[i].initials = new
        return true
    }

    // MARK: Group by colour (30)

    /// The rows in the order "Group by Colour" gives them: bars and milestones of one colour stand together, the
    /// colours in the order they first appear from the top. Rows keep their order inside a colour. A phase is a
    /// heading: it stays where it is, and the rows under it are grouped among themselves.
    var rowsGroupedByColour: [UUID] {
        let rows = timelineRows
        var order: [String] = []
        for item in rows where item.kind != .phase {
            let name = timelineColour(of: item)
            if !order.contains(name) { order.append(name) }
        }
        var result: [UUID] = []
        var run: [Item] = []
        func flush() {
            // `sorted` is not stable: the old place breaks a tie.
            let ordered = run.enumerated().sorted {
                (order.firstIndex(of: timelineColour(of: $0.element)) ?? 0, $0.offset) <
                (order.firstIndex(of: timelineColour(of: $1.element)) ?? 0, $1.offset)
            }
            result += ordered.map(\.element.id)
            run = []
        }
        for item in rows {
            if item.kind == .phase { flush(); result.append(item.id) } else { run.append(item) }
        }
        flush()
        return result
    }

    /// Whether "Group by Colour" would move anything.
    var canGroupByColour: Bool { isTimeline && rowsGroupedByColour != timelineRows.map(\.id) }

    /// Lines the bars of one colour up on neighbouring rows. Returns whether any row moved.
    @discardableResult
    mutating func groupByColour() -> Bool {
        let order = rowsGroupedByColour
        guard order != timelineRows.map(\.id) else { return false }
        for (n, id) in order.enumerated() {
            if let i = index(of: id) { items[i].row = n }
        }
        return true
    }

    // MARK: Repeat a bar (31)

    /// A bar (or milestone) comes again: `times` in all, the first being itself, so `times - 1` copies on the rows right
    /// under it, in the order of their days, each as long as the bar and in its colour (and with its name, who and
    /// note). A copy is not done and has no plan or "comes after" of its own. A copy whose day is outside the sane
    /// years is left out. Returns the copies.
    @discardableResult
    mutating func repeatRow(_ id: UUID, every: BarRepeat, times: Int) -> [UUID] {
        guard let source = item(id), let span = source.span, let row = timelineRow(of: id) else { return [] }
        let length = span.end - span.start
        var copies: [UUID] = []
        var order = timelineRows.map(\.id)
        var at = row + 1
        for n in 1..<BarRepeat.clean(times: times) {
            let first = every.start(of: n, from: span.start)
            guard DayRange.sane(first), DayRange.sane(first + length) else { break }
            var copy = source
            copy.id = UUID()
            copy.doneDay = nil
            copy.planStart = nil
            copy.planEnd = nil
            copy.setSpan(first, first + length)
            items.append(copy)
            order.insert(copy.id, at: at)
            at += 1
            copies.append(copy.id)
        }
        for (n, rowID) in order.enumerated() {
            if let i = index(of: rowID) { items[i].row = n }
        }
        return copies
    }
}
