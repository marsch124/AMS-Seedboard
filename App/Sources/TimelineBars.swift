import SwiftUI
import SeedboardCore
import AMSIcons

// The bars of a timeline board. `BoardView` shows these in place of the ordinary tools, zoom buttons
// and selection bar when the board is a timeline; everything else on the screen is the same.

/// The tools of a timeline: Bar, Milestone, Phase, Comes after. Each has its word under it.
struct TimelineToolPill: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: 6) {
            tool("Bar", .new(.bar), .timeline, "tool.bar", "Bar: a new row, starting today (B)") { session.addTimeline(.bar) }
            tool("Milestone", .new(.milestone), .paragon, "tool.milestone", "Milestone: one day, drawn as a diamond (M)") { session.addTimeline(.milestone) }
            tool("Phase", .app(.seedPhase), .frames, "tool.phase", "Phase: a heading for the rows under it (P)") { session.addTimeline(.phase) }
            tool("Comes after", .app(.seedComesAfter), .arrows, "tool.after", "Comes after: press the bar that comes first, then the one after it (A)", on: session.linking) {
                session.commitEdit()
                session.linking.toggle()
                // With one bar chosen, the arrow starts there.
                session.linkFrom = session.linking ? session.single.flatMap { $0.span == nil ? nil : $0.id } : nil
            }
        }
        .padding(6)
        .fixedSize()
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.tools")
    }

    private func tool(_ word: String, _ glyph: Glyph, _ part: Part, _ id: String, _ help: String, on: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                GlyphView(glyph: glyph, size: 22, colour: on ? .white : part.text)
                Text(word)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(on ? Color.white : Color.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 7)
            .frame(minWidth: 50)
            .frame(height: 44)
            .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(tint: part.text))
        .help(help)
        .accessibilityLabel(word)
        .accessibilityIdentifier(id)
    }
}

/// Further away, closer (days → weeks → months), the whole timeline at once, and Today.
struct TimelineZoomCluster: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: 2) {
            button(.app(.zoomOut), "zoom.out", "Further away: weeks, then months", on: session.timeline.scale.further != nil) {
                withAnimation(.easeOut(duration: 0.2)) { session.stepTimeScale(closer: false) }
            }
            Text(session.timeline.scale.word)
                .font(Txt.pill)
                .frame(width: 52)
                .accessibilityIdentifier("zoom.value")
            button(.app(.zoomIn), "zoom.in", "Closer: weeks, then days", on: session.timeline.scale.closer != nil) {
                withAnimation(.easeOut(duration: 0.2)) { session.stepTimeScale(closer: true) }
            }
            button(.app(.seedFit), "zoom.fit", "Show the whole timeline", on: true) {
                withAnimation(.easeOut(duration: 0.2)) { session.timelineFit() }
            }
            Button {
                withAnimation(.easeOut(duration: 0.2)) { session.timelineShowToday() }
            } label: {
                HStack(spacing: 3) {
                    GlyphView(glyph: .new(.today), size: 15, colour: .white)
                    Text("Today")
                        .font(Txt.pill)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
                .background(Part.timeline.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(tint: .black))
            .help("Bring today into view (T)")
            .accessibilityLabel("Today")
            .accessibilityIdentifier("timeline.today")
            .padding(.leading, 3)
        }
        .padding(4)
        .fixedSize()
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.primary.opacity(0.10)))
        .plateShadow()
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline.zoom")
    }

    private func button(_ glyph: Glyph, _ id: String, _ help: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlyphView(glyph: glyph, size: 18, colour: Part.arrows.text)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(!on)
        .opacity(on ? 1 : 0.35)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityIdentifier(id)
    }
}

