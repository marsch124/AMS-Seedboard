import Foundation
import SeedboardCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Where the boards are kept: ONE FILE PER BOARD, `<uuid>.seedboard`, in the app's iCloud Drive folder
/// (Documents/Boards) so Mac, iPad and iPhone share them. A copy on the device itself opens at once and still
/// works without iCloud.
///
/// The rules that keep the boards safe:
/// - for the same board, the newer change wins; a losing version that differs is kept in SafetyCopies;
/// - a version iCloud parked because two devices wrote at once is joined in, never dropped;
/// - a file from a newer version of the app is never written over;
/// - a cloud file that cannot be read is never written over;
/// - a removed board moves to a Removed folder (30 days) and is never deleted outright;
/// - once a day a safety copy of all boards is kept on the device, 14 days back.
@MainActor
final class BoardStore {
    private let sample: Bool
    private let disk = BoardDisk()
    private var memory: [UUID: Board] = [:]
    /// The `changed` of each board this store has seen, so only real news is passed on.
    private var known: [UUID: Date] = [:]
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var checking = false

    var onCloudChange: (([Board]) -> Void)?
    /// Boards another device removed: they left this device's list too.
    var onCloudGone: ((Set<UUID>) -> Void)?

    init(sample: Bool) {
        self.sample = sample
    }

    /// False when iCloud Drive is not available (not signed in, or switched off).
    var cloudIsOn: Bool {
        !sample && FileManager.default.ubiquityIdentityToken != nil
    }

    /// The device's copies and iCloud's files made into one list. For the same id the newer `changed` wins.
    func loadAll() async -> [Board] {
        if sample { return Array(memory.values).sorted { $0.changed > $1.changed } }
        let disk = self.disk
        let found = await Task.detached(priority: .userInitiated) { disk.loadAll() }.value
        for board in found.boards { known[board.id] = board.changed }
        for id in found.gone { known[id] = nil }
        startWatching()
        return found.boards
    }

    /// Writes the device copy at once, the iCloud copy off the main thread.
    func save(_ board: Board) {
        known[board.id] = board.changed
        if sample { memory[board.id] = board; return }
        // One after the other on the store's own line of work, so the main thread never waits for a file
        // and a later change is never written before an earlier one.
        disk.save(board) { [weak self] newer in
            // iCloud held a newer version: it was kept, and mine went to the safety copies.
            Task { @MainActor in self?.tell([newer]) }
        }
    }

    /// Waits (at most two seconds) until everything handed to `save` is on the device.
    /// Called when the app is left, so nothing typed is lost.
    func flush() {
        guard !sample else { return }
        disk.flush()
    }

    /// Moves both copies into the Removed folder (kept 30 days). Never deletes outright.
    func remove(id: UUID) {
        known[id] = nil
        if sample { memory[id] = nil; return }
        disk.remove(id: id)
    }

    /// Plain words for Settings, e.g. "12 boards · last safety copy today 08:10".
    func safetyLine() -> String {
        let count = sample ? memory.count : known.count
        let boards = count == 1 ? "1 board" : "\(count) boards"
        if sample { return "\(boards) · example boards, nothing is saved" }
        let cloud = cloudIsOn ? "" : " · iCloud is off: the boards are on this device only"
        guard let when = disk.lastSafetyCopy() else { return "\(boards) · no safety copy yet\(cloud)" }
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        let day: String
        if Calendar.current.isDateInToday(when) {
            day = "today"
        } else if Calendar.current.isDateInYesterday(when) {
            day = "yesterday"
        } else {
            let d = DateFormatter()
            d.dateFormat = "d MMM"
            day = d.string(from: when)
        }
        return "\(boards) · last safety copy \(day) \(time.string(from: when))\(cloud)"
    }

    // MARK: Watching iCloud

    private func tell(_ boards: [Board]) {
        for board in boards { known[board.id] = board.changed }
        onCloudChange?(boards)
    }

