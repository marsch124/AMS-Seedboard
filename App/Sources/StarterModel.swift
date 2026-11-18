import SwiftUI
import SeedboardCore

// Starter boards in the app's state (0.3): the shelf, the questions about it, and changing a starter
// as a working copy. The shelf's rules are `StarterShelf` (Core); the files are `StarterStore`.

/// A question about the shelf that a screen asks the window to show.
enum StarterAsk: Identifiable, Equatable {
    /// Name a board as a new own starter.
    case save(Board)
    case rename(String)
    case remove(String)
    /// Open a starter for changing.
    case change(String)
    /// Open the Starters page.
    case page

    var id: String {
        switch self {
        case .save(let board): return "save." + board.id.uuidString
        case .rename(let id): return "rename." + id
        case .remove(let id): return "remove." + id
        case .change(let id): return "change." + id
        case .page: return "page"
        }
    }
}

/// The starter that is being changed: its working copy is the open board (`BoardSession.starterDraft`).
struct StarterChange: Equatable {
    var id: String
    /// The starter's name as it will be saved (File ▸ Rename… on the working copy changes this).
    var name: String
    /// Something was changed on the working copy.
    var dirty = false
}

extension AppModel {
    // MARK: Loading

    func loadStarters() async {
        let found = await starterStore.loadAll()
        // What was changed here meanwhile is not lost: of two copies the newer wins.
        var merged = StarterShelf(entries: found + Array(shelf.entries.values))
        merged.purge()
        shelf = merged
        await reopenWorkLeftBehind()
        await starterLaunchWords()
    }

    /// The starters are read again (the app came to the front, the Starters page opened).
    func reloadStarters() {
        Task { await loadStarters() }
    }

    /// For pictures: `-starterPage` opens the Starters page, `-starterChange <id or name>` opens a starter for changing.
    private func starterLaunchWords() async {
        let page = LaunchOptions.arguments.contains("-starterPage")
        let word = LaunchOptions.value(for: "-starterChange")
        guard page || word != nil, !launchWordsDone else { return }
        launchWordsDone = true
        for _ in 0..<100 where !loaded { try? await Task.sleep(nanoseconds: 50_000_000) }
        if let word {
            let found = shelf.shown.first { $0.id == word } ?? shelf.shown.first { $0.name.localizedCaseInsensitiveCompare(word) == .orderedSame }
            if let found { changeStarter(found.id) }
        } else if page {
            showStarterPage = true
        }
    }

    // MARK: Changing the shelf

    private func apply(_ work: (inout StarterShelf) -> Void) {
        let before = shelf
        var next = shelf
        work(&next)
        for entry in next.changes(since: before) { starterStore.write(entry) }
        shelf = next
    }

