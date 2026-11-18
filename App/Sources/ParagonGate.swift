import Foundation
import SeedboardCore

// The way into PARAGON. Two rules keep the owner's notes safe:
//  1. Seedboard only ever ADDS files to the PARAGON folder (a new note, a new picture).
//     It never opens, changes or replaces a file that is already there. The one file it may take
//     away again is a picture it made itself a moment ago, when the note that needs it could not be written.
//  2. Lines for the Inbox are not written into Inbox.md. They go into the waiting list that
//     PARAGON's own Share button uses, and PARAGON files them itself the next time it opens.

enum SendKind: String, CaseIterable, Identifiable {
    case note, project, todos
    var id: String { rawValue }
}

struct ParagonPlace {
    /// PARAGON's notes folder.
    var vault: URL
    /// PARAGON's waiting list for the Inbox; nil when this device cannot reach it.
    var outbox: URL?
}

struct SendResult {
    var info: SentInfo?
    var todos: [UUID]
    var message: String
}

enum SendProblem: LocalizedError {
    case notFound
    case nothingToSend
    case noInbox
    case cannotWrite(String)
    /// The note could not be written, and the picture made for it could not be taken away again.
    case pictureLeft(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "PARAGON's notes were not found on this device."
        case .nothingToSend: return "No to-do boxes are waiting to be sent."
        case .noInbox: return "This device cannot reach PARAGON's Inbox. Send the board as a note or a project instead."
        case .cannotWrite(let what): return "The \(what) could not be saved in PARAGON's folder. Nothing was changed."
        case .pictureLeft(let name): return "The note could not be saved in PARAGON's folder. Its picture “\(name)” is left in PARAGON's Pictures folder; no note uses it."
        }
    }
}

enum ParagonGate {
    static let container = "iCloud.com.schabbauer.AMSPara"
    #if os(macOS)
    static let group = "D24ENP83QQ.group.com.schabbauer.amspara"
    #else
    static let group = "group.com.schabbauer.amspara"
    #endif

    /// Looks for PARAGON's notes. Slow the first time: call it off the main thread.
    /// Called when the app starts, on Settings → Check again, and again at EVERY Send.
    static func find() -> ParagonPlace? {
        let fm = FileManager.default
        #if DEBUG
        // For trying the hand-over on a throwaway folder: `-paragonFolder <path>`.
        if let path = LaunchOptions.value(for: "-paragonFolder") {
            let vault = URL(fileURLWithPath: path, isDirectory: true)
            guard isVault(vault, alsoBareProjects: true) else { return nil }
            return ParagonPlace(vault: vault, outbox: vault.appendingPathComponent(".seedboard-test-outbox/capture-outbox.jsonl"))
        }
        #endif
        if LaunchOptions.sampleData { return nil }
        // No iCloud folder means no PARAGON here; the shared Inbox list is not even asked for.
        guard let root = fm.url(forUbiquityContainerIdentifier: container) else { return nil }
        let vault = root.appendingPathComponent("Documents", isDirectory: true)
        guard isVault(vault) else { return nil }
        let outbox = fm.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("capture-outbox.jsonl")
        return ParagonPlace(vault: vault, outbox: outbox)
    }

    /// A PARAGON folder IN USE has its Inbox note or PARAGON's own settings file (`.ams-para/config.json`).
    /// A folder with only a `Projects` folder is not taken (it can be one PARAGON never used), except for
    /// the throwaway test folder of debug builds.
    private static func isVault(_ url: URL, alsoBareProjects: Bool = false) -> Bool {
        let fm = FileManager.default
        var names = Set((try? fm.contentsOfDirectory(atPath: url.path)) ?? [])
        for file in (try? fm.contentsOfDirectory(atPath: url.appendingPathComponent(".ams-para").path)) ?? [] {
            names.insert(".ams-para/" + file)
        }
        if ParagonExport.looksLikeParagonFolder(names) { return true }
        var isDir: ObjCBool = false
        return alsoBareProjects && fm.fileExists(atPath: url.appendingPathComponent("Projects").path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Every note title in the folder, in small letters, so a new note never takes a used name.
    private static func titles(in vault: URL) -> Set<String> {
        var found: Set<String> = []
        guard let walker = FileManager.default.enumerator(at: vault, includingPropertiesForKeys: nil,
                                                          options: [.skipsPackageDescendants]) else { return found }
        for case let url as URL in walker {
            var name = url.lastPathComponent
            // A file iCloud has not fetched yet is listed as ".Name.md.icloud".
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(7))
            } else if name.hasPrefix(".") {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { walker.skipDescendants() }
                continue
            }
            if name.lowercased().hasSuffix(".md") { found.insert(String(name.dropLast(3)).lowercased()) }
        }
        return found
    }

