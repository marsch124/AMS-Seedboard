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
    /// A timeline board's own things (format 2): a bar on days, a one-day milestone, a heading row.
    case bar, milestone, phase
    /// New in 0.2 (ShapeOutline.swift). The stored names are these words and never change.
    case person, document, slanted, store
    /// A "Who does what" board's own things (format 2): a name with its dashed line, a message between two
    /// names, a note across the lines, a section heading.
    case who, message, band, section
    /// Lines drawn by hand (format 2): the strokes are in `Item.strokes` (Ink.swift).
    case drawing
    /// A picture laid on the board (format 3): the picture itself is a file of its own, named in `Item.picture`.
    case picture
    /// A door to another board (format 5): the board it leads to is in `Item.door`. Two presses open that board.
    case door
    /// 0.14 (format 8): a small table of cells; the words are in `Item.cells` (rows of columns).
    case table
    /// 0.14 (format 8): a "Who does what" block round a few messages ("repeat", "if", "else" in `text`);
    /// the first and the last message are `from` and `to`.
    case block

    /// The flowchart shapes (`ItemKind.flowShapes`).
    public var isShape: Bool { ItemKind.flowShapes.contains(self) }

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
        case .bar: return "Bar"
        case .milestone: return "Milestone"
        case .phase: return "Phase"
        case .person: return "Person"
        case .document: return "Document"
        case .slanted: return "Slanted box"
        case .store: return "Store"
        case .who: return "Who"
        case .message: return "Message"
        case .band: return "Note"
        case .section: return "Section"
        case .drawing: return "Sketch"
        case .picture: return "Picture"
        case .door: return "Door"
        case .table: return "Table"
        case .block: return "Block"
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
        case .bar, .milestone, .phase: return CGSize(width: 150, height: 22)
        case .person: return CGSize(width: 110, height: 96)
        case .document: return CGSize(width: 150, height: 68)
        case .slanted: return CGSize(width: 160, height: 56)
        case .store: return CGSize(width: 130, height: 80)
        case .who, .message, .band, .section: return CGSize(width: 60, height: 17)
        case .drawing: return CGSize(width: 120, height: 80)
        case .picture: return CGSize(width: 240, height: 180)
        case .door: return CGSize(width: 190, height: 56)
        case .table: return CGSize(width: 330, height: 120)
        case .block: return CGSize(width: 60, height: 17)
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
    /// Mind map, main branch of a both-sides map only: the side it stays on. nil = not settled yet.
    public var side: Side? = nil
    /// Timeline: the first and the last day of a bar as "2026-12-01" (a milestone has only `start`).
    public var start: String?
    public var end: String?
    /// Timeline: the row, 0 at the top.
    public var row: Int?
    /// A frame only: its lanes (Lanes.swift). nil = a plain frame.
    public var lanes: Lanes? = nil
    /// Who does what: the name a message comes from and the name it goes to (the same for a message to itself).
    public var from: UUID?
    public var to: UUID?
    /// Who does what: the message is an answer, drawn with dashes.
    public var answer: Bool?
    /// A drawing's lines, measured from its corner (Ink.swift). nil for everything else.
    public var strokes: [Stroke]?
    /// A picture only: the name of its file in the Pictures folder, e.g. "3F2A….jpg". The file is written once and never changed.
    public var picture: String?
    /// A picture only (format 4): the part of the picture that is shown, as x, y, width, height, each 0 to 1 of the
    /// whole picture. nil = all of it. Always clean (see `Item.cleanCrop`). The file itself is never changed.
    public var crop: [Double]?
    /// A door only (format 5): the board it leads to.
    public var door: UUID?
    /// A timeline bar or milestone only (format 5): the day it was marked done, as "2026-12-01". nil = not done.
    public var doneDay: String?
    /// 0.9 (format 6): vote dots given to this thing. nil = none.
    public var votes: Int?
    /// 0.9 (format 6): pinned in place — it cannot be moved or resized by accident. nil = free.
    public var locked: Bool?
    /// 0.9 (format 6): the title of the web page whose address is in the words, once it was fetched. nil = not fetched.
    public var linkTitle: String?
    /// 0.9 (format 6): a picture only — the words read inside it (for search). nil = not read yet; "" = none found.
    public var pictureWords: String?
    /// 0.14 (format 8): turned by this many degrees round its middle (a note stuck on crooked). nil = straight.
    public var tilt: Double?
    /// 0.14 (format 8): free text only — "title" or "small". nil = normal.
    public var textSize: String?
    /// 0.14 (format 8): a table only — its cells, row by row. nil = not a table.
    public var cells: [[String]]?
    /// 0.14 (format 8): a timeline bar or milestone only — where it stood when "Set the plan" was pressed
    /// ("yyyy-MM-dd"). nil = no plan set.
    public var planStart: String?
    public var planEnd: String?

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
        case side
        case start, end, row
        case lanes
        case from, to, answer
        case strokes
        case picture
        case crop
        case door, doneDay
        case votes, locked, linkTitle, pictureWords
        case tilt, textSize, cells, planStart, planEnd
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        let kindWord = (try? c.decode(String.self, forKey: .kind)) ?? "box"
        kind = ItemKind(rawValue: kindWord) ?? .box
        unknownKind = ItemKind(rawValue: kindWord) == nil ? kindWord : nil
        extra = unknownFields(of: decoder, known: CodingKeys.allCases.map(\.rawValue))
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        x = SafeNumber.position((try? c.decode(Double.self, forKey: .x)) ?? 0)
        y = SafeNumber.position((try? c.decode(Double.self, forKey: .y)) ?? 0)
        w = SafeNumber.size((try? c.decode(Double.self, forKey: .w)) ?? Double(kind.defaultSize.width), fallback: Double(kind.defaultSize.width))
        h = SafeNumber.size((try? c.decode(Double.self, forKey: .h)) ?? Double(kind.defaultSize.height), fallback: Double(kind.defaultSize.height))
        colour = (try? c.decode(String.self, forKey: .colour)) ?? ""
        todo = (try? c.decode(Bool.self, forKey: .todo)) ?? false
        parent = try? c.decode(UUID.self, forKey: .parent)
        order = (try? c.decode(Double.self, forKey: .order)) ?? 0
        folded = (try? c.decode(Bool.self, forKey: .folded)) ?? false
        bothSides = (try? c.decode(Bool.self, forKey: .bothSides)) ?? false
        side = try? c.decode(Side.self, forKey: .side)
        start = try? c.decode(String.self, forKey: .start)
        end = try? c.decode(String.self, forKey: .end)
        row = try? c.decode(Int.self, forKey: .row)
        lanes = try? c.decode(Lanes.self, forKey: .lanes)
        from = try? c.decode(UUID.self, forKey: .from)
        to = try? c.decode(UUID.self, forKey: .to)
        answer = try? c.decode(Bool.self, forKey: .answer)
        strokes = (try? c.decode([Lenient<Stroke>].self, forKey: .strokes))?.compactMap(\.value)
        picture = try? c.decode(String.self, forKey: .picture)
        crop = Item.cleanCrop(try? c.decode([Double].self, forKey: .crop))
        door = try? c.decode(UUID.self, forKey: .door)
        doneDay = try? c.decode(String.self, forKey: .doneDay)
        votes = try? c.decode(Int.self, forKey: .votes)
        locked = try? c.decode(Bool.self, forKey: .locked)
        linkTitle = try? c.decode(String.self, forKey: .linkTitle)
        pictureWords = try? c.decode(String.self, forKey: .pictureWords)
        if let t = try? c.decode(Double.self, forKey: .tilt), t.isFinite { tilt = max(-180, min(180, t)) }
        textSize = try? c.decode(String.self, forKey: .textSize)
        cells = try? c.decode([[String]].self, forKey: .cells)
        planStart = try? c.decode(String.self, forKey: .planStart)
        planEnd = try? c.decode(String.self, forKey: .planEnd)
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
        try c.encodeIfPresent(side, forKey: .side)
        try c.encodeIfPresent(start, forKey: .start)
        try c.encodeIfPresent(end, forKey: .end)
        try c.encodeIfPresent(row, forKey: .row)
        try c.encodeIfPresent(lanes, forKey: .lanes)
        try c.encodeIfPresent(from, forKey: .from)
        try c.encodeIfPresent(to, forKey: .to)
        try c.encodeIfPresent(answer, forKey: .answer)
        try c.encodeIfPresent(strokes, forKey: .strokes)
        try c.encodeIfPresent(picture, forKey: .picture)
        try c.encodeIfPresent(crop, forKey: .crop)
        try c.encodeIfPresent(door, forKey: .door)
        try c.encodeIfPresent(doneDay, forKey: .doneDay)
        try c.encodeIfPresent(votes, forKey: .votes)
        try c.encodeIfPresent(locked, forKey: .locked)
        try c.encodeIfPresent(linkTitle, forKey: .linkTitle)
        try c.encodeIfPresent(pictureWords, forKey: .pictureWords)
        try c.encodeIfPresent(tilt, forKey: .tilt)
        try c.encodeIfPresent(textSize, forKey: .textSize)
        try c.encodeIfPresent(cells, forKey: .cells)
        try c.encodeIfPresent(planStart, forKey: .planStart)
        try c.encodeIfPresent(planEnd, forKey: .planEnd)
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
    /// 0.2: the side of the first item the owner chose for the line to leave from (nil: found by the app).
    public var fromSide: Direction?
    /// 0.2: the side of the second item the owner chose for the line to arrive at (nil: found by the app).
    public var toSide: Direction?
    /// 0.2: an arrow head at the near end as well (both ways).
    public var tail: Bool?
    /// 0.2: drawn with dashes.
    public var dashed: Bool?

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

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, from, to, text, colour, style, head
        case fromSide, toSide, tail, dashed
    }

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
        fromSide = (try? c.decode(String.self, forKey: .fromSide)).flatMap { Direction(rawValue: $0) }
        toSide = (try? c.decode(String.self, forKey: .toSide)).flatMap { Direction(rawValue: $0) }
        tail = try? c.decode(Bool.self, forKey: .tail)
        dashed = try? c.decode(Bool.self, forKey: .dashed)
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
        try c.encodeIfPresent(fromSide?.rawValue, forKey: .fromSide)
        try c.encodeIfPresent(toSide?.rawValue, forKey: .toSide)
        try c.encodeIfPresent(tail, forKey: .tail)
        try c.encodeIfPresent(dashed, forKey: .dashed)
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

