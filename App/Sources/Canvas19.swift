import SwiftUI
import SeedboardCore

/// 0.19 (canvas): every SF Symbol this file uses, in one place so a name can be swapped after a look.
enum Marks19Canvas {
    static let readMode = "book"
}

/// 0.19 (17): Read mode is kept per board on this device, never in the board.
enum Read19 {
    static func key(_ id: UUID) -> String { "readMode.\(id.uuidString)" }
    static func isOn(for id: UUID) -> Bool { UserDefaults.standard.bool(forKey: key(id)) }
    static func keep(_ on: Bool, for id: UUID) {
        if on { UserDefaults.standard.set(true, forKey: key(id)) } else { UserDefaults.standard.removeObject(forKey: key(id)) }
    }
}

extension BoardSession {
    /// Read mode on or off. A board that cannot be changed at all has nothing to freeze.
    func setReadMode(_ on: Bool) {
        guard board.canBeChanged, readMode != on else { return }
        if on { commitEdit(); linking = false; linkFrom = nil }
        readMode = on
        Read19.keep(on, for: board.id)
        takeKeys()
    }

    /// 0.19 (18): the paper colour; undoable, refused on a board that is read-only (or in Read mode).
    func setPaper(_ colour: PaperColour?) {
        guard marksOn, board.paperColour != colour else { return }
        change { $0.paperColour = colour }
    }
}

/// "Read mode  Done" at the top while Read mode is on.
struct ReadModePill: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: Marks19Canvas.readMode)
                .foregroundStyle(Part.boards.text)
            Text("Read mode")
                .font(Txt.label)
                .accessibilityIdentifier("readmode.pill")
            Button("Done") { session.setReadMode(false) }
                .buttonStyle(FilledButton(.boards))
                .accessibilityIdentifier("readmode.done")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.plate, in: Capsule())
        .overlay(Capsule().stroke(Part.boards.text.opacity(0.35)))
        .transition(.message)
    }
}

/// The line in the board's More menu.
struct ReadModeMoreLine: View {
    @ObservedObject var session: BoardSession

    var body: some View {
        Button { session.setReadMode(!session.readMode) } label: {
            Label(session.readMode ? "Leave Read mode" : "Read mode", systemImage: Marks19Canvas.readMode)
        }
        .accessibilityIdentifier("more.readMode")
    }
}

/// Asks for the paper page ("Background colour…" in More).
@MainActor
final class BackdropColourDesk: ObservableObject {
    static let shared = BackdropColourDesk()
    @Published var show = false
}

struct BackdropColourHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = BackdropColourDesk.shared

    func body(content: Content) -> some View {
        content.sheet(isPresented: $desk.show, onDismiss: { session.takeKeys() }) {
            BackdropColourSheet(session: session)
        }
    }
}

/// Four round swatches with words: Plain, Paper, Warm grey, Night blue. A press changes the board at once (one undo step).
struct BackdropColourSheet: View {
    @ObservedObject var session: BoardSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private func fill(_ colour: PaperColour?) -> Color {
        Paint(scheme, paper: colour?.rawValue).canvas
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background colour")
                .font(Txt.big)
                .foregroundStyle(Part.boards.text)
            HStack(alignment: .top, spacing: 14) {
                swatch(nil, word: PaperColour.plainWord, id: "plain")
                ForEach(PaperColour.allCases, id: \.self) { swatch($0, word: $0.word, id: $0.rawValue) }
            }
            Text("It goes with the dots or squares of Background.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(FilledButton(.boards))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("paper.done")
                Button("") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 360)
        #else
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(220)])
        #endif
    }

    private func swatch(_ colour: PaperColour?, word: String, id: String) -> some View {
        let chosen = session.board.paperColour == colour
        return Button { session.setPaper(colour) } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(fill(colour))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
                    .overlay(Circle().stroke(Part.boards.text, lineWidth: chosen ? 3 : 0).padding(-3))
                Text(word)
                    .font(.caption)
                    .foregroundStyle(chosen ? Part.boards.text : Color.primary)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(word)
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier("paper.swatch.\(id)")
    }
}
