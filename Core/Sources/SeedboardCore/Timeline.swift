import Foundation
import CoreGraphics

// The timeline board: a simple Gantt. Across are days, down are rows. A bar has a first and a last
// day (whole days); its place and length on screen always come from those. A milestone is one day,
// a phase is a heading row that groups the rows under it, and "comes after" is an arrow from the
// end of one bar to the start of the next. No screen in here: every rule below has a data test.

// MARK: A day

/// A calendar day without a clock, counted in whole days, so a bar's length is plain sums and
/// no time zone or summer time can ever move a bar.
public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Days since 1 January 1970 (that day is 0).
    public var number: Int

    public init(number: Int) { self.number = number }

    public init(year: Int, month: Int, day: Int) {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        number = era * 146_097 + doe - 719_468
    }

    /// Reads "2026-12-01" (what the file keeps). Anything after the tenth character is passed over.
    public init?(iso: String) {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// The day this moment falls on, where the owner is.
    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(_ now: Date = Date(), calendar: Calendar = .current) -> Day { Day(now, calendar: calendar) }

    public var parts: (year: Int, month: Int, day: Int) {
        let z = number + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? y + 1 : y, m, d)
    }

    /// 0 = Monday … 6 = Sunday. Weeks start on Monday.
    public var weekday: Int { ((number % 7) + 7 + 3) % 7 }

    public var isWeekend: Bool { weekday >= 5 }

    /// "2026-12-01", as the file keeps it and as PARAGON writes a date.
    public var iso: String {
        let p = parts
        return String(format: "%04d-%02d-%02d", p.year, p.month, p.day)
    }

    public var description: String { iso }

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let fullMonths = ["January", "February", "March", "April", "May", "June", "July",
                                     "August", "September", "October", "November", "December"]

    /// "Dec"
    public var monthWord: String { Day.months[parts.month - 1] }
    /// "December 2026"
    public var monthAndYear: String { "\(Day.fullMonths[parts.month - 1]) \(parts.year)" }
    /// "1 Dec"
    public var short: String { "\(parts.day) \(monthWord)" }
    /// "1 Dec 2026"
    public var long: String { "\(short) \(parts.year)" }

    /// The Monday of this day's week.
    public var weekStart: Day { self - weekday }
    /// The number of this day's week, 1 to 53, counted as in Sweden and most of Europe: weeks begin on
    /// Monday, and week 1 is the week that holds the year's first Thursday.
    public var weekNumber: Int {
        let thursday = weekStart + 3
        return (thursday - Day(year: thursday.parts.year, month: 1, day: 1)) / 7 + 1
    }
    /// "w 49", as it stands above a week on the Weeks scale.
    public var weekWord: String { "w \(weekNumber)" }
    /// The first day of this day's month.
    public var monthStart: Day { self - (parts.day - 1) }
    /// The first day of the month after this day's.
    public var nextMonthStart: Day {
        let p = parts
        return p.month == 12 ? Day(year: p.year + 1, month: 1, day: 1) : Day(year: p.year, month: p.month + 1, day: 1)
    }

    /// Noon of the day, for a date picker.
    public func date(calendar: Calendar = .current) -> Date {
        let p = parts
        return calendar.date(from: DateComponents(year: p.year, month: p.month, day: p.day, hour: 12)) ?? Date()
    }

    public static func < (a: Day, b: Day) -> Bool { a.number < b.number }
    public static func + (a: Day, days: Int) -> Day { Day(number: a.number + days) }
    public static func - (a: Day, days: Int) -> Day { Day(number: a.number - days) }
    /// Whole days from `b` to `a`.
    public static func - (a: Day, b: Day) -> Int { a.number - b.number }
}

// MARK: The three scales

/// How wide a day is drawn. Zooming a timeline steps through these three.
public enum TimeScale: String, CaseIterable, Sendable {
    case days, weeks, months

    public var word: String {
        switch self {
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .months: return "Months"
        }
    }

    /// Screen points for one day: a day is 28 wide, a week 56, a month about 72.
    public var pointsPerDay: Double {
        switch self {
        case .days: return 28
        case .weeks: return 8
        case .months: return 2.4
        }
    }

