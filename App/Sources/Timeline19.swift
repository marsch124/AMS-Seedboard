import SwiftUI
import SeedboardCore

// 0.19, timelines: a note on a milestone or bar (27), who does a bar (32), repeat a bar (31), group by colour (30),
// the Weeks / Months switch (29), the soft gap while a row is dragged (26) and the big dates while a bar is held (28).
// Rules are in Core (Timeline19.swift); this file has the pages, the marks and the small views.

/// Every SF Symbol this lane added, in one place so a name can be swapped.
enum Marks19Timeline {
    static let note = "note.text"
    static let repeatBar = "repeat"
    static let who = "person.crop.circle"
}

/// Which small page is open, and whose note is shown in its bubble. One at a time, for the open timeline.
@MainActor
final class TimelineDesk19: ObservableObject {
    static let shared = TimelineDesk19()

    enum Page: Identifiable, Equatable {
        case note(UUID), repeating(UUID), who(UUID)
        var id: String {
            switch self {
            case .note(let id): return "note-\(id)"
            case .repeating(let id): return "repeat-\(id)"
            case .who(let id): return "who-\(id)"
            }
        }
    }

    @Published var page: Page?
    /// The row whose note shows in a small bubble (a tap on it).
    @Published var bubble: UUID?
}

// MARK: The session's side

extension BoardSession {
    func timelineSetNote(_ id: UUID, _ text: String) {
        guard !readOnly, board.isTimeline else { return }
        change { $0.setNote(id, text) }
        if board.item(id)?.note == nil, TimelineDesk19.shared.bubble == id { TimelineDesk19.shared.bubble = nil }
    }

    func timelineSetWho(_ id: UUID, _ text: String) {
        guard !readOnly, board.isTimeline else { return }
        change { $0.setInitials(id, text) }
    }

    /// "Repeat…": the copies are chosen after they are made, so Undo takes them all away in one step.
    @discardableResult
    func timelineRepeat(_ id: UUID, every: BarRepeat, times: Int) -> Int {
        guard !readOnly, board.isTimeline else { return 0 }
        var made: [UUID] = []
        change { made = $0.repeatRow(id, every: every, times: times) }
        if !made.isEmpty { selection = [id] }
        return made.count
    }

    /// "Group by colour": returns the line to say.
    @discardableResult
    func timelineGroupByColour() -> String? {
        guard !readOnly, board.isTimeline else { return nil }
        if editing != nil { commitEdit() }
        guard board.canGroupByColour else { return "The colours are in groups already." }
        var colours = Set<String>()
        for item in board.timelineRows where item.kind != .phase { colours.insert(board.timelineColour(of: item)) }
        change { $0.groupByColour() }
        return "Grouped by colour: \(colours.count) \(colours.count == 1 ? "colour" : "colours")."
    }
}

// MARK: Pages

/// Hosts the three small pages for the open timeline.
struct TimelinePages19: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = TimelineDesk19.shared

    func body(content: Content) -> some View {
        content.sheet(item: $desk.page, onDismiss: { session.takeKeys() }) { page in
            switch page {
            case .note(let id): TimelineNoteSheet(session: session, id: id)
            case .repeating(let id): TimelineRepeatSheet(session: session, id: id)
            case .who(let id): TimelineWhoSheet(session: session, id: id)
            }
        }
    }
}

/// The header every page of this lane starts with.
private struct PageHead: View {
    let symbol: String
    let title: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Part.timeline.text)
                Text(title)
                    .font(Txt.big)
                    .foregroundStyle(Part.timeline.text)
                Spacer(minLength: 0)
            }
            Text(line)
                .font(Txt.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

@MainActor private func rowName(_ session: BoardSession, _ id: UUID) -> String {
    let item = session.board.item(id)
    let name = item?.nameLine ?? ""
    return name.isEmpty ? (item?.kind.word ?? "Bar") : name
}

/// "Note…": a short note on a milestone or bar. Cancel / Save.
struct TimelineNoteSheet: View {
    @ObservedObject var session: BoardSession
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(session: BoardSession, id: UUID) {
        self.session = session
        self.id = id
        _text = State(initialValue: session.board.item(id)?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHead(symbol: Marks19Timeline.note, title: "Note", line: rowName(session, id))
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 90, maxHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.15)))
                .onChange(of: text) { _, new in if new.count > Item.longestNote { text = String(new.prefix(Item.longestNote)) } }
                .accessibilityIdentifier("note.field")
            Text("\(text.count) of \(Item.longestNote) letters")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("note.cancel")
                Button("Save") {
                    session.timelineSetNote(id, text)
                    dismiss()
                }
                .buttonStyle(FilledButton(.timeline))
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("note.save")
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 360)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(330)])
        #endif
        .accessibilityIdentifier("timeline.notePage")
    }
}

/// "Who…": one to three letters, shown in a small round at the start of the bar. Cancel / Save.
struct TimelineWhoSheet: View {
    @ObservedObject var session: BoardSession
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(session: BoardSession, id: UUID) {
        self.session = session
        self.id = id
        _text = State(initialValue: session.board.item(id)?.initials ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHead(symbol: Marks19Timeline.who, title: "Who does it", line: rowName(session, id))
            TextField("Initials, one to three letters", text: $text)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                #endif
                .onChange(of: text) { _, new in
                    let clean = String(new.filter { $0.isLetter }.prefix(3)).uppercased()
                    if clean != new { text = clean }
                }
                .onSubmit { save() }
                .accessibilityIdentifier("who.field")
            Text("They show in a small grey round at the start of the bar. Empty takes them away.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("who.cancel")
                Button("Save") { save() }
                    .buttonStyle(FilledButton(.timeline))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("who.save")
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 340)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(250)])
        #endif
        .accessibilityIdentifier("timeline.whoPage")
    }

    private func save() {
        session.timelineSetWho(id, text)
        dismiss()
    }
}

