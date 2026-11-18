import Foundation

// "Export all boards": every board as its .seedboard file plus a plain-text outline, in ONE zip file.
// The names and the words are plain rules; `BoardArchive` makes the zip with what the system offers.

public enum ExportRules {
    /// "Seedboard boards 2026-11-18" — the name of the folder inside the zip and of the zip itself (plus ".zip").
    public static func archiveName(_ now: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        return "Seedboard boards \(f.string(from: now))"
    }

    /// A file name (without ending) for every board: its title with the characters a file name may not
    /// hold replaced; two boards never get the same name ("Title", "Title (2)"), whatever the capitals.
    public static func fileNames(_ boards: [Board]) -> [UUID: String] {
        var used = Set<String>()
        var names: [UUID: String] = [:]
        for board in boards {
            let base = ParagonExport.noteTitle(for: board.title)
            var name = base
            var n = 2
            while used.contains(name.lowercased()) {
                name = "\(base) (\(n))"
                n += 1
            }
            used.insert(name.lowercased())
            names[board.id] = name
        }
        return names
    }

    /// The board as plain text for reading without the app: its name, a line of facts, the outline
    /// (maps, flow, notes, loose shapes) and the things marked "to do".
    public static func outline(of board: Board, now: Date, timeZone: TimeZone = .current) -> String {
        var out = "# \(board.title)\n\n"
        out += "\(board.countLine) · last changed \(KeptRules.dayTime(board.changed, now: now, timeZone: timeZone))"
        out += " · exported from Seedboard on \(KeptRules.day(now, now: now, timeZone: timeZone))\n"
        let words = board.outlineText
        if !words.isEmpty { out += "\n\(words)\n" }
        let todo = board.items.filter { $0.todo && !ParagonExport.oneLine($0.text).isEmpty }
            .map { "- [ ] \(ParagonExport.oneLine($0.text))" }
        if !todo.isEmpty { out += "\nTo do:\n\(todo.joined(separator: "\n"))\n" }
        return out
    }

    /// The files of the export: for every board `<name>.seedboard` (its bytes as given) and `<name>.md`.
    /// A board whose bytes are missing is left out.
    public static func files(_ boards: [Board], bytes: (Board) -> Data?, now: Date,
                             timeZone: TimeZone = .current) -> [(name: String, data: Data)] {
        let names = fileNames(boards)
        var out: [(name: String, data: Data)] = []
        for board in boards {
            guard let name = names[board.id], let data = bytes(board) else { continue }
            out.append(("\(name).seedboard", data))
            out.append(("\(name).md", Data(outline(of: board, now: now, timeZone: timeZone).utf8)))
        }
        return out
    }

    // MARK: Starters and pictures (0.5)

    /// The folder inside the zip that holds the starters.
    public static let starterFolder = "Starters"

    /// The starters an export packs: every own starter and every built-in whose board was changed, not the
    /// removed ones, each as an ordinary board that carries the starter's name. (Import brings it in as a board;
    /// "Save as a starter…" makes it a starter again.)
    public static func starterBoards(_ entries: [StarterEntry]) -> [Board] {
        entries.filter { !$0.removed && $0.board != nil }
            .sorted { ($0.order, $0.id) < ($1.order, $1.id) }
            .compactMap { entry in
                var board = entry.board
                board?.title = entry.name
                return board
            }
    }

    /// The starters' files: `Starters/<name>.seedboard` for each. One whose bytes are missing is left out.
    public static func starterFiles(_ entries: [StarterEntry], bytes: (Board) -> Data?) -> [(name: String, data: Data)] {
        let boards = starterBoards(entries)
        let names = fileNames(boards)
        return boards.compactMap { board in
            guard let name = names[board.id], let data = bytes(board) else { return nil }
            return ("\(starterFolder)/\(name).seedboard", data)
        }
    }

    /// The names of every picture file the export packs: what the boards show AND what the starters show.
    public static func pictureNames(boards: [Board], starters: [StarterEntry]) -> [String] {
        var names = Set(boards.flatMap(\.pictureNames))
        for board in starterBoards(starters) { names.formUnion(board.pictureNames) }
        return names.sorted()
    }

    /// What was packed, and what could not be: "Exported 14 boards and 31 pictures. 3 pictures are not on this
    /// device yet and are not in the file."
    public static func summary(boards: Int, starters: Int = 0, pictures: Int, missing: Int) -> String {
        var parts = [boards == 1 ? "1 board" : "\(boards) boards"]
        if starters > 0 { parts.append(starters == 1 ? "1 starter" : "\(starters) starters") }
        if pictures > 0 { parts.append(pictures == 1 ? "1 picture" : "\(pictures) pictures") }
        let last = parts.removeLast()
        var line = "Exported " + (parts.isEmpty ? last : parts.joined(separator: ", ") + " and " + last) + "."
        if missing == 1 { line += " 1 picture is not on this device yet and is not in the file." }
        if missing > 1 { line += " \(missing) pictures are not on this device yet and are not in the file." }
        return line
    }

    /// "Last export: 18 Nov" — or that there was none yet.
    public static func lastExportLine(_ last: Date?, now: Date, timeZone: TimeZone = .current) -> String {
        guard let last else { return "No export yet." }
        return "Last export: \(KeptRules.day(last, now: now, timeZone: timeZone))"
    }

    // MARK: Coming in again

    /// True when the bytes are a board's file (and not any other file that happens to hold an "id").
    public static func looksLikeBoard(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return object["id"] is String && object["items"] is [Any] && object["title"] is String
    }

    /// A board read from an exported file comes in as a NEW board: its own identity, never a name that
    /// is taken ("Title (imported)", "Title (imported 2)"), changed now, not pinned, not sent anywhere.
    public static func imported(_ board: Board, taken: Set<String>, now: Date = Date()) -> Board {
        var new = board
        new.id = UUID()
        let used = Set(taken.map { $0.lowercased() })
        var name = board.title
        var n = 1
        while used.contains(name.lowercased()) {
            name = n == 1 ? "\(board.title) (imported)" : "\(board.title) (imported \(n))"
            n += 1
        }
        new.title = name
        new.changed = now
        new.pinned = false
        new.sent = nil
        new.sentTodos = []
        return new
    }
}

/// Makes ONE zip file out of a handful of files, with what the system offers (no other code, no Terminal).
public enum BoardArchive {
    public enum Problem: Error { case folder, zip }

    /// Writes `files` into a new folder `name` inside `place`, has the system zip that folder, and
    /// gives back `place/<name>.zip`. The folder itself is cleared away again.
    public static func make(name: String, files: [(name: String, data: Data)], in place: URL) throws -> URL {
        let fm = FileManager.default
        let folder = place.appendingPathComponent(name, isDirectory: true)
        let target = place.appendingPathComponent("\(name).zip")
        try? fm.removeItem(at: folder)
        try? fm.removeItem(at: target)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in files {
                let target = folder.appendingPathComponent(file.name)
                // A name with a folder in front ("Starters/…") gets that folder.
                if file.name.contains("/") { try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true) }
                try file.data.write(to: target, options: .atomic)
            }
        } catch {
            throw Problem.folder
        }
        defer { try? fm.removeItem(at: folder) }
        var problem: NSError?
        var made = false
        // Reading a FOLDER "for uploading" hands over a zip of it, which is there only inside this block.
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &problem) { zipped in
            made = (try? fm.copyItem(at: zipped, to: target)) != nil
        }
        guard made, problem == nil else { throw Problem.zip }
        return target
    }
}