/// One thing of a board that became a task in PARAGON (format 5): which thing, the task's words exactly as they
/// were sent (without the box in front), and where it went. The board uses it to show "in PARAGON", to find the
/// task again when PARAGON's note is read, and to send only what is new the next time.
public struct SentTask: Codable, Equatable, Sendable {
    /// The thing on the board.
    public var id: UUID
    /// The task line as it was sent, without "- [ ] " in front, e.g. "Permit (starts 1 Dec) >2026-12-05".
    public var words: String
    /// Where it went: `SentTask.inbox` (PARAGON's Inbox, by the waiting list) or `SentTask.note` (inside the note or
    /// project the board became, or added to it later).
    public var place: String
    /// Fields in the file this version does not know: carried through a load and a save untouched.
    public private(set) var extra: [String: JSONValue] = [:]

    public static let inbox = "inbox"
    public static let note = "note"

    enum CodingKeys: String, CodingKey, CaseIterable { case id, words, place }

    public init(id: UUID, words: String, place: String) {
        self.id = id
        self.words = words
        self.place = place
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        words = (try? c.decode(String.self, forKey: .words)) ?? ""
        place = (try? c.decode(String.self, forKey: .place)) ?? SentTask.inbox
        extra = unknownFields(of: decoder, known: CodingKeys.allCases.map(\.rawValue))
    }

