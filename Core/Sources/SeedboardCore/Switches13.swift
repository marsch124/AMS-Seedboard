import Foundation

// 0.13: the switches in Settings. Two new parts live here as plain rules:
// - the calendar that follows the timelines by itself (`CalendarFollow`): which events SHOULD be in the
//   "Seedboard" calendar, and what to add, change and take out so it matches;
// - "Still thinking about these?" (`Nudge`): which boards come up at the top of the boards.
// The calendar itself (EventKit) and the switches' storage are in the app (Switches13.swift there).

/// One event the "Seedboard" calendar should hold, or holds. `key` is the event's link, how Seedboard knows its own.
public struct FollowEvent: Equatable, Sendable {
    public var key: String
    public var title: String
    public var first: Day
    public var last: Day
    public var notes: String

    public init(key: String, title: String, first: Day, last: Day, notes: String) {
        self.key = key
        self.title = title
        self.first = first
        self.last = last
        self.notes = notes
    }
}

public enum CalendarFollow {
    /// The start of every link Seedboard puts on its events. Events without it are never touched.
    public static let linkStart = "seedboard://board/"

    public static func key(board: UUID, item: UUID) -> String {
        BoardLink.link(board: board, item: item)
    }

    /// Whether an event's link is one of Seedboard's.
    public static func isOurs(_ link: String?) -> Bool {
        guard let link else { return false }
        return link.hasPrefix(linkStart) && link.contains("/item/")
    }

    /// Every milestone and bar with days, of every board that is not put away. Done ones end with " (done)".
    public static func wanted(boards: [Board]) -> [FollowEvent] {
        var out: [FollowEvent] = []
        for board in boards where !board.isPutAway {
            for item in board.timelineRows where item.kind == .bar || item.kind == .milestone {
                guard let event = board.calendarEvent(item) else { continue }
                out.append(FollowEvent(key: key(board: board.id, item: item.id),
                                       title: event.title + (item.isDone ? " (done)" : ""),
                                       first: event.first, last: event.last, notes: event.notes))
            }
        }
        return out
    }

    public struct Plan: Equatable, Sendable {
        public var add: [FollowEvent] = []
        /// The wanted version of an event that is there but differs (name, days or notes).
        public var change: [FollowEvent] = []
        /// Keys to take out: no longer wanted, or a second copy of one that is.
        public var remove: [String] = []
        /// Second copies (two devices once added the same row): how many of each key to take out.
        public var twins: [String: Int] = [:]

        public var isEmpty: Bool { add.isEmpty && change.isEmpty && remove.isEmpty && twins.isEmpty }
    }

    /// What to do so the calendar's events (`existing`, Seedboard's own only) match `wanted`.
    public static func plan(wanted: [FollowEvent], existing: [FollowEvent]) -> Plan {
        var plan = Plan()
        var there: [String: FollowEvent] = [:]
        for e in existing where isOurs(e.key) {
            if there[e.key] == nil { there[e.key] = e } else { plan.twins[e.key, default: 0] += 1 }
        }
        var seen = Set<String>()
        for w in wanted where !seen.contains(w.key) {
            seen.insert(w.key)
            if let e = there[w.key] {
                if e != w { plan.change.append(w) }
            } else {
                plan.add.append(w)
            }
        }
        plan.remove = there.keys.filter { !seen.contains($0) }.sorted()
        return plan
    }

    // MARK: 0.14: care with the calendar

    /// Never more than this many days are taken out in one pass; the rest waits for the next one.
    public static let mostRemovals = 5
    /// Said under the switch when the calendar refused a change.
    public static let failedLine = "Could not update the calendar — will try again"

    /// The plan with its removals cut to `most`; `held` is how many wait. Added, changed and twin copies are not cut.
    public static func limited(_ plan: Plan, most: Int = mostRemovals) -> (plan: Plan, held: Int) {
        guard plan.remove.count > most else { return (plan, 0) }
        var cut = plan
        cut.remove = Array(plan.remove.prefix(most))
        return (cut, plan.remove.count - most)
    }

