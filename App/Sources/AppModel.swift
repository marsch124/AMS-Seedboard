import SwiftUI
import Combine
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
    /// Boards whose newest change is on this device but not in iCloud yet (a small dot in the list).
    @Published private(set) var notInCloud: Set<UUID> = []
    /// Plain words when a board could not be saved; nil when all is well (shown in Settings).
    @Published private(set) var saveWarning: String?
    /// A link led to a board that was removed: which one, and when. The place for a "Bring back" button
    /// (`bringBack`). Cleared when the board is back or another board is opened.
    @Published var removedLink: RemovedBoard?
    /// Two devices changed the same board: the one-line notice that says where the other version is kept.
    @Published var clash: ClashNotice?
    /// The page "Removed and earlier versions" is asked for over the main window (BringBack.swift).
    @Published var keptPage: KeptPageAsk?

    struct RemovedBoard: Equatable {
        var id: UUID
        var removed: Date
    }

    let store: BoardStore
    /// The starter boards (StarterModel.swift): the shelf, its files, and the questions about it.
    @Published var shelf = StarterShelf()
    @Published var starterAsk: StarterAsk?
    @Published var showStarterPage = false
    @Published var changing: StarterChange?
    var launchWordsDone = false
    let starterStore = StarterStore(sample: LaunchOptions.sampleData)
    private(set) var place: ParagonPlace?
    private var saveWork: DispatchWorkItem?
    private var pendingSave: Board?
    private var flashWork: DispatchWorkItem?
    /// News from another device that arrived while the owner was typing or dragging in that board.
    /// Not shown and not thrown away: offered again the moment he stops.
    private var heldNews: [UUID: Board] = [:]
    private var heldWatch: AnyCancellable?
    /// A `seedboard://board/<id>` link that could not be followed yet (the boards were still loading,
    /// or the board has not arrived on this device).
    private var waitingLink: UUID?
    private var sending = false

    init() {
        store = BoardStore(sample: LaunchOptions.sampleData)
        store.onCloudChange = { [weak self] news in self?.cloudBrought(news) ?? [] }
        store.onCloudGone = { [weak self] gone in self?.cloudRemoved(gone) }
        store.onState = { [weak self] in self?.storeStateChanged() }
        store.onClash = { [weak self] id, title in self?.clash = ClashNotice(id: id, title: title) }
        #if os(macOS)
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.leaving(closing: true) }
        }
        #endif
        Task { await load() }
        Task { await loadStarters() }
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
        // With no launch words of its own, the board that was open last comes back (pick 26, Remember.swift).
        if session == nil, waitingLink == nil, let id = Remember.boardToReopen(among: all) { open(id) }
        // For pictures: `-pick <word>` chooses the first thing whose words hold it.
        if let word = LaunchOptions.value(for: "-pick"), let session,
           let item = session.board.items.first(where: { $0.text.localizedCaseInsensitiveContains(word) }) {
            session.select(item.id)
        }
        // For pictures: `-pickAll <words>` chooses every thing whose words hold one of them ("New idea,Worth,plan").
        if let words = LaunchOptions.value(for: "-pickAll")?.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }), let session {
            session.selection = Set(session.board.items.filter { item in words.contains { item.text.localizedCaseInsensitiveContains($0) } }.map(\.id))
        }
        // For pictures: `-type` starts typing in the picked thing (the bar above the keyboard shows).
        if LaunchOptions.arguments.contains("-type"), let session, let id = session.selection.first { session.beginEdit(id) }
        // For pictures: `-pickArrow <word>` chooses the first arrow whose words hold it.
        if let word = LaunchOptions.value(for: "-pickArrow"), let session,
           let link = session.board.links.first(where: { $0.text.localizedCaseInsensitiveContains(word) }) {
            session.selection = []
            session.selectedLink = link.id
        }
        // For pictures: `-draw` opens the board with the Draw tool on and its plate showing.
        if LaunchOptions.arguments.contains("-draw") { session?.ink.on = true }
        if LaunchOptions.arguments.contains("-send") { showSend = true }
        // For pictures: `-removed` opens "Removed and earlier versions", `-clash` shows the clash notice.
        bringBackLaunch()
        // A link that arrived before the boards were loaded is followed now.
        if let id = waitingLink { follow(id) }
        checkParagon()
        #if DEBUG
        // For trying the hand-over without a press: `-sendNow note|project|todos` (with `-paragonFolder`).
        if let word = LaunchOptions.value(for: "-sendNow"), let kind = SendKind(rawValue: word) {
            Task {
                for _ in 0..<50 where place == nil { try? await Task.sleep(nanoseconds: 100_000_000) }
                let problem = await send(kind: kind, title: "")
                print("SENDNOW \(word): \(problem ?? "ok") — \(flash ?? "")")
            }
        }
        #endif
    }

    /// News from iCloud. Gives back the ids that are shown now; what is held or not needed is not "seen".
    @discardableResult
    private func cloudBrought(_ news: [Board]) -> Set<UUID> {
        var taken = Set<UUID>()
        for board in news {
            if let i = boards.firstIndex(where: { $0.id == board.id }) {
                // In the middle of typing or dragging the open board is left alone, and the news is HELD:
                // it is offered again the moment the typing ends (`offerHeld`).
                let busy = openID == board.id && session?.busy == true
                switch SafetyRules.news(incoming: board.changed, shown: boards[i].changed, busy: busy) {
                case .ignore:
                    continue
                case .hold:
                    heldNews[board.id] = board
                    watchHeld()
                case .take:
                    heldNews[board.id] = nil
                    boards[i] = board
                    if openID == board.id { session?.replace(with: board) }
                    taken.insert(board.id)
                }
            } else {
                boards.append(board)
                taken.insert(board.id)
            }
        }
        boards.sort { $0.changed > $1.changed }
        safetyLine = store.safetyLine()
        // A link was waiting for this board to arrive.
        if let id = waitingLink, loaded, boards.contains(where: { $0.id == id }) {
            waitingLink = nil
            open(id)
        }
        return taken
    }

    /// While news is held, every change of the open board is a moment to look whether the typing has ended.
    private func watchHeld() {
        guard heldWatch == nil, let session else { return }
        heldWatch = session.objectWillChange.sink { [weak self] _ in
            // After the change has landed, not before.
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.offerHeld() } }
        }
    }

    /// Offers the held news again. Typing ended without a change: the other device's version is shown now.
    /// Typing ended with a change: mine is the newer one and stays; theirs is kept in SafetyCopies by the
    /// save that follows, because it is not a version this board grew from.
    private func offerHeld() {
        guard !heldNews.isEmpty else {
            heldWatch = nil
            return
        }
        if let id = openID, heldNews[id] != nil, session?.busy == true { return }
        let news = Array(heldNews.values)
        heldNews = [:]
        heldWatch = nil
        let taken = cloudBrought(news)
        store.took(news.filter { taken.contains($0.id) })
        if let lost = news.first(where: { !taken.contains($0.id) && heldNews[$0.id] == nil }) {
            clash = ClashNotice(id: lost.id, title: boards.first { $0.id == lost.id }?.title ?? lost.title)
        }
    }

    /// Another device removed these boards: they leave this device's list too.
    /// The open board stays when it was changed AFTER the removal (the owner was typing in it): that
    /// change wins, the board is saved again and comes back on every device.
    private func cloudRemoved(_ gone: [UUID: Date]) {
        var ids = Set(gone.keys)
        if let open = openID, let removedAt = gone[open], let session {
            session.commitEdit()
            if SafetyRules.removal(removedAt: removedAt, lastChange: session.board.changed) == .comesBack {
                ids.remove(open)
                keep(session.board)
                saveNow()
            } else {
                self.session = nil
                openID = nil
                pendingSave = nil
                saveWork?.cancel()
            }
        }
        for id in ids { heldNews[id] = nil }
        boards.removeAll { ids.contains($0.id) }
        safetyLine = store.safetyLine()
    }

    private func storeStateChanged() {
        if notInCloud != store.notInCloud { notInCloud = store.notInCloud }
        let warning = store.warning
        if saveWarning != warning {
            // A board that cannot be saved on the device is said at once, not only in Settings.
            if let warning, saveWarning == nil { say(warning) }
            saveWarning = warning
        }
    }

    /// The app is being left or closed: what is being typed is kept and everything is written.
    /// The device copy is written before this returns; iCloud's copy gets background time to finish
    /// (iPhone and iPad), or two more seconds when the Mac app closes for good.
    func leaving(closing: Bool = false) {
        session?.commitEdit()
        saveNow()
        starterStore.flush()
        #if os(macOS)
        store.flush(cloudToo: closing)
        #else
        let time = BackgroundTime()
        time.begin()
        store.flush()
        store.afterCloud { time.end() }
        #endif
    }

    /// The open board changed: the list shows it at once, the file follows half a second later.
    private func keep(_ board: Board) {
        // A board that was removed meanwhile is not put back.
        guard openID == board.id || boards.contains(where: { $0.id == board.id }) else { return }
        if let i = boards.firstIndex(where: { $0.id == board.id }) { boards[i] = board } else { boards.insert(board, at: 0) }
        boards.sort { $0.changed > $1.changed }
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

    func write(_ board: Board) {
        if let i = boards.firstIndex(where: { $0.id == board.id }) { boards[i] = board } else { boards.insert(board, at: 0) }
        boards.sort { $0.changed > $1.changed }
        store.save(board)
        safetyLine = store.safetyLine()
    }

    // MARK: The list

    var pinned: [Board] { boards.filter(\.pinned) }
    var recent: [Board] { boards.filter { !$0.pinned && $0.sent == nil } }
    var sent: [Board] { boards.filter { !$0.pinned && $0.sent != nil } }

    func open(_ id: UUID?) {
        guard id != openID || session == nil else { return }
        // Going to another board while a starter is being changed leaves that change unsaved.
        if changing != nil { endChange() }
        session?.commitEdit()
        saveNow()
        // Leaving a board ends its typing: news that was held for it is offered now.
        heldWatch = nil
        openID = id
        if id != waitingLink { waitingLink = nil }
        if id != removedLink?.id { removedLink = nil }
        defer { offerHeld() }
        guard let id, let board = boards.first(where: { $0.id == id }) else {
            session = nil
            return
        }
        let new = BoardSession(board: board)
        new.onChange = { [weak self] board in self?.keep(board) }
        session = new
    }

    /// A working copy that is not one of the boards (changing a starter): shown like a board, never kept as one.
    func present(draft new: BoardSession) {
        heldWatch = nil
        openID = new.board.id
        session = new
    }

    func closeDraft() {
        session = nil
        openID = nil
    }

    @discardableResult
    func newBoard(_ starter: Starter) -> UUID { add(starter.board()) }

    /// A board made by a starter or handed in from outside (a Shortcuts action) joins the list:
    /// its own colour, a name of its own, saved and opened.
    @discardableResult
    func add(_ made: Board) -> UUID {
        var board = made
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
        guard copy.canBeChanged else {
            say("This board was made by a newer Seedboard. Update the app to copy it.")
            return
        }
        copy.id = UUID()
        let names = Set(boards.map { $0.title.lowercased() })
        let base = copy.title + " copy"
        copy.title = base
        var n = 2
        while names.contains(copy.title.lowercased()) {
            copy.title = "\(base) \(n)"
            n += 1
        }
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
    /// A link that arrives before the boards are loaded (the app was started by it) is held and
    /// followed once loading has finished.
    func open(url: URL) {
        guard let id = BoardLink.id(from: url) else { return }
        guard loaded else {
            waitingLink = id
            return
        }
        follow(id)
    }

    private func follow(_ id: UUID) {
        if boards.contains(where: { $0.id == id }) {
            waitingLink = nil
            open(id)
            return
        }
        // Not here: removed, or not arrived yet. If iCloud brings it, it opens then (`cloudBrought`).
        waitingLink = id
        Task {
            let removedAt = await store.removedDate(id)
            guard waitingLink == id else { return }
            let onDevice = boards.contains(where: { $0.id == id })
            switch BoardLink.answer(loaded: loaded, onDevice: onDevice, removedAt: removedAt) {
            case .hold:
                break
            case .open:
                waitingLink = nil
                open(id)
            case .removed(let date):
                waitingLink = nil
                // Shown as a line with a "Bring back" button (BringBack.swift).
                removedLink = RemovedBoard(id: id, removed: date)
            case .missing:
                say("That board is not on this device yet. It opens when it arrives.")
            }
        }
    }

    /// Brings a removed board back from the Removed folder (kept 30 days), under the same identity,
    /// on every device, and opens it. The hook for a "Bring back" button.
    func bringBack(_ id: UUID) {
        Task {
            guard let board = await store.bringBack(id: id) else {
                say("That board could not be brought back: no copy of it is left.")
                return
            }
            if let i = boards.firstIndex(where: { $0.id == id }) { boards[i] = board } else { boards.append(board) }
            boards.sort { $0.changed > $1.changed }
            removedLink = nil
            safetyLine = store.safetyLine()
            open(id)
            say("“\(board.title)” is back.")
        }
    }

    // MARK: PARAGON

    func checkParagon() {
        paragonLine = "Looking for PARAGON…"
        Task.detached(priority: .userInitiated) {
            let found = ParagonGate.find()
            await MainActor.run { self.found(found) }
        }
    }

    private func found(_ found: ParagonPlace?) {
        place = found
        paragonReady = found != nil
        if LaunchOptions.sampleData {
            paragonLine = "Sample boards: nothing is sent anywhere."
        } else if let found {
            paragonLine = found.outbox == nil
                ? "PARAGON's notes are found. Notes and projects can be sent; the Inbox cannot be reached from this device."
                : "PARAGON's notes are found. Boards can be sent as a note, a project, or tasks for the Inbox."
        } else {
            paragonLine = "PARAGON's notes were not found on this device. Open PARAGON once with its own iCloud folder, then check again."
        }
    }

    /// Sends the open board. The board's picture is made here, the files are written off the main thread.
    /// `branch`: only this idea and everything under it is sent, as a small map of its own.
    func send(kind: SendKind, title: String, branch: UUID? = nil) async -> String? {
        guard let session else { return SendProblem.notFound.errorDescription }
        // One hand-over at a time: a second press while the first is on its way does nothing.
        guard !sending else { return "The board is on its way already." }
        sending = true
        defer { sending = false }
        session.commitEdit()
        // PARAGON's folder is looked for again at every Send, not only when the app started:
        // it may have appeared, gone or moved since.
        let found = await Task.detached(priority: .userInitiated) { ParagonGate.find() }.value
        self.found(found)
        guard let place = found else { return SendProblem.notFound.errorDescription }
        let board = branch.flatMap { session.board.branchOnly($0) } ?? session.board
        let png = kind == .todos ? nil : BoardPicture.png(of: board)
        // Inbox tasks: the "already sent" ticks are on the device BEFORE the tasks are handed over, so a
        // stop in between can never send the same tasks twice. If the hand-over fails, the ticks come off again.
        var ticked: Board?
        if kind == .todos, board.canBeChanged {
            let ids = ParagonExport.inboxTasks(board: board).map(\.id)
            if !ids.isEmpty, place.outbox != nil {
                saveNow()
                var marked = board
                marked.sentTodos = Array(Set(marked.sentTodos).union(ids))
                marked.touch()
                store.save(marked)
                store.flush()
                ticked = marked
            }
        }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try ParagonGate.send(board: board, kind: kind, title: title, png: png, place: place)
            }.value
            if self.session === session {
                // One branch is not the whole board: the board gets no "sent" mark for it.
                session.markSent(branch == nil ? result.info : nil, todos: result.todos)
                saveNow()
            } else if var other = boards.first(where: { $0.id == board.id }) {
                // Another board was opened meanwhile: the sent mark goes onto the board itself.
                if let info = result.info, branch == nil { other.sent = info }
                other.sentTodos = Array(Set(other.sentTodos).union(result.todos))
                other.touch()
                write(other)
            }
            say(result.message)
            return nil
        } catch {
            if let ticked {
                // Nothing went to the Inbox: the board is stored again as it was, without the ticks.
                var back = self.session === session ? session.board : (boards.first(where: { $0.id == board.id }) ?? board)
                back.changed = max(Date(), back.changed, ticked.changed).addingTimeInterval(0.002)
                store.save(back)
            }
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

#if !os(macOS)
/// Asks iOS for a little time after the app is left, so iCloud's copy of the last change can still be written.
@MainActor
private final class BackgroundTime {
    private var task = UIBackgroundTaskIdentifier.invalid

    func begin() {
        task = UIApplication.shared.beginBackgroundTask(withName: "Seedboard saves") { [weak self] in
            // Time is up: iOS is told at once. The device copy is long written by then.
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
#endif