    /// One step closer (months → weeks → days); nil at the closest.
    public var closer: TimeScale? {
        switch self {
        case .months: return .weeks
        case .weeks: return .days
        case .days: return nil
        }
    }

    /// One step further away (days → weeks → months); nil at the furthest.
    public var further: TimeScale? {
        switch self {
        case .days: return .weeks
        case .weeks: return .months
        case .months: return nil
        }
    }

    /// The length a new bar gets: 3 days, a week, or 30 days.
    public var newBarDays: Int {
        switch self {
        case .days: return 3
        case .weeks: return 7
        case .months: return 30
        }
    }

    /// Empty days shown before the first and after the last bar.
    public var air: Int {
        switch self {
        case .days: return 3
        case .weeks: return 7
        case .months: return 21
        }
    }

    /// The closest scale at which this many days still fit into the width; months when none does.
    public static func fitting(days: Int, width: Double) -> TimeScale {
        for scale in [TimeScale.days, .weeks, .months] where Double(days) * scale.pointsPerDay <= width { return scale }
        return .months
    }
}

/// A date written in the pinned row at the top, with its line down the chart.
public struct TimeTick: Equatable, Sendable {
    public var day: Day
    public var label: String
    /// A Monday among days: its line is a little stronger.
    public var strong: Bool
}

/// Where everything of a timeline is on screen. Days ↔ x, rows ↔ y; nothing else decides a place.
public struct TimelineGeometry: Equatable, Sendable {
    /// The day whose left edge is at the start of the chart when nothing is slid.
    public static let zero = Day(year: 2000, month: 1, day: 3)

    public var scale: TimeScale
    /// The pinned column of names at the left.
    public var namesWidth: Double
    /// The pinned band of dates at the top.
    public var headerHeight: Double
    public var rowHeight: Double
    public var barHeight: Double
    /// How far the days are slid sideways and the rows up or down.
    public var slide: CGSize

    public init(scale: TimeScale, namesWidth: Double = 170, headerHeight: Double = 44, rowHeight: Double = 34,
                barHeight: Double = 22, slide: CGSize = .zero) {
        self.scale = scale
        self.namesWidth = namesWidth
        self.headerHeight = headerHeight
        self.rowHeight = rowHeight
        self.barHeight = barHeight
        self.slide = slide
    }

    /// The left edge of a day.
    public func x(of day: Day) -> Double {
        namesWidth + Double(day - TimelineGeometry.zero) * scale.pointsPerDay + Double(slide.width)
    }

    /// The day under an x.
    public func day(atX x: Double) -> Day {
        TimelineGeometry.zero + Int(((x - namesWidth - Double(slide.width)) / scale.pointsPerDay).rounded(.down))
    }

    /// Whole days for a sideways drag of this many points (half a day rounds away from nothing).
    public func days(forDrag points: Double) -> Int { Int((points / scale.pointsPerDay).rounded()) }

    /// The top of a row.
    public func y(ofRow row: Int) -> Double { headerHeight + Double(row) * rowHeight + Double(slide.height) }

    /// The row under a y (it may be before the first or after the last).
    public func row(atY y: Double) -> Int { Int(((y - headerHeight - Double(slide.height)) / rowHeight).rounded(.down)) }

    /// A bar from the morning of its first day to the evening of its last.
    public func bar(from start: Day, to end: Day, row: Int) -> CGRect {
        let left = x(of: start) + 1
        let right = x(of: max(start, end) + 1) - 1
        return CGRect(x: left, y: y(ofRow: row) + (rowHeight - barHeight) / 2, width: max(right - left, 4), height: barHeight)
    }

    /// A milestone's diamond, in the middle of its day.
    public func diamond(on day: Day, row: Int) -> CGRect {
        let side = barHeight - 2
        let mid = x(of: day) + scale.pointsPerDay / 2
        return CGRect(x: mid - side / 2, y: y(ofRow: row) + (rowHeight - side) / 2, width: side, height: side)
    }

    /// The Today line: down the middle of today.
    public func todayX(_ today: Day) -> Double { x(of: today) + scale.pointsPerDay / 2 }