    /// A short, steady fingerprint of the wanted days: the same days always give the same words.
    public static func signature(of wanted: [FollowEvent]) -> String {
        let text = wanted.map { "\($0.key)|\($0.title)|\($0.first.number)|\($0.last.number)|\($0.notes)" }.sorted().joined(separator: "\n")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16) + "-\(wanted.count)"
    }

    public enum Pass: Equatable, Sendable {
        /// Boards are still arriving from iCloud: do nothing now, look again soon.
        case wait
        /// The wanted days are what they were at the last pass: the calendar is not touched.
        case skip
        case go
    }

    /// Whether the calendar is looked at now. `force`: the switch was just turned on, or it has been a while.
    public static func pass(arriving: Bool, signature: String, last: String?, force: Bool) -> Pass {
        if arriving { return .wait }
        if !force, let last, last == signature { return .skip }
        return .go
    }

    /// Calendars with our name: the one to keep (the remembered one when it is among them, else the first)
    /// and the ones to join into it.
    public static func joinPlan(_ calendars: [(id: String, title: String)], named name: String, remembered: String?) -> (keep: String, join: [String])? {
        let same = calendars.filter { $0.title == name }.map(\.id)
        guard let first = same.first else { return nil }
        let keep = remembered.flatMap { same.contains($0) ? $0 : nil } ?? first
        return (keep, same.filter { $0 != keep })
    }

    /// Switching off takes the calendar away only when nothing but Seedboard's own days were in it.
    public static func mayRemoveCalendar(leftOver: Int) -> Bool { leftOver == 0 }

    /// How far to look for our days: at least 5 years back and 10 ahead, and as far as days were ever put.
    public static func reach(first: Day?, last: Day?, now: Day) -> (start: Day, end: Day) {
        let back = Day(number: now.number - 5 * 366)
        let ahead = Day(number: now.number + 10 * 366)
        return (min(back, first ?? back), max(ahead, last ?? ahead))
    }

    /// The line under the switch: "14 events in the Seedboard calendar · updated 11:42".
    public static func line(events: Int, updated: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        let count = events == 1 ? "1 event in the Seedboard calendar" : "\(events) events in the Seedboard calendar"
        guard let updated else { return count }
        let time = DateFormatter()
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.locale = Locale(identifier: "en_GB")
        time.dateFormat = calendar.isDate(updated, inSameDayAs: now) ? "HH:mm" : "d MMM HH:mm"
        return "\(count) · updated \(time.string(from: updated))"
    }
}

/// "Still thinking about these?": boards nobody changed for two weeks, at most three, the oldest first.
public enum Nudge {
    public static let heading = "Still thinking about these?"
    /// Untouched this long before a board comes up; "Not now" waits this long too.
    public static let days = 14
    public static let most = 3

    /// `notNow`: board id → the moment it may come up again.
    public static func boards(_ boards: [Board], now: Date, notNow: [UUID: Date], calendar: Calendar = .current) -> [Board] {
        guard let edge = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }
        return boards
            .filter { b in
                !b.pinned && b.sent == nil && !b.isPutAway && b.canBeChanged && b.changed <= edge
                    && (notNow[b.id].map { $0 <= now } ?? true)
            }
            .sorted { ($0.changed, $0.title) < ($1.changed, $1.title) }
            .prefix(most)
            .map { $0 }
    }

    /// When a board said "Not now" at `now` may come up again.
    public static func askAgain(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: now) ?? now.addingTimeInterval(Double(days) * 86_400)
    }

    /// The remembered "Not now" days, without boards that are gone or whose wait is over.
    public static func tidy(_ notNow: [UUID: Date], boards: [Board], now: Date) -> [UUID: Date] {
        let ids = Set(boards.map(\.id))
        return notNow.filter { ids.contains($0.key) && $0.value > now }
    }
}
