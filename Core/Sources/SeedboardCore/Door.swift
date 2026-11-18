import Foundation
import CoreGraphics

// 0.5, pick 13: a door from one board to another.
//
// A door is a thing of its own kind (`ItemKind.door`) that holds the identity of the board it leads to in
// `Item.door`, and that board's name in `Item.text` (the app keeps the name current, so the words that go
// to PARAGON, the board's text and the search always say the name the board has now).
// The rules here are plain: what a door shows, how one is made, how chosen things move to a new board and
// leave a door behind, the way back, and the line a door becomes in PARAGON.

public enum Door {
    /// What a door shows on the board.
    public enum Face: Equatable, Sendable {
        /// The board is here: its name and the colour of its dot.
        case open(title: String, colour: String)
        /// The board was removed (it is kept for 30 days in the Removed folder): the name the door remembers.
        case removed(name: String)
        /// The board is not on this device (yet): the name the door remembers.
        case away(name: String)
    }

    /// The line on a door whose board was removed.
    public static let removedWords = "This board was removed"
    /// The line on a door whose board has not arrived on this device.
    public static let awayWords = "Not on this device yet"

    /// What the door shows: `board` is the board it leads to when that board is in the list, `removed` says
    /// that the board lies in the Removed folder.
    public static func face(of door: Item, board: Board?, removed: Bool) -> Face {
        if let board { return .open(title: board.title, colour: board.colour) }
        let name = ParagonExport.oneLine(door.text)
        return removed ? .removed(name: name) : .away(name: name)
    }

    /// A board's name made from typed words: one line, at most 60 letters, never empty.
    public static func cleanName(_ words: String) -> String {
        let one = ParagonExport.oneLine(words)
        let short = one.count > 60 ? String(one.prefix(60)).trimmingCharacters(in: .whitespaces) : one
        return short.isEmpty ? "New board" : short
    }

    /// A name no other board has: "Kitchen", "Kitchen 2", "Kitchen 3" … (upper and lower case count as the
    /// same). "New board" may stand more than once, as in the list.
    public static func freeName(_ wanted: String, taken: [String]) -> String {
        let base = cleanName(wanted)
        guard base != "New board" else { return base }
        let used = Set(taken.map { $0.lowercased() })
        var name = base
        var n = 2
        while used.contains(name.lowercased()) {
            name = "\(base) \(n)"
            n += 1
        }
        return name
    }

    /// The board a dropped or pasted line of words leads to, when the words are nothing but a board's link
    /// (`seedboard://board/<id>`) — a board dragged from the list.
    public static func target(ofLink words: String) -> UUID? {
        let clean = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.contains(" "), !clean.contains("\n"), let url = URL(string: clean) else { return nil }
        return BoardLink.id(from: url)
    }

    /// The door as it stands in PARAGON's note or project: its board's name as a link that opens that board,
    /// "[Kitchen plan](seedboard://board/<id>)". Square brackets in a name would end the link early: they
    /// become round ones. A door that leads nowhere gives nothing.
    public static func link(for door: Item) -> String? {
        guard door.kind == .door, let target = door.door else { return nil }
        var name = ParagonExport.oneLine(door.text)
        if name.isEmpty { name = "A board" }
        name = name.replacingOccurrences(of: "[", with: "(").replacingOccurrences(of: "]", with: ")")
        return "[\(name)](\(ParagonExport.boardLink(target)))"
    }
}

/// The way back through the doors he came through: the boards, the one he left first at the front.
/// Opening a board in any other way (the list, the home page, a link, a new board) ends the walk.
public struct DoorTrail: Equatable, Sendable {
    /// The boards he came through, oldest first.
    public private(set) var came: [UUID] = []
    /// The board the walk has reached.
    public private(set) var at: UUID?
    /// A door was gone through and its board is about to open (or will, when iCloud brings it).
    private var headingFrom: UUID?
    private var headingTo: UUID?

    public init() {}

    /// The board "‹ name" goes back to; nil when he did not come through a door.
    public var back: UUID? { came.last }

    /// A door on `from` was gone through; `to` is the board it leads to. Say this BEFORE that board opens.
    public mutating func through(from: UUID, to: UUID) {
        guard from != to else { return }
        headingFrom = from
        headingTo = to
    }

    /// A board was opened (nil: the home page or the list). Say this for EVERY board that opens.
    public mutating func opened(_ id: UUID?) {
        if let id, id == headingTo, let from = headingFrom {
            // Through the door: the board he left joins the way back.
            if at != from { came = [] }
            came.append(from)
            if came.count > 50 { came.removeFirst(came.count - 50) }
            at = id
            headingFrom = nil
            headingTo = nil
            return
        }
        if let id, id == at { return }
        // Any other board: the walk is over. (Home keeps a door whose board is still on its way.)
        if id != nil {
            headingFrom = nil
            headingTo = nil
        }
        came = []
        at = id
    }

    /// One step back: the board to open now. Say `opened` for it afterwards, as for every board.
    public mutating func stepBack() -> UUID? {
        guard let last = came.popLast() else { return nil }
        at = last
        return last
    }

    /// A board is gone (removed): it is no longer a place to go back to.
    public mutating func forget(_ id: UUID) {
        came.removeAll { $0 == id }
    }
}

public extension Board {
    /// The doors on the board.
    var doors: [Item] { items.filter { $0.kind == .door } }

    /// A door to `target` can be put on this board: the board can be changed, it is not a timeline or a
    /// "Who does what" board (they place their things themselves), and the door would not lead to itself.
    func canHaveDoor(to target: UUID) -> Bool {
        canBeChanged && !placesItself && target != id
    }