    /// The slide that puts this day at the start of the chart.
    public func slide(showing day: Day, after points: Double = 0) -> Double {
        points - Double(day - TimelineGeometry.zero) * scale.pointsPerDay
    }

    /// The dates of the pinned row: every day (its number), every Monday ("1 Dec") or every month ("Dec").
    public static func ticks(from first: Day, to last: Day, scale: TimeScale) -> [TimeTick] {
        guard first <= last else { return [] }
        var ticks: [TimeTick] = []
        switch scale {
        case .days:
            var day = first
            while day <= last {
                ticks.append(TimeTick(day: day, label: "\(day.parts.day)", strong: day.weekday == 0))
                day = day + 1
            }
        case .weeks:
            var day = first.weekday == 0 ? first : first.weekStart + 7
            while day <= last {
                ticks.append(TimeTick(day: day, label: day.short, strong: false))
                day = day + 7
            }
        case .months:
            var day = first.parts.day == 1 ? first : first.nextMonthStart
            while day <= last {
                ticks.append(TimeTick(day: day, label: day.monthWord, strong: day.parts.month == 1))
                day = day.nextMonthStart
            }
        }
        return ticks
    }

    /// The small words above the dates, saying what the dates leave out: the month and year
    /// above day numbers, the year above weeks and months.
    public static func heads(from first: Day, to last: Day, scale: TimeScale) -> [TimeTick] {
        guard first <= last else { return [] }
        var heads = [TimeTick(day: first, label: head(for: first, scale: scale), strong: true)]
        var day = scale == .days ? first.nextMonthStart : Day(year: first.parts.year + 1, month: 1, day: 1)
        while day <= last {
            heads.append(TimeTick(day: day, label: head(for: day, scale: scale), strong: false))
            day = scale == .days ? day.nextMonthStart : Day(year: day.parts.year + 1, month: 1, day: 1)
        }
        return heads
    }

    public static func head(for day: Day, scale: TimeScale) -> String {
        scale == .days ? day.monthAndYear : "\(day.parts.year)"
    }

    /// The thin right-angled "comes after" arrow from the end of one bar to the start of the next.
    /// With room between them it goes out, down and in; without, it runs back along the line between the rows.
    public func arrow(from a: CGRect, to b: CGRect) -> [CGPoint] {
        let start = CGPoint(x: a.maxX, y: a.midY)
        let end = CGPoint(x: b.minX, y: b.midY)
        let out: CGFloat = 8
        if abs(end.y - start.y) < 0.5 {
            return end.x >= start.x ? [start, end] : [start, CGPoint(x: start.x + out, y: start.y), end]
        }
        if end.x >= start.x + out + 6 {
            return [start, CGPoint(x: start.x + out, y: start.y), CGPoint(x: start.x + out, y: end.y), end]
        }
        let lane = start.y + (end.y > start.y ? 1 : -1) * CGFloat(rowHeight) / 2
        return [start, CGPoint(x: start.x + out, y: start.y), CGPoint(x: start.x + out, y: lane),
                CGPoint(x: end.x - out, y: lane), CGPoint(x: end.x - out, y: end.y), end]
    }
}

// MARK: What is kept in the file

public extension ItemKind {
    /// A bar, a milestone or a phase: the three things of a timeline.
    var isTimeline: Bool { self == .bar || self == .milestone || self == .phase }
}

public enum BarEdge: Sendable { case start, end }

public extension Item {
    /// The first and the last day of a bar (the same day for a milestone). nil for a phase,
    /// for anything that is not on a timeline, and when no day is written.
    var span: (start: Day, end: Day)? {
        guard kind == .bar || kind == .milestone, let first = start.flatMap({ Day(iso: $0) }) else { return nil }
        if kind == .milestone { return (first, first) }
        let last = end.flatMap { Day(iso: $0) } ?? first
        return (first, max(first, last))
    }

    /// The name on one line (line breaks become spaces), as it stands in the names column.
    var nameLine: String { ParagonExport.oneLine(text) }

