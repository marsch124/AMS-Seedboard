import Foundation
import SeedboardCore

// 0.5, pick 16: looking at the note a board became. READING ONLY: nothing in here writes, moves, renames
// or removes anything in PARAGON's folder. The one thing it may ask for is that iCloud brings a note that
// is not on this device yet. What the note says is worked out in SeedboardCore (`ParagonRead`).

extension ParagonGate {
    /// What looking for a board's note gave.
    enum EchoLook {
        /// The note, where it is now inside PARAGON's folder, under the title it has now, and what it says.
        case found(path: String, title: String, reading: ParagonRead.Reading)
        /// iCloud has not brought the note (or a part of the folder it may be in) to this device yet.
        case notHereYet
        /// Every note on this device was looked through: none holds the board's link.
        case gone
    }

    private enum Read {
        case text(String)
        case notHere
        case nothing
    }

    /// Looks for the note `board` became: first where it was found last time, then where Seedboard wrote it
    /// (`SentInfo.path`); a note there counts when it holds the board's own link `seedboard://board/<id>`.
    /// If it is at neither place — renamed, or moved to the Archive — and `walk` is true, every note in
    /// PARAGON's folder is looked through for that link. nil: it is at neither place and no walk was asked for.
    /// Runs off the main thread.
    static func look(for board: Board, sent: SentInfo, lastFound: String?, walk: Bool, place: ParagonPlace) -> EchoLook? {
        var waiting = false
        // A note that stands where Seedboard wrote it but no longer holds the link (the line was taken out).
        var plain: (path: String, text: String)?
        var asked = Set<String>()
        for path in [lastFound, sent.path].compactMap({ $0 }) where asked.insert(path).inserted {
            switch read(path, in: place.vault) {
            case .text(let text):
                if ParagonRead.holdsLink(text, to: board.id) { return found(path, text, board, sent) }
                if path == sent.path { plain = (path, text) }
            case .notHere: waiting = true
            case .nothing: break
            }
        }
        if waiting { return .notHereYet }
        guard walk else { return plain.map { found($0.path, $0.text, board, sent) } }

        // Through every note that is on this device. The best one: most of the board's tasks, then the newest.
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey, .fileSizeKey, .contentModificationDateKey]
        guard let walker = fm.enumerator(at: place.vault, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants]) else {
            return plain.map { found($0.path, $0.text, board, sent) } ?? .notHereYet
        }
        let link = Data(ParagonExport.boardLink(board.id).utf8)
        let depth = place.vault.pathComponents.count
        var best: (path: String, text: String, tasks: Int, changed: Date)?
        var skipped = false
        for case let url as URL in walker {
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: Set(keys))
            if name.hasPrefix(".") {
                // A note iCloud has not fetched is listed as ".Name.md.icloud"; PARAGON's own folders (settings,
                // safety copies, Deleted) are hidden and are not notes.
                if name.lowercased().hasSuffix(".md.icloud") { skipped = true }
                if values?.isDirectory == true { walker.skipDescendants() }
                continue
            }
            if values?.isDirectory == true {
                if name == "Pictures", url.pathComponents.count == depth + 1 { walker.skipDescendants() }
                continue
            }
            guard name.lowercased().hasSuffix(".md") else { continue }
            // Never make iCloud fetch the whole folder: a note that is not here is passed over.
            if values?.ubiquitousItemDownloadingStatus == .notDownloaded {
                skipped = true
                continue
            }
            guard (values?.fileSize ?? 0) <= 2_000_000, let data = try? Data(contentsOf: url), data.range(of: link) != nil,
                  let text = String(data: data, encoding: .utf8) else { continue }
            let tasks = ParagonRead.reading(board: board, note: text, kind: sent.kind).states.count
            let changed = values?.contentModificationDate ?? .distantPast
            if let now = best, (now.tasks, now.changed) >= (tasks, changed) { continue }
            best = (url.pathComponents.dropFirst(depth).joined(separator: "/"), text, tasks, changed)
        }
        if let best { return found(best.path, best.text, board, sent) }
        if let plain { return found(plain.path, plain.text, board, sent) }
        return skipped ? .notHereYet : .gone
    }

    private static func found(_ path: String, _ text: String, _ board: Board, _ sent: SentInfo) -> EchoLook {
        .found(path: path, title: ParagonRead.title(of: text, fileName: (path as NSString).lastPathComponent),
               reading: ParagonRead.reading(board: board, note: text, kind: sent.kind))
    }

    /// Reads one note by its place inside PARAGON's folder. Never writes.
    private static func read(_ path: String, in vault: URL) -> Read {
        // Only ever a place inside PARAGON's folder.
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return .nothing }
        let fm = FileManager.default
        let url = vault.appendingPathComponent(path)
        if fm.fileExists(atPath: url.path) {
            let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
            if status == .notDownloaded {
                try? fm.startDownloadingUbiquitousItem(at: url)
                return .notHere
            }
            guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return .nothing }
            return .text(text)
        }
        // On older systems a note iCloud has not fetched stands there as ".Name.md.icloud".
        let stub = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        guard fm.fileExists(atPath: stub.path) else { return .nothing }
        try? fm.startDownloadingUbiquitousItem(at: url)
        return .notHere
    }
}
