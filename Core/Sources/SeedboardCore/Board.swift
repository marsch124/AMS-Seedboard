import Foundation
import CoreGraphics

// A board is one endless sheet. Everything on it is an Item (an idea of a mind map, a shape,
// a sticky note, free text, a frame) or a Link (an arrow between two items).
// Decoding is tolerant on purpose: a field that is missing gets its plain default, so an older or
// newer file never fails to open. A field this version does not know is CARRIED: it is kept beside
// the board, the item or the arrow and written back untouched, so an older app never drops what a
// newer one wrote. A kind of item or arrow this version does not know makes the board read-only.

/// Any JSON value, kept as it was read. Holds the fields this version of the app does not know.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() {
            self = .null
        } else if let value = try? box.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? box.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? box.decode(Double.self) {
            self = .double(value)
        } else if let value = try? box.decode(String.self) {
            self = .string(value)
        } else if let value = try? box.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try box.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .null: try box.encodeNil()
        case .bool(let value): try box.encode(value)
        case .int(let value): try box.encode(value)
        case .double(let value): try box.encode(value)
        case .string(let value): try box.encode(value)
        case .array(let value): try box.encode(value)
        case .object(let value): try box.encode(value)
        }
    }
}

/// A key by its plain name, for reading and writing the fields this version does not know.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ name: String) { stringValue = name }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// The fields of `decoder`'s object that are not among `known`, exactly as they were written.
func unknownFields(of decoder: Decoder, known: [String]) -> [String: JSONValue] {
    guard let all = try? decoder.container(keyedBy: AnyKey.self) else { return [:] }
    var extra: [String: JSONValue] = [:]
    for key in all.allKeys where !known.contains(key.stringValue) {
        if let value = try? all.decode(JSONValue.self, forKey: key) { extra[key.stringValue] = value }
    }
    return extra
}

func writeUnknownFields(_ extra: [String: JSONValue], to encoder: Encoder) throws {
    guard !extra.isEmpty else { return }
    var box = encoder.container(keyedBy: AnyKey.self)
    for (name, value) in extra { try box.encode(value, forKey: AnyKey(name)) }
}

public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case idea, box, round, diamond, oval, note, text, frame

    /// The four flowchart shapes.
    public var isShape: Bool { self == .box || self == .round || self == .diamond || self == .oval }

    public var word: String {
        switch self {
        case .idea: return "Idea"
        case .box: return "Box"
        case .round: return "Round box"
        case .diamond: return "Diamond"
        case .oval: return "Oval"
        case .note: return "Sticky note"
        case .text: return "Text"
        case .frame: return "Frame"
        }
    }

    public var defaultSize: CGSize {
        switch self {
        case .idea: return CGSize(width: 90, height: 30)
        case .box: return CGSize(width: 150, height: 56)
        case .round: return CGSize(width: 150, height: 52)
        case .diamond: return CGSize(width: 160, height: 104)
        case .oval: return CGSize(width: 150, height: 72)
        case .note: return CGSize(width: 150, height: 110)
        case .text: return CGSize(width: 120, height: 28)
        case .frame: return CGSize(width: 440, height: 300)
        }
    }
}

