import Foundation
import CoreGraphics

// 0.5 (pick 23): a thought is added to a board that already exists, from outside the app — a Shortcuts
// action, Siri, the Action button, Raycast. These are the rules; the app only carries them out.

public extension Outside {
    // MARK: Which board

    /// Why a board cannot take a thing from outside, in plain words; nil when it can.
    /// A timeline and a "Who does what" board place their things themselves; a board made by a newer
    /// Seedboard may not be changed.
    static func refusal(for board: Board) -> String? {
        if !board.canBeChanged {
            return "Nothing was added. “\(board.title)” was made by a newer Seedboard. Update the app to add to it."
        }
        if board.isTimeline {
            return "Nothing was added. “\(board.title)” is a timeline and places its things itself. Choose another board."
        }
        if board.isSequence {
            return "Nothing was added. “\(board.title)” is a “Who does what” board and places its things itself. Choose another board."
        }
        return nil
    }

    /// The board a thought goes to when none was named: the one changed last among the boards that can
    /// take it (`boards` as the app lists them, newest change first). nil when there is none.
    static func boardForThought(in boards: [Board]) -> Board? {
        boards.filter { refusal(for: $0) == nil }.max { $0.changed < $1.changed }
    }

    /// Said when no board was named and none can take a thought.
    static let noBoardLine = "Nothing was added. There is no board yet that a thought can be added to. Make a board first."
    /// Said when neither words nor a picture were handed over.
    static let nothingLine = "There was nothing to add."

    // MARK: Adding

    /// A picture that was already taken into the Pictures folder: the name of its file and its size in pixels.
    struct ArrivedPicture: Equatable, Sendable {
        public var name: String
        public var pixels: CGSize
        public init(name: String, pixels: CGSize) {
            self.name = name
            self.pixels = pixels
        }
    }

    /// True when the board is one mind map and nothing else (every thing on it is an idea, with one middle).
    static func isOneMap(_ board: Board) -> Bool {
        !board.items.isEmpty && board.mapCentres.count == 1 && board.items.allSatisfy { $0.kind == .idea }
    }

    /// Adds what came from outside and gives back the new things (empty: nothing was added).
    /// - One line of words on a board that is one mind map and nothing else: a new main branch of that map.
    /// - Any other words follow the rule for pasted words (`addWords`): a list becomes a mind map, anything
    ///   else one sticky note.
    /// - A picture becomes a picture.
    /// What is not a branch is laid at `arrivalSpot`: a free column to the right of everything on the board,
    /// the picture under the words, so nothing is ever covered. Nothing is added to a board that refuses
    /// (`refusal(for:)`).
    @discardableResult
    static func add(text: String, picture: ArrivedPicture? = nil, to board: inout Board) -> [UUID] {
        guard refusal(for: board) == nil else { return [] }
        let before = board
        let known = Set(board.items.map(\.id))
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var laid: [CGRect] = []

        if !clean.isEmpty {
            let oneLine = !clean.contains(where: \.isNewline)
            if oneLine, isOneMap(board), let centre = board.mapCentres.first, let branch = board.addChild(of: centre.id, text: clean) {
                // Its size until the app measures the words; its place comes from the map.
                if let i = board.index(of: branch) {
                    let size = Board.roughSize(for: clean)
                    board.items[i].w = Double(size.width)
                    board.items[i].h = Double(size.height)
                }
                board.layoutMaps()
            } else if board.addWords(clean, at: .zero) != nil {
                // Made round the zero point, then carried as one block to the free column.
                let made = board.items.filter { !known.contains($0.id) }
                if let first = made.first {
                    let box = made.dropFirst().reduce(first.frame) { $0.union($1.frame) }
                    let spot = before.arrivalSpot(size: box.size)
                    board.move(Set(made.map(\.id)), by: CGSize(width: spot.x - box.minX, height: spot.y - box.minY))
                    laid.append(CGRect(origin: spot, size: box.size))
                }
            }
        }

        if let picture {
            let size = Board.pictureSize(forPixels: picture.pixels)
            let spot = before.arrivalSpot(size: size, taken: laid)
            board.addPicture(name: picture.name, pixelSize: picture.pixels,
                             centre: CGPoint(x: spot.x + size.width / 2, y: spot.y + size.height / 2))
        }
        return board.items.filter { !known.contains($0.id) }.map(\.id)
    }