    public func encode(to encoder: Encoder) throws {
        try writeUnknownFields(extra, to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(words, forKey: .words)
        try c.encode(place, forKey: .place)
    }
}

public struct Board: Codable, Identifiable, Equatable, Sendable {
    /// Raise this when a new version writes something an older version would lose: a new stored field,
    /// a new kind of item or arrow. A test (`StoredFieldsTests`) fails when a field is added without it.
    /// 2 (Seedboard 0.2): the timeline board — `kind` on the board; bars, milestones and phases with
    /// `start`, `end` and `row`; a main branch's `side`. An app that only knows 1 shows such a board without letting it be changed.
    /// 3 (Seedboard 0.3): pictures on a board — the kind `picture` and the field `picture` on an item.
    /// 4 (Seedboard 0.4): a cropped picture — the field `crop` on an item (the part of the picture that is shown).
    /// 5 (Seedboard 0.5): a door to another board — the kind `door` and the field `door` on an item; the day a
    /// timeline bar was done — `doneDay` on an item; every thing that became a PARAGON task — `sentTasks` on the board.
    /// 6 (Seedboard 0.9): vote dots, pinned in place, a web page's title, the words inside a picture (`votes`,
    /// `locked`, `linkTitle`, `pictureWords` on an item); the board's colour legend, background, numbered steps and
    /// "put away" (`legend`, `backdrop`, `numberSteps`, `putAway` on the board); a highlighter stroke (`pen` on a stroke).
    /// 7 (Seedboard 0.11): a board's own due day (`due` on the board, "yyyy-MM-dd").
    public static let currentFormat = 8

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
    /// Every thing that became a task in PARAGON, with the words that were sent (format 5). One entry per thing:
    /// use `noteSent` to add, never append by hand.
    public var sentTasks: [SentTask] = []
    /// Fields in the file this version does not know: carried through a load and a save untouched.
    public private(set) var extra: [String: JSONValue] = [:]
    /// What kind of board this is: "timeline", "sequence" (Who does what), or nothing for an ordinary board.
    public var kind: String?
    /// 0.9 (format 6): what each sticky-note colour means on this board, colour name → words. nil = no legend.
    public var legend: [String: String]?
    /// 0.9 (format 6): the board's background: "dots" or "squares". nil = plain.
    public var backdrop: String?
    /// 0.9 (format 6): the steps of a flowchart are numbered. nil = not.
    public var numberSteps: Bool?
    /// 0.9 (format 6): the day the board was put away (out of the list, never deleted). nil = in the list.
    public var putAway: Date?
    /// 0.11 (format 7): the board's own due day, "yyyy-MM-dd" (shown on its card, sorts the list, goes to PARAGON as
    /// the project's due day). nil = none.
    public var due: String?
    /// 0.14 (format 8): the board asks for Face ID / Touch ID / the device code before it opens. nil = open.
    public var faceLock: Bool?
    /// 0.14 (format 8): a timeline hides its done bars and milestones. nil = all shown.
    public var hideDone: Bool?

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
        case kind
        case sentTasks
        case legend, backdrop, numberSteps, putAway, due
        case faceLock, hideDone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? "Board"
        // An unreadable "created" takes the file's own date when the reader gave it, so "newer wins" stays right.
        created = (try? c.decode(Date.self, forKey: .created)) ?? (decoder.userInfo[Board.fileDateKey] as? Date) ?? Date(timeIntervalSince1970: 0)
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
        kind = try? c.decode(String.self, forKey: .kind)
        sentTasks = ((try? c.decode([Lenient<SentTask>].self, forKey: .sentTasks)) ?? []).compactMap(\.value)
        legend = try? c.decode([String: String].self, forKey: .legend)
        backdrop = try? c.decode(String.self, forKey: .backdrop)
        numberSteps = try? c.decode(Bool.self, forKey: .numberSteps)
        putAway = try? c.decode(Date.self, forKey: .putAway)
        due = try? c.decode(String.self, forKey: .due)
        faceLock = try? c.decode(Bool.self, forKey: .faceLock)
        hideDone = try? c.decode(Bool.self, forKey: .hideDone)
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
        try c.encodeIfPresent(kind, forKey: .kind)
        // Written only when it holds something, so a board nothing was sent from stays as small as before.
        if !sentTasks.isEmpty { try c.encode(sentTasks, forKey: .sentTasks) }
        try c.encodeIfPresent(legend, forKey: .legend)
        try c.encodeIfPresent(backdrop, forKey: .backdrop)
        try c.encodeIfPresent(numberSteps, forKey: .numberSteps)
        try c.encodeIfPresent(putAway, forKey: .putAway)
        try c.encodeIfPresent(due, forKey: .due)
        try c.encodeIfPresent(faceLock, forKey: .faceLock)
        try c.encodeIfPresent(hideDone, forKey: .hideDone)
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
    public mutating func touch(_ now: Date = Date()) {
        changed = max(now, changed.addingTimeInterval(0.001))
        // A board this version changes is written in this version's format, so an older app shows it read-only
        // instead of saving it back without what it does not know.
        format = max(format, Board.currentFormat)
    }
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