    /// How many days it takes: 1 for a milestone and for a bar that starts and ends on the same day.
    var dayCount: Int { span.map { $0.end - $0.start + 1 } ?? 0 }

    /// Writes the days. A bar is never shorter than one day; a milestone keeps only its day.
    mutating func setSpan(_ first: Day, _ last: Day) {
        start = first.iso
        end = kind == .milestone ? nil : max(first, last).iso
    }

    /// "1 Dec – 12 Dec 2026 · 12 days", "20 Feb 2027" for one day.
    var spanWords: String {
        guard let span else { return "" }
        if span.start == span.end { return span.start.long }
        let first = span.start.parts.year == span.end.parts.year ? span.start.short : span.start.long
        return "\(first) – \(span.end.long) · \(dayCount) days"
    }
}

/// A phase with the rows that belong to it and the days they cover.
public struct PhaseGroup: Equatable, Sendable {
    public var id: UUID
    /// The heading's own row.
    public var firstRow: Int
    /// The last row under it (its own row when it is empty).
    public var lastRow: Int
    /// From the first day of its earliest bar to the last day of its latest; nil when it is empty.
    public var start: Day?
    public var end: Day?
}

// MARK: The rules

public extension Board {
    /// What `kind` holds for a timeline. A board without a kind is an ordinary board.
    static let timelineKind = "timeline"

    var isTimeline: Bool { kind == Board.timelineKind }

    /// A new, empty timeline.
    static func timeline(title: String = "Timeline", created: Date = Date()) -> Board {
        var board = Board(title: title, created: created)
        board.kind = Board.timelineKind
        return board
    }

    /// The starter: three steps one after the other and a milestone, beginning today.
    static func timelineStart(title: String = "Timeline", now: Date = Date()) -> Board {
        var board = Board.timeline(title: title, created: now)
        let today = Day(now)
        let plan = board.addBar("Plan", start: today, days: 5, colour: "blue")
        let make = board.addBar("Do", start: today + 5, days: 10, colour: "teal")
        let check = board.addBar("Check", start: today + 15, days: 5, colour: "orange")
        let done = board.addMilestone("Done", on: today + 20)
        board.comesAfter(make, after: plan)
        board.comesAfter(check, after: make)
        board.comesAfter(done, after: check)
        return board
    }

    // MARK: Rows

    /// The rows from the top: every bar, milestone and phase, by its row number
    /// (two with the same number stay in the order they were made).
    var timelineRows: [Item] {
        items.enumerated().filter { $0.element.kind.isTimeline }
            .sorted { ($0.element.row ?? Int.max, $0.offset) < ($1.element.row ?? Int.max, $1.offset) }
            .map(\.element)
    }

    /// The row an item is in, counted from 0 at the top.
    func timelineRow(of id: UUID) -> Int? { timelineRows.firstIndex { $0.id == id } }

    private mutating func number(rows order: [UUID]) {
        for (n, id) in order.enumerated() {
            if let i = index(of: id) { items[i].row = n }
        }
    }

    private mutating func insert(_ item: Item, atRow row: Int?) {
        var order = timelineRows.map(\.id)
        order.insert(item.id, at: min(max(row ?? order.count, 0), order.count))
        items.append(item)
        number(rows: order)
    }

    /// Puts a row at another place (0 = the top); the rows between move up or down by one.
    mutating func moveRow(_ id: UUID, to row: Int) {
        var order = timelineRows.map(\.id)
        guard let from = order.firstIndex(of: id) else { return }
        order.remove(at: from)
        order.insert(id, at: min(max(row, 0), order.count))
        number(rows: order)
    }