    /// The answer after adding: "Added to Summer cabin."
    static func addedLine(to board: Board) -> String { "Added to \(board.title)." }

    // MARK: Finding boards (the Shortcuts action "Find boards")

    /// One thing a board is asked about.
    enum BoardAsk: Equatable, Sendable {
        case nameIs(String)
        case nameHolds(String)
        case nameBegins(String)
        case changedAfter(Date)
        case changedBefore(Date)
        case pinned(Bool)
        /// Sent to PARAGON as a note or a project.
        case sent(Bool)

        func fits(_ board: Board) -> Bool {
            func plain(_ s: String) -> String { BoardSearch.plain(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
            switch self {
            case .nameIs(let words): return plain(board.title) == plain(words)
            case .nameHolds(let words): return plain(board.title).contains(plain(words))
            case .nameBegins(let words): return plain(board.title).hasPrefix(plain(words))
            case .changedAfter(let day): return board.changed > day
            case .changedBefore(let day): return board.changed < day
            case .pinned(let yes): return board.pinned == yes
            case .sent(let yes): return (board.sent != nil) == yes
            }
        }
    }

    enum BoardOrder: Equatable, Sendable { case name, changed }

    /// The boards that fit what is asked: all of the asks (`any` false) or at least one of them (`any` true);
    /// no asks at all finds every board. In the order given (`boards` as they came when no order is asked
    /// for), at most `limit` of them.
    static func find(in boards: [Board], asks: [BoardAsk], any: Bool = false,
                     order: BoardOrder? = nil, ascending: Bool = true, limit: Int? = nil) -> [Board] {
        var found = boards.filter { board in
            if asks.isEmpty { return true }
            return any ? asks.contains { $0.fits(board) } : asks.allSatisfy { $0.fits(board) }
        }
        if let order {
            // A steady order: boards that tie stay as they came.
            let sorted = found.enumerated().sorted { a, b in
                switch order {
                case .name:
                    let x = BoardSearch.plain(a.element.title), y = BoardSearch.plain(b.element.title)
                    if x != y { return ascending ? x < y : x > y }
                case .changed:
                    let x = a.element.changed, y = b.element.changed
                    if x != y { return ascending ? x < y : x > y }
                }
                return a.offset < b.offset
            }
            found = sorted.map(\.element)
        }
        if let limit, limit >= 0, found.count > limit { found = Array(found.prefix(limit)) }
        return found
    }

    // MARK: Starters by name (the Shortcuts action "New board")

    /// The starters for a name that was typed or spoken: the exact name first, then names that begin with
    /// it, then names that hold it. Capitals do not matter. No words: every starter, as given.
    static func starters(named words: String, in starters: [ShelfStarter]) -> [ShelfStarter] {
        let asked = BoardSearch.plain(words.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !asked.isEmpty else { return starters }
        func rank(_ starter: ShelfStarter) -> Int? {
            let name = BoardSearch.plain(starter.name)
            if name == asked { return 0 }
            if name.hasPrefix(asked) { return 1 }
            if name.contains(asked) { return 2 }
            return nil
        }
        return starters.enumerated()
            .compactMap { entry in rank(entry.element).map { (rank: $0, at: entry.offset, starter: entry.element) } }
            .sorted { ($0.rank, $0.at) < ($1.rank, $1.at) }
            .map(\.starter)
    }

    // MARK: The device's search

    /// Every word of a board for the device's search (it is searched, never shown): the board's name, the
    /// words on its things and on its arrows, one per line, cut at `limit` letters.
    static func searchText(of board: Board, limit: Int = 20_000) -> String {
        String(board.readableText.prefix(limit))
    }
}

/// The things that were added from outside while the board was not looked at, kept on THIS device only
/// (the device's own settings, never in the board): they are chosen once when the board is opened next.
public struct OutsideArrivals: Codable, Equatable, Sendable {
    /// By the board's id as text: the things that arrived, in the order they came.
    public private(set) var waiting: [String: [UUID]]

    public init(waiting: [String: [UUID]] = [:]) { self.waiting = waiting }

    enum CodingKeys: String, CodingKey { case waiting }

    /// Tolerant: whatever cannot be read is simply not remembered.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        waiting = (try? c.decode([String: [UUID]].self, forKey: .waiting)) ?? [:]
    }

    public var isEmpty: Bool { waiting.isEmpty }

    /// These things arrived on that board.
    public mutating func note(_ things: [UUID], on board: UUID) {
        guard !things.isEmpty else { return }
        var all = waiting[board.uuidString] ?? []
        for id in things where !all.contains(id) { all.append(id) }
        waiting[board.uuidString] = all
    }

    /// The board is opened: the arrivals that are still on it (`present`), once — they are forgotten here.
    public mutating func take(for board: UUID, present: Set<UUID>) -> [UUID] {
        guard let all = waiting.removeValue(forKey: board.uuidString) else { return [] }
        return all.filter(present.contains)
    }

    /// Boards that are gone are forgotten, so the list never grows without end.
    public func keeping(_ boards: Set<UUID>) -> OutsideArrivals {
        OutsideArrivals(waiting: waiting.filter { entry in UUID(uuidString: entry.key).map(boards.contains) ?? false })
    }
}

/// Handoff (pick 28): a board open on one device offers itself on the others. What travels with the offer,
/// and what the device that takes it up does when it is faster than iCloud.
public enum Handoff {
    public static let activityType = "com.schabbauer.AMSSeedboard.board"
    /// The longest a device waits for the newest version before it opens what it has.
    public static let longestWait: TimeInterval = 20
    /// Said over the board while it waits.
    public static let waitingLine = "Waiting for the newest version from iCloud…"

