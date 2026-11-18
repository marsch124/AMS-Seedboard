import Foundation

// Removed boards and earlier versions: what is kept, for how long, what the page shows and how a
// copy comes back. Plain decisions only; the folders are read in KeptFiles.swift.

/// Where a set-aside version came from, as far as the device could tell when it kept it.
public enum SetAsideOrigin: String, Equatable, Sendable {
    /// The version this device had (it was shown or saved here).
    case here
    /// A version another device wrote that was never shown on this one.
    case away
}

/// The name of a kept file, read from the name alone.
///
/// - `Removed/<id>-<yyyyMMdd-HHmmss>.seedboard` — a removed board, with the moment it was moved there.
/// - `SafetyCopies/<id>-<yyyyMMdd-HHmmss>-<6 letters>.seedboard` — a version that was set aside.
/// - `SafetyCopies/<id>-<yyyyMMdd-HHmmss>-<6 letters>-here.seedboard` (or `-away`) — the same, saying where it came from.
/// - the ending `.unreadable` — set-aside bytes that are not a board.
/// - `.<name>.icloud` — any of the above that has not arrived from iCloud yet.
public struct KeptFileName: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case removed
        case setAside(SetAsideOrigin?)
    }

    public var id: UUID
    public var kind: Kind
    /// When the file was put there (read from its name; the file's own date still says when the board was changed).
    public var kept: Date
    /// False for the ending `.unreadable`.
    public var isBoard: Bool
    /// The file has not arrived from iCloud yet.
    public var waiting: Bool
    /// The file's real name, without iCloud's wrapping.
    public var name: String

    public init?(_ fileName: String, timeZone: TimeZone = .current) {
        var real = fileName
        var waiting = false
        if real.hasPrefix("."), real.hasSuffix(".icloud") {
            real = String(real.dropFirst().dropLast(".icloud".count))
            waiting = true
        }
        guard let dot = real.lastIndex(of: ".") else { return nil }
        switch String(real[real.index(after: dot)...]) {
        case "seedboard": isBoard = true
        case "unreadable": isBoard = false
        default: return nil
        }
        let stem = String(real[real.startIndex..<dot])
        // A board's identity is 36 letters long; a "-" and the stamp follow.
        guard stem.count > 37, let id = UUID(uuidString: String(stem.prefix(36))) else { return nil }
        let rest = stem.dropFirst(36)
        guard rest.first == "-" else { return nil }
        let parts = rest.dropFirst().split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, let date = KeptRules.stamp(timeZone).date(from: parts[0] + "-" + parts[1]) else { return nil }
        switch parts.count {
        case 2:
            guard isBoard else { return nil }
            kind = .removed
        case 3:
            kind = .setAside(nil)
        case 4:
            kind = .setAside(SetAsideOrigin(rawValue: parts[3]))
        default:
            return nil
        }
        self.id = id
        self.kept = date
        self.waiting = waiting
        name = real
    }

    /// The end of a set-aside file's name that says where the version came from ("-away"; nothing when unknown).
    public static func ending(for origin: SetAsideOrigin?) -> String {
        origin.map { "-" + $0.rawValue } ?? ""
    }
}

/// One readable copy of a removed board in a Removed folder.
public struct RemovedCopy: Equatable, Sendable, Identifiable {
    public var board: Board
    /// When this copy was moved to the Removed folder: its 30 days count from here.
    public var removed: Date

    public var id: UUID { board.id }

    public init(board: Board, removed: Date) {
        self.board = board
        self.removed = removed
    }
}

/// One readable earlier version of a board in SafetyCopies.
public struct EarlierVersion: Equatable, Sendable, Identifiable {
    public enum Source: Equatable, Sendable {
        /// The copy of all boards made once a day (14 days back).
        case daily
        /// A version that lost against another, or was about to be written over.
        case setAside(SetAsideOrigin?)
    }

    /// The copy's place inside SafetyCopies ("2026-11-17/<id>.seedboard", or the set-aside file's name).
    public var path: String
    public var boardID: UUID
    public var title: String
    /// "12 ideas · 5 shapes".
    public var counts: String
    /// The version's own date: when this version of the board was last changed.
    public var changed: Date
    /// When the copy was made.
    public var kept: Date
    public var source: Source

    public var id: String { path }

    public init(path: String, boardID: UUID, title: String, counts: String, changed: Date, kept: Date, source: Source) {
        self.path = path
        self.boardID = boardID
        self.title = title
        self.counts = counts
        self.changed = changed
        self.kept = kept
        self.source = source
    }

    public init(path: String, board: Board, kept: Date, source: Source) {
        self.init(path: path, boardID: board.id, title: board.title, counts: board.countLine,
                  changed: board.changed, kept: kept, source: source)
    }
}

