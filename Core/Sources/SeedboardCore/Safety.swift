import Foundation

// The rules that keep boards safe between devices, as plain decisions: no files, no screens.
// The store (BoardStore.swift) reads and writes the files and asks these rules what to do.

// MARK: - File names

/// What a file in a Boards folder is, read from its name alone.
///
/// - `<id>.seedboard` — a board.
/// - `<id> 2.seedboard` (any number) — a copy iCloud made by itself when two devices wrote at once.
/// - `<id>.gone` — the mark that says the board was removed.
/// - `.<name>.icloud` — any of the above that has not arrived from iCloud yet.
public struct BoardFileName: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case board, removalMark }

    public var id: UUID
    public var kind: Kind
    /// 2 for "<id> 2.seedboard"; nil for the board's own file.
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
        guard let dot = real.lastIndex(of: ".") else { return nil }
        let stem = String(real[real.startIndex..<dot])
        switch String(real[real.index(after: dot)...]) {
        case "seedboard": kind = .board
        case "gone": kind = .removalMark
        default: return nil
        }
        if let id = UUID(uuidString: stem) {
            self.id = id
            copy = nil
        } else if let space = stem.lastIndex(of: " "),
                  let id = UUID(uuidString: String(stem[stem.startIndex..<space])),
                  let number = Int(stem[stem.index(after: space)...]), number >= 2 {
            self.id = id
            copy = number
        } else {
            return nil
        }
        self.waiting = waiting
        name = real
    }
}

// MARK: - The removal mark

/// The small file `<id>.gone` that says "this board was removed", so the removal reaches every device.
/// It carries WHEN the board was removed, so a change made after that can win and bring the board back.
public enum RemovalMark {
    private static let fine: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain = ISO8601DateFormatter()

    /// The mark's contents: `{"removed":"2026-11-18T09:15:00.123Z"}`.
    public static func data(removedAt: Date) -> Data {
        Data("{\"removed\":\"\(fine.string(from: removedAt))\"}\n".utf8)
    }

    /// When the board was removed. An old mark is empty: it counts as "removed at the mark file's date".
    /// nil when neither is known.
    public static func removedAt(from data: Data?, fileDate: Date?) -> Date? {
        if let data, !data.isEmpty,
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = object["removed"] as? String,
           let date = fine.date(from: text) ?? plain.date(from: text) {
            return date
        }
        return fileDate
    }

    /// The time to write into a new mark: now, and always later than the board's last change
    /// (even when this device's clock runs behind the one that made the change).
    public static func time(now: Date, lastChange: Date?) -> Date {
        guard let lastChange else { return now }
        return max(now, lastChange.addingTimeInterval(0.002))
    }
}

// MARK: - Decisions

/// The stamps of the versions a board on this device grew from: every version the app showed, and
/// every version it saved. A stored version that is NOT among them was written by another device
/// and never seen here, so it must be kept before anything is written over it.
public struct Lineage: Sendable {
    private var stamps: [Date] = []
    /// Plenty for a long day of work on one board; older stamps are let go.
    public static let most = 600

    public init() {}

    public mutating func add(_ stamp: Date) {
        if holds(stamp) { return }
        stamps.append(stamp)
        if stamps.count > Lineage.most { stamps.removeFirst(stamps.count - Lineage.most) }
    }

    public func holds(_ stamp: Date) -> Bool {
        stamps.contains { SafetyRules.sameMoment($0, stamp) }
    }
}

public enum SafetyRules {
    /// Times are written to the file to the thousandth of a second, so two stamps this close are the same version.
    public static func sameMoment(_ a: Date, _ b: Date) -> Bool {
        abs(a.timeIntervalSince(b)) < 0.0015
    }

    /// Of two versions of one board: does `a` win over `b`?
    /// The one this version of the app cannot change (a newer app wrote it) stays; otherwise the newer change wins.
    public static func wins(_ a: Board, over b: Board) -> Bool {
        if a.canBeChanged != b.canBeChanged { return !a.canBeChanged }
        return a.changed > b.changed
    }

    // News from another device

    public enum News: Equatable, Sendable {
        /// Not newer than what is shown: nothing to do.
        case ignore
        /// Shown at once.
        case take
        /// The owner is typing or dragging in that board: kept aside, and offered again the moment he stops.
        case hold
    }

    /// A version of a board that is already in the list arrived from another device.
    public static func news(incoming: Date, shown: Date, busy: Bool) -> News {
        guard incoming > shown, !sameMoment(incoming, shown) else { return .ignore }
        return busy ? .hold : .take
    }

    // Writing over a stored version

    public enum Write: Equatable, Sendable {
        /// Nothing in the way, or the stored version is one this board grew from.
        case write
        /// The stored version was never seen here: it goes to the safety copies first, then mine is written.
        case keepStoredThenWrite
        /// The stored version is the newer one: it stays, and mine goes to the safety copies.
        case storedStays
        /// The same version is stored already.
        case nothing
        /// Never written: a newer app made the stored version, or mine cannot be changed by this version.
        case refuse
    }

    /// What to do before `mine` is written where `stored` is now.
    /// `storedIsSame`: both are the same version. `inLineage`: the stored version is one this board grew from.
    public static func write(mine: Board, stored: Board?, storedIsSame: Bool, inLineage: Bool) -> Write {
        guard mine.canBeChanged else { return .refuse }
        guard let stored else { return .write }
        guard stored.canBeChanged else { return .refuse }
        if storedIsSame { return .nothing }
        if stored.changed > mine.changed { return .storedStays }
        return inLineage ? .write : .keepStoredThenWrite
    }

    // Removed boards

    public enum Removal: Equatable, Sendable { case staysRemoved, comesBack }

    /// A board has a removal mark. A version changed AFTER the removal wins: the board comes back
    /// on every device and the mark is cleared. Otherwise the board stays removed.
    public static func removal(removedAt: Date, lastChange: Date?) -> Removal {
        guard let lastChange, lastChange > removedAt, !sameMoment(lastChange, removedAt) else { return .staysRemoved }
        return .comesBack
    }
}

// MARK: - Links in

/// `seedboard://board/<id>`: the link a PARAGON note carries back to its board.
public enum BoardLink {
    public static func id(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == "seedboard", url.host?.lowercased() == "board" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    public enum Answer: Equatable, Sendable {
        /// The boards are not loaded yet: the link is held and followed once they are.
        case hold
        case open
        /// The board was removed on that day.
        case removed(Date)
        /// Not on this device (yet): the link is held, and the board opens if iCloud brings it.
        case missing
    }

    public static func answer(loaded: Bool, onDevice: Bool, removedAt: Date?) -> Answer {
        guard loaded else { return .hold }
        if onDevice { return .open }
        if let removedAt { return .removed(removedAt) }
        return .missing
    }

    /// "This board was removed on 18 Nov 2026."
    public static func removedLine(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = timeZone
        f.dateFormat = "d MMM yyyy"
        return "This board was removed on \(f.string(from: date))."
    }
}