    /// A row dragged up or down by its name. A bar or a milestone moves alone (`moveRow`). A phase carries
    /// its rows: the heading and every row under it move as one block, and the block only ever lands where
    /// it splits no other phase — before another phase, at the very end, or among the rows above the first phase.
    mutating func carryRow(_ id: UUID, to row: Int) {
        guard let group = phaseGroups.first(where: { $0.id == id }) else { moveRow(id, to: row); return }
        var order = timelineRows.map(\.id)
        let block = Array(order[group.firstRow...group.lastRow])
        order.removeSubrange(group.firstRow...group.lastRow)
        let phases = Set(items.filter { $0.kind == .phase }.map(\.id))
        let firstPhase = order.firstIndex(where: phases.contains) ?? order.count
        let wanted = min(max(row, 0), order.count)
        let allowed = (0...order.count).filter { $0 <= firstPhase || $0 == order.count || phases.contains(order[$0]) }
        // The nearest such place; of two equally near, the one in the direction the block is dragged.
        let down = row > group.firstRow
        let at = allowed.min { a, b in
            (abs(a - wanted), down ? -a : a) < (abs(b - wanted), down ? -b : b)
        } ?? wanted
        order.insert(contentsOf: block, at: at)
        number(rows: order)
    }

    /// The phases with their rows: a phase holds every row under it down to the next phase.
    var phaseGroups: [PhaseGroup] {
        let rows = timelineRows
        var groups: [PhaseGroup] = []
        for (n, item) in rows.enumerated() {
            if item.kind == .phase {
                groups.append(PhaseGroup(id: item.id, firstRow: n, lastRow: n, start: nil, end: nil))
            } else if !groups.isEmpty, let span = item.span {
                let g = groups.count - 1
                groups[g].lastRow = n
                groups[g].start = groups[g].start.map { min($0, span.start) } ?? span.start
                groups[g].end = groups[g].end.map { max($0, span.end) } ?? span.end
            } else if !groups.isEmpty {
                groups[groups.count - 1].lastRow = n
            }
        }
        return groups
    }

    // MARK: Adding

    /// A new bar of this many days (never fewer than one). Without a row it goes under the last one.
    @discardableResult
    mutating func addBar(_ text: String = "", start: Day, days: Int = 7, atRow row: Int? = nil, colour: String = "") -> UUID {
        var item = Item(kind: .bar, text: text, colour: colour)
        if colour.isEmpty { item.colour = Palette.branch(items.filter { $0.kind == .bar }.count) }
        item.setSpan(start, start + (max(days, 1) - 1))
        insert(item, atRow: row)
        return item.id
    }

    /// A new milestone: one day, drawn as a diamond.
    @discardableResult
    mutating func addMilestone(_ text: String = "", on day: Day, atRow row: Int? = nil, colour: String = "purple") -> UUID {
        var item = Item(kind: .milestone, text: text, colour: colour)
        item.setSpan(day, day)
        insert(item, atRow: row)
        return item.id
    }

    /// A new phase: a heading row for the rows under it.
    @discardableResult
    mutating func addPhase(_ text: String = "", atRow row: Int? = nil, colour: String = "") -> UUID {
        var item = Item(kind: .phase, text: text, colour: colour)
        if colour.isEmpty {
            let used = items.filter { $0.kind == .phase }.count
            item.colour = ["teal", "blue", "orange", "green", "pink", "purple"][used % 6]
        }
        insert(item, atRow: row)
        return item.id
    }

    /// Return on a chosen bar: the next bar, in the row below, starting the day after this one ends,
    /// as long as this one (a week after a milestone), in its colour, already joined "comes after".
    @discardableResult
    mutating func addBarAfter(_ id: UUID) -> UUID? {
        guard let source = item(id), let span = source.span, let row = timelineRow(of: id) else { return nil }
        let days = source.kind == .bar ? source.dayCount : 7
        let new = addBar(start: span.end + 1, days: days, atRow: row + 1, colour: source.kind == .bar ? source.colour : "")
        links.append(Link(from: id, to: new))
        return new
    }

    // MARK: Moving and stretching

    private mutating func slideDays(_ id: UUID, by days: Int) {
        guard days != 0, let i = index(of: id), let span = items[i].span else { return }
        items[i].setSpan(span.start + days, span.end + days)
    }

    /// The first day a bar may start on: the day after the last of the bars it comes after ends.
    func earliestStart(of id: UUID) -> Day? {
        links.filter { $0.to == id }.compactMap { item($0.from)?.span?.end }.max().map { $0 + 1 }
    }