/// The earlier versions of one board, as the page lists them.
public struct VersionGroup: Equatable, Sendable, Identifiable {
    public enum State: Equatable, Sendable {
        /// The board is in the list.
        case inList
        /// The board is among the removed ones (it can be brought back).
        case removed
        /// The board is nowhere else: these copies are all that is left of it.
        case lost
    }

    public var boardID: UUID
    public var title: String
    public var state: State
    /// Newest first.
    public var versions: [EarlierVersion]
    /// Older versions of this device's own that are kept but not listed (see `KeptRules.mostOwn`).
    public var hidden = 0

    public var id: UUID { boardID }

    /// "3 earlier versions".
    public var countLine: String {
        versions.count == 1 ? "1 earlier version" : "\(versions.count) earlier versions"
    }
}

public enum KeptRules {
    /// Removed boards and set-aside versions are kept this many days.
    public static let keepDays = 30
    /// Every time another device's change arrives, this device's version before it is set aside. Of
    /// those only the newest few are listed per board; daily copies and other devices' versions all are.
    public static let mostOwn = 10

    // MARK: How long

    /// Whole days until a removed board is let go for good: 30 on the day it was removed, never below 0.
    public static func daysLeft(since kept: Date, now: Date) -> Int {
        let left = Double(keepDays) - now.timeIntervalSince(kept) / 86_400
        return max(0, Int(left.rounded(.up)))
    }

    public enum Copy: Equatable, Sendable { case removed, setAside, daily }

    /// The tidy decision: is this copy let go now? Removed boards and set-aside versions after 30 days;
    /// the daily copies never by this rule (the store keeps the newest 14 days of them).
    public static func letGo(_ kind: Copy, kept: Date, now: Date) -> Bool {
        switch kind {
        case .daily: return false
        case .removed, .setAside: return now.timeIntervalSince(kept) > Double(keepDays) * 86_400
        }
    }

    // MARK: Which copy

    /// Of all copies in the Removed folders (the device's and iCloud's): one per board, the newest.
    /// Newest = the version changed last; of two copies of the same version, the one removed last.
    /// The list comes most recently removed first.
    public static func newest(_ copies: [RemovedCopy]) -> [RemovedCopy] {
        var best: [UUID: RemovedCopy] = [:]
        for copy in copies {
            guard let now = best[copy.id] else {
                best[copy.id] = copy
                continue
            }
            if SafetyRules.sameMoment(copy.board.changed, now.board.changed) {
                if copy.removed > now.removed { best[copy.id] = copy }
            } else if copy.board.changed > now.board.changed {
                best[copy.id] = copy
            }
        }
        return best.values.sorted {
            $0.removed != $1.removed ? $0.removed > $1.removed : $0.board.title.lowercased() < $1.board.title.lowercased()
        }
    }

    /// The rows of "Removed": the newest copy of every board that is not in the list now.
    /// (A board that was brought back leaves its old copies in the folder until their 30 days are over.)
    public static func removedRows(_ copies: [RemovedCopy], present: Set<UUID>) -> [RemovedCopy] {
        newest(copies.filter { !present.contains($0.id) })
    }

    /// The earlier versions, board by board. A version is listed once (the same version kept twice is one row,
    /// said by the copy that knows most about where it came from); a copy that is the board as it stands
    /// now (or the removed copy itself) is not an EARLIER version and is left out.
    /// A board that was removed for good (its mark is there, no removed copy is left) is not listed.
    public static func groups(versions: [EarlierVersion], boards: [Board], removed: [RemovedCopy],
                              marked: Set<UUID>) -> [VersionGroup] {
        let inList = boards.reduce(into: [UUID: Board]()) { $0[$1.id] = $1 }
        let gone = newest(removed).reduce(into: [UUID: RemovedCopy]()) { $0[$1.id] = $1 }
        var groups: [VersionGroup] = []
        for (id, all) in Dictionary(grouping: versions, by: \.boardID) {
            let state: VersionGroup.State
            let title: String
            let current: Date?
            if let board = inList[id] {
                (state, title, current) = (.inList, board.title, board.changed)
            } else if let copy = gone[id] {
                (state, title, current) = (.removed, copy.board.title, copy.board.changed)
            } else if marked.contains(id) {
                continue
            } else {
                (state, title, current) = (.lost, all.max { $0.changed < $1.changed }?.title ?? "Board", nil)
            }
            var rows: [EarlierVersion] = []
            for version in all.sorted(by: { rank($0) != rank($1) ? rank($0) > rank($1) : $0.kept > $1.kept }) {
                if let current, SafetyRules.sameMoment(version.changed, current) { continue }
                if rows.contains(where: { SafetyRules.sameMoment($0.changed, version.changed) }) { continue }
                rows.append(version)
            }
            guard !rows.isEmpty else { continue }
            rows.sort { $0.changed > $1.changed }
            var own = 0
            let shown = rows.filter { version in
                guard version.source == .setAside(.here) else { return true }
                own += 1
                return own <= mostOwn
            }
            groups.append(VersionGroup(boardID: id, title: title, state: state, versions: shown, hidden: rows.count - shown.count))
        }
        func order(_ state: VersionGroup.State) -> Int {
            switch state {
            case .inList: return 0
            case .removed: return 1
            case .lost: return 2
            }
        }
        return groups.sorted {
            order($0.state) != order($1.state) ? order($0.state) < order($1.state) : $0.title.lowercased() < $1.title.lowercased()
        }
    }

