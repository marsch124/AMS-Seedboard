import Foundation

// 0.11, the PARAGON lane: picks 5 (the real cause of a Send problem), 26 (waiting for PARAGON), 27 (send only the
// chosen things) and 40 (Copy as email). Rules only; the app draws them.

// MARK: 5 — the real cause of a Send problem

/// Why a write into PARAGON's folder failed, in the owner's words (`SendCause.words`).
public enum SendCause: Equatable, Sendable {
    case diskFull
    case locked
    case inUse
    case folderMissing
    case iCloudFull
    case iCloudUnavailable
    case other(String)

    private static let posixFull: Set<Int> = [28, 69]            // ENOSPC, EDQUOT
    private static let posixLocked: Set<Int> = [1, 13, 30]       // EPERM, EACCES, EROFS
    private static let posixBusy: Set<Int> = [16, 26, 11, 35]    // EBUSY, ETXTBSY, EAGAIN (Linux, Mac)
    private static let posixMissing: Set<Int> = [2, 20]          // ENOENT, ENOTDIR
    private static let cocoaFull = 640, cocoaLocked: Set<Int> = [513, 642], cocoaMissing: Set<Int> = [4, 260, 2]
    private static let cocoaQuota = 4354, cocoaICloud: Set<Int> = [4353, 4355, 4352]

    /// Looks at the error and the one under it.
    public static func classify(_ error: Error) -> SendCause {
        var current: NSError? = error as NSError
        var depth = 0
        while let ns = current, depth < 4 {
            let code = ns.code
            if ns.domain == NSPOSIXErrorDomain {
                if posixFull.contains(code) { return .diskFull }
                if posixLocked.contains(code) { return .locked }
                if posixBusy.contains(code) { return .inUse }
                if posixMissing.contains(code) { return .folderMissing }
            } else if ns.domain == NSCocoaErrorDomain {
                if code == cocoaFull { return .diskFull }
                if code == cocoaQuota { return .iCloudFull }
                if cocoaICloud.contains(code) { return .iCloudUnavailable }
                if cocoaLocked.contains(code) { return .locked }
                if cocoaMissing.contains(code) { return .folderMissing }
            }
            current = ns.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return .other((error as NSError).localizedDescription)
    }

    /// The whole message. `what`: "the Inbox", "the note", "the picture".
    public static func words(_ cause: SendCause, what: String) -> String {
        let head = what.prefix(1).uppercased() + what.dropFirst()
        switch cause {
        case .diskFull:
            return "\(head) could not be saved: the disk is full. Free some space, then send again. Nothing was changed."
        case .locked:
            return "\(head) could not be saved: PARAGON's folder is locked or only readable here. Nothing was changed."
        case .inUse:
            return "\(head) could not be saved: the file is in use by another app. Wait a moment, then send again. Nothing was changed."
        case .folderMissing:
            return "\(head) could not be saved: PARAGON's folder is missing. Open PARAGON once, then check again in Settings. Nothing was changed."
        case .iCloudFull:
            return "\(head) could not be saved: iCloud has no room left. Nothing was changed."
        case .iCloudUnavailable:
            return "\(head) could not be saved: iCloud is off or cannot be reached right now. Nothing was changed."
        case .other(let why):
            return "\(head) could not be saved (\(why)). Nothing was changed."
        }
    }

    public static func words(for error: Error, what: String) -> String { words(classify(error), what: what) }

    /// The Inbox cannot be reached at all (PARAGON's shared folder is not on this device).
    public static let inboxFolderMissing = "PARAGON's Inbox folder is missing on this device. Open PARAGON once, then check again in Settings. A note or a project can still be sent."
}

// MARK: 26 — waiting for PARAGON

/// How things that went to the Inbox stand: derived from what the board keeps (`sentTasks`, `sent.when`, else the
/// day the board last changed, which Send itself sets) and what the read-back saw. Nothing new is stored.
public enum InboxWait {
    public enum State: Equatable, Sendable { case waiting, filed, late }

    /// After this long without being seen filed: "not filed yet".
    public static let lateAfter: TimeInterval = 86_400

    /// nil: the thing did not go to the Inbox. `seen`: what the read-back found (thing → how it stands there).
    public static func state(of id: UUID, in board: Board, seen: [UUID: TodoState], now: Date = Date()) -> State? {
        guard let task = board.sentTask(id), task.place == SentTask.inbox else { return nil }
        if seen[id] != nil { return .filed }
        let since = board.sent?.when ?? board.changed
        return now.timeIntervalSince(since) >= lateAfter ? .late : .waiting
    }

    /// The small line: "2 waiting for PARAGON", "1 in PARAGON", "1 not filed yet — open PARAGON"; nil when nothing went to the Inbox.
    public static func line(for board: Board, seen: [UUID: TodoState], now: Date = Date()) -> String? {
        let here = Set(board.items.map(\.id))
        var waiting = 0, filed = 0, late = 0
        for task in board.sentTasks where here.contains(task.id) {
            switch state(of: task.id, in: board, seen: seen, now: now) {
            case .waiting: waiting += 1
            case .filed: filed += 1
            case .late: late += 1
            case nil: break
            }
        }
        var parts: [String] = []
        if late > 0 { parts.append(late == 1 ? "1 not filed yet — open PARAGON" : "\(late) not filed yet — open PARAGON") }
        if waiting > 0 { parts.append("\(waiting) waiting for PARAGON") }
        if filed > 0 { parts.append("\(filed) in PARAGON") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: 27 — only the chosen things

public extension Board {
    /// A board that holds just the chosen things (an idea with everything under it) and the arrows between them, for
    /// sending them alone. Keeps the board's identity and name and the ticks already sent; carries no "sent" mark. An
    /// idea whose parent is not chosen becomes the middle of a small map. nil: nothing chosen can be sent.
    func chosenOnly(_ ids: Set<UUID>) -> Board? {
        var keep = ids.filter { item($0) != nil }
        for id in keep where item(id)?.kind == .idea { keep.formUnion(descendants(of: id)) }
        keep = keep.filter { id in
            guard let i = item(id) else { return false }
            return i.unknownKind == nil && !i.kind.isTimeline && !i.kind.isSequence
        }
        guard !keep.isEmpty else { return nil }
        var part = self
        part.sent = nil
        if sent != nil {
            for id in sentTodos where keep.contains(id) && sentTask(id) == nil {
                part.sentTasks.append(SentTask(id: id, words: "", place: SentTask.note))
            }
        }
        part.items = items.filter { keep.contains($0.id) }
        part.links = links.filter { keep.contains($0.from) && keep.contains($0.to) }
        for n in part.items.indices {
            guard let parent = part.items[n].parent, !keep.contains(parent) else { continue }
            let colour = branchColour(of: part.items[n].id)
            part.items[n].parent = nil
            part.items[n].side = nil
            part.items[n].bothSides = false
            if part.items[n].colour.isEmpty { part.items[n].colour = colour }
        }
        part.layoutMaps()
        return part
    }

    /// The words on the Send page: "The 3 chosen things".
    static func chosenWords(_ count: Int) -> String { "The \(count) chosen things" }

    /// 40 — the outline as an email to paste into Mail: a short first line, the outline, "Made with Seedboard".
    var emailText: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = name.isEmpty ? "Here is my board:" : "Here is my board “\(name)”:"
        let body = outlineText
        return head + "\n\n" + (body.isEmpty ? "(empty)\n\n" : body + "\n\n") + "Made with Seedboard"
    }
}