    /// After these bars were moved or stretched: none of them starts before a bar it comes after has
    /// ended, and every bar that comes after them is pushed later (keeping its length) until none
    /// starts before its forerunner ends. Bars are only ever pushed later, never pulled earlier.
    /// Returns how many OTHER bars were pushed.
    @discardableResult
    mutating func settle(_ ids: Set<UUID>) -> Int {
        for _ in 0..<max(ids.count, 1) {
            var changed = false
            for id in ids {
                guard let span = item(id)?.span, let earliest = earliestStart(of: id), span.start < earliest else { continue }
                slideDays(id, by: earliest - span.start)
                changed = true
            }
            if !changed { break }
        }
        var pushed: Set<UUID> = []
        var work = Array(ids)
        // A file from elsewhere could hold a ring of arrows: the count below ends the work in any case.
        var steps = (items.count + 1) * (links.count + 1)
        while let id = work.popLast(), steps > 0 {
            steps -= 1
            guard let span = item(id)?.span else { continue }
            for link in links where link.from == id {
                guard let next = item(link.to)?.span, next.start <= span.end else { continue }
                slideDays(link.to, by: span.end + 1 - next.start)
                if !ids.contains(link.to) { pushed.insert(link.to) }
                work.append(link.to)
            }
        }
        return pushed.count
    }

    /// Moves bars and milestones by whole days. Returns how many other bars were pushed along.
    @discardableResult
    mutating func shift(_ ids: Set<UUID>, byDays days: Int) -> Int {
        let timed = Set(ids.filter { item($0)?.span != nil })
        guard days != 0, !timed.isEmpty else { return 0 }
        for id in timed { slideDays(id, by: days) }
        return settle(timed)
    }

    /// Pulls one end of a bar to a day. The bar is never shorter than one day, and its start never
    /// goes before the end of a bar it comes after. Returns how many bars were pushed along.
    @discardableResult
    mutating func stretch(_ id: UUID, _ edge: BarEdge, to day: Day) -> Int {
        guard let i = index(of: id), items[i].kind == .bar, let span = items[i].span else { return 0 }
        switch edge {
        case .start:
            var first = min(day, span.end)
            if let earliest = earliestStart(of: id) { first = max(first, min(earliest, span.end)) }
            items[i].setSpan(first, span.end)
            return 0
        case .end:
            items[i].setSpan(span.start, max(day, span.start))
            return settle([id])
        }
    }

    /// Sets both days at once (the Dates page). Returns how many bars were pushed along.
    @discardableResult
    mutating func setDates(_ id: UUID, start: Day, end: Day) -> Int {
        guard let i = index(of: id), items[i].span != nil else { return 0 }
        items[i].setSpan(start, max(start, end))
        return settle([id])
    }

    // MARK: Comes after

    /// True when following the "comes after" arrows from one bar leads to the other.
    func leads(from: UUID, to: UUID) -> Bool {
        var seen: Set<UUID> = []
        var work = [from]
        while let id = work.popLast() {
            if id == to { return true }
            guard seen.insert(id).inserted else { continue }
            work.append(contentsOf: links.filter { $0.from == id }.map(\.to))
        }
        return false
    }

    /// Joins two bars: `follower` comes after `forerunner`. Refused (nil) for a phase, for the same
    /// pair twice, and when it would close a ring. Otherwise the follower (and what comes after it)
    /// is pushed where needed, and the number of bars that moved comes back.
    @discardableResult
    mutating func comesAfter(_ follower: UUID, after forerunner: UUID) -> Int? {
        guard follower != forerunner, item(follower)?.span != nil, item(forerunner)?.span != nil,
              !links.contains(where: { $0.from == forerunner && $0.to == follower }),
              !leads(from: follower, to: forerunner) else { return nil }
        links.append(Link(from: forerunner, to: follower))
        return settle([forerunner])
    }

    /// Copies bars into the rows right under them (the copy of a bar is not joined to anything).
    @discardableResult
    mutating func duplicateRows(_ ids: Set<UUID>) -> Set<UUID> {
        var copies: Set<UUID> = []
        for source in timelineRows.reversed() where ids.contains(source.id) {
            guard let row = timelineRow(of: source.id) else { continue }
            var copy = source
            copy.id = UUID()
            // A copy is a new piece of work: it is not done yet.
            copy.doneDay = nil
            insert(copy, atRow: row + 1)
            copies.insert(copy.id)
        }
        return copies
    }

