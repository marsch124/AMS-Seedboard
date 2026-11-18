import SwiftUI
import Combine
import AppIntents
import SeedboardCore

// 0.5 (pick 23): a thought is added to a board from outside the app (the Shortcuts action "Add to board").
// The app stays in the back. The rules are in SeedboardCore (OutsideAdd.swift); this file carries them out
// through the one model, keeps the device copy safe before the action answers, and remembers — on this
// device only — which things arrived, so they are chosen once when the board is opened next.

extension AppModel {
    enum OutsideAnswer {
        /// The board as it is now, and the line that says so ("Added to Summer cabin.").
        case added(Board, String)
        /// Nothing was added, and why, in plain words.
        case refused(String)
    }

    static let goneLine = "That board is not on this device any more."

    /// The board as it stands this moment: the open one with its newest change, else the one in the list.
    func boardNow(_ id: UUID) -> Board? {
        if openID == id, let session, !session.starterDraft { return session.board }
        return boards.first { $0.id == id }
    }

    /// A name a file can have: the board's name without the signs a file name may not hold.
    static func fileName(for board: Board) -> String {
        let name = board.title.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Board" : name
    }

    /// The board's picture, with its pictures read from their files first (a board that is not open has
    /// none of them in memory).
    func pictureNow(of board: Board) async -> Data? {
        let names = board.pictureNames
        if !names.isEmpty {
            await Task.detached(priority: .userInitiated) {
                for name in names { _ = PictureStore.shared.imageNow(name) }
            }.value
        }
        return BoardPicture.png(of: board)
    }

    /// Adds words, a picture, or both to a board. `id` nil: the board changed last that can take a thought.
    /// The open board is changed through its own session (so Undo and the screen follow) and the new things
    /// are chosen at once; any other board is written straight away and its new things are chosen when it is
    /// opened next. Before this returns the device copy is written, so nothing is lost when the app is put
    /// to sleep again right after the action.
    func addFromOutside(text: String, picture: Data?, to id: UUID?) async -> OutsideAnswer {
        let target: Board
        if let id {
            guard let found = boardNow(id) else { return .refused("Nothing was added. " + AppModel.goneLine) }
            target = found
        } else {
            guard let found = Outside.boardForThought(in: boards) else { return .refused(Outside.noBoardLine) }
            target = found
        }
        if let line = Outside.refusal(for: target) { return .refused(line) }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty || picture != nil else { return .refused(Outside.nothingLine) }

        // The picture is taken into the Pictures folder first, off the main thread.
        var arrived: Outside.ArrivedPicture?
        if let picture {
            let taken = await Task.detached(priority: .userInitiated) { PictureStore.shared.take(picture) }.value
            arrived = taken.map { Outside.ArrivedPicture(name: $0.name, pixels: $0.pixels) }
        }
        let unread = picture != nil && arrived == nil
        guard !clean.isEmpty || arrived != nil else { return .refused("Nothing was added. That could not be read as a picture.") }

        var made: [UUID] = []
        let result: Board
        if openID == target.id, let session, !session.starterDraft {
            session.commitEdit()
            session.change { made = Outside.add(text: clean, picture: arrived, to: &$0) }
            result = session.board
            if !made.isEmpty {
                session.selectedLink = nil
                session.selection = Set(made)
                if let first = made.first { session.reveal(first) }
            }
        } else {
            // The board may have changed while the picture was read: the newest one is taken.
            guard var board = boards.first(where: { $0.id == target.id }) else { return .refused("Nothing was added. " + AppModel.goneLine) }
            made = Outside.add(text: clean, picture: arrived, to: &board)
            if !made.isEmpty {
                // The words are measured as they are when a board is opened, so the next arrival sees the real sizes.
                Lettering.fit(&board, facts: MapFacts(board))
                board.touch()
                write(board)
                OutsideWatch.shared.note(made, on: board.id)
            }
            result = board
        }
        guard !made.isEmpty else { return .refused("Nothing was added. “\(target.title)” cannot be changed just now. Try again in a moment.") }
        await writtenOnTheDevice()
        return .added(result, Outside.addedLine(to: result) + (unread ? " The picture could not be read." : ""))
    }

