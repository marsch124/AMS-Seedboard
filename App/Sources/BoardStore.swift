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
/// The rules that keep the boards safe (the decisions themselves are in SeedboardCore, Safety.swift):
/// - for the same board, the newer change wins; a losing version that differs is kept in SafetyCopies;
/// - before a stored version is written over that this board did not grow from, it is kept in SafetyCopies;
/// - news that arrives while the owner is typing is held, not marked as seen, and offered again;
/// - a version iCloud parked because two devices wrote at once is joined in, never dropped unread;
/// - a file from a newer version of the app is never written over;
/// - a cloud file that cannot be read is never written over;
/// - a removed board moves to a Removed folder (30 days) and is never deleted outright; its mark carries
///   the time, and a change made after that brings the board back;
/// - the device copy is written at once, on its own line of work; iCloud follows on another;
/// - a write that fails is said (`warning`), and a board that is not in iCloud yet is known (`notInCloud`);
/// - once a day a safety copy of all boards is kept on the device, 14 days back.
@MainActor
final class BoardStore {
    private let sample: Bool
    private let disk = BoardDisk()
    private var memory: [UUID: Board] = [:]
    /// The `changed` of each board as the app shows it: the version every next save grows from.
    private var known: [UUID: Date] = [:]
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var checking = false
    private var polling = false

    /// News from iCloud. The app answers with the ids it now SHOWS. What it holds back (the owner is
    /// typing in that board) or has no use for is not marked as seen: it is offered again.
    var onCloudChange: (([Board]) -> Set<UUID>)?
    /// Boards another device removed, each with the time of its removal: they left this device's list too.
    var onCloudGone: (([UUID: Date]) -> Void)?
    /// `notInCloud` or `warning` changed.
    var onState: (() -> Void)?
    /// Two devices changed the same board: the version that lost is kept under Earlier versions (id, title).
    var onClash: ((UUID, String) -> Void)?

    /// Boards whose newest change is on this device but not in iCloud yet. Empty when iCloud is off.
    private(set) var notInCloud: Set<UUID> = []
    /// Boards whose last write failed, with their titles.
    private var deviceProblems: [UUID: Board] = [:]
    private var cloudProblems: [UUID: String] = [:]