    // MARK: What is seen

    /// The days a timeline shows when it is seen whole: from a few days before its first bar to a
    /// few days after its last, and always with today in it.
    func timelineRange(today: Day, air: Int = 7) -> (first: Day, last: Day) {
        let spans = items.compactMap(\.span)
        let first = min(spans.map(\.start).min() ?? today, today)
        let last = max(spans.map(\.end).max() ?? today, today)
        return (first - max(air, 0), last + max(air, 0))
    }

    /// The scale and the box of a timeline drawn whole (for its picture): names, dates and every row.
    func timelinePicture(today: Day = .today(), width: Double = 1100) -> (geometry: TimelineGeometry, box: CGRect) {
        var range = timelineRange(today: today, air: 0)
        let scale = TimeScale.fitting(days: range.last - range.first + 1 + 14, width: width)
        range = timelineRange(today: today, air: scale.air)
        // Whole weeks or months, so the first date line is at the left edge.
        let first = scale == .months ? range.first.monthStart : range.first.weekStart
        let longest = timelineRows.map { Double(Board.roughSize(for: $0.text).width) }.max() ?? 0
        var geometry = TimelineGeometry(scale: scale, namesWidth: min(max(longest + 44, 120), 260))
        geometry.slide = CGSize(width: geometry.slide(showing: first), height: 0)
        let days = Double(range.last - first + 1)
        let box = CGRect(x: 0, y: 0, width: geometry.namesWidth + days * scale.pointsPerDay,
                         height: geometry.headerHeight + Double(max(timelineRows.count, 1)) * geometry.rowHeight + 10)
        return (geometry, box)
    }

    /// Short words for the list: "6 bars · 1 milestone · 2 phases".
    var timelineCountLine: String {
        func count(_ kind: ItemKind, _ one: String, _ many: String) -> String? {
            let n = items.filter { $0.kind == kind }.count
            return n == 0 ? nil : (n == 1 ? "1 \(one)" : "\(n) \(many)")
        }
        let parts = [count(.bar, "bar", "bars"), count(.milestone, "milestone", "milestones"), count(.phase, "phase", "phases")]
            .compactMap { $0 }
        return parts.isEmpty ? "Empty" : parts.joined(separator: " · ")
    }

    /// The timeline as plain text to copy: its rows with their dates, then what comes after what.
    var timelineText: String {
        var lines = ParagonExport.timelineBullets(self)
        let after = ParagonExport.timelineOrder(self)
        if !after.isEmpty { lines.append(""); lines.append("Comes after:"); lines.append(contentsOf: after) }
        return lines.joined(separator: "\n")
    }
}

// MARK: The hand-over to PARAGON

// Read from PARAGON's own code (TaskParser.swift, Note.swift), build 339:
// - a task line carries ONE day of its own, written ` >2026-12-14` (PARAGON calls it due); the mark
//   must stand alone between spaces or at the end of the line;
// - there is no start or defer day on a task. `@deadline(…)` exists, but PARAGON counts a task as
//   overdue from the EARLIER of the two, so a bar written "do on its first day, in by its last"
//   would turn red on its second day. So: the bar's LAST day is its due day in PARAGON's own form,
//   and its first day stands in plain words on the line — "(starts 1 Dec)";
// - a project's own last day is the line `due: 2026-12-31` in the note's head.
public extension ParagonExport {
    private static func name(_ item: Item) -> String {
        let words = oneLine(item.text)
        return words.isEmpty ? "(empty)" : words
    }

    /// One task line: "- [ ] Foundation (starts 1 Dec) >2026-12-14". A milestone and a one-day bar
    /// carry only their day.
    static func timelineTask(_ item: Item) -> String {
        guard let span = item.span else { return "- [ ] \(name(item))" }
        if span.start == span.end { return "- [ ] \(name(item)) >\(span.end.iso)" }
        let first = span.start.parts.year == span.end.parts.year ? span.start.short : span.start.long
        return "- [ ] \(name(item)) (starts \(first)) >\(span.end.iso)"
    }

