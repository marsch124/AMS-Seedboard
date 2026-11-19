import SwiftUI
import Combine
import EventKit
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 0.13: the switches in Settings (kept on this device), the calendar that follows the timelines by itself, and
// "Still thinking about these?" at the top of the boards. The rules are in SeedboardCore (Switches13.swift).

/// The six switches. Each device keeps its own.
enum Switch {
    static let taps = "switch.taps"
    static let calendarAuto = "switch.calendarAuto"
    static let nudge = "switch.nudge"
    static let doneTicksParagon = "switch.doneTicksParagon"
    static let readParagon = "switch.readParagon"
    static let search = "switch.search"

    /// Everything is on at first, except the calendar (it asks for the calendar first).
    static func isOn(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil ? key != calendarAuto : defaults.bool(forKey: key)
    }
}

// MARK: - The calendar that follows

@MainActor
final class CalendarFollower: ObservableObject {
    static let shared = CalendarFollower()
    static let calendarName = "Seedboard"
    private static let idKey = "calendar.seedboardID"
    private static let lastKey = "calendar.followed"
    private static let countKey = "calendar.followCount"

    @Published private(set) var line = ""
    @Published private(set) var refused = false

    private let store = EKEventStore()
    /// `-calendarTest`: the sample boards go to the calendar too (simulator only, to see it work).
    private static let test = LaunchOptions.arguments.contains("-calendarTest")
    private var watching: AnyCancellable?
    private var active: AnyCancellable?
    private var running = false
    private var again: [Board]?

