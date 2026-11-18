import Foundation
import CoreGraphics

// 0.5, pick 18: a timeline that can be planned with. A bar can be marked done; a bar whose last day is
// behind today and is not done is late; one line says how far the plan is; "Catch up" brings a plan that
// fell behind back to today in one step; and the view (scale and place) a timeline was left at comes back
// on the same device. No screen in here: every rule below has a data test.

public extension Item {
    /// A bar or a milestone that was marked done (the day it was done is kept in `doneDay`).
    var isDone: Bool { (kind == .bar || kind == .milestone) && !(doneDay ?? "").isEmpty }

    /// The day it was marked done; nil when it is not done.
    var doneOn: Day? { isDone ? doneDay.flatMap { Day(iso: $0) } : nil }
}

/// How far a timeline is: "3 of 8 done · 1 late · ends 20 Feb".
public struct TimelineProgress: Equatable, Sendable {
    /// Bars and milestones that are done.
    public var done: Int
    /// All bars and milestones.
    public var total: Int
    /// Bars and milestones whose last day is behind today and that are not done.
    public var late: Int
    /// The last day of the latest bar.
    public var ends: Day?

    /// The pieces of the line, in order: "3 of 8 done", "1 late" (only when something is late), "ends 20 Feb"
    /// (with the year when it is not this year). Empty for a timeline without bars.
    public func parts(today: Day) -> [String] {
        guard total > 0 else { return [] }
        var parts = ["\(done) of \(total) done"]
        if late > 0 { parts.append("\(late) late") }
        if let ends { parts.append("ends \(ends.words(seenFrom: today))") }
        return parts
    }

    /// "3 of 8 done · 1 late · ends 20 Feb"; empty for a timeline without bars.
    public func line(today: Day) -> String { parts(today: today).joined(separator: " · ") }
}

public extension Day {
    /// "20 Feb" for a day in today's year, "20 Feb 2027" for any other.
    func words(seenFrom today: Day) -> String { parts.year == today.parts.year ? short : long }
}

/// What "Catch up" did.
public struct CatchUp: Equatable, Sendable {
    /// Bars and milestones whose days changed (the late ones and those pushed along).
    public var moved: Int
    /// The plan's last day before and after.
    public var was: Day?
    public var now: Day?

    /// "4 bars moved. The plan now ends 27 Feb (was 20 Feb)." — or "… The plan still ends 20 Feb."
    public func line(today: Day) -> String {
        let bars = moved == 1 ? "1 bar moved." : "\(moved) bars moved."
        guard let was, let now else { return bars }
        if was == now { return "\(bars) The plan still ends \(now.words(seenFrom: today))." }
        return "\(bars) The plan now ends \(now.words(seenFrom: today)) (was \(was.words(seenFrom: today)))."
    }
}

public extension Board {
    // MARK: Done

    /// Done: marked done on the board, or — `also` — ticked off in PARAGON (read back on this device, never
    /// kept in the board).
    func timelineIsDone(_ id: UUID, also: Set<UUID> = []) -> Bool {
        guard let item = item(id), item.span != nil else { return false }
        return item.isDone || also.contains(id)
    }

    /// Marks bars and milestones done on this day, or takes the mark off. A phase carries no mark.
    mutating func setDone(_ ids: Set<UUID>, _ done: Bool, on day: Day) {
        for id in ids {
            guard let i = index(of: id), items[i].span != nil else { continue }
            if done {
                if !items[i].isDone { items[i].doneDay = day.iso }
            } else {
                items[i].doneDay = nil
            }
        }
    }

    /// The Done button: when every chosen bar is done the mark comes off, otherwise all of them are done.
    /// Returns true when they are done afterwards.
    @discardableResult
    mutating func toggleDone(_ ids: Set<UUID>, on day: Day) -> Bool {
        let timed = ids.filter { item($0)?.span != nil }
        guard !timed.isEmpty else { return false }
        let allDone = timed.allSatisfy { item($0)?.isDone == true }
        setDone(timed, !allDone, on: day)
        return !allDone
    }

    // MARK: Late

    /// Late: its last day is behind today and it is not done.
    func timelineIsLate(_ id: UUID, today: Day, also done: Set<UUID> = []) -> Bool {
        guard let span = item(id)?.span else { return false }
        return span.end < today && !timelineIsDone(id, also: done)
    }

    /// The late bars and milestones, from the top row down.
    func lateBars(today: Day, also done: Set<UUID> = []) -> [UUID] {
        timelineRows.map(\.id).filter { timelineIsLate($0, today: today, also: done) }
    }

