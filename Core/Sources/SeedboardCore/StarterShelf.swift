import Foundation

// The shelf of starter boards (0.3): the seven built-in starters and the owner's own, in one list the
// owner can rename, reorder, change and remove. Nothing here knows about files or the screen.
// A starter that was never touched has no entry; an entry exists once something was changed or made.

/// One stored starter: a changed built-in, or an own starter. Decoding is tolerant, unknown fields are carried.
public struct StarterEntry: Codable, Equatable, Identifiable, Sendable {
    /// A built-in's raw value such as "mindMap", or a UUID string for an own starter.
    public var id: String
    public var name: String
    /// The grey line under the name.
    public var hint: String
    public var order: Double
    public var removed: Bool
    public var removedWhen: Date?
    /// The built-in this entry belongs to (nil for an own starter).
    public var builtin: String?
    /// nil for a built-in whose content was never changed.
    public var board: Board?
    public var changed: Date
    /// 0.5: when the CONTENT (the board) was last set — by Change, Save as a starter or "back to the original".
    /// A rename or a move stamps `changed` only, so it can never win over a newer board made on another device.
    /// nil in a file of 0.4: the content then counts as old as `changed` (`boardStamp`).
    public var boardChanged: Date?
    public private(set) var extra: [String: JSONValue] = [:]

    public init(id: String, name: String, hint: String = "", order: Double = 0, removed: Bool = false,
                removedWhen: Date? = nil, builtin: String? = nil, board: Board? = nil, changed: Date = Date(),
                boardChanged: Date? = nil) {
        self.id = id
        self.name = name
        self.hint = hint
        self.order = order
        self.removed = removed
        self.removedWhen = removedWhen
        self.builtin = builtin
        self.board = board
        self.changed = changed
        self.boardChanged = boardChanged
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, name, hint, order, removed, removedWhen, builtin, board, changed, boardChanged
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Starter"
        hint = (try? c.decode(String.self, forKey: .hint)) ?? ""
        order = (try? c.decode(Double.self, forKey: .order)) ?? 0
        removed = (try? c.decode(Bool.self, forKey: .removed)) ?? false
        removedWhen = try? c.decode(Date.self, forKey: .removedWhen)
        builtin = try? c.decode(String.self, forKey: .builtin)
        board = try? c.decode(Board.self, forKey: .board)
        changed = (try? c.decode(Date.self, forKey: .changed)) ?? Date(timeIntervalSince1970: 0)
        boardChanged = try? c.decode(Date.self, forKey: .boardChanged)
        extra = unknownFields(of: decoder, known: CodingKeys.allCases.map(\.rawValue))
    }

    public func encode(to encoder: Encoder) throws {
        try writeUnknownFields(extra, to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(hint, forKey: .hint)
        try c.encode(order, forKey: .order)
        try c.encode(removed, forKey: .removed)
        try c.encodeIfPresent(removedWhen, forKey: .removedWhen)
        try c.encodeIfPresent(builtin, forKey: .builtin)
        try c.encodeIfPresent(board, forKey: .board)
        try c.encode(changed, forKey: .changed)
        try c.encodeIfPresent(boardChanged, forKey: .boardChanged)
    }

    /// How new the content is. A file of 0.4 has no stamp of its own: its content counts as old as `changed`.
    /// A 0.4 app that changes the board carries an old stamp along unchanged, but it dates the board itself, so
    /// the later of the two is taken.
    public var boardStamp: Date { max(boardChanged ?? changed, board?.changed ?? .distantPast) }

    /// Of two copies of the same entry (two devices): the name, the grey line, the place and "removed" come from
    /// the copy with the later `changed`; the board comes from the copy whose CONTENT is the later one. So a
    /// rename or a move made elsewhere never brings an older board back (0.5).
    public static func newer(_ a: StarterEntry, _ b: StarterEntry) -> StarterEntry {
        var out = b.changed > a.changed ? b : a
        // Two contents equally new (two files of 0.4, or the same content): the later copy's, as before 0.5.
        let content = b.boardStamp > a.boardStamp ? b : (a.boardStamp > b.boardStamp ? a : out)
        out.board = content.board
        out.boardChanged = content.boardStamp
        // Two copies that say the same stay exactly as they are (nothing is written again for a stamp alone).
        if out.board == a.board, out.changed == a.changed, a.boardStamp == out.boardStamp { return a }
        if out.board == b.board, out.changed == b.changed, b.boardStamp == out.boardStamp { return b }
        return out
    }
}

/// A starter as the screens show it.
public struct ShelfStarter: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var hint: String
    public var order: Double
    public var removed: Bool
    /// Set for a built-in.
    public var builtin: Starter?
    /// The own or changed board; nil for an untouched built-in.
    public var board: Board?