    init(sample: Bool) {
        self.sample = sample
        disk.report = { [weak self] event in
            // One after the other, in the order they happened.
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.handle(event) } }
        }
    }

    /// False when iCloud Drive is not available (not signed in, or switched off).
    var cloudIsOn: Bool {
        !sample && FileManager.default.ubiquityIdentityToken != nil
    }

    /// Plain words when a write failed; nil when all is well.
    var warning: String? {
        if let board = deviceProblems.values.sorted(by: { $0.title < $1.title }).first {
            let what = deviceProblems.count == 1 ? "“\(board.title)”" : "\(deviceProblems.count) boards"
            return "\(what) could not be saved on this device. Keep Seedboard open: it tries again by itself."
        }
        if let title = cloudProblems.values.sorted().first {
            let what = cloudProblems.count == 1 ? "“\(title)”" : "\(cloudProblems.count) boards"
            return "\(what) could not be put into iCloud. Nothing is lost: the device has it, and Seedboard tries again by itself."
        }
        return nil
    }

    /// 0.5 (Share): true while this board's last write on the device failed.
    func notOnDevice(_ id: UUID) -> Bool { deviceProblems[id] != nil }

    /// The device's copies and iCloud's files made into one list. For the same id the newer `changed` wins.
    func loadAll() async -> [Board] {
        if sample { return Array(memory.values).sorted { $0.changed > $1.changed } }
        let disk = self.disk
        let found = await Task.detached(priority: .userInitiated) { disk.loadAll() }.value
        for board in found.boards { known[board.id] = board.changed }
        for id in found.gone.keys { known[id] = nil }
        // Everything in the list is shown: these are the versions the boards grow from.
        disk.took(found.boards)
        absorb(found)
        startWatching()
        return found.boards
    }

    /// Writes the device copy at once; the iCloud copy follows on its own line of work.
    func save(_ board: Board) {
        let grewFrom = known[board.id]
        known[board.id] = max(grewFrom ?? .distantPast, board.changed)
        if sample { memory[board.id] = board; return }
        if cloudIsOn, notInCloud.insert(board.id).inserted { onState?() }
        disk.save(board, grewFrom: grewFrom)
    }

    /// The app now shows these versions (news it had held back while the owner was typing).
    func took(_ boards: [Board]) {
        for board in boards { known[board.id] = max(known[board.id] ?? .distantPast, board.changed) }
        if !sample { disk.took(boards) }
    }

    /// Waits (at most two seconds) until everything handed to `save` is on the device. With `cloudToo`
    /// it then waits as long again for iCloud's copy (the Mac, when the app closes for good).
    func flush(cloudToo: Bool = false) {
        guard !sample else { return }
        disk.flush(cloudToo: cloudToo)
    }

    /// Calls `done` on the main thread once everything handed over so far has had its turn with iCloud.
    func afterCloud(_ done: @escaping @MainActor () -> Void) {
        guard !sample else { done(); return }
        disk.afterCloud { DispatchQueue.main.async { MainActor.assumeIsolated { done() } } }
    }

    /// Moves both copies into the Removed folder (kept 30 days). Never deletes outright.
    func remove(id: UUID) {
        known[id] = nil
        forget(id)
        if sample { memory[id] = nil; return }
        disk.remove(id: id)
    }

    /// When that board was removed; nil when it was not (or nobody knows).
    func removedDate(_ id: UUID) async -> Date? {
        if sample { return nil }
        let disk = self.disk
        return await Task.detached(priority: .userInitiated) { disk.removedDate(id) }.value
    }

    /// Brings a removed board back from the Removed folder, under the same identity, on every device.
    /// The hook for a "Bring back" button; nil when there is no copy left to bring back.
    func bringBack(id: UUID) async -> Board? {
        if sample { return nil }
        let disk = self.disk
        guard let board = await Task.detached(priority: .userInitiated, operation: { disk.restore(id) }).value else { return nil }
        known[id] = board.changed
        if cloudIsOn { notInCloud.insert(id); startPolling() }
        onState?()
        return board
    }

    /// A board as the bytes of its file, and back (for the export, and for boards that come in again).
    func bytes(of board: Board) -> Data? { disk.encode(board) }
    func board(from data: Data) -> Board? { disk.decode(data) }

    /// Work on the kept copies (the Removed folders and SafetyCopies; BringBack.swift), in line with the
    /// store's other file work and off the main thread. nil with the example boards: nothing is read then.
    func kept<T: Sendable>(_ work: @escaping @Sendable (KeptPlaces) -> T) async -> T? {
        if sample { return nil }
        let disk = self.disk
        return await Task.detached(priority: .userInitiated) { disk.kept(work) }.value
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

    // MARK: What the files said

    private func forget(_ id: UUID) {
        let had = notInCloud.remove(id) != nil
        let hadProblem = deviceProblems.removeValue(forKey: id) != nil || cloudProblems.removeValue(forKey: id) != nil
        if had || hadProblem { onState?() }
    }

    private func handle(_ event: BoardDisk.Event) {
        switch event {
        case .deviceSaved(let id):
            deviceProblems[id] = nil
        case .deviceFailed(let board):
            guard known[board.id] != nil else { break }
            deviceProblems[board.id] = board
            startPolling()
        case let .cloudSaved(id, changed, uploaded):
            cloudProblems[id] = nil
            if uploaded { settle([id: changed]) } else { startPolling() }
        case let .cloudFailed(id, title):
            guard known[id] != nil else { break }
            cloudProblems[id] = title
            notInCloud.insert(id)
            startPolling()
        case .cloudWaiting(let id):
            guard known[id] != nil else { break }
            notInCloud.insert(id)
            startPolling()
        case .cloudOff(let id):
            notInCloud.remove(id)
            cloudProblems[id] = nil
        case .newer(let board):
            tell([board])
            onClash?(board.id, board.title)
        case let .clash(id, title):
            onClash?(id, title)
        }
        onState?()
    }

    /// These boards are in iCloud with that `changed`: no longer "not in iCloud yet", unless the app has moved on.
    private func settle(_ uploaded: [UUID: Date]) {
        for (id, stamp) in uploaded {
            guard let now = known[id], SafetyRules.sameMoment(now, stamp) else { continue }
            notInCloud.remove(id)
            cloudProblems[id] = nil
        }
    }

    private func absorb(_ found: BoardDisk.Found) {
        if cloudIsOn {
            notInCloud.formUnion(found.notUploaded.filter { known[$0] != nil })
            settle(found.uploaded)
        } else {
            notInCloud = []
            cloudProblems = [:]
        }
        if !notInCloud.isEmpty { startPolling() }
        onState?()
    }

    /// While something is not in iCloud yet or a write failed: looks again every few seconds (slower and
    /// slower, 30 s at most), tries the failed writes again, and stops by itself when all is well.
    private func startPolling() {
        guard !polling, !sample else { return }
        polling = true
        Task { [weak self] in
            var wait: UInt64 = 3
            while true {
                try? await Task.sleep(nanoseconds: wait * 1_000_000_000)
                guard let self else { return }
                guard await self.lookAgain() else {
                    self.polling = false
                    return
                }
                wait = min(wait * 2, 30)
            }
        }
    }

    /// True while there is still something to wait for.
    private func lookAgain() async -> Bool {
        for board in deviceProblems.values where known[board.id] != nil { disk.save(board, grewFrom: nil) }
        // A look at iCloud writes whatever is only on the device.
        if !cloudProblems.isEmpty { checkCloud() }
        let waiting = notInCloud
        if !waiting.isEmpty {
            let disk = self.disk
            let answer = await Task.detached(priority: .utility) { disk.uploaded(waiting) }.value
            if answer.cloudOn { settle(answer.uploaded) } else { notInCloud = []; cloudProblems = [:] }
            onState?()
        }
        return !(notInCloud.isEmpty && deviceProblems.isEmpty && cloudProblems.isEmpty)
    }

    // MARK: Watching iCloud

    /// Hands news to the app. Only what the app then shows counts as seen.
    private func tell(_ boards: [Board]) {
        let taken = onCloudChange?(boards) ?? []
        let shown = boards.filter { taken.contains($0.id) }
        guard !shown.isEmpty else { return }
        took(shown)
    }

    private func startWatching() {
        guard query == nil, cloudIsOn else { return }
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        // The boards and the marks of removed boards.
        q.predicate = NSPredicate(format: "%K LIKE '*.seedboard' OR %K LIKE '*.gone'", NSMetadataItemFSNameKey, NSMetadataItemFSNameKey)
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

    /// Looks at iCloud; whatever is newer than what the app shows goes to `onCloudChange`.
    private func checkCloud() {
        guard !checking, !sample else { return }
        checking = true
        let disk = self.disk
        Task.detached(priority: .utility) { [weak self] in
            let found = disk.loadAll()
            await self?.finishedCheck(found)
        }
    }

    private func finishedCheck(_ found: BoardDisk.Found) {
        checking = false
        let left = found.gone.filter { known[$0.key] != nil }
        if !left.isEmpty {
            for id in left.keys {
                known[id] = nil
                forget(id)
            }
            onCloudGone?(left)
        }
        absorb(found)
        // Compared with what the app shows NOW (it may have moved on while the look ran).
        let fresh = found.boards.filter { board in
            guard let now = known[board.id] else { return true }
            return SafetyRules.news(incoming: board.changed, shown: now, busy: false) == .take
        }
        guard !fresh.isEmpty else { return }
        tell(fresh)
    }
}

// MARK: - The files

/// Everything that touches files. Safe to call from any thread. Two lines of work, each one thing at a time:
/// `local` for the device's own folders (fast, never waits for iCloud) and `cloud` for iCloud's.
/// The device's board files are only ever WRITTEN on `local`; `cloud` hands such a write over and waits.
/// `local` never waits for `cloud`.
final class BoardDisk: @unchecked Sendable {
    static let container = "iCloud.com.schabbauer.AMSSeedboard"
    static let keepSafetyDays = 14
    static let keepRemovedDays: Double = 30

    enum Event: Sendable {
        case deviceSaved(UUID)
        /// The device copy could not be written.
        case deviceFailed(Board)
        /// iCloud's folder holds this version now; `uploaded` says whether it has left the device too.
        case cloudSaved(UUID, changed: Date, uploaded: Bool)
        case cloudFailed(UUID, title: String)
        /// iCloud's copy was left alone for now (it has not arrived yet, or cannot be read).
        case cloudWaiting(UUID)
        /// There is no iCloud on this device.
        case cloudOff(UUID)
        /// iCloud held a newer version: it was kept, and mine went to the safety copies.
        case newer(Board)
        /// Another device's version of this board lost against this device's and was set aside.
        case clash(UUID, title: String)
    }

    struct Found: Sendable {
        var boards: [Board] = []
        /// Removed boards, each with the time of its removal.
        var gone: [UUID: Date] = [:]
        /// Shown boards that are not (fully) in iCloud.
        var notUploaded: Set<UUID> = []
        /// Shown boards that are in iCloud, with the `changed` iCloud has.
        var uploaded: [UUID: Date] = [:]
    }

    /// Set once, before anything else is called.
    var report: (@Sendable (Event) -> Void)?

    private let local = DispatchQueue(label: "com.schabbauer.AMSSeedboard.store.device")
    private let cloud = DispatchQueue(label: "com.schabbauer.AMSSeedboard.store.icloud")
    private let lock = NSLock()
    /// Behind `lock`: what each board on this device grew from.
    private var lineage: [UUID: Lineage] = [:]
    /// Behind `lock`: the newest version of each board still waiting for its turn with iCloud.
    private var waitingCloud: [UUID: Board] = [:]
    // Only on `cloud`:
    private var cloudRoot: URL?
    private var cloudAsked = Date.distantPast
    /// 0.11 (tests): another place for the device's folders, and a stand-in for iCloud's Documents folder.
    /// Both nil in the app itself.
    private let supportOverride: URL?
    private let cloudOverride: Bool

    init(support: URL? = nil, cloudDocuments: URL? = nil) {
        supportOverride = support
        cloudOverride = cloudDocuments != nil
        cloudRoot = cloudDocuments
    }
    /// The `changed` of the version iCloud's folder was last seen to hold.
    private var cloudStamp: [UUID: Date] = [:]

    private enum Read {
        /// No file there.
        case absent
        /// The file is there but could not be read: never write over it.
        case unreadable
        case got(Board)
    }

    // MARK: What the boards grew from

    func took(_ boards: [Board]) {
        lock.lock()
        for board in boards { lineage[board.id, default: Lineage()].add(board.changed) }
        lock.unlock()
    }

    private func inLineage(_ id: UUID, _ stamp: Date) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return lineage[id]?.holds(stamp) ?? false
    }

    /// Where a version that is set aside came from, as far as this run of the app can tell: one this
    /// device showed or saved, or one another device wrote. nil while the board was not shown here yet.
    private func origin(_ board: Board) -> SetAsideOrigin? {
        lock.lock()
        defer { lock.unlock() }
        guard let line = lineage[board.id] else { return nil }
        return line.holds(board.changed) ? .here : .away
    }

    // MARK: Folders

    private var support: URL {
        if let supportOverride { return supportOverride }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
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
        if !cloudOverride, cloudRoot == nil, Date().timeIntervalSince(cloudAsked) > 30 {
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

    /// A small file that says "this board was removed, then", so the removal reaches every device.
    private func goneName(_ id: UUID) -> String { "\(id.uuidString).gone" }

    private func files(in folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    }

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    /// When a mark says its board was removed. An old, empty mark counts from its file's date.
    private func markDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let fileDate = values?.contentModificationDate ?? values?.creationDate
        return RemovalMark.removedAt(from: try? Data(contentsOf: url), fileDate: fileDate) ?? Date()
    }

    // MARK: Coding

    func encode(_ board: Board) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Times are written to the thousandth of a second, so "which change is newer" is never a tie.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var box = encoder.singleValueContainer()
            try box.encode(Self.fine.string(from: date))
        }
        return try? encoder.encode(board)
    }

    func decode(_ data: Data) -> Board? {
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
        guard exists(file) else { return .absent }
        guard let data = try? Data(contentsOf: file) else { return .unreadable }
        return interpret(data)
    }

    /// The bytes of a file in iCloud's folder, read politely. nil when it is not there or cannot be read.
    private func cloudData(_ file: URL) -> Data? {
        var data: Data?
        var problem: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &problem) { url in
            data = try? Data(contentsOf: url)
        }
        return data
    }

    /// The cloud file of one board, with any versions iCloud parked joined in (the newer wins, the other is kept).
    private func readCloud(_ id: UUID) -> Read {
        guard let folder = cloudBoards() else { return .absent }
        let file = folder.appendingPathComponent(name(id))
        // Still on its way from iCloud (it shows as ".<name>.icloud"): ask for it, and never write over it.
        let waiting = folder.appendingPathComponent(".\(name(id)).icloud")
        if exists(waiting) {
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
        // What iCloud parked when two devices wrote at the same moment. Each version is settled BY ITSELF and
        // only once it was really read and its words are safe (in the board's own file, or in SafetyCopies).
        // One that has not arrived, or cannot be dealt with now, stays where it is for the next look.
        for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: file) ?? [] {
            guard let data = try? Data(contentsOf: version.url) else { continue }
            var settled = false
            var other: Board?
            if case let .got(board) = interpret(data), board.id == id { other = board }
            switch result {
            case .unreadable:
                break   // the board's own file cannot be read now: nothing is joined, nothing cleared
            case .absent:
                if let other {
                    if writeCloudBytes(data, to: file) {
                        result = .got(other)
                        settled = true
                    }
                } else {
                    settled = setAside(data, id: id, ending: "unreadable")
                }
            case let .got(mine):
                if let other {
                    if same(mine, other) {
                        settled = true
                    } else if SafetyRules.wins(other, over: mine) {
                        // Its own bytes go into the board's file, so nothing a newer app wrote is lost.
                        if keepLoser(mine), writeCloudBytes(data, to: file) {
                            result = .got(other)
                            settled = true
                            report?(.clash(id, title: other.title))
                        }
                    } else {
                        settled = setAside(data, id: id, ending: "seedboard")
                        if settled { report?(.clash(id, title: mine.title)) }
                    }
                } else {
                    settled = setAside(data, id: id, ending: "unreadable")
                }
            }
            if settled {
                version.isResolved = true
                try? version.remove()
            }
        }
        return result
    }

    /// The newer of two; the other, when it differs, goes to the safety copies.
    private func winner(_ a: Board, _ b: Board) -> Board {
        let (win, lose) = SafetyRules.wins(b, over: a) ? (b, a) : (a, b)
        if !same(win, lose) { keepLoser(lose) }
        return win
    }

    /// Keeps a version that lost in SafetyCopies. False when it could not be kept.
    @discardableResult
    private func keepLoser(_ board: Board) -> Bool {
        guard let bytes = encode(board) else { return false }
        return setAside(bytes, id: board.id, ending: "seedboard")
    }

    /// Keeps these bytes in SafetyCopies as `<id>-<yyyyMMdd-HHmmss>-<6 letters>.<ending>`; a board's name
    /// also says where the version came from when that is known (`…-here.seedboard`, `…-away.seedboard`).
    /// The same bytes are not kept twice. False when they could not be kept.
    @discardableResult
    private func setAside(_ bytes: Data, id: UUID, ending: String) -> Bool {
        let fm = FileManager.default
        for url in files(in: safety) where url.pathExtension == ending && url.lastPathComponent.hasPrefix(id.uuidString) {
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
            if size == bytes.count, (try? Data(contentsOf: url)) == bytes { return true }
        }
        // A few random letters at the end: two set-aside versions in one second never share a name.
        let kept = ending == "seedboard" ? decode(bytes) : nil
        let from = kept.flatMap(origin)
        let file = safety.appendingPathComponent("\(id.uuidString)-\(stamp())-\(UUID().uuidString.prefix(6))\(KeptFileName.ending(for: from)).\(ending)")
        do {
            try bytes.write(to: file, options: .atomic)
            // Another device's version lost: said once, so the clash is not silent.
            if let kept, from == .away { report?(.clash(id, title: kept.title)) }
            return true
        } catch {
            return false
        }
    }

    // MARK: Loading

    /// Looks at the device and at iCloud and makes them agree. Runs on `cloud`; never call it from the main thread.
    func loadAll() -> Found {
        cloud.sync {
            local.sync { dailySafetyCopy() }
            purgeRemoved()
            // Set-aside versions are kept 30 days (the daily copies keep their own 14).
            KeptFiles.tidy(safety: safety, now: Date())
            var found = Found()
            var ids = Set<UUID>()
            var marks: [UUID: [URL]] = [:]
            var marksWaiting = Set<UUID>()
            var copies: [UUID: [URL]] = [:]
            for url in files(in: localBoards) {
                guard let file = BoardFileName(url.lastPathComponent) else { continue }
                switch file.kind {
                case .removalMark: marks[file.id, default: []].append(url)
                case .board: if file.copy == nil { ids.insert(file.id) }
                }
            }
            let cloudFolder = cloudBoards()
            if let cloudFolder {
                for url in files(in: cloudFolder) {
                    guard let file = BoardFileName(url.lastPathComponent) else { continue }
                    let real = cloudFolder.appendingPathComponent(file.name)
                    // A file iCloud has not downloaded yet shows as ".<name>.icloud": ask for it, and count it.
                    if file.waiting { try? FileManager.default.startDownloadingUbiquitousItem(at: real) }
                    switch file.kind {
                    case .removalMark:
                        if file.waiting { marksWaiting.insert(file.id) } else { marks[file.id, default: []].append(real) }
                    case .board:
                        ids.insert(file.id)
                        // "<id> 2.seedboard": a copy iCloud made by itself. Read and joined below, never skipped.
                        if file.copy != nil, !file.waiting { copies[file.id, default: []].append(real) }
                    }
                }
            }

            // Removed boards. The mark says when; a version changed after that wins and the board comes back.
            for id in Set(marks.keys).union(marksWaiting) {
                guard let dates = marks[id]?.map(markDate), let removedAt = dates.max() else {
                    ids.remove(id)   // the mark has not arrived yet: nothing is decided this time
                    continue
                }
                // Long gone, nothing left in either Boards folder: nothing to read or move.
                if !ids.contains(id) {
                    found.gone[id] = removedAt
                    continue
                }
                let onDevice = readLocal(id)
                let inCloud = readCloud(id)
                if case .unreadable = inCloud {
                    ids.remove(id)   // iCloud's copy cannot be read yet: which is later cannot be told
                    continue
                }
                var last: Date?
                if case let .got(board) = onDevice { last = board.changed }
                if case let .got(board) = inCloud { last = max(last ?? .distantPast, board.changed) }
                if SafetyRules.removal(removedAt: removedAt, lastChange: last) == .comesBack {
                    clearMarks(id)
                } else {
                    moveAway(id, removedAt: removedAt)
                    ids.remove(id)
                    found.gone[id] = removedAt
                }
            }

            // iCloud's own copies ("<id> 2.seedboard").
            for (id, urls) in copies where ids.contains(id) {
                for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) { join(copy: url, of: id) }
            }

            for id in ids {
                let onDevice = readLocal(id)
                let inCloud = readCloud(id)
                var shown: Board?
                var cloudHasIt = false
                switch (onDevice, inCloud) {
                case let (.got(l), .got(c)):
                    if same(l, c) {
                        shown = l
                        cloudHasIt = true
                    } else if SafetyRules.wins(c, over: l) {
                        // iCloud's is the newer one: the device's version is kept aside and replaced.
                        shown = c
                        cloudHasIt = true
                        local.sync { replaceLocal(with: c, ifStill: l.changed) }
                    } else {
                        // The device is ahead. iCloud's version is kept, unless it is one this board grew from.
                        shown = l
                        if !inLineage(id, c.changed) { keepLoser(c) }
                        cloudHasIt = writeCloud(l, reading: inCloud)
                    }
                case let (.got(l), .absent):
                    shown = l
                    if cloudFolder != nil { cloudHasIt = writeCloud(l, reading: inCloud) }
                case let (.got(l), .unreadable):
                    shown = l   // cloud unreadable or not arrived: shown from the device copy, cloud untouched
                case let (.absent, .got(c)):
                    shown = c
                    cloudHasIt = true
                    local.sync { replaceLocal(with: c, ifStill: nil) }
                case let (.unreadable, .got(c)):
                    shown = c
                    cloudHasIt = true
                default:
                    break
                }
                guard let shown else { continue }
                found.boards.append(shown)
                guard let cloudFolder else { continue }
                if cloudHasIt { cloudStamp[id] = shown.changed }
                if cloudHasIt, isUploaded(cloudFolder.appendingPathComponent(name(id))) {
                    found.uploaded[id] = shown.changed
                } else {
                    found.notUploaded.insert(id)
                }
            }
            found.boards.sort { $0.changed > $1.changed }
            return found
        }
    }

    /// One of iCloud's own copies ("<id> 2.seedboard") is read and joined with the board's file by the usual
    /// rule (the newer wins, the other goes to SafetyCopies), then cleared away. It is cleared only when its
    /// words are safe elsewhere; a copy that cannot be dealt with now stays for the next look.
    private func join(copy url: URL, of id: UUID) {
        let main = readCloud(id)
        if case .unreadable = main { return }
        guard let folder = cloudBoards(), let data = cloudData(url) else { return }
        let file = folder.appendingPathComponent(name(id))
        guard case let .got(other) = interpret(data), other.id == id else {
            // Read, but not this board: the bytes are kept as they are, and the stray file goes.
            if setAside(data, id: id, ending: "unreadable") { removeCloud(url) }
            return
        }
        switch main {
        case .unreadable:
            return
        case .absent:
            guard writeCloudBytes(data, to: file) else { return }
        case let .got(mine):
            if same(mine, other) {
                break
            } else if SafetyRules.wins(other, over: mine) {
                guard keepLoser(mine), writeCloudBytes(data, to: file) else { return }
                report?(.clash(id, title: other.title))
            } else {
                guard setAside(data, id: id, ending: "seedboard") else { return }
                report?(.clash(id, title: mine.title))
            }
        }
        removeCloud(url)
    }

    // MARK: Writing on the device (always on `local`)

    private enum Outcome { case written, same, kept, refused, removed, failed }

    private func writeLocalBytes(_ board: Board) -> Bool {
        guard let bytes = encode(board) else { return false }
        do {
            try bytes.write(to: localBoards.appendingPathComponent(name(board.id)), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// The owner's change goes onto the device.
    private func saveLocal(_ board: Board) -> Outcome {
        let mark = localBoards.appendingPathComponent(goneName(board.id))
        if exists(mark) {
            // A board that was removed is not put back, unless this change was made after the removal.
            guard SafetyRules.removal(removedAt: markDate(mark), lastChange: board.changed) == .comesBack else { return .removed }
            try? FileManager.default.removeItem(at: mark)
        }
        var stored: Board?
        switch readLocal(board.id) {
        case .absent:
            break
        case .unreadable:
            // A device file that cannot be read must not stop every save for ever: its bytes are kept, then replaced.
            let file = localBoards.appendingPathComponent(name(board.id))
            guard let bytes = try? Data(contentsOf: file), setAside(bytes, id: board.id, ending: "unreadable") else { return .failed }
        case let .got(old):
            stored = old
        }
        let isSame = stored.map { same($0, board) } ?? false
        let grown = stored.map { inLineage(board.id, $0.changed) } ?? false
        switch SafetyRules.write(mine: board, stored: stored, storedIsSame: isSame, inLineage: grown) {
        case .refuse:
            return .refused
        case .nothing:
            return .same
        case .storedStays:
            keepLoser(board)
            return .kept
        case .keepStoredThenWrite:
            if let stored { keepLoser(stored) }
            return writeLocalBytes(board) ? .written : .failed
        case .write:
            return writeLocalBytes(board) ? .written : .failed
        }
    }

    /// iCloud's version goes onto the device, over the version the device was seen to hold (`stamp`; nil = none).
    /// If the device has moved on meanwhile, nothing is done: the next save settles it.
    private func replaceLocal(with new: Board, ifStill stamp: Date?) {
        // Never write a board this version only half understands, and never write over one.
        guard new.canBeChanged else { return }
        switch readLocal(new.id) {
        case .absent:
            break
        case .unreadable:
            return
        case let .got(old):
            guard old.canBeChanged, let stamp, SafetyRules.sameMoment(old.changed, stamp) else { return }
            if same(old, new) { return }
            keepLoser(old)
        }
        _ = writeLocalBytes(new)
    }

    // MARK: Saving

    /// The device copy at once on `local`; iCloud follows on `cloud`. Never blocks the caller, and the
    /// device copy never waits for iCloud. `grewFrom`: the `changed` of the version this one grew from.
    func save(_ board: Board, grewFrom: Date?) {
        lock.lock()
        if let grewFrom { lineage[board.id, default: Lineage()].add(grewFrom) }
        lineage[board.id, default: Lineage()].add(board.changed)
        waitingCloud[board.id] = board
        lock.unlock()
        local.async {
            self.dailySafetyCopy()
            switch self.saveLocal(board) {
            case .written, .same: self.report?(.deviceSaved(board.id))
            case .failed: self.report?(.deviceFailed(board))
            case .kept, .refused, .removed: break
            }
        }
        cloud.async { self.saveCloud(board.id) }
    }

    /// The newest waiting version of that board goes to iCloud. Several quick saves become one write.
    private func saveCloud(_ id: UUID) {
        lock.lock()
        let waiting = waitingCloud.removeValue(forKey: id)
        lock.unlock()
        guard let board = waiting else { return }
        guard let folder = cloudBoards() else {
            report?(.cloudOff(id))
            return
        }
        let mark = folder.appendingPathComponent(goneName(id))
        if exists(mark) {
            guard SafetyRules.removal(removedAt: markDate(mark), lastChange: board.changed) == .comesBack else { return }
            removeCloud(mark)
        }
        let file = folder.appendingPathComponent(name(id))
        var stored: Board?
        switch readCloud(id) {
        case .unreadable:
            report?(.cloudWaiting(id))
            return
        case .absent:
            break
        case let .got(there):
            stored = there
        }
        let isSame = stored.map { same($0, board) } ?? false
        let grown = stored.map { inLineage(id, $0.changed) } ?? false
        switch SafetyRules.write(mine: board, stored: stored, storedIsSame: isSame, inLineage: grown) {
        case .refuse:
            report?(.cloudWaiting(id))
        case .nothing:
            cloudStamp[id] = board.changed
            report?(.cloudSaved(id, changed: board.changed, uploaded: isUploaded(file)))
        case .storedStays:
            // iCloud holds a newer version: it stays, mine is kept aside, and the app is told.
            guard let there = stored else { return }
            keepLoser(board)
            cloudStamp[id] = there.changed
            local.sync { replaceLocal(with: there, ifStill: board.changed) }
            report?(.newer(there))
        case .keepStoredThenWrite, .write:
            if let stored, !grown { keepLoser(stored) }
            if writeCloudFile(board, to: file) {
                cloudStamp[id] = board.changed
                report?(.cloudSaved(id, changed: board.changed, uploaded: isUploaded(file)))
            } else {
                report?(.cloudFailed(id, title: board.title))
            }
        }
    }

    /// Waits until the work handed over so far is on the device, two seconds at most; with `cloudToo`,
    /// then as long again for iCloud's copy.
    func flush(cloudToo: Bool) {
        let done = DispatchSemaphore(value: 0)
        local.async { done.signal() }
        _ = done.wait(timeout: .now() + 2)
        guard cloudToo else { return }
        let sent = DispatchSemaphore(value: 0)
        cloud.async { sent.signal() }
        _ = sent.wait(timeout: .now() + 2)
    }

    /// Calls `done` once everything handed over so far has had its turn with iCloud.
    func afterCloud(_ done: @escaping @Sendable () -> Void) {
        local.async { self.cloud.async { done() } }
    }

    /// True when iCloud has taken the file off this device's hands.
    private func isUploaded(_ file: URL) -> Bool {
        (try? file.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]).ubiquitousItemIsUploaded) ?? false
    }

    /// Which of these boards are in iCloud now, each with the `changed` iCloud has.
    func uploaded(_ ids: Set<UUID>) -> (uploaded: [UUID: Date], cloudOn: Bool) {
        cloud.sync {
            guard let folder = cloudBoards() else { return ([:], false) }
            var out: [UUID: Date] = [:]
            for id in ids {
                guard let stamp = cloudStamp[id], isUploaded(folder.appendingPathComponent(name(id))) else { continue }
                out[id] = stamp
            }
            return (out, true)
        }
    }

    /// Writes bytes into a file in iCloud's folder, politely. False when it failed.
    private func writeCloudBytes(_ bytes: Data, to file: URL) -> Bool {
        var ok = false
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &problem) { url in
            do {
                try bytes.write(to: url, options: .atomic)
                ok = true
            } catch {
                ok = false
            }
        }
        return ok && problem == nil
    }

    private func writeCloudFile(_ board: Board, to file: URL) -> Bool {
        guard let bytes = encode(board) else { return false }
        return writeCloudBytes(bytes, to: file)
    }

    /// Takes a file out of iCloud's folder (a mark that no longer holds, or a copy whose words are safe elsewhere).
    private func removeCloud(_ file: URL) {
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forDeleting, error: &problem) { url in
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Writes the device's version to iCloud while the two are being made to agree. True when iCloud has it now.
    private func writeCloud(_ board: Board, reading state: Read) -> Bool {
        guard board.canBeChanged else { return false }
        switch state {
        case .unreadable: return false
        case let .got(there) where !there.canBeChanged: return false
        default: break
        }
        guard let folder = cloudBoards() else { return false }
        return writeCloudFile(board, to: folder.appendingPathComponent(name(board.id)))
    }

    // MARK: Removing

    private func stamp(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// A free name in a Removed folder: `<id>-<yyyyMMdd-HHmmss>.seedboard`. When a copy of the same second
    /// is there already, the next free second is taken, so a move never fails for a name that is in use.
    private func removedPlace(_ id: UUID, in folder: URL) -> URL {
        var date = Date()
        var url = folder.appendingPathComponent("\(id.uuidString)-\(stamp(date)).seedboard")
        while exists(url) {
            date = date.addingTimeInterval(1)
            url = folder.appendingPathComponent("\(id.uuidString)-\(stamp(date)).seedboard")
        }
        return url
    }

    /// Removes a board: a mark that says WHEN it went is left on the device and in iCloud (so no device
    /// puts it back, unless it was changed after that), and both copies move to the Removed folders.
    func remove(id: UUID) {
        lock.lock()
        waitingCloud[id] = nil
        lock.unlock()
        local.async {
            var last: Date?
            if case let .got(board) = self.readLocal(id) { last = board.changed }
            let removedAt = RemovalMark.time(now: Date(), lastChange: last)
            // A fresh removal always writes its own time, also over an older mark.
            try? RemovalMark.data(removedAt: removedAt).write(to: self.localBoards.appendingPathComponent(self.goneName(id)), options: .atomic)
            self.moveAwayLocal(id, removedAt: removedAt)
            self.cloud.async { self.moveAwayCloud(id, removedAt: removedAt, fresh: true) }
        }
    }

    /// Moves a removed board's copies to the Removed folders and makes sure the mark is in both places. On `cloud`.
    private func moveAway(_ id: UUID, removedAt: Date) {
        local.sync { moveAwayLocal(id, removedAt: removedAt) }
        moveAwayCloud(id, removedAt: removedAt, fresh: false)
    }

    private func moveAwayLocal(_ id: UUID, removedAt: Date) {
        let fm = FileManager.default
        let mark = localBoards.appendingPathComponent(goneName(id))
        if !exists(mark) { try? RemovalMark.data(removedAt: removedAt).write(to: mark, options: .atomic) }
        let file = localBoards.appendingPathComponent(name(id))
        if exists(file) {
            try? fm.moveItem(at: file, to: removedPlace(id, in: localRemoved))
        }
    }

    private func moveAwayCloud(_ id: UUID, removedAt: Date, fresh: Bool) {
        let fm = FileManager.default
        guard let folder = cloudBoards(), let removed = cloudRemoved() else { return }
        let mark = folder.appendingPathComponent(goneName(id))
        if fresh || !exists(mark) { _ = writeCloudBytes(RemovalMark.data(removedAt: removedAt), to: mark) }
        cloudStamp[id] = nil
        let cloudFile = folder.appendingPathComponent(name(id))
        guard exists(cloudFile) else { return }
        let target = removedPlace(id, in: removed)
        var problem: NSError?
        NSFileCoordinator().coordinate(writingItemAt: cloudFile, options: .forMoving,
                                       writingItemAt: target, options: .forReplacing, error: &problem) { from, to in
            try? fm.moveItem(at: from, to: to)
        }
    }

    /// Takes the removal marks of a board away, on the device and in iCloud: the board is back for every device. On `cloud`.
    private func clearMarks(_ id: UUID) {
        local.sync {
            for url in files(in: localBoards) {
                guard let file = BoardFileName(url.lastPathComponent), file.id == id, file.kind == .removalMark else { continue }
                try? FileManager.default.removeItem(at: url)
            }
        }
        guard let folder = cloudBoards() else { return }
        for url in files(in: folder) {
            guard let file = BoardFileName(url.lastPathComponent), file.id == id, file.kind == .removalMark, !file.waiting else { continue }
            removeCloud(url)
        }
    }

    /// When that board was removed, read from its marks; nil when it has none.
    func removedDate(_ id: UUID) -> Date? {
        cloud.sync {
            var folders = [localBoards]
            if let folder = cloudBoards() { folders.append(folder) }
            let dates = folders.map { $0.appendingPathComponent(goneName(id)) }.filter(exists).map(markDate)
            return dates.max()
        }
    }

    /// Brings a removed board back: the newest copy in the Removed folders becomes the board again, stamped
    /// later than its removal, so it wins on every device and the marks are cleared. The copies in Removed
    /// stay until their 30 days are over. nil when no copy can be read.
    func restore(_ id: UUID) -> Board? {
        cloud.sync {
            var best: Board?
            var folders = [localRemoved]
            if let folder = cloudRemoved() { folders.append(folder) }
            for folder in folders {
                for url in files(in: folder) where url.pathExtension == "seedboard" && url.lastPathComponent.hasPrefix(id.uuidString) {
                    guard let data = try? Data(contentsOf: url), case let .got(board) = interpret(data), board.id == id else { continue }
                    if best.map({ board.changed > $0.changed }) ?? true { best = board }
                }
            }
            guard var board = best, board.canBeChanged else { return nil }
            var marks = [localBoards]
            if let folder = cloudBoards() { marks.append(folder) }
            let removedAt = marks.map { $0.appendingPathComponent(goneName(id)) }.filter(exists).map(markDate).max()
            board.changed = max(Date(), board.changed.addingTimeInterval(0.001), (removedAt ?? .distantPast).addingTimeInterval(0.002))
            clearMarks(id)
            took([board])
            var written = false
            local.sync { written = writeLocalBytes(board) }
            guard written else { return nil }
            if let folder = cloudBoards(), case .absent = readCloud(id),
               writeCloudFile(board, to: folder.appendingPathComponent(name(id))) {
                cloudStamp[id] = board.changed
            }
            return board
        }
    }

    /// The folders of the kept copies, for work that runs in line with the store's other file work
    /// (BringBack.swift: listing them, removing one board for good, reading an earlier version).
    func kept<T>(_ work: (KeptPlaces) -> T) -> T {
        cloud.sync {
            work(KeptPlaces(removed: [localRemoved] + [cloudRemoved()].compactMap { $0 }, safety: safety,
                            boards: [localBoards] + [cloudBoards()].compactMap { $0 },
                            decode: { [self] data in decode(data) }))
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
            for url in files(in: folder) {
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