    /// What an offer says: which board, when it was last changed on the offering device, and the view there.
    public struct Offer: Equatable, Sendable {
        public var id: UUID
        public var changed: Date?
        public var view: LeftView?
        public init(id: UUID, changed: Date? = nil, view: LeftView? = nil) {
            self.id = id
            self.changed = changed
            self.view = view
        }
    }

    /// The offer as it travels: plain values only (words and numbers), as Handoff asks for.
    public static func info(for offer: Offer) -> [String: Any] {
        var out: [String: Any] = ["id": offer.id.uuidString]
        if let changed = offer.changed { out["changed"] = changed.timeIntervalSinceReferenceDate }
        if let view = offer.view {
            out["scale"] = view.scale
            out["x"] = view.x
            out["y"] = view.y
        }
        return out
    }

    /// Reads an offer; nil when it names no board. A view that is not whole or not sound is left out.
    public static func offer(from info: [AnyHashable: Any]?) -> Offer? {
        guard let word = info?["id"] as? String, let id = UUID(uuidString: word) else { return nil }
        func number(_ key: String) -> Double? {
            if let n = info?[key] as? Double { return n }
            return (info?[key] as? NSNumber)?.doubleValue
        }
        var offer = Offer(id: id)
        if let stamp = number("changed"), stamp.isFinite { offer.changed = Date(timeIntervalSinceReferenceDate: stamp) }
        if let scale = number("scale"), let x = number("x"), let y = number("y"),
           scale.isFinite, x.isFinite, y.isFinite, scale > 0 {
            offer.view = LeftView(scale: scale, x: x, y: y)
        }
        return offer
    }

    public enum Step: Equatable, Sendable {
        /// This device has the offered version (or a newer one): the board opens as usual.
        case open
        /// This device's copy is older: the board is shown, not changeable, until the newest version is here.
        case wait
        /// Waited long enough: the board opens with what is here.
        case openWhatIsHere
    }

    /// What to do with an offer: `here` = when this device's copy was last changed, `there` = the same on the
    /// offering device, `waited` = the seconds waited so far. Times are kept to the thousandth of a second, so
    /// two thousandths count as the same moment.
    public static func step(here: Date, there: Date?, waited: TimeInterval) -> Step {
        guard let there, here.addingTimeInterval(0.002) < there else { return .open }
        return waited >= longestWait ? .openWhatIsHere : .wait
    }
}
