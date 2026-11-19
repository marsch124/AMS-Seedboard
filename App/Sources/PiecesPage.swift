import SwiftUI
import SeedboardCore

// 0.14 (idea 27): saved pieces. "Save as a piece…" keeps the chosen things (with the arrows between them and a
// mind-map branch's children); "Add a piece…" opens this page; choosing a piece drops a copy in the middle of
// the screen, chosen, as one step for Undo. The rules are `PieceShelf` (Core); the files are `PieceStore`.

/// A question "Save as a piece…" asks: the things to keep, and a name to start from.
struct PieceAsk: Identifiable {
    let id = UUID()
    let clip: Clip
    let suggestion: String
}

@MainActor
final class PieceDesk: ObservableObject {
    static let shared = PieceDesk()

    @Published private(set) var shelf = PieceShelf()
    @Published var showPage = false
    @Published var asking: PieceAsk?
    private let store = PieceStore(sample: LaunchOptions.sampleData)

    /// Reads the files again (the page opened, the app came to the front); what was changed here meanwhile is kept.
    func load() {
        Task {
            let found = await store.loadAll()
            var merged = PieceShelf(entries: found + Array(shelf.entries.values))
            merged.purge()
            shelf = merged
        }
    }

    private func apply(_ work: (inout PieceShelf) -> Void) {
        let before = shelf
        var next = shelf
        work(&next)
        for entry in next.changes(since: before) { store.write(entry) }
        shelf = next
    }

    func flush() { store.flush() }

    // MARK: Asking

    /// "Save as a piece…": asks for a name for what is chosen. Nothing happens when nothing can be kept.
    func askToSave(_ session: BoardSession) {
        guard !session.readOnly, let clip = PieceShelf.cut(from: session.board, chosen: session.selection) else { return }
        session.commitEdit()
        let first = clip.topIdeas.first ?? clip.items.first
        let words = first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        asking = PieceAsk(clip: clip, suggestion: String(words.prefix(40)))
    }

    func canSave(_ session: BoardSession) -> Bool {
        !session.readOnly && !session.board.placesItself && !session.selection.isEmpty
    }

    func canAdd(_ session: BoardSession) -> Bool {
        !session.readOnly && !session.board.placesItself && !session.starterDraft
    }

    func openPage(_ session: BoardSession) {
        guard canAdd(session) else { return }
        session.commitEdit()
        load()
        showPage = true
    }

    // MARK: Changing the shelf

    func save(_ clip: Clip, name: String) {
        var made = ""
        apply { shelf in
            if let id = shelf.save(clip, name: name) { made = shelf.piece(id)?.name ?? name }
        }
        if !made.isEmpty { AppModel.shared.say("Saved as the piece “\(made)”.") }
    }

    func edit(names: [String: String], removed: Set<String>) {
        apply { shelf in
            for (id, name) in names where shelf.piece(id)?.name != name { shelf.rename(id, name: name) }
            for id in removed { shelf.remove(id) }
        }
    }

    // MARK: Dropping

    /// A copy of the piece in the middle of the screen, chosen: one step for Undo.
    func drop(_ piece: PieceEntry, into session: BoardSession) {
        guard canAdd(session) else { return }
        guard piece.clip.canBePasted else {
            AppModel.shared.say("This piece was made in a newer Seedboard. Update the app to use it.", tone: .problem)
            return
        }
        let spot = session.freeSpot(near: session.visibleCentre, size: piece.clip.bounds?.size ?? CGSize(width: 200, height: 120))
        var made: Set<UUID> = []
        session.change { made = PieceShelf.drop(piece, into: &$0, at: spot) }
        guard !made.isEmpty else { return }
        session.selectedLink = nil
        session.selection = made
        if let first = made.first { session.reveal(first) }
        AppModel.shared.say("Added the piece “\(piece.name)”.")
    }
}

// MARK: The host

struct PieceHost: ViewModifier {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = PieceDesk.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $desk.showPage, onDismiss: { session.takeKeys() }) {
                PiecesPage(session: session)
            }
            .sheet(item: $desk.asking, onDismiss: { session.takeKeys() }) { ask in
                PieceNameSheet(ask: ask)
            }
    }
}

// MARK: Name a piece

private struct PieceNameSheet: View {
    let ask: PieceAsk
    @ObservedObject private var desk = PieceDesk.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var ready = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save as a piece")
                .font(Txt.sectionTitle)
                .foregroundStyle(Part.boards.text)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("pieceName.field")
                .onSubmit(save)
            Text("\(PieceEntry.countLine(of: ask.clip)) with the arrows between them. You can add the piece to any board later.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("pieceName.cancel")
                Button("Save", action: save)
                    .buttonStyle(FilledButton(.boards))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("pieceName.save")
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 360)
        #else
        .presentationDetents([.height(220)])
        #endif
        .onAppear {
            guard !ready else { return }
            ready = true
            name = ask.suggestion
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pieceName.sheet")
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        desk.save(ask.clip, name: name)
        dismiss()
    }
}

// MARK: The Pieces page