    public var isBuiltin: Bool { builtin != nil }
    /// A built-in whose board was changed (it can go back to the original).
    public var isChangedBuiltin: Bool { builtin != nil && board != nil }
    /// The Blank board cannot be removed: a new board must always be possible.
    public var canBeRemoved: Bool { builtin != .blank }
}

public struct StarterShelf: Equatable, Sendable {
    /// Days after which a removed own starter's file may go.
    public static let keepRemoved = 30

    public private(set) var entries: [String: StarterEntry]

    public init(entries: [StarterEntry] = []) {
        var map: [String: StarterEntry] = [:]
        for e in entries { map[e.id] = map[e.id].map { StarterEntry.newer($0, e) } ?? e }
        self.entries = map
    }

    /// Every starter, removed ones too, by order.
    public var everything: [ShelfStarter] {
        var list: [ShelfStarter] = []
        for (n, s) in Starter.allCases.enumerated() {
            if let e = entries[s.id] {
                list.append(ShelfStarter(id: s.id, name: e.name, hint: e.hint, order: e.order, removed: e.removed, builtin: s, board: e.board))
            } else {
                list.append(ShelfStarter(id: s.id, name: s.name, hint: s.hint, order: Double(n), removed: false, builtin: s, board: nil))
            }
        }
        for e in entries.values where e.builtin == nil || Starter(rawValue: e.builtin ?? "") == nil {
            if Starter(rawValue: e.id) != nil { continue }
            list.append(ShelfStarter(id: e.id, name: e.name, hint: e.hint, order: e.order, removed: e.removed, builtin: nil, board: e.board))
        }
        return list.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    /// What the owner sees: the starters not removed, in order.
    public var shown: [ShelfStarter] { everything.filter { !$0.removed } }

    public func starter(_ id: String) -> ShelfStarter? { everything.first { $0.id == id } }

    /// A built-in is missing from the shelf (so "Bring back the built-in starters" is offered).
    public var missingBuiltins: Bool { everything.contains { $0.isBuiltin && $0.removed } }

    // MARK: Changing

    private mutating func entry(for id: String, now: Date) -> StarterEntry? {
        if let e = entries[id] { return e }
        guard let s = Starter(rawValue: id), let n = Starter.allCases.firstIndex(of: s) else { return nil }
        // An untouched built-in has no content of its own: its content is as old as can be.
        return StarterEntry(id: id, name: s.name, hint: s.hint, order: Double(n), builtin: id, changed: now,
                            boardChanged: Date(timeIntervalSince1970: 0))
    }

    /// `content`: the board itself was set (Change, back to the original); otherwise only the name, the grey
    /// line, the place or "removed" changed, and the content keeps the stamp it had.
    private mutating func store(_ e: StarterEntry, now: Date, content: Bool = false) {
        var e = e
        let stamp = max(now, (entries[e.id]?.changed ?? .distantPast).addingTimeInterval(0.001))
        e.boardChanged = content ? stamp : e.boardStamp
        e.changed = stamp
        entries[e.id] = e
    }

    /// The entries that changed against `before` (what the store writes).
    public func changes(since before: StarterShelf) -> [StarterEntry] {
        entries.values.filter { before.entries[$0.id] != $0 }
    }

    public mutating func rename(_ id: String, name: String, hint: String, now: Date = Date()) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, var e = entry(for: id, now: now) else { return }
        e.name = clean
        e.hint = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        store(e, now: now)
    }

    /// Puts the starter at `index` of the shown list as it stands without it.
    public mutating func move(_ id: String, to index: Int, now: Date = Date()) {
        let others = shown.filter { $0.id != id }
        guard var e = entry(for: id, now: now) else { return }
        let i = min(max(index, 0), others.count)
        switch (i > 0 ? others[i - 1].order : nil, i < others.count ? others[i].order : nil) {
        case (nil, nil): e.order = 0
        case (nil, let after?): e.order = after - 1
        case (let before?, nil): e.order = before + 1
        case (let before?, let after?): e.order = (before + after) / 2
        }
        store(e, now: now)
    }

    /// False for the Blank board.
    @discardableResult
    public mutating func remove(_ id: String, now: Date = Date()) -> Bool {
        guard let s = starter(id), s.canBeRemoved, var e = entry(for: id, now: now) else { return false }
        e.removed = true
        e.removedWhen = now
        store(e, now: now)
        return true
    }

    public mutating func bringBackBuiltins(now: Date = Date()) {
        for s in everything where s.isBuiltin && s.removed {
            guard var e = entries[s.id] else { continue }
            e.removed = false
            e.removedWhen = nil
            store(e, now: now)
        }
    }