    private func startWatching() {
        guard query == nil, cloudIsOn else { return }
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K LIKE '*.seedboard'", NSMetadataItemFSNameKey)
        let center = NotificationCenter.default
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(center.addObserver(forName: name, object: q, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.checkCloud() }
            })
        }
        #if os(macOS)
        let active = NSApplication.didBecomeActiveNotification
        #else
        let active = UIApplication.didBecomeActiveNotification
        #endif
        observers.append(center.addObserver(forName: active, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.checkCloud() }
        })
        query = q
        q.start()
    }

    /// Looks at iCloud; whatever is newer than what this store has seen goes to `onCloudChange`.
    private func checkCloud() {
        guard !checking, !sample else { return }
        checking = true
        let disk = self.disk
        let seen = known
        Task.detached(priority: .utility) { [weak self] in
            let found = disk.loadAll()
            let news = found.boards.filter { board in
                guard let before = seen[board.id] else { return true }
                return board.changed > before
            }
            await self?.finishedCheck(news, gone: found.gone)
        }
    }

    private func finishedCheck(_ news: [Board], gone: Set<UUID>) {
        checking = false
        let left = gone.filter { known[$0] != nil }
        if !left.isEmpty {
            for id in left { known[id] = nil }
            onCloudGone?(left)
        }
        // `known` may have moved on while the check ran: pass on only what is still news.
        let fresh = news.filter { board in
            guard let now = known[board.id] else { return true }
            return board.changed > now
        }
        guard !fresh.isEmpty else { return }
        tell(fresh)
    }
}

// MARK: - The files

/// Everything that touches files. Safe to call from any thread: one queue runs it one at a time.
private final class BoardDisk: @unchecked Sendable {
    static let container = "iCloud.com.schabbauer.AMSSeedboard"
    static let keepSafetyDays = 14
    static let keepRemovedDays: Double = 30

    private let queue = DispatchQueue(label: "com.schabbauer.AMSSeedboard.store")
    private var cloudRoot: URL?
    private var cloudAsked = Date.distantPast

    private enum Read {
        /// No file there.
        case absent
        /// The file is there but could not be read: never write over it.
        case unreadable
        case got(Board)
    }

    // MARK: Folders