    /// Waits until what was changed is on the device, exactly as leaving the app does; on iPhone and iPad it
    /// then gives iCloud's copy a little time too (at most 8 seconds — an action has about 30).
    private func writtenOnTheDevice() async {
        saveNow()
        store.flush()
        #if !os(macOS)
        await withCheckedContinuation { (waiting: CheckedContinuation<Void, Never>) in
            let once = Once { waiting.resume() }
            store.afterCloud { once.run() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { once.run() }
        }
        #endif
    }
}

/// Runs its work the first time it is asked, and never again. Used on the main thread only.
private final class Once {
    private var work: (() -> Void)?
    init(_ work: @escaping () -> Void) { self.work = work }
    func run() {
        let now = work
        work = nil
        now?()
    }
}

/// Watches the app for what came in from outside: the things added while a board was not open are chosen
/// once when it is opened next, and the names Siri and Shortcuts offer for "New board" follow his starters.
@MainActor
final class OutsideWatch {
    static let shared = OutsideWatch()

    /// This device's own settings; never synced, never in a board.
    private static let key = "seedboard.outsideArrivals"
    private var arrivals = OutsideWatch.read()
    private weak var model: AppModel?
    private var watches = Set<AnyCancellable>()

    private static func read() -> OutsideArrivals {
        guard !LaunchOptions.sampleData, let data = UserDefaults.standard.data(forKey: key),
              let found = try? JSONDecoder().decode(OutsideArrivals.self, from: data) else { return OutsideArrivals() }
        return found
    }

    /// With `-sampleData` nothing is written down (the arrivals live for this run only).
    private func save() {
        guard !LaunchOptions.sampleData else { return }
        if arrivals.isEmpty {
            UserDefaults.standard.removeObject(forKey: OutsideWatch.key)
        } else if let data = try? JSONEncoder().encode(arrivals) {
            UserDefaults.standard.set(data, forKey: OutsideWatch.key)
        }
    }

    func note(_ things: [UUID], on board: UUID) {
        arrivals.note(things, on: board)
        save()
    }

    func watch(_ model: AppModel) {
        guard self.model == nil else { return }
        self.model = model
        // A board is opened (told just before it shows): its arrivals are chosen.
        model.$session
            .sink { [weak self] new in self?.opened(new) }
            .store(in: &watches)
        // Boards that are gone are forgotten, once the boards are read.
        model.$loaded
            .filter { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak model] _ in
                guard let self, let model, !self.arrivals.isEmpty else { return }
                self.arrivals = self.arrivals.keeping(Set(model.boards.map(\.id)))
                self.save()
            }
            .store(in: &watches)
        // "New board" offers his own starters by name: Siri and Shortcuts hear when the shelf's names change.
        model.$shelf
            .map { $0.shown.map(\.name) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { _ in SeedboardShortcuts.updateAppShortcutParameters() }
            .store(in: &watches)
        #if DEBUG
        tryOut(model)
        HandoffDesk.shared.tryOut(model)
        #endif
    }

    private func opened(_ session: BoardSession?) {
        guard let session, !arrivals.isEmpty else { return }
        let things = arrivals.take(for: session.board.id, present: Set(session.board.items.map(\.id)))
        save()
        guard !things.isEmpty else { return }
        session.selectedLink = nil
        session.selection = Set(things)
        // Once the board has its room on screen, the first arrival is brought into sight (a board that was
        // never moved shows everything anyway).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak session, weak model] in
            guard let session, model?.session === session, session.selection == Set(things), let first = things.first else { return }
            session.reveal(first)
        }
    }

    #if DEBUG
    /// For pictures and for trying it without the Shortcuts app: `-addThought "<words>"` adds the words to the
    /// board that is open (`-board <word>`), or with `-addTo <word>` to the first board whose name holds the
    /// word — that board is not open then, and is opened a second later so the arrival shows chosen.
    private func tryOut(_ model: AppModel) {
        guard let words = LaunchOptions.value(for: "-addThought") else { return }
        Task { @MainActor in
            await model.whenLoaded()
            let other = LaunchOptions.value(for: "-addTo").flatMap { word in
                model.boards.first { $0.title.localizedCaseInsensitiveContains(word) }
            }
            let answer = await model.addFromOutside(text: words.replacingOccurrences(of: "\\n", with: "\n"), picture: nil, to: other?.id ?? model.openID)
            switch answer {
            case .added(let board, let line): print("ADDTHOUGHT: \(line) (\(board.items.count) things)")
            case .refused(let line): print("ADDTHOUGHT refused: \(line)")
            }
            if let other {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                model.open(other.id)
            }
        }
    }
    #endif
}