/// "Repeat…": every Day / Week / 2 Weeks / Month, 2 to 12 times in all (the bar itself is the first). Cancel / Repeat.
struct TimelineRepeatSheet: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var every = BarRepeat.standard.every
    @State private var times = BarRepeat.standard.times

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHead(symbol: Marks19Timeline.repeatBar, title: "Repeat", line: rowName(session, id))
            Picker("Every", selection: $every) {
                ForEach(BarRepeat.allCases, id: \.self) { Text($0.word).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("repeat.every")
            Stepper(value: $times, in: BarRepeat.fewest...BarRepeat.most) {
                Text("\(times) times in all")
                    .monospacedDigit()
            }
            .accessibilityIdentifier("repeat.times")
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("repeat.summary")
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repeat.cancel")
                Button("Repeat") {
                    let n = session.timelineRepeat(id, every: every, times: times)
                    if n > 0 { model.say(n == 1 ? "1 copy made, under the bar." : "\(n) copies made, under the bar.") }
                    dismiss()
                }
                .buttonStyle(FilledButton(.timeline))
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("repeat.go")
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 360)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(290)])
        #endif
        .accessibilityIdentifier("timeline.repeatPage")
    }

    /// "The bar comes 6 times: 1 Dec, 8 Dec … 5 Jan. 5 copies go on the rows under it."
    private var summary: String {
        guard let first = session.board.item(id)?.span?.start else { return "" }
        let last = every.start(of: times - 1, from: first)
        return "It comes \(times) times: \(first.short) to \(last.short). \(times - 1) copies go on the rows under it, as long as the bar and in its colour."
    }
}

// MARK: The Weeks / Months switch (29)

/// Two buttons beside the zoom: Weeks and Months set the scale at once (the zoom's − and + step through
/// Days, Weeks and Months). While the scale is Days neither one is on; the zoom's word says "Days".
struct TimelineScaleSwitch: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: 2) {
            part(.weeks, "timeline.weeks")
            part(.months, "timeline.months")
        }
        .padding(3)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.10)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline.scaleSwitch")
    }

    private func part(_ scale: TimeScale, _ id: String) -> some View {
        let on = session.timeline.scale == scale
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { session.setTimeScale(scale) }
            session.takeKeys()
        } label: {
            Text(scale.word)
                .font(Txt.pill)
                .foregroundStyle(on ? Color.white : Color.primary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(on ? Part.timeline.fill : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(tint: Part.timeline.text))
        .accessibilityLabel(scale.word)
        .accessibilityValue(on ? "on" : "off")
        .accessibilityIdentifier(id)
    }
}

// MARK: The soft gap (26)

/// Draws its content again at every step of a spring: `t` runs from 1 back to 0, and the rows that were pushed
/// aside by a dragged bar slide to their places from there.
struct SpringFrame<Content: View>: View, Animatable {
    var t: CGFloat
    let content: (CGFloat) -> Content

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    var body: some View { content(t) }
}

// MARK: The note and who marks, and the note bubble

extension TimelinePainter {
    /// The small marks that stand on a row: the grey round with the initials at the start of a bar, and the tiny note
    /// mark after the end of a bar or milestone that has a note. Neutral grey: no signal colour.
    func drawMarks19(_ item: Item, _ box: CGRect, _ ctx: inout GraphicsContext) {
        if item.kind == .bar, let initials = item.initials, !initials.isEmpty {
            let r: CGFloat = 8
            // Inside the bar's start; a bar too short for it carries the round before its start.
            let inside = box.width >= 34
            let c = CGPoint(x: inside ? box.minX + r + 3 : box.minX - r - 7, y: box.midY)
            let round = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(round, with: .color(paint.night ? Color(white: 0.30) : Color(white: 0.88)))
            ctx.stroke(round, with: .color(paint.faint), lineWidth: 1)
            let text = ctx.resolve(Text(initials).font(.system(size: initials.count > 2 ? 7.5 : 9, weight: .bold)).foregroundColor(paint.ink))
            ctx.draw(text, at: c, anchor: .center)
        }
        if item.span != nil, let note = item.note, !note.isEmpty {
            let c = CGPoint(x: box.maxX + 10, y: box.midY)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(ground ?? paint.canvas))
            var symbol = ctx.resolve(Image(systemName: Marks19Timeline.note))
            symbol.shading = .color(paint.ink.opacity(0.75))
            ctx.draw(symbol, in: CGRect(x: c.x - 5.5, y: c.y - 5.5, width: 11, height: 11))
        }
    }
}

/// A tap on a milestone or bar with a note: the note in a small bubble above it (below it in the top rows).
struct TimelineNoteBubble: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = TimelineDesk19.shared

    var body: some View {
        if let id = desk.bubble, let note = session.board.item(id)?.note, let rect = session.timelineRect(of: id) {
            let width = Double(session.viewSize.width)
            let x = min(max(rect.midX, 120), max(width - 120, 120))
            let below = rect.minY < Double(TimelineLook.headerHeight) + 90
            Color.clear
                .frame(width: 1, height: 1)
                .overlay(alignment: below ? .top : .bottom) {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 220, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.12)))
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                        .fixedSize()
                        .accessibilityIdentifier("timeline.noteBubble")
                }
                .offset(x: x, y: below ? rect.maxY + 6 : rect.minY - 6)
                .allowsHitTesting(false)
        }
    }
}
