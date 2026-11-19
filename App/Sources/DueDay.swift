import SwiftUI
import SeedboardCore

// 0.11: a board's own due day. "Due day…" in the board's More menu (and the Mac's File menu) opens a small page with a
// date picker; the card and the row show "Due 12 Jan"; Send as a project gives PARAGON that day.

/// Asks for the page; one at a time, for the board that is open.
@MainActor
final class DueDesk: ObservableObject {
    static let shared = DueDesk()
    @Published var show = false
}

/// "Due 12 Jan", small, red when the day is past. Nothing when the board has no due day.
struct DueWords: View {
    let board: Board

    var body: some View {
        if let words = board.dueWords() {
            Text(words.text)
                .font(.caption)
                .foregroundStyle(words.past ? Color.red : Color.secondary)
                .lineLimit(1)
                .accessibilityIdentifier("home.due.\(board.title)")
        }
    }
}

struct DueHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = DueDesk.shared

    func body(content: Content) -> some View {
        content.sheet(isPresented: $desk.show, onDismiss: { session.takeKeys() }) {
            DueSheet(session: session)
        }
    }
}

struct DueSheet: View {
    @ObservedObject var session: BoardSession
    @Environment(\.dismiss) private var dismiss
    @State private var day: Date
    @State private var problem: String?

    init(session: BoardSession) {
        self.session = session
        _day = State(initialValue: (session.board.dueDay ?? .today()).date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GlyphView(glyph: .new(.calendar), size: 22, colour: Part.boards.text)
                Text("Due day")
                    .font(Txt.big)
                    .foregroundStyle(Part.boards.text)
                Spacer(minLength: 0)
            }
            DatePicker("Due", selection: $day, displayedComponents: .date)
                .accessibilityIdentifier("due.picker")
            if let problem {
                Text(problem).font(.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("due.problem")
            }
            Text("It shows on the board's card, and goes to PARAGON as the project's due day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if session.board.due != nil {
                    Button("No due day") {
                        session.change { $0.setDue(nil) }
                        dismiss()
                    }
                    .accessibilityIdentifier("due.none")
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("due.cancel")
                Button("Save") { save() }
                    .buttonStyle(FilledButton(.boards))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("due.save")
            }
            .padding(.top, 2)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 340)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(230)])
        #endif
    }

    private func save() {
        let chosen = Day(day)
        guard DayRange.sane(chosen) else { problem = DayRange.refusal; return }
        session.change { $0.setDue(chosen) }
        dismiss()
    }
}