    func watch(_ model: AppModel) {
        guard watching == nil, !LaunchOptions.sampleData || Self.test else { return }
        sayLine()
        watching = model.$boards
            .combineLatest(model.$loaded)
            .filter { $0.1 }
            .map { $0.0 }
            .debounce(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] boards in self?.follow(boards) }
        #if os(macOS)
        let name = NSApplication.didBecomeActiveNotification
        #else
        let name = UIApplication.didBecomeActiveNotification
        #endif
        active = NotificationCenter.default.publisher(for: name)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self, weak model] _ in
                guard let self, let model, model.loaded else { return }
                self.follow(model.boards)
            }
    }

    /// The switch was flipped.
    func switched(_ on: Bool) {
        let model = AppModel.shared
        if on {
            follow(model.boards)
        } else {
            Task { await takeOut() }
        }
    }

    func follow(_ boards: [Board]) {
        guard Switch.isOn(Switch.calendarAuto), !LaunchOptions.sampleData || Self.test else { return }
        guard !running else {
            again = boards
            return
        }
        running = true
        Task {
            await self.match(boards)
            self.running = false
            if let next = self.again {
                self.again = nil
                self.follow(next)
            }
        }
    }

    // MARK: The calendar itself

    private func allowed() async -> Bool {
        let ok = (try? await store.requestFullAccessToEvents()) ?? false
        refused = !ok
        if !ok { line = "" }
        return ok
    }

    private func ourCalendar(make: Bool) -> EKCalendar? {
        if let id = UserDefaults.standard.string(forKey: Self.idKey), let found = store.calendar(withIdentifier: id) {
            return found
        }
        if let found = store.calendars(for: .event).first(where: { $0.title == Self.calendarName && $0.allowsContentModifications }) {
            UserDefaults.standard.set(found.calendarIdentifier, forKey: Self.idKey)
            return found
        }
        guard make else { return nil }
        let made = EKCalendar(for: .event, eventStore: store)
        made.title = Self.calendarName
        // The timeline's own orange, so the days are easy to tell from his appointments.
        made.cgColor = CGColor(red: 0xC4 / 255, green: 0x55 / 255, blue: 0x1F / 255, alpha: 1)
        let sources = [store.defaultCalendarForNewEvents?.source].compactMap { $0 }
            + store.sources.filter { $0.sourceType == .calDAV } + store.sources.filter { $0.sourceType == .local }
        for source in sources {
            made.source = source
            if (try? store.saveCalendar(made, commit: true)) != nil {
                UserDefaults.standard.set(made.calendarIdentifier, forKey: Self.idKey)
                return made
            }
        }
        return nil
    }

    /// Seedboard's own events in its calendar, looked for from two years back to four years ahead (and the wanted days).
    private func ourEvents(in calendar: EKCalendar, around wanted: [FollowEvent]) -> [EKEvent] {
        let cal = Calendar.current
        let now = Date()
        var start = cal.date(byAdding: .year, value: -2, to: now) ?? now
        var end = cal.date(byAdding: .year, value: 4, to: now) ?? now
        for w in wanted {
            start = min(start, w.first.date(calendar: cal))
            end = max(end, cal.date(byAdding: .day, value: 1, to: w.last.date(calendar: cal)) ?? end)
        }
        var seen = Set<String>()
        var out: [EKEvent] = []
        var from = start
        // The calendar answers at most four years at a time.
        while from < end {
            let to = min(end, cal.date(byAdding: .year, value: 3, to: from) ?? end)
            let ask = store.predicateForEvents(withStart: from, end: to, calendars: [calendar])
            for e in store.events(matching: ask) where CalendarFollow.isOurs(e.url?.absoluteString) {
                let id = (e.eventIdentifier ?? UUID().uuidString) + "\(e.startDate.timeIntervalSince1970)"
                if seen.insert(id).inserted { out.append(e) }
            }
            from = to
        }
        return out
    }

    private static func read(_ e: EKEvent) -> FollowEvent {
        let cal = Calendar.current
        let first = Day(e.startDate, calendar: cal)
        var endDate: Date = e.endDate
        // An all-day end at midnight is the next day's start: the last day is the one before.
        if endDate > e.startDate, cal.startOfDay(for: endDate) == endDate {
            endDate = endDate.addingTimeInterval(-1)
        }
        return FollowEvent(key: e.url?.absoluteString ?? "", title: e.title ?? "", first: first,
                           last: max(first, Day(endDate, calendar: cal)), notes: e.notes ?? "")
    }

    private func write(_ w: FollowEvent, into e: EKEvent) {
        let cal = Calendar.current
        e.title = w.title
        e.notes = w.notes
        e.url = URL(string: w.key)
        e.isAllDay = true
        e.startDate = cal.startOfDay(for: w.first.date(calendar: cal))
        // Noon of the last day: whatever the calendar makes of an all-day end, it reads back as that day.
        e.endDate = cal.startOfDay(for: w.last.date(calendar: cal)).addingTimeInterval(12 * 3600)
    }

    private func match(_ boards: [Board]) async {
        guard await allowed(), let calendar = ourCalendar(make: true) else { return }
        let wanted = CalendarFollow.wanted(boards: boards)
        let events = ourEvents(in: calendar, around: wanted)
        let plan = CalendarFollow.plan(wanted: wanted, existing: events.map(Self.read))
        if !plan.isEmpty {
            var byKey: [String: [EKEvent]] = [:]
            for e in events { byKey[e.url?.absoluteString ?? "", default: []].append(e) }
            do {
                for w in plan.add {
                    let e = EKEvent(eventStore: store)
                    e.calendar = calendar
                    write(w, into: e)
                    try store.save(e, span: .thisEvent, commit: false)
                }
                for w in plan.change {
                    guard let e = byKey[w.key]?.first else { continue }
                    write(w, into: e)
                    try store.save(e, span: .thisEvent, commit: false)
                }
                for key in plan.remove {
                    for e in byKey[key] ?? [] { try store.remove(e, span: .thisEvent, commit: false) }
                }
                for (key, extra) in plan.twins {
                    for e in (byKey[key] ?? []).dropFirst().prefix(extra) { try store.remove(e, span: .thisEvent, commit: false) }
                }
                try store.commit()
            } catch {
                store.reset()
            }
        }
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: Self.lastKey)
        defaults.set(Set(wanted.map(\.key)).count, forKey: Self.countKey)
        sayLine()
    }

    /// Switched off: Seedboard's events go, and its calendar too when nothing else is in it.
    private func takeOut() async {
        defer { sayLine() }
        UserDefaults.standard.removeObject(forKey: Self.countKey)
        UserDefaults.standard.removeObject(forKey: Self.lastKey)
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess, let calendar = ourCalendar(make: false) else { return }
        do {
            for e in ourEvents(in: calendar, around: []) { try store.remove(e, span: .thisEvent, commit: false) }
            try store.commit()
            let cal = Calendar.current
            let now = Date()
            let start = cal.date(byAdding: .year, value: -2, to: now) ?? now
            let end = cal.date(byAdding: .year, value: 1, to: now) ?? now
            let left = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: [calendar]))
            if left.isEmpty {
                try store.removeCalendar(calendar, commit: true)
                UserDefaults.standard.removeObject(forKey: Self.idKey)
            }
        } catch {
            store.reset()
        }
    }

    private func sayLine() {
        guard Switch.isOn(Switch.calendarAuto) else {
            line = ""
            refused = false
            return
        }
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: Self.lastKey) as? Date
        line = last == nil ? "Not in the calendar yet." : CalendarFollow.line(events: defaults.integer(forKey: Self.countKey), updated: last)
    }
}

// MARK: - Settings sections

/// Calendar: the switch, the line under it, and what to do when the calendar said no.
struct CalendarFollowSection: View {
    @AppStorage(Switch.calendarAuto) private var on = false
    @ObservedObject private var follower = CalendarFollower.shared

