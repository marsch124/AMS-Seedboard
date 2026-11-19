import SwiftUI
import EventKit
import SeedboardCore
import AMSIcons

// 0.9: a timeline's milestones (and, if ticked, its bars) into the owner's calendar. Apple Calendar;
// Fantastical and the others read the same calendars. Seedboard asks only for WRITE-ONLY access: it can
// add all-day events and can never read the calendar. The rules (which row becomes which event, "Added",
// "Day changed") are in SeedboardCore (CalendarPlan.swift); this file is the page and the calendar call.

/// What this device remembers about what it put in the calendar (its own settings; never in the board).
enum CalendarKeep {
    private static let key = "calendar.added.v1"

    static func load() -> CalendarMemory {
        guard let data = UserDefaults.standard.data(forKey: key),
              let memory = try? JSONDecoder().decode(CalendarMemory.self, from: data) else { return CalendarMemory() }
        return memory
    }

    static func save(_ memory: CalendarMemory) {
        if let data = try? JSONEncoder().encode(memory) { UserDefaults.standard.set(data, forKey: key) }
    }
}

/// The one call to the calendar.
enum CalendarWriter {
    enum Outcome: Equatable {
        case added(Int)
        /// The owner said no (or it is switched off): the page tells how to allow it.
        case refused
        case failed
    }

    static func add(_ events: [CalendarEvent]) async -> Outcome {
        let store = EKEventStore()
        do {
            guard try await store.requestWriteOnlyAccessToEvents() else { return .refused }
        } catch {
            return .refused
        }
        guard let calendar = store.defaultCalendarForNewEvents else { return .failed }
        let cal = Calendar.current
        do {
            for e in events {
                let made = EKEvent(eventStore: store)
                made.calendar = calendar
                made.title = e.title
                made.notes = e.notes
                made.isAllDay = true
                made.startDate = cal.startOfDay(for: e.first.date(calendar: cal))
                made.endDate = cal.startOfDay(for: e.last.date(calendar: cal))
                try store.save(made, span: .thisEvent, commit: false)
            }
            try store.commit()
            return .added(events.count)
        } catch {
            return .failed
        }
    }
}

/// The page "Add to Calendar": the milestones, then the bars, each with a tick box and its day.
struct CalendarAddSheet: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    @Environment(\.dismiss) private var dismiss

    @State private var memory = CalendarKeep.load()
    @State private var ticked: Set<UUID> = []
    @State private var started = false
    @State private var refused = false
    @State private var working = false

    private var choices: (milestones: [CalendarChoice], bars: [CalendarChoice]) { session.board.calendarChoices(memory: memory) }
    private var chosen: [CalendarEvent] {
        (choices.milestones + choices.bars).filter { ticked.contains($0.event.id) }.map(\.event)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GlyphView(glyph: .new(.calendar), size: 22, colour: Part.timeline.text)
                Text("Add to Calendar")
                    .font(Txt.big)
                    .foregroundStyle(Part.timeline.text)
                Spacer(minLength: 0)
            }
            if Switch.isOn(Switch.calendarAuto) {
                // 0.13: the calendar follows by itself; adding by hand would make a second event.
                Text("Your timeline days go to the Seedboard calendar by themselves (Settings ▸ Calendar).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("calendar.byItself")
                Spacer(minLength: 0)
            } else if choices.milestones.isEmpty && choices.bars.isEmpty {
                Text("This timeline has no milestones or bars with days yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("calendar.empty")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if !choices.milestones.isEmpty { section("Milestones", choices.milestones) }
                        if !choices.bars.isEmpty { section("Bars", choices.bars) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if refused {
                Text("Seedboard cannot add to your calendar yet. Allow it in Settings ▸ Privacy ▸ Calendars (on the Mac: System Settings ▸ Privacy & Security ▸ Calendars), then try again.")
                    .font(.caption)
                    .foregroundStyle(Paint(.light).line("red"))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("calendar.refused")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("calendar.cancel")
                Button("Add") { add() }
                    .buttonStyle(FilledButton(.timeline))
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosen.isEmpty || working || Switch.isOn(Switch.calendarAuto))
                    .accessibilityIdentifier("calendar.add")
            }
            .padding(.top, 2)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 400, height: 440)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        #endif
        .accessibilityIdentifier("calendar.page")
        .onAppear {
            guard !started else { return }
            started = true
            ticked = Set((choices.milestones + choices.bars).filter(\.ticked).map(\.event.id))
        }
    }

    private func section(_ title: String, _ lines: [CalendarChoice]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Txt.label)
                .foregroundStyle(Part.timeline.text)
                .padding(.top, 4)
            ForEach(lines, id: \.event.id) { line in row(line) }
        }
    }

    private func row(_ line: CalendarChoice) -> some View {
        let on = ticked.contains(line.event.id)
        let note = line.state == .new ? "" : (session.board.item(line.event.id).map { memory.words(of: $0) } ?? "")
        return Button {
            if on { ticked.remove(line.event.id) } else { ticked.insert(line.event.id) }
        } label: {
            HStack(spacing: 8) {
                GlyphView(glyph: on ? .control(.ticked) : .control(.circle), size: 18, colour: on ? Part.timeline.text : .secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(line.event.title)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(days(line.event))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if !note.isEmpty {
                            Text(note)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(line.state == .changed ? Paint(.light).line("orange") : Part.timeline.text)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar.row.\(line.event.title)")
        .accessibilityValue(on ? "Ticked" : "Not ticked")
    }

    private func days(_ e: CalendarEvent) -> String {
        e.first == e.last ? e.first.long : "\(e.first.short) – \(e.last.long) · \(e.dayCount) days"
    }

    private func add() {
        let events = chosen
        guard !events.isEmpty else { return }
        working = true
        refused = false
        Task {
            let outcome = await CalendarWriter.add(events)
            working = false
            switch outcome {
            case .added(let n):
                var kept = CalendarKeep.load()
                kept.remember(events, on: .today())
                CalendarKeep.save(kept)
                model.say(n == 1 ? "1 event is in your calendar." : "\(n) events are in your calendar.")
                dismiss()
            case .refused:
                refused = true
            case .failed:
                model.say("The calendar did not take them. Nothing was added.", tone: .problem)
            }
        }
    }
}

extension BoardSession {
    /// The page "Add to Calendar…" can open: a timeline that can be looked at (a read-only one too — it only reads the board).
    var canAddToCalendar: Bool { board.isTimeline && starterDraft == false && !board.timelineRows.isEmpty }
}
