import Foundation

// 0.5, data safety for starters (panel findings 1, 2, 3 and 9). Plain rules and small file helpers that work on
// whatever folder they are handed, so each can be tried against a throwaway folder. The app's `StarterStore`
// hands them the real ones.

// MARK: - A starter that is being changed (finding 1)

/// The working copy of a starter that is being changed, kept on THIS device only while the change is open:
/// `Starters/<id>.working` in Application Support, never in iCloud. If the app is stopped in the middle, the
/// work is opened again at the next start. Its field is called `starter`, not `id`, so the file can never be
/// read as a starter itself.
public struct StarterWorking: Codable, Equatable, Sendable {
    /// The starter's id (a built-in's word such as "mindMap", or an own starter's UUID).
    public var starter: String
    /// The name as it will be saved.
    public var name: String
    public var board: Board
    /// When this copy was written.
    public var when: Date

    public init(starter: String, name: String, board: Board, when: Date = Date()) {
        self.starter = starter
        self.name = name
        self.board = board
        self.when = when
    }

    public static let ending = "working"

    public static func fileName(_ starter: String) -> String { "\(starter).\(ending)" }

    /// Writes the working copy into the folder. False when it could not be written.
    @discardableResult
    public func write(in folder: URL) -> Bool {
        guard PictureKeeping.isPlainName(starter), let bytes = try? JSONEncoder().encode(self) else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Only ever one change is open: an older working copy of another starter goes.
        for url in StarterWorking.files(in: folder) where url.lastPathComponent != StarterWorking.fileName(starter) {
            try? FileManager.default.removeItem(at: url)
        }
        return (try? bytes.write(to: folder.appendingPathComponent(StarterWorking.fileName(starter)), options: .atomic)) != nil
    }

    /// The working copy that waits in the folder (the newest, should there be two); nil when there is none.
    public static func waiting(in folder: URL) -> StarterWorking? {
        files(in: folder)
            .compactMap { try? JSONDecoder().decode(StarterWorking.self, from: Data(contentsOf: $0)) }
            .max { $0.when < $1.when }
    }

    /// The change has ended (Save, Cancel, or it was left): no working copy stays behind.
    public static func clear(in folder: URL) {
        for url in files(in: folder) { try? FileManager.default.removeItem(at: url) }
    }

    private static func files(in folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == ending }
    }

    /// The board to go on with. A timeline moves by whole days, so the plan sits as far from today as it did
    /// when the work was stopped (as `StarterShelf.workingBoard` does).
    public func board(now: Date) -> Board {
        var b = board
        StarterShelf.move(&b, byDays: b.isTimeline ? Day(now) - Day(when) : 0)
        return b
    }
}

// MARK: - The files of the starters (finding 3)

/// What a file in a Starters folder is, read from its name alone.
///
/// - `<id>.seedstarter` — a starter.
/// - `<id> 2.seedstarter` (any number) — a copy iCloud made by itself when two devices wrote at once.
/// - `.<name>.icloud` — either of the above that has not arrived from iCloud yet.
public struct StarterFileName: Equatable, Sendable {
    public static let ending = "seedstarter"

    public var id: String
    /// 2 for "<id> 2.seedstarter"; nil for the starter's own file.
    public var copy: Int?
    /// The file has not arrived from iCloud yet (it shows as ".<name>.icloud").
    public var waiting: Bool
    /// The file's real name, without iCloud's wrapping.
    public var name: String

    public init?(_ fileName: String) {
        var real = fileName
        var waiting = false
        if real.hasPrefix("."), real.hasSuffix(".icloud") {
            real = String(real.dropFirst().dropLast(".icloud".count))
            waiting = true
        }
        let end = "." + StarterFileName.ending
        guard real.hasSuffix(end), !real.hasPrefix(".") else { return nil }
        let stem = String(real.dropLast(end.count))
        guard !stem.isEmpty else { return nil }
        if let space = stem.lastIndex(of: " "), space != stem.startIndex,
           let number = Int(stem[stem.index(after: space)...]), number >= 2 {
            id = String(stem[stem.startIndex..<space])
            copy = number
        } else {
            id = stem
            copy = nil
        }
        self.waiting = waiting
        name = real
    }
}

/// Making the device and iCloud level, as a plain decision.
public enum StarterLevelling {
    public struct Plan: Equatable, Sendable {
        /// The newest of everything that could be read, per starter.
        public var best: [String: StarterEntry]
        /// The starters whose device file is to be replaced by `best`.
        public var toDevice: Set<String>
        /// The starters whose own iCloud file is to be replaced by `best`.
        public var toCloud: Set<String>
    }