public struct Item: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: ItemKind { didSet { unknownKind = nil } }
    /// The kind word as it stood in the file when this version does not know it (a newer app wrote it).
    /// The item is then drawn as a box, the board is read-only, and the word is written back as it was.
    public private(set) var unknownKind: String?
    /// Fields in the file this version does not know: carried through a load and a save untouched.
    public private(set) var extra: [String: JSONValue] = [:]
    public var text: String
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    /// A colour name from `Palette`; empty = the kind's own colour.
    public var colour: String
    /// Marked "to do": goes to PARAGON as a task.
    public var todo: Bool
    /// Mind map: the idea this one hangs under. nil = the centre of a map, or not an idea.
    public var parent: UUID?
    /// Mind map: place among its sisters, small first.
    public var order: Double
    /// Mind map: its branches are folded away.
    public var folded: Bool
    /// Mind map centre only: branches go to the left as well as to the right.
    public var bothSides: Bool

    public init(id: UUID = UUID(), kind: ItemKind, text: String = "", x: Double = 0, y: Double = 0,
                w: Double? = nil, h: Double? = nil, colour: String = "", todo: Bool = false,
                parent: UUID? = nil, order: Double = 0, folded: Bool = false, bothSides: Bool = false) {
        self.id = id
        self.kind = kind
        self.text = text
        self.x = x
        self.y = y
        self.w = w ?? Double(kind.defaultSize.width)
        self.h = h ?? Double(kind.defaultSize.height)
        self.colour = colour
        self.todo = todo
        self.parent = parent
        self.order = order
        self.folded = folded
        self.bothSides = bothSides
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, text, x, y, w, h, colour, todo, parent, order, folded, bothSides
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        let kindWord = (try? c.decode(String.self, forKey: .kind)) ?? "box"
        kind = ItemKind(rawValue: kindWord) ?? .box
        unknownKind = ItemKind(rawValue: kindWord) == nil ? kindWord : nil
        extra = unknownFields(of: decoder, known: CodingKeys.allCases.map(\.rawValue))
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        x = (try? c.decode(Double.self, forKey: .x)) ?? 0
        y = (try? c.decode(Double.self, forKey: .y)) ?? 0
        w = (try? c.decode(Double.self, forKey: .w)) ?? Double(kind.defaultSize.width)
        h = (try? c.decode(Double.self, forKey: .h)) ?? Double(kind.defaultSize.height)
        colour = (try? c.decode(String.self, forKey: .colour)) ?? ""
        todo = (try? c.decode(Bool.self, forKey: .todo)) ?? false
        parent = try? c.decode(UUID.self, forKey: .parent)
        order = (try? c.decode(Double.self, forKey: .order)) ?? 0
        folded = (try? c.decode(Bool.self, forKey: .folded)) ?? false
        bothSides = (try? c.decode(Bool.self, forKey: .bothSides)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        try writeUnknownFields(extra, to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(unknownKind ?? kind.rawValue, forKey: .kind)
        try c.encode(text, forKey: .text)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(w, forKey: .w)
        try c.encode(h, forKey: .h)
        try c.encode(colour, forKey: .colour)
        try c.encode(todo, forKey: .todo)
        try c.encodeIfPresent(parent, forKey: .parent)
        try c.encode(order, forKey: .order)
        try c.encode(folded, forKey: .folded)
        try c.encode(bothSides, forKey: .bothSides)
    }

    public var frame: CGRect {
        get { CGRect(x: x, y: y, width: w, height: h) }
        set { x = Double(newValue.minX); y = Double(newValue.minY); w = Double(newValue.width); h = Double(newValue.height) }
    }

    public var centre: CGPoint { CGPoint(x: x + w / 2, y: y + h / 2) }
}

public enum LinkStyle: String, Codable, CaseIterable, Sendable {
    case elbow, straight, curve

    public var word: String {
        switch self {
        case .elbow: return "Right angles"
        case .straight: return "Straight"
        case .curve: return "Curved"
        }
    }
}

public struct Link: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var from: UUID
    public var to: UUID
    /// The words on the arrow.
    public var text: String
    public var colour: String
    public var style: LinkStyle { didSet { unknownStyle = nil } }
    /// The style word as it stood in the file when this version does not know it (see `Item.unknownKind`).
    public private(set) var unknownStyle: String?
    /// Fields in the file this version does not know: carried through a load and a save untouched.
    public private(set) var extra: [String: JSONValue] = [:]
    /// An arrow head at the far end.
    public var head: Bool

    public init(id: UUID = UUID(), from: UUID, to: UUID, text: String = "", colour: String = "",
                style: LinkStyle = .elbow, head: Bool = true) {
        self.id = id
        self.from = from
        self.to = to
        self.text = text
        self.colour = colour
        self.style = style
        self.head = head
    }

    enum CodingKeys: String, CodingKey, CaseIterable { case id, from, to, text, colour, style, head }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        from = try c.decode(UUID.self, forKey: .from)
        to = try c.decode(UUID.self, forKey: .to)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        colour = (try? c.decode(String.self, forKey: .colour)) ?? ""
        let styleWord = (try? c.decode(String.self, forKey: .style)) ?? LinkStyle.elbow.rawValue
        style = LinkStyle(rawValue: styleWord) ?? .elbow
        unknownStyle = LinkStyle(rawValue: styleWord) == nil ? styleWord : nil
        extra = unknownFields(of: decoder, known: CodingKeys.allCases.map(\.rawValue))
        head = (try? c.decode(Bool.self, forKey: .head)) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        try writeUnknownFields(extra, to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(from, forKey: .from)
        try c.encode(to, forKey: .to)
        try c.encode(text, forKey: .text)
        try c.encode(colour, forKey: .colour)
        try c.encode(unknownStyle ?? style.rawValue, forKey: .style)
        try c.encode(head, forKey: .head)
    }
}

/// What went to PARAGON last, so the board can say so and open the note again.
public struct SentInfo: Codable, Equatable, Sendable {
    public var when: Date
    /// "note" or "project".
    public var kind: String
    /// The note's title in PARAGON.
    public var title: String
    /// The note's place inside the PARAGON folder, e.g. "Projects/Summer cabin.md".
    public var path: String

