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
        let boards = await Task.detached(priority: .userInitiated) { disk.loadAll() }.value
        for board in boards { known[board.id] = board.changed }
        startWatching()
        return boards
    }

    /// Writes the device copy at once, the iCloud copy off the main thread.
    func save(_ board: Board) {
        known[board.id] = board.changed
        if sample { memory[board.id] = board; return }
        let disk = self.disk
        disk.writeLocal(board)
        Task.detached(priority: .utility) { [weak self] in
            if let newer = disk.writeCloud(board) {
                // iCloud held a newer version: it was kept, and mine went to the safety copies.
                await self?.tell([newer])
            }
        }
    }

    /// Moves both copies into the Removed folder (kept 30 days). Never deletes outright.
    func remove(id: UUID) {
        known[id] = nil
        if sample { memory[id] = nil; return }
        let disk = self.disk
        disk.removeLocal(id: id)
        Task.detached(priority: .utility) { disk.removeCloud(id: id) }
    }

    /// Plain words for Settings, e.g. "12 boards · last safety copy today 08:10".
    func safetyLine() -> String {
        let count = sample ? memory.count : known.count
        let boards = count == 1 ? "1 board" : "\(count) boards"
        if sample { return "\(boards) · example boards, nothing is saved" }
        guard let when = disk.lastSafetyCopy() else { return "\(boards) · no safety copy yet" }
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
        return "\(boards) · last safety copy \(day) \(time.string(from: when))"
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
            let boards = disk.loadAll()
            let news = boards.filter { board in
                guard let before = seen[board.id] else { return true }
                return board.changed > before
            }
            await self?.finishedCheck(news)
        }
    }

    private func finishedCheck(_ news: [Board]) {
        checking = false
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

    /// Just enough of a file to know its format, without reading the rest.
    private struct FormatPeek: Decodable { var format: Int? }

    private enum Read {
        /// No file there.
        case absent
        /// The file is there but could not be read: never write over it.
        case unreadable
        /// The file is from a newer version of the app: never write over it, never read it.
        case newer
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

    // MARK: Coding

    private func encode(_ board: Board) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(board)
    }

    private func decode(_ data: Data) -> Board? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Board.self, from: data)
    }

    private func same(_ a: Board, _ b: Board) -> Bool {
        guard let x = encode(a), let y = encode(b) else { return false }
        return x == y
    }

    private func interpret(_ data: Data) -> Read {
        if let peek = try? JSONDecoder().decode(FormatPeek.self, from: data),
           let format = peek.format, format > Board.currentFormat { return .newer }
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
        let (win, lose) = b.changed > a.changed ? (b, a) : (a, b)
        if !same(win, lose) { keepLoser(lose) }
        return win
    }

    private func keepLoser(_ board: Board) {
        guard let bytes = encode(board) else { return }
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let file = safety.appendingPathComponent("\(board.id.uuidString)-\(stamp.string(from: Date())).seedboard")
        try? bytes.write(to: file, options: .atomic)
    }

    // MARK: Loading

    func loadAll() -> [Board] {
        queue.sync {
            purgeRemoved()
            var ids = Set<UUID>()
            for url in (try? FileManager.default.contentsOfDirectory(at: localBoards, includingPropertiesForKeys: nil)) ?? [] {
                if let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) { ids.insert(id) }
            }
            if let folder = cloudBoards() {
                for url in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
                    var base = url.lastPathComponent
                    // A file iCloud has not downloaded yet shows as ".<name>.icloud": ask for it, and count it.
                    if base.hasPrefix("."), base.hasSuffix(".icloud") {
                        base = String(base.dropFirst().dropLast(".icloud".count))
                        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                    }
                    if let id = UUID(uuidString: (base as NSString).deletingPathExtension) { ids.insert(id) }
                }
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
                case let (.absent, .got(c)), let (.unreadable, .got(c)), let (.newer, .got(c)):
                    out.append(c)
                    if case .absent = local { writeLocalFile(c) }
                default:
                    break
                }
            }
            dailySafetyCopy()
            return out.sorted { $0.changed > $1.changed }
        }
    }

    // MARK: Writing

    private func writeLocalFile(_ board: Board) {
        switch readLocal(board.id) {
        case .unreadable, .newer: return
        default: break
        }
        guard let bytes = encode(board) else { return }
        try? bytes.write(to: localBoards.appendingPathComponent(name(board.id)), options: .atomic)
    }

    func writeLocal(_ board: Board) {
        queue.sync {
            dailySafetyCopy()
            if case let .got(old) = readLocal(board.id), !same(old, board), old.changed > board.changed {
                keepLoser(board)
                return
            }
            writeLocalFile(board)
        }
    }

    private func writeCloudFile(_ board: Board, to file: URL) {
        guard let bytes = encode(board) else { return }
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &problem) { url in
            try? bytes.write(to: url, options: .atomic)
        }
    }

    private func writeCloud(_ board: Board, reading state: Read) {
        switch state {
        case .unreadable, .newer: return
        default: break
        }
        guard let folder = cloudBoards() else { return }
        writeCloudFile(board, to: folder.appendingPathComponent(name(board.id)))
    }

    /// Writes the cloud copy. If iCloud already holds a newer version, that one stays, mine goes to the
    /// safety copies, and the newer one is given back so the app can show it.
    func writeCloud(_ board: Board) -> Board? {
        queue.sync {
            guard cloudBoards() != nil else { return nil }
            let state = readCloud(board.id)
            switch state {
            case .unreadable, .newer:
                return nil
            case let .got(there):
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

    func removeLocal(id: UUID) {
        queue.sync {
            let file = localBoards.appendingPathComponent(name(id))
            guard FileManager.default.fileExists(atPath: file.path) else { return }
            let target = localRemoved.appendingPathComponent("\(id.uuidString)-\(stamp()).seedboard")
            try? FileManager.default.moveItem(at: file, to: target)
        }
    }

    func removeCloud(id: UUID) {
        queue.sync {
            guard let folder = cloudBoards(), let removed = cloudRemoved() else { return }
            let file = folder.appendingPathComponent(name(id))
            guard FileManager.default.fileExists(atPath: file.path) else { return }
            let target = removed.appendingPathComponent("\(id.uuidString)-\(stamp()).seedboard")
            var problem: NSError?
            NSFileCoordinator().coordinate(writingItemAt: file, options: .forMoving,
                                           writingItemAt: target, options: .forReplacing, error: &problem) { from, to in
                try? FileManager.default.moveItem(at: from, to: to)
            }
        }
    }

    /// Boards removed more than 30 days ago are let go for good, on the device and in iCloud.
    private func purgeRemoved() {
        let limit = Date().addingTimeInterval(-Self.keepRemovedDays * 86_400)
        var folders = [localRemoved]
        if let cloud = cloudRemoved() { folders.append(cloud) }
        for folder in folders {
            for url in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                if date < limit { try? FileManager.default.removeItem(at: url) }
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

    func lastSafetyCopy() -> Date? {
        queue.sync {
            let days = ((try? FileManager.default.contentsOfDirectory(atPath: safety.path)) ?? [])
                .filter { $0.count == 10 && $0.hasPrefix("20") }.sorted()
            guard let last = days.last else { return nil }
            return try? safety.appendingPathComponent(last)
                .resourceValues(forKeys: [.creationDateKey]).creationDate
        }
    }
}