    /// - `device`: what the device's files hold.
    /// - `cloudMain`: what each starter's OWN iCloud file holds.
    /// - `cloudOthers`: what was read from iCloud's own copies ("<id> 2.seedstarter") and from versions iCloud parked.
    /// - `held`: the starters of which something in iCloud could NOT be read (not arrived yet, or unreadable).
    ///   Nothing of theirs is ever written to iCloud: an older copy from this device must never land on a newer
    ///   one that is still on its way.
    /// Of two copies the newer wins (`StarterEntry.newer`), whichever file it was in.
    public static func plan(device: [String: StarterEntry], cloudMain: [String: StarterEntry],
                            cloudOthers: [StarterEntry] = [], held: Set<String> = [], cloudOn: Bool = true) -> Plan {
        var best = device
        for entry in cloudMain.values.sorted(by: { $0.id < $1.id }) + cloudOthers {
            best[entry.id] = best[entry.id].map { StarterEntry.newer($0, entry) } ?? entry
        }
        var plan = Plan(best: best, toDevice: [], toCloud: [])
        for (id, entry) in best {
            if device[id] != entry { plan.toDevice.insert(id) }
            if cloudOn, !held.contains(id), cloudMain[id] != entry { plan.toCloud.insert(id) }
        }
        return plan
    }
}

// MARK: - A starter version that was written over (finding 2)

/// A starter's file that was about to be replaced by another version with a different board is kept in
/// SafetyCopies as `starter-<id>-<yyyyMMdd-HHmmss>-<6 letters>.seedstarter`, for 30 days.
public enum StarterKept {
    /// Is the stored version worth keeping before `new` is written over it? Only when it has a board of its own
    /// and that board is not the one that is about to be stored.
    public static func keepAside(stored: StarterEntry?, new: StarterEntry) -> Bool {
        guard let old = stored?.board else { return false }
        return old != new.board
    }

    public static func name(id: String, at date: Date, tag: String = String(UUID().uuidString.prefix(6)),
                            timeZone: TimeZone = .current) -> String {
        "starter-\(id)-\(KeptRules.stamp(timeZone).string(from: date))-\(tag).\(StarterFileName.ending)"
    }

    /// When a kept starter file was put there, read from its name; nil for any other file.
    public static func kept(_ fileName: String, timeZone: TimeZone = .current) -> Date? {
        let end = "." + StarterFileName.ending
        guard fileName.hasPrefix("starter-"), fileName.hasSuffix(end) else { return nil }
        let parts = fileName.dropLast(end.count).split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        // … -<yyyyMMdd>-<HHmmss>-<tag>
        guard parts.count >= 5 else { return nil }
        return KeptRules.stamp(timeZone).date(from: parts[parts.count - 3] + "-" + parts[parts.count - 2])
    }
}

// MARK: - Two lines of work (finding 9)

/// The two lines of work of a store: the device's files on one, everything that talks to iCloud on the other,
/// so a device write never waits behind iCloud. `flush` waits for the device line only, two seconds at most,
/// and not at all when nothing was handed over since the last time.
public final class StoreLines: @unchecked Sendable {
    public let device: DispatchQueue
    public let cloud: DispatchQueue
    private let lock = NSLock()
    private var waitingWork = false

    public init(label: String) {
        device = DispatchQueue(label: label + ".device")
        cloud = DispatchQueue(label: label + ".icloud")
    }

    /// Work on the device's files.
    public func onDevice(_ work: @escaping () -> Void) {
        lock.lock(); waitingWork = true; lock.unlock()
        device.async(execute: work)
    }

    /// Work that reads or writes iCloud's folder. It may take as long as iCloud likes; nothing waits for it.
    public func inCloud(_ work: @escaping () -> Void) {
        cloud.async(execute: work)
    }

    /// Waits until everything handed to `onDevice` is done, `limit` seconds at most. True when it is done
    /// (or there was nothing to wait for).
    @discardableResult
    public func flush(limit: TimeInterval = 2) -> Bool {
        lock.lock()
        let needed = waitingWork
        waitingWork = false
        lock.unlock()
        guard needed else { return true }
        let done = DispatchSemaphore(value: 0)
        device.async { done.signal() }
        if done.wait(timeout: .now() + limit) == .success { return true }
        lock.lock(); waitingWork = true; lock.unlock()
        return false
    }
}