struct PiecesPage: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = PieceDesk.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var names: [String: String] = [:]
    @State private var removed: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pieces")
                    .font(Txt.big)
                    .foregroundStyle(Part.boards.text)
                Spacer()
                if editing {
                    Button("Cancel") { editing = false }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("pieces.cancel")
                    Button("Done") {
                        desk.edit(names: names, removed: removed)
                        editing = false
                    }
                    .buttonStyle(FilledButton(.boards))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("pieces.done")
                } else {
                    if !desk.shelf.shown.isEmpty {
                        Button("Edit") {
                            names = Dictionary(uniqueKeysWithValues: desk.shelf.shown.map { ($0.id, $0.name) })
                            removed = []
                            editing = true
                        }
                        .accessibilityIdentifier("pieces.edit")
                    }
                    Button("Close") { dismiss() }
                        .buttonStyle(FilledButton(.boards))
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("pieces.close")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            if desk.shelf.shown.isEmpty {
                Text("No pieces yet. Choose some things on a board, then press “Save as a piece…”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("pieces.empty")
            } else {
                List {
                    Section {
                        ForEach(desk.shelf.shown) { piece in
                            if editing { editRow(piece) } else { row(piece) }
                        }
                    } footer: {
                        Text(editing ? "Rename a piece or mark it to remove. Removed pieces are kept for 30 days."
                                     : "Press a piece to add a copy of it to this board.")
                    }
                }
                .listStyle(.plain)
                .accessibilityIdentifier("pieces.list")
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 360)
        #endif
        .onAppear { desk.load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pieces.page")
    }

    private func row(_ piece: PieceEntry) -> some View {
        Button {
            dismiss()
            desk.drop(piece, into: session)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(piece.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(piece.countLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pieces.row.\(piece.id)")
    }

    private func editRow(_ piece: PieceEntry) -> some View {
        let gone = removed.contains(piece.id)
        return HStack(spacing: 8) {
            TextField("Name", text: Binding(get: { names[piece.id] ?? piece.name }, set: { names[piece.id] = $0 }))
                .textFieldStyle(.roundedBorder)
                .disabled(gone)
                .opacity(gone ? 0.4 : 1)
                .accessibilityIdentifier("pieces.name.\(piece.id)")
            Button(gone ? "Keep" : "Remove") {
                if gone { removed.remove(piece.id) } else { removed.insert(piece.id) }
            }
            .foregroundStyle(gone ? Part.boards.text : Color.red)
            .accessibilityIdentifier("pieces.remove.\(piece.id)")
        }
    }
}

// MARK: 22 The brainstorm timer

/// The one timer of the board that is open. Nothing is saved; leaving the board stops it.
@MainActor
final class BrainstormDesk: ObservableObject {
    static let shared = BrainstormDesk()

    enum State: Equatable {
        case off
        case choosing
        case running(start: Date, total: TimeInterval)
        case timeUp(total: TimeInterval)
    }

    @Published private(set) var state: State = .off
    @Published private(set) var board: UUID?
    private var work: Task<Void, Never>?

    func offer(on board: UUID) {
        work?.cancel()
        self.board = board
        state = .choosing
    }

    func start(minutes: Int) {
        work?.cancel()
        let total = TimeInterval(minutes * 60)
        state = .running(start: Date(), total: total)
        work = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(total: total)
        }
    }

    private func finish(total: TimeInterval) {
        state = .timeUp(total: total)
        Feel.timeUp()
        TickSound.play()
        work = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(BrainstormTimer.timeShown * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        work?.cancel()
        work = nil
        state = .off
        board = nil
    }

    func stop(leaving id: UUID) { if board == id { stop() } }
}

/// The small pill at the top of the board: 5 min / 10 min before it starts; then a ring and "4:12 left" with Stop;
/// at the end "Time!" for 4 seconds.
struct BrainstormPill: View {
    @ObservedObject var session: BoardSession
    @ObservedObject private var desk = BrainstormDesk.shared

    var body: some View {
        if desk.board == session.board.id, desk.state != .off {
            HStack(spacing: 8) {
                switch desk.state {
                case .choosing:
                    Text("Brainstorm")
                        .font(Txt.label)
                    ForEach(BrainstormTimer.minutes, id: \.self) { m in
                        Button("\(m) min") { desk.start(minutes: m) }
                            .buttonStyle(FilledButton(.mindMap))
                            .accessibilityIdentifier("timer.min.\(m)")
                    }
                    Button("Cancel") { desk.stop() }
                        .accessibilityIdentifier("timer.cancel")
                case .running(let start, let total):
                    SwiftUI.TimelineView(.periodic(from: start, by: 0.5)) { context in
                        let elapsed = context.date.timeIntervalSince(start)
                        HStack(spacing: 8) {
                            ring(BrainstormTimer.filled(total: total, elapsed: elapsed))
                            Text(BrainstormTimer.leftWords(total: total, elapsed: elapsed))
                                .font(Txt.label)
                                .monospacedDigit()
                                .accessibilityIdentifier("timer.left")
                        }
                    }
                    Button("Stop") { desk.stop() }
                        .accessibilityIdentifier("timer.stop")
                case .timeUp:
                    ring(1)
                    Text("Time!")
                        .font(Txt.label.weight(.bold))
                        .accessibilityIdentifier("timer.timeUp")
                case .off:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.plate, in: Capsule())
            .overlay(Capsule().stroke(Part.mindMap.text.opacity(0.4)))
            .plateShadow()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("timer.pill")
            .transition(.message)
        }
    }

    private func ring(_ filled: Double) -> some View {
        ZStack {
            Circle().stroke(Part.mindMap.text.opacity(0.2), lineWidth: 2.5)
            Circle().trim(from: 0, to: filled)
                .stroke(Part.mindMap.text, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}