    /// The bars and milestones as tasks: those above the first phase first, then each phase as a
    /// `###` heading with its tasks. Inside each group in date order (first day, then last day).
    static func timelineTaskGroups(_ board: Board) -> (loose: [String], groups: [[String]]) {
        func inOrder(_ items: [Item]) -> [String] {
            items.enumerated().sorted { a, b in
                let x = a.element.span, y = b.element.span
                return (x?.start.number ?? Int.max, x?.end.number ?? Int.max, a.offset)
                    < (y?.start.number ?? Int.max, y?.end.number ?? Int.max, b.offset)
            }.map { timelineTask($0.element) }
        }
        var loose: [Item] = []
        var groups: [(String, [Item])] = []
        for item in board.timelineRows {
            if item.kind == .phase {
                groups.append((name(item), []))
            } else if groups.isEmpty {
                loose.append(item)
            } else {
                groups[groups.count - 1].1.append(item)
            }
        }
        return (inOrder(loose), groups.map { ["### \($0.0)"] + inOrder($0.1) })
    }

    /// The rows as a list for a note: a phase in bold, under it "- Permit: 1 Dec – 12 Dec 2026 · 12 days".
    static func timelineBullets(_ board: Board) -> [String] {
        var lines: [String] = []
        var inPhase = false
        for item in board.timelineRows {
            if item.kind == .phase {
                lines.append("- **\(name(item))**")
                inPhase = true
                continue
            }
            let words = item.spanWords
            let mark = item.kind == .milestone ? " (milestone)" : ""
            lines.append((inPhase ? "  " : "") + "- \(name(item))\(mark)" + (words.isEmpty ? "" : ": \(words)"))
        }
        return lines
    }

    /// "- Foundation comes after Permit", one line per arrow.
    static func timelineOrder(_ board: Board) -> [String] {
        board.links.compactMap { link in
            guard let a = board.item(link.from), let b = board.item(link.to), a.kind.isTimeline, b.kind.isTimeline else { return nil }
            return "- \(name(b)) comes after \(name(a))"
        }
    }

    /// A timeline as a NOTE for Resources/: the picture, the way back, the rows with their dates,
    /// what comes after what, and the to-do bars as tasks with their days.
    static func timelineNote(board: Board, title: String, picture: String?, now: Date) -> String {
        var out = frontMatter(title: title, type: "resource", status: nil, now: now)
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        section("Timeline", timelineBullets(board), into: &out)
        section("Comes after", timelineOrder(board), into: &out)
        section("Tasks", board.timelineRows.filter { $0.todo && $0.kind != .phase }.map { timelineTask($0) }, into: &out)
        return out
    }

    /// A timeline as a PROJECT for Projects/: phases as `###` headings under `## Tasks`, bars as tasks
    /// in date order with their first day in words and their last day as PARAGON's due day,
    /// milestones as tasks on their day. The project's own `due:` is the last day on the timeline.
    static func timelineProject(board: Board, title: String, picture: String?, now: Date) -> String {
        var out = frontMatter(title: title, type: "project", status: "active", now: now)
        if let last = board.items.compactMap({ $0.span?.end }).max(), out.hasSuffix("---\n") {
            out.removeLast(4)
            out += "due: \(last.iso)\n---\n"
        }
        out += "# \(title)\n\n"
        out += head(board: board, picture: picture)
        out += "## Outcome\n\n\(title)\n\n"
        let tasks = timelineTaskGroups(board)
        out += "## Tasks\n\n"
        if !tasks.loose.isEmpty { out += tasks.loose.joined(separator: "\n") + "\n\n" }
        for group in tasks.groups { out += group.joined(separator: "\n") + "\n\n" }
        out += "## Notes\n\n"
        let order = timelineOrder(board)
        if !order.isEmpty { out += order.joined(separator: "\n") + "\n\n" }
        out += "## Log\n\n- \(stamp(now, "yyyy-MM-dd")): Project created from a Seedboard timeline\n"
        return out
    }
}