    var body: some View {
        Section {
            Toggle("Timeline days in Calendar", isOn: $on)
                .tint(Part.timeline.text)
                .accessibilityIdentifier("settings.calendarAuto")
                .onChange(of: on) { _, now in follower.switched(now) }
            if on && follower.refused {
                Text("Seedboard may not use your calendar yet. Allow it in Settings ▸ Privacy ▸ Calendars (on the Mac: System Settings ▸ Privacy & Security ▸ Calendars).")
                    .font(Txt.label)
                    .foregroundStyle(Part.notes.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.calendarRefused")
            } else if on && !follower.line.isEmpty {
                Text(follower.line)
                    .font(Txt.label)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.calendarLine")
            }
        } header: { PartHeader("Calendar", .timeline) }
        footer: {
            Text("Milestones and bars of your timelines go into their own calendar, “Seedboard”, and follow when you move them. Done ones stay, with “(done)” after the name. Turn it on on one device; your calendar brings the days to the others. Off takes Seedboard's events out again.")
        }
    }
}

/// Home page: "Still thinking about these?".
struct NudgeSwitchSection: View {
    @AppStorage(Switch.nudge) private var on = true

    var body: some View {
        Section {
            Toggle(Nudge.heading, isOn: $on)
                .tint(Part.boards.text)
                .accessibilityIdentifier("settings.nudge")
        } header: { PartHeader("Home page", .boards) }
        footer: {
            Text("Boards you have not changed for 2 weeks come up at the top of your boards, at most 3, with Put away and Not now. Not now asks again 2 weeks later.")
        }
    }
}

/// The two PARAGON switches, inside the PARAGON section.
struct ParagonSwitchRows: View {
    @AppStorage(Switch.doneTicksParagon) private var ticks = true
    @AppStorage(Switch.readParagon) private var read = true

    var body: some View {
        Toggle("Done ticks the PARAGON task", isOn: $ticks)
            .tint(Part.paragon.text)
            .accessibilityIdentifier("settings.doneTicksParagon")
        Toggle("Read back from PARAGON", isOn: $read)
            .tint(Part.paragon.text)
            .accessibilityIdentifier("settings.readParagon")
            .onChange(of: read) { _, _ in EchoKeeper.shared.objectWillChange.send() }
    }
}

/// Search: the boards in the device's search.
struct SearchSwitchSection: View {
    @AppStorage(Switch.search) private var on = true

    var body: some View {
        Section {
            Toggle("Boards in search", isOn: $on)
                .tint(Part.boards.text)
                .accessibilityIdentifier("settings.search")
                .onChange(of: on) { _, _ in SpotlightIndex.shared.switched() }
        } header: { PartHeader("Search", .boards) }
        footer: {
            Text("Your boards show up when you search on this device. Off takes them out of the search.")
        }
    }
}

// MARK: - Still thinking about these?

/// The boards' "Not now" days, kept on this device.
@MainActor
final class NudgeKeep: ObservableObject {
    static let shared = NudgeKeep()
    private static let key = "nudge.notNow.v1"

    @Published private(set) var notNow: [UUID: Date] = {
        let stored = UserDefaults.standard.dictionary(forKey: NudgeKeep.key) as? [String: Double] ?? [:]
        return Dictionary(uniqueKeysWithValues: stored.compactMap { k, v in UUID(uuidString: k).map { ($0, Date(timeIntervalSince1970: v)) } })
    }()

    func later(_ id: UUID, boards: [Board]) {
        var next = Nudge.tidy(notNow, boards: boards, now: Date())
        next[id] = Nudge.askAgain(after: Date())
        notNow = next
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: next.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) }), forKey: Self.key)
    }
}

/// The heading and up to three boards with Put away and Not now. Nothing at all when the switch is off,
/// while searching, or when no board has waited two weeks.
struct NudgeRows: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(Switch.nudge) private var on = true
    @ObservedObject private var keep = NudgeKeep.shared
    @Environment(\.colorScheme) private var scheme
    let search: String
    let open: (UUID) -> Void

    var body: some View {
        let boards = on && model.loaded && BoardSearch.words(search).isEmpty
            ? Nudge.boards(model.boards, now: Date(), notNow: keep.notNow) : []
        if !boards.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(Nudge.heading.uppercased())
                    .font(.caption.weight(.bold))
                    .kerning(0.5)
                    .foregroundStyle(Part.notes.text)
                    .padding(.top, 10)
                    .accessibilityIdentifier("home.heading.\(Nudge.heading)")
                ForEach(boards) { board in row(board) }
            }
        }
    }

    private func row(_ board: Board) -> some View {
        let paint = Paint(scheme)
        return HStack(spacing: 8) {
            Button { open(board.id) } label: {
                HStack(spacing: 7) {
                    Circle().fill(paint.line(board.colour)).frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(board.title.isEmpty ? "Untitled" : board.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        Text(board.changedWords())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("nudge.board.\(board.title)")
            Button("Not now") { keep.later(board.id, boards: model.boards) }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("nudge.notNow.\(board.title)")
            Button("Put away") { model.putAway(board.id) }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(FilledButton(.notes))
                .accessibilityIdentifier("nudge.putAway.\(board.title)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Part.notes.text.opacity(scheme == .dark ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