    private var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private func folder(_ name: String) -> URL {
        let url = support.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var localBoards: URL { folder("Boards") }
    private var localRemoved: URL { folder("Removed") }
    private var safety: URL { folder("SafetyCopies") }

    /// iCloud's Documents folder. Asked again now and then, so signing in later is noticed without a restart.
    private func cloudDocuments() -> URL? {
        if cloudRoot == nil, Date().timeIntervalSince(cloudAsked) > 30 {
            cloudAsked = Date()
            if let root = FileManager.default.url(forUbiquityContainerIdentifier: Self.container) {
                cloudRoot = root.appendingPathComponent("Documents", isDirectory: true)
            }
        }
        return cloudRoot
    }

    private func cloudBoards() -> URL? {
        guard let docs = cloudDocuments() else { return nil }
        let url = docs.appendingPathComponent("Boards", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cloudRemoved() -> URL? {
        guard let docs = cloudDocuments() else { return nil }
        let url = docs.appendingPathComponent("Removed", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func name(_ id: UUID) -> String { "\(id.uuidString).seedboard" }

    /// A small empty file that says "this board was removed", so the removal reaches every device.
    private func goneName(_ id: UUID) -> String { "\(id.uuidString).gone" }

    private func isGone(_ id: UUID) -> Bool {
        if FileManager.default.fileExists(atPath: localBoards.appendingPathComponent(goneName(id)).path) { return true }
        if let cloud = cloudBoards(), FileManager.default.fileExists(atPath: cloud.appendingPathComponent(goneName(id)).path) { return true }
        return false
    }

    // MARK: Coding

    private func encode(_ board: Board) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Times are written to the thousandth of a second, so "which change is newer" is never a tie.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var box = encoder.singleValueContainer()
            try box.encode(Self.fine.string(from: date))
        }
        return try? encoder.encode(board)
    }

    private func decode(_ data: Data) -> Board? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.fine.date(from: text) ?? Self.plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not a date"))
        }
        return try? decoder.decode(Board.self, from: data)
    }

    private static let fine: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain = ISO8601DateFormatter()

    private func same(_ a: Board, _ b: Board) -> Bool {
        guard let x = encode(a), let y = encode(b) else { return false }
        return x == y
    }

    private func interpret(_ data: Data) -> Read {
        // A board from a newer version of the app is read too (it can be looked at); `canBeChanged`
        // is false for it, and the writing rules below never put anything over such a file.
        if let board = decode(data) { return .got(board) }
        return .unreadable
    }

    // MARK: Reading

    private func readLocal(_ id: UUID) -> Read {
        let file = localBoards.appendingPathComponent(name(id))
        guard FileManager.default.fileExists(atPath: file.path) else { return .absent }
        guard let data = try? Data(contentsOf: file) else { return .unreadable }
        return interpret(data)
    }

    /// The cloud file of one board, with any versions iCloud parked joined in (the newer wins, the other is kept).
    private func readCloud(_ id: UUID) -> Read {
        guard let folder = cloudBoards() else { return .absent }
        let file = folder.appendingPathComponent(name(id))
        // Still on its way from iCloud (it shows as ".<name>.icloud"): ask for it, and never write over it.
        let waiting = folder.appendingPathComponent(".\(name(id)).icloud")
        if FileManager.default.fileExists(atPath: waiting.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: file)
            return .unreadable
        }
        try? FileManager.default.startDownloadingUbiquitousItem(at: file)
        var result: Read = .absent
        var problem: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { url in
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            if let data = try? Data(contentsOf: url) { result = interpret(data) } else { result = .unreadable }
        }
        if case .absent = result,
           (try? file.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true {
            result = .unreadable   // iCloud knows the file, it has not arrived yet
        }
        // What iCloud parked when two devices wrote at the same moment: join it in, then clear it away.
        if let parked = NSFileVersion.unresolvedConflictVersionsOfItem(at: file), !parked.isEmpty {
            var current = result
            var joined = false
            for version in parked {
                if let data = try? Data(contentsOf: version.url), case let .got(other) = interpret(data) {
                    switch current {
                    case let .got(mine):
                        current = .got(winner(mine, other))
                    case .absent:
                        current = .got(other)
                    default:
                        break
                    }
                    joined = true
                }
            }
            if case .got = current {
                for version in parked { version.isResolved = true }
                try? NSFileVersion.removeOtherVersionsOfItem(at: file)
                if joined, case let .got(board) = current { writeCloudFile(board, to: file) }
            }
            result = current
        }
        return result
    }

    /// The newer of two; the other, when it differs, goes to the safety copies.
    private func winner(_ a: Board, _ b: Board) -> Board {
        let (win, lose): (Board, Board)
        if a.canBeChanged != b.canBeChanged {
            // The one from a newer version of the app stays: this version would lose what it does not know.
            (win, lose) = a.canBeChanged ? (b, a) : (a, b)
        } else {
            (win, lose) = b.changed > a.changed ? (b, a) : (a, b)
        }
        if !same(win, lose) { keepLoser(lose) }
        return win
    }

    private func keepLoser(_ board: Board) {
        guard let bytes = encode(board) else { return }
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        // A few random letters at the end: two set-aside versions in one second never share a name.
        let file = safety.appendingPathComponent("\(board.id.uuidString)-\(stamp.string(from: Date()))-\(UUID().uuidString.prefix(6)).seedboard")
        try? bytes.write(to: file, options: .atomic)
    }

    // MARK: Loading

    func loadAll() -> (boards: [Board], gone: Set<UUID>) {
        queue.sync {
            purgeRemoved()
            var ids = Set<UUID>()
            var gone = Set<UUID>()
            for url in (try? FileManager.default.contentsOfDirectory(at: localBoards, includingPropertiesForKeys: nil)) ?? [] {
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
                if url.pathExtension == "gone" { gone.insert(id) } else if url.pathExtension == "seedboard" { ids.insert(id) }
            }
            if let folder = cloudBoards() {
                for url in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
                    var base = url.lastPathComponent
                    // A file iCloud has not downloaded yet shows as ".<name>.icloud": ask for it, and count it.
                    if base.hasPrefix("."), base.hasSuffix(".icloud") {
                        base = String(base.dropFirst().dropLast(".icloud".count))
                        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                    }
                    guard let id = UUID(uuidString: (base as NSString).deletingPathExtension) else { continue }
                    if (base as NSString).pathExtension == "gone" { gone.insert(id) } else if (base as NSString).pathExtension == "seedboard" { ids.insert(id) }
                }
            }
            // A board removed on any device leaves every device: its copies move to Removed, nothing is put back.
            for id in gone {
                moveAway(id)
                ids.remove(id)
            }
            var out: [Board] = []
            for id in ids {
                let local = readLocal(id)
                let cloud = readCloud(id)
                switch (local, cloud) {
                case let (.got(l), .got(c)):
                    let win = winner(c, l)
                    out.append(win)
                    if !same(win, l) { writeLocalFile(win) }
                    if !same(win, c) { writeCloud(win, reading: cloud) }
                case let (.got(l), .absent):
                    out.append(l)
                    if cloudBoards() != nil { writeCloud(l, reading: cloud) }
                case let (.got(l), _):
                    out.append(l)   // cloud unreadable or newer: shown from the device copy, cloud untouched
                case let (.absent, .got(c)), let (.unreadable, .got(c)):
                    out.append(c)
                    if case .absent = local { writeLocalFile(c) }
                default:
                    break
                }
            }
            dailySafetyCopy()
            return (out.sorted { $0.changed > $1.changed }, gone)
        }
    }