    /// Saves a NEW file. Fails rather than replace anything.
    private static func writeNew(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var failure: Error?
        var coordinatorError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinatorError) { target in
            do {
                try data.write(to: target, options: .withoutOverwriting)
            } catch {
                failure = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let failure { throw failure }
    }

    /// Takes away a file this very hand-over made a moment ago (never any other file). True when it is gone.
    private static func removeJustMade(_ url: URL) -> Bool {
        var gone = false
        var coordinatorError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { target in
            gone = (try? FileManager.default.removeItem(at: target)) != nil
        }
        return gone || !FileManager.default.fileExists(atPath: url.path)
    }

    /// Hands a board over. Runs off the main thread.
    static func send(board: Board, kind: SendKind, title wanted: String, png: Data?, place: ParagonPlace, now: Date = Date()) throws -> SendResult {
        switch kind {
        case .todos:
            let tasks = ParagonExport.inboxTasks(board: board)
            guard !tasks.isEmpty else { throw SendProblem.nothingToSend }
            guard let outbox = place.outbox else { throw SendProblem.noInbox }
            // All of them in one write: either every task is on its way, or none is.
            do { try append(ParagonExport.taskLines(tasks, now: now), to: outbox) } catch { throw SendProblem.noInbox }
            let count = tasks.count == 1 ? "1 task is" : "\(tasks.count) tasks are"
            return SendResult(info: nil, todos: tasks.map(\.id), message: "\(count) on the way to the PARAGON Inbox. They show the next time PARAGON opens.")

        case .note, .project:
            let clean = ParagonExport.noteTitle(for: wanted.isEmpty ? board.title : wanted)
            let title = ParagonExport.freeTitle(clean, taken: titles(in: place.vault))
            let folder = kind == .project ? "Projects" : "Resources"
            let noteURL = place.vault.appendingPathComponent(folder).appendingPathComponent(title + ".md")
            guard !FileManager.default.fileExists(atPath: noteURL.path) else { throw SendProblem.cannotWrite("note") }

            // The picture first: a note must never point at a picture that is not there.
            var picture: String?
            var pictureURL: URL?
            if let png {
                var name = ParagonExport.pictureName(for: board.title, now: now)
                var url = place.vault.appendingPathComponent("Pictures").appendingPathComponent(name)
                var n = 1
                while FileManager.default.fileExists(atPath: url.path), n < 50 {
                    n += 1
                    name = name.replacingOccurrences(of: ".png", with: " b\(n).png")
                    url = place.vault.appendingPathComponent("Pictures").appendingPathComponent(name)
                }
                do {
                    try writeNew(png, to: url)
                    picture = name
                    pictureURL = url
                } catch {
                    throw SendProblem.cannotWrite("picture")
                }
            }

            let text = kind == .project
                ? ParagonExport.project(board: board, title: title, picture: picture, now: now)
                : ParagonExport.note(board: board, title: title, picture: picture, now: now)
            do {
                try writeNew(Data(text.utf8), to: noteURL)
            } catch {
                // The note is not there, so its picture must not stay behind: the file made a moment ago
                // (only that one) is taken away again, and the message says what is true.
                if let pictureURL, let picture, !removeJustMade(pictureURL) { throw SendProblem.pictureLeft(picture) }
                throw SendProblem.cannotWrite("note")
            }

            // A note also gets one line in the Inbox that points to it, so it can be filed from there.
            var inInbox = false
            if kind == .note, let outbox = place.outbox {
                inInbox = (try? append([ParagonExport.noteLine(title: title, now: now)], to: outbox)) != nil
            }
            let info = SentInfo(when: now, kind: kind.rawValue, title: title, path: "\(folder)/\(title).md")
            let todos = board.items.filter(\.todo).map(\.id)
            let where_ = kind == .project ? "Projects" : (inInbox ? "Resources, with a line in the Inbox" : "Resources")
            return SendResult(info: info, todos: todos, message: "“\(title)” is in PARAGON under \(where_).")
        }
    }

    // MARK: PARAGON's waiting list

    /// The lines are made in SeedboardCore (`ParagonExport.WaitingLine`), exactly the way PARAGON's own
    /// Share button writes them; a test there reads them with a copy of PARAGON's reader.
    private static func append(_ lines: [ParagonExport.WaitingLine], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try ParagonExport.waitingData(lines)
        // Added at the end in one step, so PARAGON and Seedboard can never write into each other.
        let fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { throw SendProblem.noInbox }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
    }
}