    /// A changed built-in goes back to its own board (its name, hint and place stay as set).
    public mutating func backToOriginal(_ id: String, now: Date = Date()) {
        guard Starter(rawValue: id) != nil, var e = entries[id], e.board != nil else { return }
        e.board = nil
        store(e, now: now, content: true)
    }

    /// Stores a changed board: a built-in's own board, or an own starter's.
    public mutating func change(_ id: String, board: Board, now: Date = Date()) {
        guard var e = entry(for: id, now: now) else { return }
        var b = board
        b.changed = now
        e.board = b
        store(e, now: now, content: true)
    }

    /// A name no shown starter has yet: "Name", else "Name 2", "Name 3" …
    public func freeName(_ wanted: String, ignoring id: String? = nil) -> String {
        let base = wanted.trimmingCharacters(in: .whitespacesAndNewlines)
        let taken = Set(shown.filter { $0.id != id }.map { $0.name.lowercased() })
        var name = base, n = 2
        while taken.contains(name.lowercased()) { name = "\(base) \(n)"; n += 1 }
        return name
    }

    /// Makes an own starter of a board; it goes last. Returns its id.
    @discardableResult
    public mutating func saveAs(_ board: Board, name: String, hint: String = "", now: Date = Date()) -> String {
        let id = UUID().uuidString
        var b = board
        b.id = UUID()
        b.changed = now
        let last = (everything.map(\.order).max() ?? -1) + 1
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = StarterEntry(id: id, name: freeName(clean.isEmpty ? board.title : clean),
                             hint: hint, order: last, board: b, changed: now, boardChanged: now)
        entries[id] = e
        return id
    }

    /// Own starters removed more than 30 days ago: their files may be deleted.
    public func purgeable(now: Date = Date()) -> [String] {
        entries.values.filter {
            $0.builtin == nil && $0.removed
                && ($0.removedWhen ?? $0.changed) < now.addingTimeInterval(-Double(StarterShelf.keepRemoved) * 86_400)
        }.map(\.id)
    }

    public mutating func purge(now: Date = Date()) {
        for id in purgeable(now: now) { entries[id] = nil }
    }

    // MARK: A new board

    /// A fresh board from a starter, or nil when the id is unknown.
    public func makeBoard(from id: String, now: Date = Date()) -> Board? {
        guard let s = starter(id) else { return nil }
        if let b = s.board { return StarterShelf.fresh(b, titled: s.name, now: now) }
        guard let built = s.builtin else { return nil }
        return built.board(title: s.name == built.name ? nil : s.name, now: now)
    }

    /// The starter's board for changing it: the same ids, and a timeline moved to sit round today (so saving it
    /// again, which dates it today, keeps the plan as far from today as it looks).
    public func workingBoard(for id: String, now: Date = Date()) -> Board? {
        guard let s = starter(id) else { return nil }
        if var b = s.board {
            StarterShelf.move(&b, byDays: b.isTimeline ? Day(now) - Day(b.changed) : 0)
            return b
        }
        return s.builtin?.board(title: s.name == s.builtin?.name ? nil : s.name, now: now)
    }

    static func move(_ b: inout Board, byDays shift: Int) {
        guard shift != 0 else { return }
        for i in b.items.indices {
            if let s = b.items[i].start, let d = Day(iso: s) { b.items[i].start = (d + shift).iso }
            if let s = b.items[i].end, let d = Day(iso: s) { b.items[i].end = (d + shift).iso }
        }
    }

    /// A copy of a board with new ids everywhere and every reference re-pointed; not sent, not pinned,
    /// made and changed now. A timeline moves by whole days to sit as far from today as it did when saved.
    public static func fresh(_ board: Board, titled title: String, now: Date = Date()) -> Board {
        var b = board
        b.id = UUID()
        b.title = title
        b.created = now
        b.changed = now
        b.pinned = false
        b.sent = nil
        b.sentTodos = []
        var map: [UUID: UUID] = [:]
        for item in b.items { map[item.id] = UUID() }
        StarterShelf.move(&b, byDays: board.isTimeline ? Day(now) - Day(board.changed) : 0)
        for i in b.items.indices {
            b.items[i].id = map[b.items[i].id] ?? UUID()
            b.items[i].parent = b.items[i].parent.flatMap { map[$0] }
            b.items[i].from = b.items[i].from.flatMap { map[$0] }
            b.items[i].to = b.items[i].to.flatMap { map[$0] }
        }
        var arrows: [Link] = []
        for var link in b.links {
            guard let f = map[link.from], let t = map[link.to] else { continue }
            link.id = UUID()
            link.from = f
            link.to = t
            arrows.append(link)
        }
        b.links = arrows
        return b
    }
}