    /// A question from a card's menu or a button: shown by the window, a moment later so a pop-up that
    /// is closing does not get in its way.
    func ask(_ question: StarterAsk) {
        switch question {
        case .change(let id): changeStarter(id)
        case .page: openStarterPage()
        default:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.starterAsk = question }
        }
    }

    func openStarterPage() {
        reloadStarters()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.showStarterPage = true }
    }

    /// A new board from a starter of the shelf: always a fresh one.
    @discardableResult
    func newBoard(from starter: ShelfStarter) -> UUID {
        guard let made = shelf.makeBoard(from: starter.id) else { return newBoard(.blank) }
        // A starter a newer Seedboard wrote: a board made of it could not be saved (it was gone at the next start).
        guard made.canBeChanged else {
            let id = newBoard(.blank)
            say("This starter was made by a newer Seedboard. Update the app to use it. A blank board was made instead.", tone: .problem, seconds: 6)
            return id
        }
        return add(made)
    }

    func saveAsStarter(_ board: Board, name: String) {
        guard board.canBeChanged else { return }
        var made = ""
        apply { shelf in
            let id = shelf.saveAs(board, name: name, hint: "Your own starter")
            made = shelf.starter(id)?.name ?? name
        }
        say("Saved as the starter “\(made)”.")
    }

    /// The board to offer for "Save as a starter…": the open one as it is now.
    func boardForStarter(_ id: UUID) -> Board? {
        if openID == id, let live = session?.board { return live }
        return boards.first { $0.id == id }
    }

    func renameStarter(_ id: String, name: String, hint: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        apply { $0.rename(id, name: $0.freeName(clean, ignoring: id), hint: hint) }
    }

    func moveStarter(_ id: String, to index: Int) { apply { $0.move(id, to: index) } }

    func removeStarter(_ id: String) {
        var name = ""
        apply { shelf in
            name = shelf.starter(id)?.name ?? ""
            shelf.remove(id)
        }
        say("Removed the starter “\(name)”.")
    }

    func bringBackStarters() {
        apply { $0.bringBackBuiltins() }
        say("The built-in starters are back.")
    }

    func starterBackToOriginal(_ id: String) {
        apply { $0.backToOriginal(id) }
        say("The starter is as it was.")
    }

    // MARK: Changing a starter

    /// Opens the starter's board as a working copy in the ordinary board screen, with a banner.
    /// Nothing is stored until Save.
    func changeStarter(_ id: String) {
        guard let starter = shelf.starter(id), let work = shelf.workingBoard(for: id) else { return }
        showStarterPage = false
        leaveChange()
        session?.commitEdit()
        saveNow()
        let draft = BoardSession(board: work)
        draft.starterDraft = true
        draft.onChange = { [weak self] _ in
            self?.changing?.dirty = true
            self?.keepWorkingSoon()
        }
        changing = StarterChange(id: id, name: starter.name)
        present(draft: draft)
    }

    func renameChange(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, changing != nil else { return }
        changing?.name = clean
        changing?.dirty = true
        keepWorkingSoon()
    }

    func saveChange() {
        guard let change = changing, let draft = session, draft.starterDraft else { return }
        draft.commitEdit()
        let board = draft.board
        var name = change.name
        apply { shelf in
            if let current = shelf.starter(change.id), current.name != change.name {
                shelf.rename(change.id, name: shelf.freeName(change.name, ignoring: change.id), hint: current.hint)
            }
            shelf.change(change.id, board: board)
            name = shelf.starter(change.id)?.name ?? name
        }
        endChange()
        say("Saved the starter “\(name)”.")
    }

    /// The owner goes somewhere else without pressing Cancel or Save: what was changed is kept.
    func leaveChange() {
        guard changing != nil else { return }
        if changing?.dirty == true { saveChange() } else { endChange() }
    }

    /// Closes the working copy (saved, cancelled, or left).
    func endChange() {
        forgetWorking()
        changing = nil
        closeDraft()
    }

    // MARK: The working copy is kept on this device while a starter is being changed (0.5, data safety 1)

    /// Half a second after a change of the working copy (the wait a board has before it is saved) it is written
    /// to this device, `Starters/<id>.working`. Never into the shelf and never to iCloud: Cancel must still work,
    /// and half-done work must not reach the other devices.
    func keepWorkingSoon() {
        let desk = StarterWorkDesk.shared
        desk.work?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.keepWorkingNow() }
        desk.work = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Writes the working copy now (also when the app is left). Nothing when no starter is being changed, or
    /// nothing was changed yet.
    func keepWorkingNow() {
        StarterWorkDesk.shared.work?.cancel()
        StarterWorkDesk.shared.work = nil
        guard let change = changing, change.dirty, let draft = session, draft.starterDraft else { return }
        starterStore.keepWorking(StarterWorking(starter: change.id, name: change.name, board: draft.board))
    }

    /// The change has ended (Save, Cancel, or it was left): no working copy stays behind.
    private func forgetWorking() {
        StarterWorkDesk.shared.work?.cancel()
        StarterWorkDesk.shared.work = nil
        starterStore.clearWorking()
    }

    /// Once, after the first loading: the app was stopped while a starter was being changed (iOS dropped it from
    /// memory, a crash, a forced quit). The working copy is opened again, marked as changed.
    private func reopenWorkLeftBehind() async {
        let desk = StarterWorkDesk.shared
        guard !desk.looked else { return }
        desk.looked = true
        guard let work = await starterStore.waitingWork() else { return }
        // The boards first: the board that was open last comes back before the working copy lies over it.
        for _ in 0..<100 where !loaded { try? await Task.sleep(nanoseconds: 50_000_000) }
        leaveChange()
        let board = work.board(now: Date())
        guard let starter = shelf.starter(work.starter), !starter.removed else {
            // The starter was removed meanwhile (on another device): the work is not thrown away.
            apply { $0.saveAs(board, name: work.name, hint: "Your own starter") }
            forgetWorking()
            say("The starter “\(work.name)” was removed. What you were changing is kept as a new starter.", seconds: 6)
            return
        }
        session?.commitEdit()
        saveNow()
        let draft = BoardSession(board: board)
        draft.starterDraft = true
        draft.onChange = { [weak self] _ in
            self?.changing?.dirty = true
            self?.keepWorkingSoon()
        }
        changing = StarterChange(id: work.starter, name: work.name, dirty: true)
        present(draft: draft)
        say("You were changing the starter “\(work.name)”. Your changes are back.", seconds: 6)
    }
}

/// What the working copy's keeping needs between calls (an extension cannot hold it).
@MainActor
private final class StarterWorkDesk {
    static let shared = StarterWorkDesk()
    var work: DispatchWorkItem?
    /// The left-behind working copy was looked for (once per start).
    var looked = false
}
