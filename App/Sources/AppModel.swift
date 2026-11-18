import SwiftUI
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The whole app's state: the boards, the one that is open, and the way to PARAGON.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var boards: [Board] = []
    @Published private(set) var session: BoardSession?
    @Published var openID: UUID?
    @Published private(set) var loaded = false
    @Published var paragonLine = "Looking for PARAGON…"
    @Published private(set) var paragonReady = false
    @Published var safetyLine = ""
    /// A short line shown for a moment at the bottom.
    @Published var flash: String?
    /// The Send to PARAGON page is asked for.
    @Published var showSend = false

    let store: BoardStore
    private(set) var place: ParagonPlace?
    private var saveWork: DispatchWorkItem?
    private var pendingSave: Board?
    private var flashWork: DispatchWorkItem?

    init() {
        store = BoardStore(sample: LaunchOptions.sampleData)
        store.onCloudChange = { [weak self] news in self?.cloudBrought(news) }
        Task { await load() }
    }

    // MARK: Loading and keeping

    private func load() async {
        var all = LaunchOptions.sampleData ? Sample.boards() : await store.loadAll()
        all.sort { $0.changed > $1.changed }
        boards = all
        loaded = true
        safetyLine = store.safetyLine()
        if let word = LaunchOptions.value(for: "-board"),
           let match = all.first(where: { $0.title.localizedCaseInsensitiveContains(word) }) {
            open(match.id)
        }
        // For pictures: `-pick <word>` chooses the first thing whose words hold it.
        if let word = LaunchOptions.value(for: "-pick"), let session,
           let item = session.board.items.first(where: { $0.text.localizedCaseInsensitiveContains(word) }) {
            session.select(item.id)
        }
        if LaunchOptions.arguments.contains("-send") { showSend = true }
        checkParagon()
    }

    private func cloudBrought(_ news: [Board]) {
        for board in news {
            if let i = boards.firstIndex(where: { $0.id == board.id }) {
                guard board.changed > boards[i].changed else { continue }
                boards[i] = board
                if openID == board.id { session?.replace(with: board) }
            } else {
                boards.append(board)
            }
        }
        boards.sort { $0.changed > $1.changed }
        safetyLine = store.safetyLine()
    }

    /// The open board changed: the list shows it at once, the file follows half a second later.
    private func keep(_ board: Board) {
        if let i = boards.firstIndex(where: { $0.id == board.id }) { boards[i] = board } else { boards.insert(board, at: 0) }
        pendingSave = board
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        guard let board = pendingSave else { return }
        pendingSave = nil
        store.save(board)
        safetyLine = store.safetyLine()
    }

    private func write(_ board: Board) {
        if let i = boards.firstIndex(where: { $0.id == board.id }) { boards[i] = board } else { boards.insert(board, at: 0) }
        store.save(board)
        safetyLine = store.safetyLine()
    }

    // MARK: The list

    var pinned: [Board] { boards.filter(\.pinned) }
    var recent: [Board] { boards.filter { !$0.pinned && $0.sent == nil } }
    var sent: [Board] { boards.filter { !$0.pinned && $0.sent != nil } }

    func open(_ id: UUID?) {
        guard id != openID || session == nil else { return }
        session?.commitEdit()
        saveNow()
        openID = id
        guard let id, let board = boards.first(where: { $0.id == id }) else {
            session = nil
            return
        }
        let new = BoardSession(board: board)
        new.onChange = { [weak self] board in self?.keep(board) }
        session = new
    }

    @discardableResult
    func newBoard(_ starter: Starter) -> UUID {
        var board = starter.board()
        board.colour = Palette.boards[boards.count % Palette.boards.count]
        // Two boards never share a name: "Mind map", "Mind map 2" …
        let names = Set(boards.map { $0.title.lowercased() })
        var n = 2
        let base = board.title
        while names.contains(board.title.lowercased()) && base != "New board" {
            board.title = "\(base) \(n)"
            n += 1
        }
        write(board)
        open(board.id)
        return board.id
    }

    func remove(_ id: UUID) {
        if openID == id {
            session = nil
            openID = nil
            pendingSave = nil
            saveWork?.cancel()
        }
        boards.removeAll { $0.id == id }
        store.remove(id: id)
        safetyLine = store.safetyLine()
        say("Board removed. It is kept for 30 days in the Removed folder.")
    }

    func duplicate(_ id: UUID) {
        guard var copy = boards.first(where: { $0.id == id }) else { return }
        if openID == id, let live = session?.board { copy = live }
        copy.id = UUID()
        copy.title += " copy"
        copy.created = Date()
        copy.changed = Date()
        copy.sent = nil
        copy.sentTodos = []
        copy.pinned = false
        write(copy)
        open(copy.id)
    }

    func togglePin(_ id: UUID) { edit(id) { $0.pinned.toggle() } }

    func rename(_ id: UUID, to title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        edit(id) { $0.title = clean }
    }

    func setColour(_ id: UUID, _ name: String) { edit(id) { $0.colour = name } }

    private func edit(_ id: UUID, _ work: @escaping (inout Board) -> Void) {
        if openID == id, let session {
            session.change(work)
            return
        }
        guard var board = boards.first(where: { $0.id == id }), board.canBeChanged else { return }
        work(&board)
        board.touch()
        write(board)
    }

    // MARK: Links in

    /// `seedboard://board/<id>` opens that board (the link PARAGON's notes carry).
    func open(url: URL) {
        guard url.scheme == "seedboard", url.host == "board",
              let id = UUID(uuidString: url.lastPathComponent) else { return }
        if boards.contains(where: { $0.id == id }) {
            open(id)
        } else {
            say("That board is not on this device yet.")
        }
    }

    // MARK: PARAGON

    func checkParagon() {
        paragonLine = "Looking for PARAGON…"
        Task.detached(priority: .userInitiated) {
            let found = ParagonGate.find()
            await MainActor.run {
                self.place = found
                self.paragonReady = found != nil
                if LaunchOptions.sampleData {
                    self.paragonLine = "Sample boards: nothing is sent anywhere."
                } else if let found {
                    self.paragonLine = found.outbox == nil
                        ? "PARAGON's notes are found. Notes and projects can be sent; the Inbox cannot be reached from this device."
                        : "PARAGON's notes are found. Boards can be sent as a note, a project, or tasks for the Inbox."
                } else {
                    self.paragonLine = "PARAGON's notes were not found on this device. Open PARAGON once with its own iCloud folder, then check again."
                }
            }
        }
    }

    /// Sends the open board. The board's picture is made here, the files are written off the main thread.
    func send(kind: SendKind, title: String) async -> String? {
        guard let session, let place else { return SendProblem.notFound.errorDescription }
        session.commitEdit()
        let board = session.board
        let png = kind == .todos ? nil : BoardPicture.png(of: board)
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try ParagonGate.send(board: board, kind: kind, title: title, png: png, place: place)
            }.value
            session.markSent(result.info, todos: result.todos)
            saveNow()
            say(result.message)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "The board could not be sent. Nothing was changed."
        }
    }

    /// Opens the note the board became, in PARAGON.
    func openInParagon(_ info: SentInfo) {
        guard let url = ParagonExport.openURL(noteTitle: info.title) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    // MARK: Small things

    func say(_ line: String) {
        flash = line
        flashWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flash = nil }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    func showBoardsFolder() {
        #if os(macOS)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        NSWorkspace.shared.open(support.appendingPathComponent("Boards", isDirectory: true))
        #endif
    }

    func copyText(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    func clipboardText() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}
