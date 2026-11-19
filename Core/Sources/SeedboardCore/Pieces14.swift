import Foundation
import CoreGraphics

// 0.14, ideas 22 and 27. The rules of the brainstorm timer (left words, the ring) and of saved pieces
// (cut out of a board, kept on a shelf like own starters, dropped into a board with new ids).
// Nothing here knows about files or the screen.

// MARK: - 22 The brainstorm timer

public enum BrainstormTimer {
    /// The lengths offered before it starts, in minutes.
    public static let minutes = [5, 10]
    /// How long "Time!" stays in the pill, in seconds.
    public static let timeShown = 4.0

    /// Whole seconds left (never below 0); a part of a second counts as a whole one, so the pill never says
    /// "0:00 left" before the end.
    public static func secondsLeft(total: TimeInterval, elapsed: TimeInterval) -> Int {
        guard total > 0 else { return 0 }
        return max(0, Int((total - max(elapsed, 0)).rounded(.up)))
    }

    /// "4:12 left".
    public static func leftWords(total: TimeInterval, elapsed: TimeInterval) -> String {
        let s = secondsLeft(total: total, elapsed: elapsed)
        return "\(s / 60):" + (s % 60 < 10 ? "0" : "") + "\(s % 60) left"
    }

    /// How much of the ring is filled, 0 to 1.
    public static func filled(total: TimeInterval, elapsed: TimeInterval) -> Double {
        guard total > 0 else { return 1 }
        return min(max(elapsed / total, 0), 1)
    }

    public static func isOver(total: TimeInterval, elapsed: TimeInterval) -> Bool { elapsed >= total }

    /// "Time!" is still shown this long after the end.
    public static func showsTimeUp(total: TimeInterval, elapsed: TimeInterval) -> Bool {
        isOver(total: total, elapsed: elapsed) && elapsed < total + timeShown
    }

    /// The whole pill is gone.
    public static func isFinished(total: TimeInterval, elapsed: TimeInterval) -> Bool {
        elapsed >= total + timeShown
    }
}

// MARK: - 27 Saved pieces

/// One saved piece: the things with the arrows between them, kept like an own starter.
public struct PieceEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var order: Double
    public var clip: Clip
    public var removed: Bool
    public var removedWhen: Date?
    public var changed: Date

    public init(id: String = UUID().uuidString, name: String, order: Double = 0, clip: Clip, removed: Bool = false,
                removedWhen: Date? = nil, changed: Date = Date()) {
        self.id = id
        self.name = name
        self.order = order
        self.clip = clip
        self.removed = removed
        self.removedWhen = removedWhen
        self.changed = changed
    }

    private enum CodingKeys: String, CodingKey { case id, name, order, clip, removed, removedWhen, changed }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Piece"
        order = (try? c.decode(Double.self, forKey: .order)) ?? 0
        clip = try c.decode(Clip.self, forKey: .clip)
        removed = (try? c.decode(Bool.self, forKey: .removed)) ?? false
        removedWhen = try? c.decode(Date.self, forKey: .removedWhen)
        changed = (try? c.decode(Date.self, forKey: .changed)) ?? Date(timeIntervalSince1970: 0)
    }

    /// The small count line under the name: "5 ideas" when all are ideas, else "5 things".
    public var countLine: String { PieceEntry.countLine(of: clip) }

    public static func countLine(of clip: Clip) -> String {
        let n = clip.items.count
        let word = clip.isOnlyIdeas ? "idea" : "thing"
        return "\(n) \(word)" + (n == 1 ? "" : "s")
    }

    /// Of two copies of the same piece (two devices): the later `changed` wins.
    public static func newer(_ a: PieceEntry, _ b: PieceEntry) -> PieceEntry { b.changed > a.changed ? b : a }
}

public struct PieceShelf: Equatable, Sendable {
    /// Days after which a removed piece's file may go.
    public static let keepRemoved = 30
    public static let ending = "seedpiece"

