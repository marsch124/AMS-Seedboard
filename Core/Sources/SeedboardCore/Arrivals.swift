import Foundation
import CoreGraphics

// 0.5, pick 24: Share › Seedboard. What is shared from another app (words, a link, pictures) is written
// as one line per thing into a waiting list; the app lays them on their board the next time it is in front.
// These are the rules: the line itself, what was shared → which lines, which board a line goes to, and how
// the things are laid so that nothing is covered and nothing is laid twice.

/// One shared thing that waits for the app.
public struct Arrival: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, link, picture }

    /// Its own identity. The thing it becomes on the board carries the SAME identity, so a line that is read
    /// twice (the app stopped between saving the board and emptying the list) is never laid twice.
    public var id: UUID
    /// One press of Send. Everything sent to "New board" in one go lands on ONE new board, which carries this identity.
    public var share: UUID
    /// Where it goes: a board's identity, or `Arrival.newBoard`.
    public var board: String
    public var kind: Kind
    /// The words (text), or the page's title (a link). Empty for a picture.
    public var words: String
    /// A link's address.
    public var address: String?
    /// A picture's file name in the waiting folder: `<id>.jpg`. The picture is kept on the board under the same name.
    public var picture: String?
    public var when: Date

    /// The word in `board` that asks for a new board.
    public static let newBoard = "new"
    /// The most letters one arrival's words may have; what is longer is cut.
    public static let longest = 20_000
    /// The most pictures one share may bring.
    public static let mostPictures = 10

    public init(id: UUID = UUID(), share: UUID, board: String, kind: Kind, words: String = "",
                address: String? = nil, picture: String? = nil, when: Date = Date()) {
        self.id = id
        self.share = share
        self.board = board
        self.kind = kind
        self.words = words
        self.address = address
        self.picture = picture
        self.when = when
    }
}

/// The waiting list as text: one arrival per line.
public enum ArrivalList {
    /// One arrival as one line (no line break inside, whatever the words hold).
    public static func line(_ arrival: Arrival) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(arrival), let line = String(data: data, encoding: .utf8) else { return nil }
        return line
    }

    private static func arrival(from line: Substring) -> Arrival? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Arrival.self, from: data)
    }

    /// Every arrival in the list, in the order they came. A line that cannot be read is passed over, not lost
    /// (`without` leaves it where it is).
    public static func read(_ text: String) -> [Arrival] {
        text.split(whereSeparator: \.isNewline).compactMap { arrival(from: $0) }
    }

    /// The list with these arrivals added at its end.
    public static func adding(_ arrivals: [Arrival], to text: String) -> String {
        var out = text
        if !out.isEmpty, !out.hasSuffix("\n") { out += "\n" }
        for arrival in arrivals {
            if let line = line(arrival) { out += line + "\n" }
        }
        return out
    }

    /// The list without these arrivals. Every other line stays exactly as it was written — also one that
    /// this version cannot read.
    public static func text(_ text: String, without ids: Set<UUID>) -> String {
        let kept = text.split(whereSeparator: \.isNewline).filter { line in
            guard let arrival = arrival(from: line) else { return true }
            return !ids.contains(arrival.id)
        }
        return kept.isEmpty ? "" : kept.joined(separator: "\n") + "\n"
    }
}

/// A board as the share page shows it: its name and its colour dot. The app writes the list for the page.
public struct ShareBoard: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var colour: String
    public var pinned: Bool

    public init(id: UUID, name: String, colour: String, pinned: Bool) {
        self.id = id
        self.name = name
        self.colour = colour
        self.pinned = pinned
    }
}

public enum ShareBoards {
    /// The most boards the share page is told of.
    public static let most = 30

    /// The boards the share page offers: the pinned ones first, then the others, each group newest first, 30 at
    /// most. A board that places its own things (a timeline, a "Who does what") and one a newer Seedboard made
    /// are left out: nothing from outside can be laid on them.
    public static func list(of boards: [Board], limit: Int = most) -> [ShareBoard] {
        let fit = boards.filter { $0.canBeChanged && !$0.placesItself }.sorted { $0.changed > $1.changed }
        let ordered = fit.filter(\.pinned) + fit.filter { !$0.pinned }
        return ordered.prefix(max(limit, 0)).map { ShareBoard(id: $0.id, name: $0.title, colour: $0.colour, pinned: $0.pinned) }
    }