    // MARK: Writing

    private func writeLocalFile(_ board: Board) {
        // Never write a board this version only half understands, and never write over one.
        guard board.canBeChanged else { return }
        switch readLocal(board.id) {
        case .unreadable: return
        case let .got(old) where !old.canBeChanged: return
        default: break
        }
        guard let bytes = encode(board) else { return }
        try? bytes.write(to: localBoards.appendingPathComponent(name(board.id)), options: .atomic)
    }

    /// The device copy first, then iCloud, in the order the changes were made. Never blocks the caller.
    func save(_ board: Board, newerInCloud: @escaping @Sendable (Board) -> Void) {
        queue.async {
            guard !self.isGone(board.id) else { return }
            self.dailySafetyCopy()
            if case let .got(old) = self.readLocal(board.id), !self.same(old, board), old.changed > board.changed {
                self.keepLoser(board)
            } else {
                self.writeLocalFile(board)
            }
            if let newer = self.writeCloudNow(board) { newerInCloud(newer) }
        }
    }

    /// Waits until the work handed over so far is done, two seconds at most.
    func flush() {
        let done = DispatchSemaphore(value: 0)
        queue.async { done.signal() }
        _ = done.wait(timeout: .now() + 2)
    }

    private func writeCloudFile(_ board: Board, to file: URL) {
        guard let bytes = encode(board) else { return }
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &problem) { url in
            try? bytes.write(to: url, options: .atomic)
        }
    }

    private func writeCloud(_ board: Board, reading state: Read) {
        guard board.canBeChanged else { return }
        switch state {
        case .unreadable: return
        case let .got(there) where !there.canBeChanged: return
        default: break
        }
        guard let folder = cloudBoards() else { return }
        writeCloudFile(board, to: folder.appendingPathComponent(name(board.id)))
    }

    /// Writes the cloud copy. If iCloud already holds a newer version, that one stays, mine goes to the
    /// safety copies, and the newer one is given back so the app can show it.
    private func writeCloudNow(_ board: Board) -> Board? {
        do {
            guard cloudBoards() != nil else { return nil }
            let state = readCloud(board.id)
            switch state {
            case .unreadable:
                return nil
            case let .got(there):
                if !there.canBeChanged { return nil }
                if there.changed > board.changed, !same(there, board) {
                    keepLoser(board)
                    writeLocalFile(there)
                    return there
                }
                if same(there, board) { return nil }
            case .absent:
                break
            }
            writeCloud(board, reading: state)
            return nil
        }
    }

    // MARK: Removing

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    /// Removes a board: a mark that it is gone is left on the device and in iCloud (so no device puts it
    /// back), and both copies move to the Removed folders.
    func remove(id: UUID) {
        queue.async {
            FileManager.default.createFile(atPath: self.localBoards.appendingPathComponent(self.goneName(id)).path, contents: Data())
            self.moveAway(id)
        }
    }

    /// Moves a removed board's copies to the Removed folders and makes sure the mark is in both places.
    private func moveAway(_ id: UUID) {
        let fm = FileManager.default
        let localMark = localBoards.appendingPathComponent(goneName(id))
        if !fm.fileExists(atPath: localMark.path) { fm.createFile(atPath: localMark.path, contents: Data()) }
        let file = localBoards.appendingPathComponent(name(id))
        if fm.fileExists(atPath: file.path) {
            try? fm.moveItem(at: file, to: localRemoved.appendingPathComponent("\(id.uuidString)-\(stamp()).seedboard"))
        }
        guard let folder = cloudBoards(), let removed = cloudRemoved() else { return }
        let cloudMark = folder.appendingPathComponent(goneName(id))
        if !fm.fileExists(atPath: cloudMark.path) { try? Data().write(to: cloudMark) }
        let cloudFile = folder.appendingPathComponent(name(id))
        guard fm.fileExists(atPath: cloudFile.path) else { return }
        let target = removed.appendingPathComponent("\(id.uuidString)-\(stamp()).seedboard")
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: cloudFile, options: .forMoving,
                                       writingItemAt: target, options: .forReplacing, error: &problem) { from, to in
            try? fm.moveItem(at: from, to: to)
        }
    }

    /// The day a file was moved to Removed, read from its name ("<id>-20261118-091500.seedboard").
    /// The file's own date is no use: it still says when the board was last changed.
    private func removedDay(_ url: URL) -> Date? {
        let base = url.deletingPathExtension().lastPathComponent
        guard base.count > 16 else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: String(base.suffix(15)))
    }

    /// Boards removed more than 30 days ago are let go for good, on the device and in iCloud.
    /// A file whose removal day cannot be read is kept. Marks of removed boards are kept a year.
    private func purgeRemoved() {
        let limit = Date().addingTimeInterval(-Self.keepRemovedDays * 86_400)
        var folders = [localRemoved]
        if let cloud = cloudRemoved() { folders.append(cloud) }
        for folder in folders {
            for url in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
                if let day = removedDay(url), day < limit { try? FileManager.default.removeItem(at: url) }
            }
        }
        let markLimit = Date().addingTimeInterval(-365 * 86_400)
        var markFolders = [localBoards]
        if let cloud = cloudBoards() { markFolders.append(cloud) }
        for folder in markFolders {
            for url in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
            where url.pathExtension == "gone" {
                if let made = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate, made < markLimit {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    // MARK: Safety copies

    /// Once a day, BEFORE the first write of the day: all boards as they were, in SafetyCopies/<day>/. 14 days kept.
    private func dailySafetyCopy() {
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        day.locale = Locale(identifier: "en_US_POSIX")
        let today = safety.appendingPathComponent(day.string(from: Date()), isDirectory: true)
        guard !FileManager.default.fileExists(atPath: today.path) else { return }
        let files = ((try? FileManager.default.contentsOfDirectory(at: localBoards, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "seedboard" }
        guard !files.isEmpty else { return }
        try? FileManager.default.createDirectory(at: today, withIntermediateDirectories: true)
        for file in files {
            try? FileManager.default.copyItem(at: file, to: today.appendingPathComponent(file.lastPathComponent))
        }
        let days = ((try? FileManager.default.contentsOfDirectory(atPath: safety.path)) ?? [])
            .filter { $0.count == 10 && $0.hasPrefix("20") }.sorted()
        for old in days.dropLast(Self.keepSafetyDays) {
            try? FileManager.default.removeItem(at: safety.appendingPathComponent(old))
        }
    }

    /// Only looks at folder names, so it never has to wait for the store's other work.
    func lastSafetyCopy() -> Date? {
        let days = ((try? FileManager.default.contentsOfDirectory(atPath: safety.path)) ?? [])
            .filter { $0.count == 10 && $0.hasPrefix("20") }.sorted()
        guard let last = days.last else { return nil }
        return try? safety.appendingPathComponent(last)
            .resourceValues(forKeys: [.creationDateKey]).creationDate
    }
}