    /// How much a copy knows about where it came from.
    private static func rank(_ version: EarlierVersion) -> Int {
        switch version.source {
        case .setAside(.some): return 2
        case .setAside(.none): return 1
        case .daily: return 0
        }
    }

    // MARK: Coming back

    /// The name of a board opened from an earlier version: "Title (version from 18 Nov 10:00)".
    /// Never a name that is taken ("… 2", "… 3").
    public static func copyTitle(_ title: String, version: Date, now: Date = Date(), taken: Set<String> = [],
                                 timeZone: TimeZone = .current) -> String {
        let base = "\(title) (version from \(dayTime(version, now: now, timeZone: timeZone)))"
        let used = Set(taken.map { $0.lowercased() })
        var name = base
        var n = 2
        while used.contains(name.lowercased()) {
            name = "\(base) \(n)"
            n += 1
        }
        return name
    }

    /// An earlier version as a NEW board: its own identity, the copy's name, changed now, not pinned,
    /// not sent anywhere. It never replaces the board it is a version of.
    public static func asCopy(_ version: Board, now: Date = Date(), taken: Set<String> = [],
                              timeZone: TimeZone = .current) -> Board {
        var copy = version
        copy.id = UUID()
        copy.title = copyTitle(version.title, version: version.changed, now: now, taken: taken, timeZone: timeZone)
        copy.created = now
        copy.changed = now
        copy.pinned = false
        copy.sent = nil
        copy.sentTodos = []
        copy.sentTasks = []
        return copy
    }

    // MARK: Words

    /// "removed 12 Nov · 18 days left".
    public static func removedLine(removed: Date, now: Date, timeZone: TimeZone = .current) -> String {
        let left = daysLeft(since: removed, now: now)
        let words = left == 0 ? "last day" : (left == 1 ? "1 day left" : "\(left) days left")
        return "removed \(day(removed, now: now, timeZone: timeZone)) · \(words)"
    }

    /// "from another device, 18 Nov 10:00" — where a version came from, and the version's own date.
    public static func sourceLine(_ version: EarlierVersion, now: Date, timeZone: TimeZone = .current) -> String {
        let from: String
        switch version.source {
        case .daily: from = "daily copy"
        case .setAside(.away): from = "from another device"
        case .setAside(.here): from = "this device's version"
        case .setAside(.none): from = "set aside"
        }
        return "\(from), \(dayTime(version.changed, now: now, timeZone: timeZone))"
    }

    /// "Another device changed “Title”. The other version is kept under Earlier versions."
    public static func clashLine(_ title: String) -> String {
        "Another device changed “\(title)”. The other version is kept under Earlier versions."
    }

    /// "18 Nov"; with the year when it is not this year's.
    public static func day(_ date: Date, now: Date, timeZone: TimeZone = .current) -> String {
        words(date, now: now, timeZone: timeZone, time: false)
    }

    /// "18 Nov 10:00"; with the year when it is not this year's.
    public static func dayTime(_ date: Date, now: Date, timeZone: TimeZone = .current) -> String {
        words(date, now: now, timeZone: timeZone, time: true)
    }

    private static func words(_ date: Date, now: Date, timeZone: TimeZone, time: Bool) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = timeZone
        f.dateFormat = (sameYear ? "d MMM" : "d MMM yyyy") + (time ? " HH:mm" : "")
        return f.string(from: date)
    }

    // MARK: Stamps in file names

    /// "20261118-091500", as the store writes it into the names of kept files.
    static func stamp(_ timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        return f
    }

    /// The day a daily safety copy was made, from its folder's name ("2026-11-17"); nil for any other name.
    public static func dailyDay(_ folderName: String, timeZone: TimeZone = .current) -> Date? {
        guard folderName.count == 10 else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        return f.date(from: folderName)
    }
}
