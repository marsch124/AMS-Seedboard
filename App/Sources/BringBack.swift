import SwiftUI
import SeedboardCore

// 0.2 picks 4 and 5: bringing back removed boards and earlier versions, and the export of all boards.
// The rules are in SeedboardCore (Kept.swift, KeptFiles.swift, ExportAll.swift); the page is KeptPage.swift;
// the lines over the main window and the rows in Settings are BringBackBars.swift.

/// Two devices changed the same board; the version that lost is kept under Earlier versions.
struct ClashNotice: Equatable {
    var id: UUID
    var title: String
}

/// The page "Removed and earlier versions" is asked for over the main window.
struct KeptPageAsk: Identifiable, Equatable {
    let id = UUID()
    /// Show this board's earlier versions (opened and scrolled to).
    var board: UUID?
}

/// What the page shows.
struct KeptShelf: Equatable {
    var removed: [RemovedCopy] = []
    var groups: [VersionGroup] = []
    /// Removed boards that are still on their way from iCloud.
    var waiting = 0
}

/// The finished export, ready for the system's save place.
struct ExportFile {
    var data: Data
    /// "Seedboard boards 2026-11-18" (the system adds ".zip").
    var name: String
    var boards: Int
}

extension AppModel {
    // MARK: Launch options (for pictures and the screen test)

    /// `-removed` opens the page over the main window (on the Mac as a sheet on the main window);
    /// `-clash` shows the clash line for the first board.
    func bringBackLaunch() {
        if LaunchOptions.arguments.contains("-clash"), let board = boards.first {
            clash = ClashNotice(id: board.id, title: board.title)
        }
        if LaunchOptions.arguments.contains("-removed") {
            // With `-removed <word>` the page opens at the board whose name holds the word.
            let word = LaunchOptions.value(for: "-removed").flatMap { $0.hasPrefix("-") ? nil : $0 }
            let focus = word.flatMap { w in boards.first { $0.title.localizedCaseInsensitiveContains(w) }?.id }
            keptPage = KeptPageAsk(board: focus)
        }
    }

    // MARK: What is kept

    /// Everything that can be brought back, read fresh from the folders (made-up with the example boards).
    func keptShelf() async -> KeptShelf {
        let listing: KeptListing
        if LaunchOptions.sampleData {
            listing = SampleKept.shared.listing(boards: boards)
        } else {
            listing = await store.kept { KeptFiles.list($0) } ?? KeptListing()
        }
        let present = Set(boards.map(\.id))
        let removed = KeptRules.removedRows(listing.removed, present: present)
        return KeptShelf(removed: removed,
                         groups: KeptRules.groups(versions: listing.versions, boards: boards, removed: removed, marked: listing.marked),
                         waiting: listing.waiting)
    }

    /// Brings a removed board back under its SAME identity (links from PARAGON's notes keep working),
    /// stamped as changed now, its removal marks cleared so it returns on every device.
    /// It joins the list; it is not opened. nil when no copy of it is left.
    func bringBack(removed id: UUID) async -> Board? {
        let back: Board?
        if LaunchOptions.sampleData {
            back = SampleKept.shared.bringBack(id)
        } else {
            back = await store.bringBack(id: id)
        }
        guard let board = back else { return nil }
        // Into the list, and once more through the store, so iCloud has it whatever lay there before.
        write(board)
        if removedLink?.id == id { removedLink = nil }
        return board
    }

    /// Deletes that board's removed copies, on the device and in iCloud. This cannot be undone.
    func removeForGood(_ id: UUID) async {
        if LaunchOptions.sampleData {
            SampleKept.shared.removeForGood(id)
        } else {
            _ = await store.kept { KeptFiles.removeForGood(id, in: $0.removed) }
        }
    }

    /// Opens an earlier version as a NEW board, "Title (version from 18 Nov 10:00)". The board it is a
    /// version of is left as it is. nil (and a reason) when the copy cannot be used.
    func openAsCopy(_ version: EarlierVersion) async -> (board: Board?, problem: String?) {
        let read: Board?
        if LaunchOptions.sampleData {
            read = SampleKept.shared.board(of: version)
        } else {
            read = await store.kept { KeptFiles.read(version, in: $0) } ?? nil
        }
        guard let old = read else { return (nil, "That version could not be read any more.") }
        guard old.canBeChanged else { return (nil, "That version was made by a newer Seedboard. Update the app to open it.") }
        let copy = KeptRules.asCopy(old, now: Date(), taken: Set(boards.map(\.title)))
        write(copy)
        open(copy.id)
        return (copy, nil)
    }

    // MARK: Export and import

    /// Every board as its `.seedboard` file plus a plain-text outline, in ONE zip file. nil when it could not be made.
    func exportAllBoards() async -> ExportFile? {
        // What is being typed belongs in the export too.
        session?.commitEdit()
        saveNow()
        let now = Date()
        let store = self.store
        let files = ExportRules.files(boards, bytes: { store.bytes(of: $0) }, now: now)
        guard !files.isEmpty else { return nil }
        let name = ExportRules.archiveName(now)
        let count = files.count / 2
        return await Task.detached(priority: .userInitiated) { () -> ExportFile? in
            // Made in a throwaway folder of the app's own; nothing of it stays behind.
            let place = FileManager.default.temporaryDirectory.appendingPathComponent("SeedboardExport-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: place) }
            guard let zip = try? BoardArchive.make(name: name, files: files, in: place),
                  let data = try? Data(contentsOf: zip) else { return nil }
            return ExportFile(data: data, name: name, boards: count)
        }.value
    }

    /// Boards from `.seedboard` files (the ones inside an export) come in as NEW boards; none is replaced.
    /// Gives back plain words about what happened.
    func importBoards(_ files: [URL]) -> String {
        var made = 0
        var skipped = 0
        for file in files {
            let allowed = file.startAccessingSecurityScopedResource()
            defer { if allowed { file.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: file), ExportRules.looksLikeBoard(data),
                  let board = store.board(from: data), board.canBeChanged else {
                skipped += 1
                continue
            }
            write(ExportRules.imported(board, taken: Set(boards.map(\.title)), now: Date()))
            made += 1
        }
        var words: [String] = []
        if made > 0 { words.append(made == 1 ? "1 board came in as a new board." : "\(made) boards came in as new boards.") }
        if skipped > 0 { words.append(skipped == 1 ? "1 file was not a board this Seedboard can read." : "\(skipped) files were not boards this Seedboard can read.") }
        return words.isEmpty ? "Nothing was chosen." : words.joined(separator: " ")
    }
}