    /// How far the plan is.
    func timelineProgress(today: Day, also done: Set<UUID> = []) -> TimelineProgress {
        let timed = items.filter { $0.span != nil }
        return TimelineProgress(done: timed.filter { timelineIsDone($0.id, also: done) }.count,
                                total: timed.count,
                                late: timed.filter { timelineIsLate($0.id, today: today, also: done) }.count,
                                ends: timed.compactMap { $0.span?.end }.max())
    }

    // MARK: Catch up

    /// Brings a plan that fell behind back to today. Every late bar is stretched to end today: it is taken
    /// to be in work. A late bar that comes after another late bar cannot have begun, and a late milestone
    /// has not happened: those keep their length and move to start today. Then the rule that is there
    /// (`settle`) puts each after its forerunner and pushes along everything that comes after.
    /// nil when nothing is late (nothing changes).
    @discardableResult
    mutating func catchUp(today: Day, also done: Set<UUID> = []) -> CatchUp? {
        let late = lateBars(today: today, also: done)
        guard !late.isEmpty else { return nil }
        func days() -> [UUID: [Day]] {
            items.reduce(into: [UUID: [Day]]()) { if let span = $1.span { $0[$1.id] = [span.start, span.end] } }
        }
        let before = days()
        let was = items.compactMap { $0.span?.end }.max()
        let lateSet = Set(late)
        for id in late {
            guard let i = index(of: id), let span = items[i].span else { continue }
            let waits = links.contains { $0.to == id && lateSet.contains($0.from) }
            if items[i].kind == .milestone || waits {
                items[i].setSpan(today, today + (span.end - span.start))
            } else {
                items[i].setSpan(span.start, today)
            }
        }
        settle(lateSet)
        let moved = days().filter { before[$0.key] != $0.value }.count
        return CatchUp(moved: moved, was: was, now: items.compactMap { $0.span?.end }.max())
    }
}

// MARK: The view a timeline was left at

/// A timeline's view as the owner left it: the scale, the day that stood at the left edge of the chart
/// (beside the names; a fraction when a day was cut by the edge) and how far the rows were slid. Days, not
/// screen points, so the same days come back in a window of another size. Kept on ONE device, in its own
/// settings — never in the board.
public struct TimelineLeft: Codable, Equatable, Sendable {
    /// "days", "weeks" or "months".
    public var scale: String
    /// Days after `TimelineGeometry.zero` at the left edge of the chart.
    public var day: Double
    /// How far the rows are slid up (0 or less).
    public var rows: Double

    public init(scale: String, day: Double, rows: Double) {
        self.scale = scale
        self.day = day
        self.rows = rows
    }

    /// Whatever cannot be read is simply not remembered.
    public var isSound: Bool { TimeScale(rawValue: scale) != nil && day.isFinite && rows.isFinite && abs(day) < 400_000 }
}

public extension TimelineGeometry {
    /// What to write down about the view as it stands.
    var left: TimelineLeft {
        TimelineLeft(scale: scale.rawValue,
                     day: (-Double(slide.width) / scale.pointsPerDay * 100).rounded() / 100,
                     rows: Double(slide.height).rounded())
    }

    /// The scale and the slide that bring a view back; nil for one that cannot be read.
    static func comeBack(to left: TimelineLeft) -> (scale: TimeScale, slide: CGSize)? {
        guard left.isSound, let scale = TimeScale(rawValue: left.scale) else { return nil }
        return (scale, CGSize(width: -left.day * scale.pointsPerDay, height: min(left.rows, 0)))
    }
}

/// Every timeline's view on this device, by the board's id as text. At most 200 are kept: the ones looked
/// at longest ago are forgotten first.
public struct TimelineViews: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var view: TimelineLeft
        public var when: Date
    }

    public private(set) var views: [String: Entry]

    public init() { views = [:] }

    /// Tolerant: what cannot be read is not remembered.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        views = (try? c.decode([String: Entry].self, forKey: .views)) ?? [:]
    }

    enum CodingKeys: String, CodingKey { case views }

    public func view(of board: UUID) -> TimelineLeft? {
        guard let found = views[board.uuidString]?.view, found.isSound else { return nil }
        return found
    }

    /// The board is shown whole again the next time (the owner pressed "Show the whole timeline", or never moved it).
    public mutating func forget(_ board: UUID) { views[board.uuidString] = nil }

    public mutating func note(_ view: TimelineLeft, of board: UUID, now: Date = Date(), most: Int = 200) {
        views[board.uuidString] = Entry(view: view, when: now)
        guard views.count > most else { return }
        for key in views.sorted(by: { $0.value.when < $1.value.when }).prefix(views.count - most).map(\.key) {
            views[key] = nil
        }
    }
}