    public static func data(of list: [ShareBoard]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(list)) ?? Data("[]".utf8)
    }

    /// The list as it was written; one entry that cannot be read does not lose the others.
    public static func read(_ data: Data) -> [ShareBoard] {
        ((try? JSONDecoder().decode([Lenient<ShareBoard>].self, from: data)) ?? []).compactMap(\.value)
    }
}

/// The arrivals that go to one board.
public struct ArrivalGroup: Equatable, Sendable {
    /// The board they are laid on.
    public var board: UUID
    /// True when that board has to be made first.
    public var isNew: Bool
    public var arrivals: [Arrival]
}

public enum Arrivals {
    // MARK: What was shared → the lines

    /// What one share becomes. `text` = shared words, `title` = the name the sending app gives (a page's title),
    /// `address` = a shared link, `pictures` = the identities of the pictures that were kept for the app.
    /// - A link is ONE arrival: the page's title and its address. Without a title, shared words of one line stand in.
    /// - Words are an arrival of their own unless they are the link's title or the address itself.
    /// - Words longer than `Arrival.longest` letters are cut.
    public static func made(share: UUID, board: String, text: String, title: String, address: String?,
                            pictures: [UUID], now: Date = Date()) -> [Arrival] {
        var out: [Arrival] = []
        let words = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Arrival.longest))
        let link = (address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var usedAsTitle = false
        if !link.isEmpty {
            var name = ParagonExport.oneLine(title)
            if name.isEmpty || name == link, !words.contains(where: \.isNewline), words != link {
                name = ParagonExport.oneLine(words)
                usedAsTitle = !name.isEmpty
            }
            if name == link { name = "" }
            out.append(Arrival(share: share, board: board, kind: .link, words: String(name.prefix(300)), address: link, when: now))
        }
        if !words.isEmpty, !usedAsTitle, words != link, link.isEmpty || ParagonExport.oneLine(words) != ParagonExport.oneLine(title) {
            out.append(Arrival(share: share, board: board, kind: .text, words: words, when: now))
        }
        for id in pictures.prefix(Arrival.mostPictures) {
            out.append(Arrival(id: id, share: share, board: board, kind: .picture, picture: PictureKeeping.freshName(id), when: now))
        }
        return out
    }

    /// What a link becomes on the board: a sticky note with the page's title, and its address on the next line.
    /// No title: the address alone.
    public static func noteWords(of arrival: Arrival) -> String {
        let name = ParagonExport.oneLine(arrival.words)
        let link = (arrival.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard arrival.kind == .link else { return arrival.words }
        if name.isEmpty || name == link { return link }
        return link.isEmpty ? name : name + "\n" + link
    }

    // MARK: Words for the owner

    /// What came, in one line, for the share page: "A link", "Words and 2 pictures", "A link, words and 1 picture".
    public static func whatCame(_ arrivals: [Arrival]) -> String {
        var parts: [String] = []
        if arrivals.contains(where: { $0.kind == .link }) { parts.append("a link") }
        if arrivals.contains(where: { $0.kind == .text }) { parts.append("words") }
        let pictures = arrivals.filter { $0.kind == .picture }.count
        if pictures > 0 { parts.append(pictures == 1 ? "1 picture" : "\(pictures) pictures") }
        guard let last = parts.popLast() else { return "Nothing to send" }
        let line = parts.isEmpty ? last : parts.joined(separator: ", ") + " and " + last
        return line.prefix(1).uppercased() + line.dropFirst()
    }

    /// The line the app shows once the things are on their board.
    public static func cameLine(_ things: Int) -> String {
        things == 1 ? "1 thing came in from Share." : "\(things) things came in from Share."
    }

    /// The line for pictures that could not be read (said, never silently dropped).
    public static func lostLine(_ pictures: Int) -> String {
        pictures == 1 ? "1 picture from Share could not be read." : "\(pictures) pictures from Share could not be read."
    }

    /// The name of a board made for a share: the first line of its words, else the link's title, else the
    /// address's site, else "Shared pictures". 40 letters at most.
    public static func boardName(for arrivals: [Arrival]) -> String {
        if let text = arrivals.first(where: { $0.kind == .text && !$0.words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return Outside.short(text.words)
        }
        if let link = arrivals.first(where: { $0.kind == .link }) {
            let name = ParagonExport.oneLine(link.words)
            if !name.isEmpty { return Outside.short(name) }
            if let host = URL(string: link.address ?? "")?.host, !host.isEmpty {
                return Outside.short(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
            }
        }
        return arrivals.contains { $0.kind == .picture } ? "Shared pictures" : "From Share"
    }

    // MARK: Which board

    /// Sorts the waiting arrivals by the board they go to, in the order they came.
    /// - The board that was picked, when it is on this device and things can be laid on it.
    /// - Otherwise (it was removed, it is a timeline or a "Who does what", a newer Seedboard made it, or "New board"
    ///   was picked): a new board that carries the share's identity — one per share, and the same one when the list
    ///   is read a second time.
    public static func groups(_ arrivals: [Arrival], boards: [Board]) -> [ArrivalGroup] {
        var out: [ArrivalGroup] = []
        for arrival in arrivals {
            var target = arrival.share
            if let picked = UUID(uuidString: arrival.board),
               let board = boards.first(where: { $0.id == picked }), board.canBeChanged, !board.placesItself {
                target = picked
            }
            if let at = out.firstIndex(where: { $0.board == target }) {
                out[at].arrivals.append(arrival)
            } else {
                out.append(ArrivalGroup(board: target, isNew: !boards.contains { $0.id == target }, arrivals: [arrival]))
            }
        }
        return out
    }
}

public extension Board {
    /// Lays arrivals on the board: words become a sticky note (a list a mind map), a link a sticky note with the
    /// title and the address, a picture a picture thing. Each lies at `arrivalSpot` — a free column to the right
    /// of everything, one under the other — so nothing on the board is covered or moved.
    /// `pixels`: the size in pixels of every picture that was kept for the board; a picture without it is not laid.
    /// The thing made carries the arrival's identity; an arrival that is on the board already is not laid again.
    /// Returns the identities of the things that were laid now.
    @discardableResult
    mutating func land(_ arrivals: [Arrival], pixels: [UUID: CGSize] = [:]) -> [UUID] {
        guard canBeChanged, !placesItself else { return [] }
        let before = self
        var taken: [CGRect] = []
        var laid: [UUID] = []
        for arrival in arrivals where item(arrival.id) == nil {
            let known = Set(items.map(\.id))
            var made: UUID?
            switch arrival.kind {
            case .text:
                made = addWords(arrival.words, at: .zero)
            case .link:
                let words = Arrivals.noteWords(of: arrival)
                if !words.isEmpty { made = add(.note, centre: .zero, text: words) }
            case .picture:
                if let name = arrival.picture, let size = pixels[arrival.id] {
                    made = addPicture(name: name, pixelSize: size, centre: .zero)
                }
            }
            guard let made else { continue }
            let new = Set(items.map(\.id)).subtracting(known)
            let frames = items.filter { new.contains($0.id) }.map(\.frame)
            guard let first = frames.first else { continue }
            let box = frames.dropFirst().reduce(first) { $0.union($1) }
            let spot = before.arrivalSpot(size: box.size, taken: taken)
            move(new, by: CGSize(width: spot.x - box.minX, height: spot.y - box.minY))
            taken.append(CGRect(origin: spot, size: box.size))
            // The thing (a map: its middle idea) takes the arrival's identity.
            if made != arrival.id {
                for i in items.indices {
                    if items[i].id == made { items[i].id = arrival.id }
                    if items[i].parent == made { items[i].parent = arrival.id }
                }
            }
            laid.append(arrival.id)
        }
        return laid
    }
}
