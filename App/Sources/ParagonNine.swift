import SwiftUI
import Combine
import SeedboardCore
import AMSIcons

// 0.9, the `paragon` lane.
//  - 40 "Only this frame (…)": the switch on the Send page when one frame is chosen, and the ways to open
//    that page from the frame itself (its bar, its right-click menu, File).
//  - 42 "Today's three": up to three chosen things go to PARAGON's Inbox as tasks due today, after a small
//    page that lists them. The rules are in SeedboardCore (`Board.frameOnly`, `ParagonExport.todayThree`).

/// What the bars, menus and the Mac menu ask of the open board: the Send page for the chosen frame, and the
/// Today's three page. `ParagonHost` (on the board) answers.
@MainActor
final class ParagonDesk: ObservableObject {
    static let shared = ParagonDesk()
    /// The board whose Today's three page is asked for.
    @Published var today: UUID?
    /// The Send page is asked for (a frame is chosen, so its switch is on).
    let openSend = PassthroughSubject<Void, Never>()

    func askToday(_ session: BoardSession) {
        guard session.todayThreeOffered else { return }
        session.commitEdit()
        today = session.board.id
    }

    func sendFrame(_ session: BoardSession) {
        guard session.frameToSend != nil else { return }
        session.commitEdit()
        openSend.send()
    }
}

extension BoardSession {
    /// The one chosen frame, when it holds something to send: the Send page then offers "Only this frame (…)".
    var frameToSend: Item? {
        guard !board.placesItself, let item = single, item.kind == .frame, !board.thingsInside(frame: item.id).isEmpty else { return nil }
        return item
    }

    /// "Only this frame (Pros)"; a frame with no words: "Only this frame".
    func frameSwitchWords(_ item: Item) -> String {
        var name = board.frameName(item.id)
        if name.count > 32 { name = String(name.prefix(30)).trimmingCharacters(in: .whitespaces) + "…" }
        return name.isEmpty ? "Only this frame" : "Only this frame (\(name))"
    }

    /// Today's three is offered: one to three things are chosen, at least one can become a task, and the board can
    /// be changed.
    var todayThreeOffered: Bool {
        guard !readOnly, !starterDraft, board.canBeChanged, !board.placesItself, editing == nil else { return false }
        return ParagonExport.todayThree(board: board, chosen: selection, now: Date()) != nil
    }
}

/// The switch "Only this frame (Pros)" on the Send page: as the branch switch, with the frame's mark.
struct FrameSwitch: View {
    let words: String
    @Binding var on: Bool

    var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 8) {
                GlyphView(glyph: .app(.seedFrame), size: 20, colour: Part.frames.text)
                Text(words)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Capsule()
                    .fill(on ? Part.paragon.fill : Color.primary.opacity(0.22))
                    .frame(width: 38, height: 22)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle().fill(Color.white).padding(2)
                    }
                    .animation(.easeOut(duration: 0.12), value: on)
            }
            .padding(8)
            .background(on ? Part.paragon.soft : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(on ? Part.paragon.text : Color.primary.opacity(0.12), lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(corner: 10))
        .accessibilityLabel(words)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityIdentifier("send.frameOnly")
    }
}

/// On the open board (`BoardView`): shows the Today's three page and opens the Send page for a chosen frame.
struct ParagonHost: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = ParagonDesk.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { desk.today == session.board.id }, set: { if !$0 { desk.today = nil } }),
                   onDismiss: { session.takeKeys() }) {
                TodayThreeSheet(session: session).environmentObject(model)
            }
            .onReceive(desk.openSend) { model.showSend = true }
            .onDisappear { if desk.today == session.board.id { desk.today = nil } }
            .onAppear {
                // For pictures: `-todayThree` opens the page with the first three things chosen (sample boards).
                if LaunchOptions.arguments.contains("-todayThree"), session.selection.isEmpty {
                    let ids = session.board.items.filter { $0.kind != .frame && $0.kind != .picture && $0.kind != .drawing }.prefix(3).map(\.id)
                    session.selection = Set(ids)
                    desk.askToday(session)
                }
            }
    }
}

/// "Today's three": the chosen things, as the tasks they will be, with Cancel and Send.
struct TodayThreeSheet: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: BoardSession
    @Environment(\.dismiss) private var dismiss
    @AppStorage("send.sayOrigin") private var sayOrigin = true
    @State private var busy = false
    @State private var problem: String?
    /// The things the page was opened for (what is chosen can change behind it).
    @State private var chosen: Set<UUID> = []

    private var lines: LinesToSend? { ParagonExport.todayThree(board: session.board, chosen: chosen, now: Date()) }
    private var rows: [(id: UUID, words: String)] {
        (lines?.tasks ?? []).map { task in (task.id, session.board.thingWords(task.id)) }
    }
    /// Chosen things that are not sent again: they are in PARAGON already, or cannot be a task.
    private var left: Int { chosen.count - rows.count }

    var body: some View {
        #if os(macOS)
        page.frame(width: 420)
        #else
        ScrollView { page.frame(maxWidth: 520).frame(maxWidth: .infinity) }
            .scrollBounceBehavior(.basedOnSize)
            .presentationDetents([.medium, .large])
        #endif
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GlyphView(glyph: .new(.today), size: 22, colour: Part.paragon.text)
                Text("Today's three")
                    .font(Txt.big)
                    .foregroundStyle(Part.paragon.text)
            }
            Text(rows.count == 1 ? "This goes to the PARAGON Inbox as a task due today:" : "These go to the PARAGON Inbox as tasks due today:")
                .font(Txt.label)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows, id: \.id) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Capsule().fill(Part.paragon.fill).frame(width: 6, height: 6).offset(y: -2)
                        Text(row.words)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Text("Today")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Part.paragon.text)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("today.line")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Part.paragon.soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if left > 0 {
                Text(left == 1 ? "1 more is left out: it is in PARAGON already, or it cannot be a task."
                               : "\(left) more are left out: they are in PARAGON already, or they cannot be tasks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SendSwitch(words: "Say where they come from", on: $sayOrigin, identifier: "today.sayOrigin")
            Text("Seedboard only adds to PARAGON's waiting list. They appear there when you switch to PARAGON, and this board shows them as in PARAGON.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let problem {
                Text(problem)
                    .font(Txt.label)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.problem")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("today.cancel")
                Button { send() } label: { Text(busy ? "Sending…" : "Send") }
                    .buttonStyle(FilledButton(.paragon))
                    .keyboardShortcut(.defaultAction)
                    .disabled(rows.isEmpty || busy || !model.paragonReady)
                    .accessibilityIdentifier("today.send")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .onAppear { if chosen.isEmpty { chosen = session.selection } }
    }

    private func send() {
        busy = true
        problem = nil
        Task {
            let failure = await model.sendToday(chosen, sayOrigin: sayOrigin)
            busy = false
            if let failure {
                problem = failure
                Feel.notSent()
            } else {
                Feel.sent()
                dismiss()
            }
        }
    }
}