    /// A door to another board, its middle at the point, carrying that board's name. nil when this board
    /// takes no door to it (`canHaveDoor`).
    @discardableResult
    mutating func addDoor(to target: UUID, name: String, centre: CGPoint) -> UUID? {
        guard canHaveDoor(to: target) else { return nil }
        var door = Item(kind: .door, text: ParagonExport.oneLine(name))
        door.door = target
        door.x = Double(centre.x) - door.w / 2
        door.y = Double(centre.y) - door.h / 2
        items.append(door)
        return door.id
    }

    /// Every door carries the name its board has now (`names`: board → name). A door whose board is not
    /// among them keeps the name it remembers. True when a name changed.
    @discardableResult
    mutating func nameDoors(_ names: [UUID: String]) -> Bool {
        var changed = false
        for i in items.indices where items[i].kind == .door {
            guard let target = items[i].door, let name = names[target], items[i].text != name else { continue }
            items[i].text = name
            changed = true
        }
        return changed
    }

    /// Everything that goes along when these things move to a new board: an idea with all the ideas under
    /// it (folded or not), a frame with what lies in it, a map with its ideas.
    func movingOut(_ ids: Set<UUID>) -> Set<UUID> {
        var whole = carried(by: ids)
        for id in ids where item(id)?.kind == .idea {
            whole.insert(id)
            whole.formUnion(descendants(of: id))
        }
        return whole
    }

    /// The name offered for the new board when these things move out: the words of the one thing that was
    /// chosen (an idea, a frame, a note …), else "Part of <this board>".
    func nameForMovedOut(_ ids: Set<UUID>) -> String {
        // What a chosen frame or map carries along was not chosen for its own name.
        var tops = ids
        for id in ids {
            guard let item = item(id), item.kind == .frame || (item.kind == .idea && item.parent == nil) else { continue }
            tops.subtract(carried(by: [id]).subtracting([id]))
        }
        if tops.count == 1, let one = tops.first.flatMap({ item($0) }), one.kind != .door {
            let words = ParagonExport.oneLine(one.text)
            if !words.isEmpty { return Door.cleanName(String(words.prefix(40))) }
        }
        return Door.cleanName("Part of \(title)")
    }

    /// "Move to a new board…": the chosen things (with what goes along, `movingOut`) leave this board and
    /// become a new board called `title`; a door to it is left where they lay, in the middle of the room
    /// they took (a little lower when a map that closed up lies there now). They keep their identities, their places and what is known about their tasks in PARAGON.
    /// The arrows among them go along; an arrow that ran between a moved thing and one that stays now starts
    /// or ends at the door. A branch moved without the idea it hung under is the middle of its own map there.
    /// Returns the new board and the door; nil when nothing can be moved (the board cannot be changed, it
    /// places its things itself, or none of the things is on it).
    mutating func moveToNewBoard(_ ids: Set<UUID>, title: String, newID: UUID = UUID(), colour: String = "green",
                                 now: Date = Date()) -> (board: Board, door: UUID)? {
        guard canBeChanged, !placesItself else { return nil }
        let whole = movingOut(ids)
        let moving = items.filter { whole.contains($0.id) }
        guard !moving.isEmpty else { return nil }
        let room = moving.dropFirst().reduce(moving[0].frame) { $0.union($1.frame) }

        var new = Board(id: newID, title: Door.cleanName(title), created: now, colour: colour)
        new.items = moving
        new.links = links.filter { whole.contains($0.from) && whole.contains($0.to) }
        new.sentTodos = sentTodos.filter { whole.contains($0) }
        new.sentTasks = sentTasks.filter { whole.contains($0.id) }
        // A branch that leaves the idea it hung under: the middle of its own map, its ideas keep its colour.
        for top in moving where top.kind == .idea {
            guard let parent = top.parent, !whole.contains(parent), let t = new.index(of: top.id) else { continue }
            let branch = branchColour(of: top.id)
            new.items[t].parent = nil
            new.items[t].colour = ""
            new.items[t].side = nil
            new.items[t].bothSides = false
            for child in new.children(of: top.id) {
                guard let c = new.index(of: child.id) else { continue }
                new.items[c].side = nil
                if new.items[c].colour.isEmpty { new.items[c].colour = branch }
            }
        }
        new.layoutMaps()

        var door = Item(kind: .door, text: new.title)
        door.door = newID
        door.x = Double(room.midX) - door.w / 2
        door.y = Double(room.midY) - door.h / 2

        var kept: [Link] = []
        for var link in links {
            let from = whole.contains(link.from), to = whole.contains(link.to)
            if from && to { continue }
            if from {
                link.from = door.id
                link.fromSide = nil
            } else if to {
                link.to = door.id
                link.toSide = nil
            }
            // Two arrows that now run the same way between the same two things are one.
            if (from || to), kept.contains(where: { $0.from == link.from && $0.to == link.to }) { continue }
            kept.append(link)
        }
        links = kept
        items.removeAll { whole.contains($0.id) }
        sentTodos.removeAll { whole.contains($0) }
        sentTasks.removeAll { whole.contains($0.id) }
        layoutMaps()
        // A map that lost a branch closes up and may now lie where the door would stand: the door steps down
        // (its own height and 12 points at a time) until it covers nothing.
        var tries = 0
        while tries < 14, items.contains(where: { $0.kind != .frame && !isHidden($0.id) && $0.frame.insetBy(dx: -8, dy: -8).intersects(door.frame) }) {
            door.y += door.h + 12
            tries += 1
        }
        items.append(door)
        return (new, door.id)
    }
}

extension ParagonExport {
    /// The doors of a board as lines for PARAGON's note and project: "- [Kitchen plan](seedboard://board/<id>)",
    /// in the order they were made. The link opens that board in Seedboard.
    static func doorBullets(_ board: Board) -> [String] {
        board.doors.compactMap { Door.link(for: $0) }.map { "- " + $0 }
    }
}