    enum CodingKeys: String, CodingKey, CaseIterable { case when, kind, title, path }

    public init(when: Date, kind: String, title: String, path: String) {
        self.when = when
        self.kind = kind
        self.title = title
        self.path = path
    }
}

public struct Board: Codable, Identifiable, Equatable, Sendable {
    /// Raise this when a new version writes something an older version would lose: a new stored field,
    /// a new kind of item or arrow. A test (`StoredFieldsTests`) fails when a field is added without it.
    public static let currentFormat = 1

    public var id: UUID
    public var title: String
    public var created: Date
    public var changed: Date
    public var format: Int
    public var pinned: Bool
    /// The colour of the board's dot in the list.
    public var colour: String
    public var items: [Item]
    public var links: [Link]
    public var sent: SentInfo?
    /// To-do boxes that already went to the PARAGON Inbox, so they are not sent twice.
    public var sentTodos: [UUID]
    /// Fields in the file this version does not know: carried through a load and a save untouched.
    public private(set) var extra: [String: JSONValue] = [:]

    public init(id: UUID = UUID(), title: String = "New board", created: Date = Date(), changed: Date? = nil,
                pinned: Bool = false, colour: String = "green", items: [Item] = [], links: [Link] = []) {
        self.id = id
        self.title = title
        self.created = created
        self.changed = changed ?? created
        self.format = Board.currentFormat
        self.pinned = pinned
        self.colour = colour
        self.items = items
        self.links = links
        self.sent = nil
        self.sentTodos = []
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, title, created, changed, format, pinned, colour, items, links, sent, sentTodos
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? "Board"
        created = (try? c.decode(Date.self, forKey: .created)) ?? Date(timeIntervalSince1970: 0)
        changed = (try? c.decode(Date.self, forKey: .changed)) ?? created
        format = (try? c.decode(Int.self, forKey: .format)) ?? 1
        pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
        colour = (try? c.decode(String.self, forKey: .colour)) ?? "green"
        // One broken item or arrow must not lose the board: each is read by itself.
        items = ((try? c.decode([Lenient<Item>].self, forKey: .items)) ?? []).compactMap(\.value)
        links = ((try? c.decode([Lenient<Link>].self, forKey: .links)) ?? []).compactMap(\.value)
        sent = try? c.decode(SentInfo.self, forKey: .sent)
        sentTodos = (try? c.decode([UUID].self, forKey: .sentTodos)) ?? []
        extra = unknownFields(of: decoder, known: CodingKeys.allCases.map(\.rawValue))
    }

    public func encode(to encoder: Encoder) throws {
        try writeUnknownFields(extra, to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(created, forKey: .created)
        try c.encode(changed, forKey: .changed)
        try c.encode(format, forKey: .format)
        try c.encode(pinned, forKey: .pinned)
        try c.encode(colour, forKey: .colour)
        try c.encode(items, forKey: .items)
        try c.encode(links, forKey: .links)
        try c.encodeIfPresent(sent, forKey: .sent)
        try c.encode(sentTodos, forKey: .sentTodos)
    }

    /// True when this version of the app may change the board: it was not written by a newer one, and
    /// it holds no kind of item or arrow this version does not know.
    public var canBeChanged: Bool { format <= Board.currentFormat && !holdsUnknownKinds }

    /// An item or an arrow of a kind this version does not know is on the board.
    public var holdsUnknownKinds: Bool {
        items.contains { $0.unknownKind != nil } || links.contains { $0.unknownStyle != nil }
    }

    /// Stamps the board as changed now.
    /// Always later than the stamp it had (even when this device's clock runs behind another's),
    /// so "the newer change wins" can never throw away the change just made.
    public mutating func touch(_ now: Date = Date()) { changed = max(now, changed.addingTimeInterval(0.001)) }
}

/// Reads one element of a list without failing the whole list.
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// Colour names kept in the file. The app turns a name into a day and a night colour.
public enum Palette {
    public static let names = ["pink", "orange", "teal", "blue", "purple", "green", "yellow", "red", "grey"]
    /// The order in which the branches of a mind map take their colours.
    public static let branches = ["pink", "orange", "teal", "blue", "purple", "green", "red"]
    /// Sticky note colours.
    public static let notes = ["yellow", "pink", "blue", "green", "orange", "purple"]
    /// Board dots in the list.
    public static let boards = ["green", "pink", "orange", "blue", "teal", "purple"]

    public static func branch(_ index: Int) -> String { branches[((index % branches.count) + branches.count) % branches.count] }
}