/// What can be done with the chosen bar, milestone, phase or "comes after" arrow.
/// It stands at the bottom, above the tools: at the top it would cover the dates.
struct TimelineSelectionBar: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showColours = false
    @State private var dating: UUID?
    /// For pictures: `-dates` opens the Dates page of the bar chosen with `-pick`, once.
    private static var launchUsed = false

    var body: some View {
        let item = session.single
        let link = session.selectedLink.flatMap { id in session.board.links.first { $0.id == id } }
        if session.readOnly || (session.selection.isEmpty && link == nil) {
            EmptyView()
        } else {
            VStack(spacing: 5) {
                WrapRow(spacing: 5) {
                    if let item {
                        itemChips(item)
                    } else if let link {
                        Text(words(for: link))
                            .font(Txt.pill)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .accessibilityIdentifier("sel.after")
                    } else {
                        Text("\(session.selection.count) chosen")
                            .font(Txt.pill)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                        chip("To do", .control(.ticked), "sel.todo", .paragon) { session.toggleTodo() }
                        chip("Duplicate", .app(.duplicate), "sel.copy", .timeline) { session.timelineDuplicate() }
                    }
                    #if !os(macOS)
                    if link == nil {
                        chip("Choose more", .control(.addCircle), "sel.more", .timeline, on: session.choosingMore) { session.choosingMore.toggle() }
                    }
                    #endif
                    // One tint per bar, as on the other boards: only "To do" is purple and "Remove" red.
                    chip("Remove", .app(.bin), "sel.remove", .kept) { session.deleteSelection() }
                }
                .padding(5)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.primary.opacity(0.10)))
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board.selectionBar")

                if showColours, let item { colourRow(for: item) }
            }
            .onChange(of: session.selection) { _, _ in showColours = false }
            .onAppear {
                guard !TimelineSelectionBar.launchUsed, LaunchOptions.arguments.contains("-dates"),
                      let item, item.span != nil else { return }
                TimelineSelectionBar.launchUsed = true
                dating = item.id
            }
            .sheet(isPresented: Binding(get: { dating != nil }, set: { if !$0 { dating = nil } })) {
                if let dating {
                    TimelineDatesSheet(session: session, id: dating).environmentObject(model)
                }
            }
        }
    }

    private func words(for link: SeedboardCore.Link) -> String {
        let first = session.board.item(link.from)?.nameLine ?? ""
        let second = session.board.item(link.to)?.nameLine ?? ""
        return "“\(second.isEmpty ? "(empty)" : second)” comes after “\(first.isEmpty ? "(empty)" : first)”"
    }

    @ViewBuilder
    private func itemChips(_ item: Item) -> some View {
        // The iPhone has no room for the dates in words: they show while dragging and on the Dates page.
        if item.span != nil, sizeClass != .compact {
            Text(item.spanWords)
                .font(Txt.pill)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .accessibilityIdentifier("sel.days")
        }
        chip("Name", .control(.edit), "sel.name", .timeline) { session.beginEdit(item.id) }
        chip("Colour", .app(.palette), "sel.colour", .timeline, on: showColours) { showColours.toggle() }
        if item.span != nil {
            chip("Dates", .new(.calendar), "sel.dates", .timeline) {
                session.commitEdit()
                dating = item.id
            }
            chip("To do", .control(.ticked), "sel.todo", .paragon, on: item.todo) { session.toggleTodo() }
        }
        chip("Duplicate", .app(.duplicate), "sel.copy", .timeline) { session.timelineDuplicate() }
    }

    private func chip(_ word: String, _ glyph: Glyph, _ id: String, _ part: Part, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                GlyphView(glyph: glyph, size: 15, colour: on ? .white : part.text)
                Text(word)
                    .font(Txt.pill)
                    .foregroundStyle(on ? Color.white : Color.primary)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(on ? part.fill : part.soft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(tint: part.text))
        .accessibilityIdentifier(id)
    }

    /// The app's palette; the colour the row has now wears a ring.
    private func colourRow(for item: Item) -> some View {
        let paint = Paint(scheme)
        return HStack(spacing: 7) {
            ForEach(Palette.names, id: \.self) { name in
                Button { session.setColour(name) } label: {
                    Circle()
                        .fill(paint.line(name))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(paint.ink, lineWidth: item.colour == name ? 2 : 0).padding(-3))
                }
                .buttonStyle(PressStyle(wash: nil))
                .accessibilityLabel(name.capitalized)
                .accessibilityIdentifier("colour.\(name)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.10)))
        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        // Its own element with its buttons inside, so each button keeps its own name for the screen tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.colours")
    }
}

/// The Dates page of one bar or milestone: Starts and Ends, then Cancel or Save.
/// Moving the start moves the whole bar (its length stays); moving the end makes it longer or shorter.
struct TimelineDatesSheet: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    let id: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var start: Date
    @State private var end: Date

    init(session: BoardSession, id: UUID) {
        self.session = session
        self.id = id
        let span = session.board.item(id)?.span
        _start = State(initialValue: (span?.start ?? .today()).date())
        _end = State(initialValue: (span?.end ?? .today()).date())
    }

    private var item: Item? { session.board.item(id) }
    private var isMilestone: Bool { item?.kind == .milestone }
    private var earliest: Day? { session.board.earliestStart(of: id) }
    private var days: Int { max(Day(end) - Day(start), 0) + 1 }

    /// The bars this one comes after, by name.
    private var forerunners: String {
        session.board.links.filter { $0.to == id }
            .compactMap { session.board.item($0.from)?.nameLine }
            .map { "“\($0.isEmpty ? "(empty)" : $0)”" }
            .joined(separator: " and ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GlyphView(glyph: .new(.calendar), size: 22, colour: Part.timeline.text)
                Text("Dates")
                    .font(Txt.big)
                    .foregroundStyle(Part.timeline.text)
                Spacer(minLength: 0)
            }
            let name = item?.nameLine ?? ""
            Text(name.isEmpty ? (item?.kind.word ?? "Bar") : name)
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            picker(isMilestone ? "Day" : "Starts", $start, from: earliest?.date(), id: "dates.start")
            if !isMilestone {
                picker("Ends", $end, from: start, id: "dates.end")
                Text(days == 1 ? "1 day" : "\(days) days")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("dates.length")
            }
            if let earliest {
                Text("It comes after \(forerunners), so it cannot start before \(earliest.long).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("dates.cancel")
                Button("Save") { save() }
                    .buttonStyle(FilledButton(.timeline))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("dates.save")
            }
            .padding(.top, 2)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 340)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(300)])
        #endif
        // A new start moves the whole bar: the end follows, so the length stays.
        .onChange(of: start) { old, new in
            end = (Day(end) + (Day(new) - Day(old))).date()
        }
    }

    @ViewBuilder
    private func picker(_ word: String, _ value: Binding<Date>, from: Date?, id: String) -> some View {
        if let from {
            // From the morning of the first day it may be.
            DatePicker(word, selection: value, in: Calendar.current.startOfDay(for: from)..., displayedComponents: .date)
                .accessibilityIdentifier(id)
        } else {
            DatePicker(word, selection: value, displayedComponents: .date)
                .accessibilityIdentifier(id)
        }
    }

    private func save() {
        let first = Day(start), last = Day(end)
        var pushed = 0
        session.change { pushed = $0.setDates(id, start: first, end: max(first, last)) }
        if let words = TimelineWords.pushed(pushed) { model.say(words) }
        dismiss()
    }
}
