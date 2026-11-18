import Foundation

// Reading and tidying the folders of kept copies (Removed, SafetyCopies). Works on whatever folders it
// is handed, so it can be tried against a throwaway folder; the store hands it the real ones and runs
// it in line with its other file work.

/// The folders the kept copies are in, and how a board is read from its bytes.
public struct KeptPlaces: Sendable {
    /// The Removed folders: the device's, then iCloud's when there is one.
    public var removed: [URL]
    /// The device's SafetyCopies folder.
    public var safety: URL
    /// The Boards folders (the device's, then iCloud's): the marks of removed boards are in them.
    public var boards: [URL]
    public var decode: @Sendable (Data) -> Board?

    public init(removed: [URL], safety: URL, boards: [URL], decode: @escaping @Sendable (Data) -> Board?) {
        self.removed = removed
        self.safety = safety
        self.boards = boards
        self.decode = decode
    }
}

/// Everything that is kept and can be read.
public struct KeptListing: Sendable {
    /// Every readable copy in the Removed folders (several per board are possible).
    public var removed: [RemovedCopy] = []
    /// Every readable copy in SafetyCopies.
    public var versions: [EarlierVersion] = []
    /// The boards that carry a removal mark.
    public var marked: Set<UUID> = []
    /// Removed copies that have not arrived from iCloud yet (they were asked for).
    public var waiting = 0

    public init() {}
}

public enum KeptFiles {
    private static func files(in folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    }

    /// Looks through the folders. A copy is listed only when it can be read as the board its name says.
    public static func list(_ places: KeptPlaces, timeZone: TimeZone = .current) -> KeptListing {
        var found = KeptListing()
        for folder in places.removed {
            for url in files(in: folder) {
                guard let name = KeptFileName(url.lastPathComponent, timeZone: timeZone), name.kind == .removed else { continue }
                if name.waiting {
                    // Still in iCloud only: asked for, and counted so the page can say so.
                    try? FileManager.default.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(name.name))
                    found.waiting += 1
                    continue
                }
                guard let data = try? Data(contentsOf: url), let board = places.decode(data), board.id == name.id else { continue }
                found.removed.append(RemovedCopy(board: board, removed: name.kept))
            }
        }
        for url in files(in: places.safety) {
            let last = url.lastPathComponent
            if let day = KeptRules.dailyDay(last, timeZone: timeZone) {
                for file in files(in: url) {
                    guard let name = BoardFileName(file.lastPathComponent), name.kind == .board, name.copy == nil, !name.waiting,
                          let data = try? Data(contentsOf: file), let board = places.decode(data), board.id == name.id else { continue }
                    found.versions.append(EarlierVersion(path: "\(last)/\(file.lastPathComponent)", board: board, kept: day, source: .daily))
                }
            } else if let name = KeptFileName(last, timeZone: timeZone), name.isBoard, !name.waiting,
                      case let .setAside(origin) = name.kind,
                      let data = try? Data(contentsOf: url), let board = places.decode(data), board.id == name.id {
                found.versions.append(EarlierVersion(path: last, board: board, kept: name.kept, source: .setAside(origin)))
            }
        }
        for folder in places.boards {
            for url in files(in: folder) {
                guard let name = BoardFileName(url.lastPathComponent), name.kind == .removalMark else { continue }
                found.marked.insert(name.id)
            }
        }
        return found
    }

    /// One earlier version, read again from its place inside SafetyCopies. nil when it is gone or cannot be read.
    public static func read(_ version: EarlierVersion, in places: KeptPlaces) -> Board? {
        // Only ever a file inside SafetyCopies, one folder deep at most.
        let parts = version.path.split(separator: "/").map(String.init)
        guard (1...2).contains(parts.count), !parts.contains(where: { $0.hasPrefix(".") }) else { return nil }
        let file = parts.reduce(places.safety) { $0.appendingPathComponent($1) }
        guard let data = try? Data(contentsOf: file), let board = places.decode(data), board.id == version.boardID else { return nil }
        return board
    }

    /// Lets the set-aside versions (and set-aside unreadable bytes) go that are older than 30 days.
    /// The daily copies are not touched. Says how many files went.
    @discardableResult
    public static func tidy(safety: URL, now: Date, timeZone: TimeZone = .current) -> Int {
        var gone = 0
        for url in files(in: safety) {
            // 0.5: a starter's version that was written over is kept for the same 30 days.
            if let kept = StarterKept.kept(url.lastPathComponent, timeZone: timeZone) {
                if KeptRules.letGo(.setAside, kept: kept, now: now), (try? FileManager.default.removeItem(at: url)) != nil { gone += 1 }
                continue
            }
            guard let name = KeptFileName(url.lastPathComponent, timeZone: timeZone), !name.waiting,
                  case .setAside = name.kind, KeptRules.letGo(.setAside, kept: name.kept, now: now) else { continue }
            if (try? FileManager.default.removeItem(at: url)) != nil { gone += 1 }
        }
        return gone
    }

    /// Removes one board for good: every copy of THAT board in the Removed folders, nothing else.
    /// Says how many files went.
    @discardableResult
    public static func removeForGood(_ id: UUID, in folders: [URL], timeZone: TimeZone = .current) -> Int {
        var gone = 0
        for folder in folders {
            for url in files(in: folder) {
                guard let name = KeptFileName(url.lastPathComponent, timeZone: timeZone), name.kind == .removed, name.id == id else { continue }
                var problem: NSError?
                NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &problem) { place in
                    if (try? FileManager.default.removeItem(at: place)) != nil { gone += 1 }
                }
            }
        }
        return gone
    }
}
