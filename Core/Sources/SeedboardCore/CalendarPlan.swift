import Foundation

// 0.9: a timeline's milestones (and, if asked, its bars) into the owner's calendar. This file is the
// pure part: which rows become which all-day events, the day maths, and what a device remembers about
// what it already added. The calendar itself (EventKit) is in the app. Write-only access cannot read
// events back, so "added" is remembered on the device: row id → the days it was added for.

/// One all-day event to make: a milestone is one day, a bar covers its first to its last day.
public struct CalendarEvent: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var first: Day
    /// The last day (the same as `first` for a milestone); an all-day event covers both ends.
    public var last: Day
    public var notes: String
    public var isMilestone: Bool

    /// How many days it covers.
    public var dayCount: Int { last - first + 1 }
}

/// What this device knows about one row: the days it was put in the calendar for, and the day it was done.
public struct CalendarEntry: Codable, Equatable, Sendable {
    public var first: String
    public var last: String
    public var added: String
}

/// What this device remembers (kept in its own settings, never in the board).
public struct CalendarMemory: Codable, Equatable, Sendable {
    public var entries: [UUID: CalendarEntry] = [:]

    public init(entries: [UUID: CalendarEntry] = [:]) { self.entries = entries }

    /// How a row stands against what was added.
    public enum State: Equatable, Sendable {
        case new
        case added(on: Day)
        /// Added before, but its days have changed since.
        case changed
    }

    public func state(of item: Item) -> State {
        guard let entry = entries[item.id], let span = item.span else { return .new }
        guard entry.first == span.start.iso, entry.last == span.end.iso else { return .changed }
        return .added(on: Day(iso: entry.added) ?? span.start)
    }

    /// The events that went into the calendar today.
    public mutating func remember(_ events: [CalendarEvent], on day: Day) {
        for e in events { entries[e.id] = CalendarEntry(first: e.first.iso, last: e.last.iso, added: day.iso) }
    }

    /// The words beside a row: "Added 18 Nov", "Day changed — add again", "Days changed — add again"; "" when new.
    public func words(of item: Item) -> String {
        switch state(of: item) {
        case .new: return ""
        case .added(let day): return "Added \(day.short)"
        case .changed: return item.kind == .milestone ? "Day changed — add again" : "Days changed — add again"
        }
    }
}

/// One line of the "Add to Calendar" page.
public struct CalendarChoice: Equatable, Sendable {
    public var event: CalendarEvent
    public var state: CalendarMemory.State
    /// Ticked when the page opens: new and changed milestones; never a bar, never what was added already.
    public var ticked: Bool
}

public extension Board {
    /// The events one row makes; nil for a phase and for a row without days.
    func calendarEvent(_ item: Item) -> CalendarEvent? {
        guard let span = item.span else { return nil }
        let name = item.nameLine.trimmingCharacters(in: .whitespaces)
        return CalendarEvent(id: item.id, title: name.isEmpty ? item.kind.word : name, first: span.start, last: span.end,
                             notes: "From the Seedboard board “\(title)”", isMilestone: item.kind == .milestone)
    }

    /// The page's lines: every milestone, by day, then every bar, by first day.
    func calendarChoices(memory: CalendarMemory) -> (milestones: [CalendarChoice], bars: [CalendarChoice]) {
        func lines(_ kind: ItemKind) -> [CalendarChoice] {
            timelineRows.filter { $0.kind == kind }
                .compactMap { item -> CalendarChoice? in
                    guard let event = calendarEvent(item) else { return nil }
                    let state = memory.state(of: item)
                    var ticked = false
                    if kind == .milestone { ticked = state != .new ? state == .changed : true }
                    return CalendarChoice(event: event, state: state, ticked: ticked)
                }
                .sorted { ($0.event.first, $0.event.title) < ($1.event.first, $1.event.title) }
        }
        return (lines(.milestone), lines(.bar))
    }
}
