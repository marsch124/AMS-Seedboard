import Foundation

// 0.14, the safety lane: small rules the app asks, kept here so each can be tested.

/// 0.14 (idea 7): "Share as picture" never makes a picture of more than about 100 million pixels.
public enum PictureLimit {
    public static let mostPixels = 100_000_000.0

    /// The scale a picture of this many points is drawn at: `wanted` (2 for sharp words, 1 for a large board),
    /// or smaller when that would pass `mostPixels`. `smaller` = it was cut and the share page says "Shown smaller".
    public static func scale(width: Double, height: Double, wanted: Double) -> (scale: Double, smaller: Bool) {
        let area = max(width, 1) * max(height, 1)
        guard area * wanted * wanted > mostPixels else { return (wanted, false) }
        return ((mostPixels / area).squareRoot(), true)
    }

    /// The scale a board of this size is drawn at today: 2, or 1 above 3,000 points, then cut by `mostPixels`.
    public static func boardScale(width: Double, height: Double) -> (scale: Double, smaller: Bool) {
        scale(width: width, height: height, wanted: max(width, height) > 3000 ? 1 : 2)
    }

    public static let smallerLine = "Shown smaller"
}

/// 0.14 (idea 8): a very large page of a PDF is drawn in strips, one after the other.
public enum PageStrips {
    public struct Strip: Equatable, Sendable {
        public var y: Double
        public var height: Double
    }

    /// One strip for an ordinary page; four (top to bottom, no gap) when the board is shrunk four times or more
    /// to fit the paper, or has more than 500 things.
    public static func strips(paperHeight: Double, scale: Double, items: Int) -> [Strip] {
        guard scale < 0.25 || items > 500, paperHeight >= 40 else { return [Strip(y: 0, height: paperHeight)] }
        let each = (paperHeight / 4).rounded(.up)
        return (0..<4).compactMap { n in
            let y = Double(n) * each
            let h = min(each, paperHeight - y)
            return h > 0 ? Strip(y: y, height: h) : nil
        }
    }
}

public extension Arrivals {
    /// 0.14 (idea 11): shared words longer than `Arrival.longest` letters are cut; the share page says so.
    static func wasCut(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count > Arrival.longest
    }

    static let cutLine = "Only the first 20,000 letters were taken."
}

public extension Board {
    /// 0.14 (idea 10): this board becomes a copy of itself, ready to be written as a new board: a new identity,
    /// a name no other board has ("… copy", "… copy 2"), not put away, not pinned, nothing sent yet.
    mutating func becomeCopy(takenTitles: [String], now: Date = Date()) {
        id = UUID()
        let names = Set(takenTitles.map { $0.lowercased() })
        let base = title + " copy"
        title = base
        var n = 2
        while names.contains(title.lowercased()) {
            title = "\(base) \(n)"
            n += 1
        }
        created = now
        changed = now
        sent = nil
        sentTodos = []
        sentTasks = []
        pinned = false
        putAway = nil
    }
}

/// 0.14 (idea 9): what Undo of "Move to a new board" says.
public enum MoveOutUndo {
    public static func words(for title: String) -> String { "The new board “\(title)” is put away." }
}

/// 0.14 (idea 12): ticks PARAGON was not told about. Kept on the device and tried again at the next start.
public struct DoneQueue: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var board: UUID
        public var line: ParagonExport.DoneLine
        public init(board: UUID, line: ParagonExport.DoneLine) { self.board = board; self.line = line }
    }

    public var entries: [Entry] = []
    public init(entries: [Entry] = []) { self.entries = entries }

    public static let notToldLine = "Not told to PARAGON yet"
    /// Nothing older than this many days is kept (PARAGON would not know the task any more).
    public static let keptDays = 60
    public static let most = 200

    public mutating func add(_ lines: [ParagonExport.DoneLine], board: UUID) {
        for line in lines where !entries.contains(where: { $0.board == board && $0.line.words == line.words && $0.line.path == line.path }) {
            entries.append(Entry(board: board, line: line))
        }
        if entries.count > Self.most { entries.removeFirst(entries.count - Self.most) }
    }

    public var lines: [ParagonExport.DoneLine] { entries.map(\.line) }
    public var boards: Set<UUID> { Set(entries.map(\.board)) }
    public mutating func clear() { entries = [] }

    public mutating func dropOld(now: Date = Date()) {
        let oldest = now.addingTimeInterval(-Double(Self.keptDays) * 86_400)
        entries.removeAll { $0.line.when < oldest }
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
    public static func decoded(_ data: Data?) -> DoneQueue {
        guard let data, let q = try? JSONDecoder().decode(DoneQueue.self, from: data) else { return DoneQueue() }
        return q
    }
}