    public private(set) var entries: [String: PieceEntry]

    public init(entries: [PieceEntry] = []) {
        var map: [String: PieceEntry] = [:]
        for e in entries { map[e.id] = map[e.id].map { PieceEntry.newer($0, e) } ?? e }
        self.entries = map
    }

    /// The pieces not removed, in the order they were saved.
    public var shown: [PieceEntry] {
        entries.values.filter { !$0.removed }.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    public func piece(_ id: String) -> PieceEntry? { entries[id] }

    /// The entries that changed against `before` (what the store writes).
    public func changes(since before: PieceShelf) -> [PieceEntry] {
        entries.values.filter { before.entries[$0.id] != $0 }
    }

    /// The things to keep from a board: the chosen ones with the arrows between them, and a mind-map branch's
    /// children. nil when nothing can be kept (nothing chosen, a timeline or "Who does what" board).
    public static func cut(from board: Board, chosen: Set<UUID>) -> Clip? {
        guard !board.placesItself, !chosen.isEmpty else { return nil }
        let clip = board.clip(of: chosen)
        return clip.isEmpty ? nil : clip
    }

    /// A name no shown piece has yet: "Name", else "Name 2" …
    public func freeName(_ wanted: String, ignoring id: String? = nil) -> String {
        let base = wanted.trimmingCharacters(in: .whitespacesAndNewlines)
        let taken = Set(shown.filter { $0.id != id }.map { $0.name.lowercased() })
        var name = base, n = 2
        while taken.contains(name.lowercased()) { name = "\(base) \(n)"; n += 1 }
        return name
    }

    /// Keeps a clip as a piece; it goes last. Returns its id, nil when the name is empty or the clip is empty.
    @discardableResult
    public mutating func save(_ clip: Clip, name: String, now: Date = Date()) -> String? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clip.isEmpty else { return nil }
        let id = UUID().uuidString
        let last = (entries.values.map(\.order).max() ?? -1) + 1
        entries[id] = PieceEntry(id: id, name: freeName(clean), order: last, clip: clip, changed: now)
        return id
    }

    public mutating func rename(_ id: String, name: String, now: Date = Date()) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, var e = entries[id] else { return }
        e.name = freeName(clean, ignoring: id)
        e.changed = max(now, e.changed.addingTimeInterval(0.001))
        entries[id] = e
    }

    public mutating func remove(_ id: String, now: Date = Date()) {
        guard var e = entries[id] else { return }
        e.removed = true
        e.removedWhen = now
        e.changed = max(now, e.changed.addingTimeInterval(0.001))
        entries[id] = e
    }

    /// Removed pieces more than 30 days ago: their files may be deleted.
    public func purgeable(now: Date = Date()) -> [String] {
        entries.values.filter {
            $0.removed && ($0.removedWhen ?? $0.changed) < now.addingTimeInterval(-Double(PieceShelf.keepRemoved) * 86_400)
        }.map(\.id)
    }

    public mutating func purge(now: Date = Date()) {
        for id in purgeable(now: now) { entries[id] = nil }
    }

    /// Drops a copy of the piece into the board, its middle at `point`, with new ids everywhere (the arrows
    /// follow). Returns what was dropped and can be chosen; empty when it cannot be dropped.
    @discardableResult
    public static func drop(_ piece: PieceEntry, into board: inout Board, at point: CGPoint) -> Set<UUID> {
        board.paste(piece.clip, at: point)
    }
}

/// The names of a piece's files, as the starters' are: `<id>.seedpiece`.
public enum PieceFileName {
    public static func id(of fileName: String) -> String? {
        let end = "." + PieceShelf.ending
        guard fileName.hasSuffix(end), !fileName.hasPrefix(".") else { return nil }
        let stem = String(fileName.dropLast(end.count))
        return stem.isEmpty || stem.contains(" ") ? nil : stem
    }
}
