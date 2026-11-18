import Foundation
import CoreGraphics

// 0.5, the flow of thinking (picks 10, 11 and 12): the next sticky note while typing; a thing turned into
// another kind; loose notes made into a mind map and an idea broken into notes again; a pile of notes sorted
// (one colour for several, a neat grid, columns by colour, all notes of one colour chosen).
// Every rule here is off on a board that places its things itself (a timeline, "Who does what").

public enum Thinking {
    /// The air between two notes that the app lays itself: the next note, a grid, columns by colour, a column of notes.
    public static let gap: Double = 16
    /// The most things side by side in a tidy grid.
    public static let mostAcross = 5

    /// How many things lie side by side in a tidy grid of `count` things: never more than five, and the rows
    /// are filled evenly (6 things lie 3 and 3, not 5 and 1).
    public static func across(_ count: Int) -> Int {
        guard count > 0 else { return 1 }
        let rows = (count + mostAcross - 1) / mostAcross
        return (count + rows - 1) / rows
    }

    /// The paper a sticky note takes for a colour name from elsewhere (a branch, a shape): its own when sticky
    /// notes have that colour, else the nearest paper; yellow for none.
    public static func notePaper(for colour: String) -> String {
        if Palette.notes.contains(colour) { return colour }
        switch colour {
        case "teal": return "green"
        case "red": return "pink"
        default: return "yellow"
        }
    }

    /// Reading order: row by row from the top, each row from the left. Things belong to one row when their
    /// middles lie within the height of the row's topmost thing.
    public static func readingOrder(_ things: [Item]) -> [Item] {
        let byTop = things.sorted { ($0.centre.y, $0.centre.x, $0.id.uuidString) < ($1.centre.y, $1.centre.x, $1.id.uuidString) }
        var rows: [[Item]] = []
        for thing in byTop {
            if let first = rows.last?.first, Double(thing.centre.y) < first.y + first.h {
                rows[rows.count - 1].append(thing)
            } else {
                rows.append([thing])
            }
        }
        return rows.flatMap { row in row.sorted { ($0.centre.x, $0.id.uuidString) < ($1.centre.x, $1.id.uuidString) } }
    }
}

public extension Board {
    private var thinkingIsOn: Bool { canBeChanged && !placesItself }

    // MARK: The next note (pick 10)

    /// Tab while a sticky note is typed: the next note, in the same colour and size, 16 points to the right of
    /// this one. When that place is taken it goes under the first note of the row instead (and further down
    /// until a place is free). Returns the new note; nothing when `id` is no sticky note.
    @discardableResult
    mutating func addNextNote(after id: UUID) -> UUID? {
        guard thinkingIsOn, let me = item(id), me.kind == .note else { return nil }
        var next = Item(kind: .note, w: me.w, h: me.h, colour: me.colour)
        func taken(_ box: CGRect) -> Bool {
            let inner = box.insetBy(dx: 1, dy: 1)
            return items.contains { $0.kind != .frame && !isHidden($0.id) && $0.frame.intersects(inner) }
        }
        next.x = me.x + me.w + Thinking.gap
        next.y = me.y
        if taken(next.frame) {
            // The row this note stands in: the notes to its left that stand close beside each other.
            var first = me
            var bottom = me.y + me.h
            var steps = 0
            while steps < 500, let left = items.filter({
                $0.kind == .note && $0.id != first.id && abs($0.y - first.y) < first.h / 2
                    && $0.x + $0.w <= first.x + 1 && first.x - ($0.x + $0.w) <= Thinking.gap * 2.5
            }).max(by: { $0.x < $1.x }) {
                first = left
                bottom = max(bottom, left.y + left.h)
                steps += 1
            }
            next.x = first.x
            next.y = bottom + Thinking.gap
            var tries = 0
            while tries < 40, taken(next.frame) {
                next.y += next.h + Thinking.gap
                tries += 1
            }
        }
        items.append(next)
        return next.id
    }

    // MARK: Turn into (pick 11)

    /// The kinds a thing can be turned into, in the order of the list.
    static let turnKinds: [ItemKind] = [.note, .box, .text, .idea]

    /// True when the thing can be turned into this kind: a sticky note, a text, a flow shape or an idea, into
    /// one of `turnKinds` it is not already. The middle of a map that has branches stays an idea.
    func canTurn(_ id: UUID, into kind: ItemKind) -> Bool {
        guard thinkingIsOn, Board.turnKinds.contains(kind), let item = item(id), item.unknownKind == nil, !isHidden(id) else { return false }
        guard item.kind == .note || item.kind == .text || item.kind == .idea || item.kind.isShape, item.kind != kind else { return false }
        if item.kind == .idea, item.parent == nil, !children(of: id).isEmpty { return false }
        return true
    }

    /// The kinds at least one of the chosen things can be turned into, in the order of the list.
    func turnChoices(for ids: Set<UUID>) -> [ItemKind] {
        Board.turnKinds.filter { kind in ids.contains { canTurn($0, into: kind) } }
    }

    /// Turns the chosen things into another kind. The words, the colour, the To do tick, the middle and the
    /// arrows stay. An idea leaves its map, and the ideas under it move up to the idea it hung under, in its
    /// place. A thing turned into an idea is the middle of a small map of its own. Returns what was turned.
    @discardableResult
    mutating func turn(_ ids: Set<UUID>, into kind: ItemKind) -> Set<UUID> {
        var turned: Set<UUID> = []
        for id in items.map(\.id) where ids.contains(id) && canTurn(id, into: kind) {
            guard let old = item(id) else { continue }
            if old.kind.isShape, kind.isShape {
                setKind(id, to: kind)
                turned.insert(id)
                continue
            }
            let centre = old.centre
            let colour = colourInUse(of: id) ?? ""
            if old.kind == .idea { leaveMap(id) }
            guard let i = index(of: id) else { continue }
            makePlain(i, kind: kind)
            switch kind {
            case .note: items[i].colour = Thinking.notePaper(for: colour)
            case .idea: items[i].colour = ""
            default: items[i].colour = Palette.names.contains(colour) ? colour : ""
            }
            items[i].x = Double(centre.x) - items[i].w / 2
            items[i].y = Double(centre.y) - items[i].h / 2
            turned.insert(id)
        }
        if !turned.isEmpty { layoutMaps() }
        return turned
    }

    /// The thing becomes a thing of another kind at the kind's own size, hanging under nothing.
    private mutating func makePlain(_ i: Int, kind: ItemKind) {
        items[i].kind = kind
        items[i].parent = nil
        items[i].order = 0
        items[i].folded = false
        items[i].side = nil
        items[i].bothSides = kind == .idea
        let size = kind == .idea ? Board.roughSize(for: items[i].text, centre: true) : kind.defaultSize
        items[i].w = Double(size.width)
        items[i].h = Double(size.height)
    }

    /// An idea is about to stop being an idea: the ideas under it hang under the idea it hung under, in its
    /// place among the sisters (main branches stay on its side).
    private mutating func leaveMap(_ id: UUID) {
        guard let me = item(id), me.kind == .idea, let parentID = me.parent else { return }
        let kids = children(of: id).map(\.id)
        guard !kids.isEmpty else { return }
        var order = children(of: parentID).map(\.id)
        let at = order.firstIndex(of: id) ?? order.count
        var moved: [UUID] = []
        for kid in kids where reparent(kid, under: parentID) {
            moved.append(kid)
            if let side = me.side, let k = index(of: kid), items[k].side != nil { items[k].side = side }
        }
        order.insert(contentsOf: moved, at: min(at, order.count))
        for (n, each) in order.enumerated() {
            if let i = index(of: each) { items[i].order = Double(n + 1) }
        }
    }

    // MARK: A note becomes an idea (pick 11)

    /// True for a sticky note, a box or a text: dragged onto an idea it becomes an idea under that one.
    func canBecomeIdea(_ id: UUID) -> Bool {
        guard thinkingIsOn, let item = item(id), item.unknownKind == nil else { return false }
        return item.kind == .note || item.kind == .box || item.kind == .text
    }

    /// A sticky note, a box or a text becomes an idea under `target`, after the ideas already there. Its words,
    /// its To do tick and its arrows stay. Under the middle of a map it is a main branch and keeps its colour
    /// when branches have that colour (a plain yellow note takes the next branch colour).
    @discardableResult
    mutating func makeIdea(_ id: UUID, under target: UUID) -> Bool {
        guard canBecomeIdea(id), let over = item(target), over.kind == .idea else { return false }
        guard hangAsIdea(id, under: target) else { return false }
        layoutMaps()
        return true
    }

    private mutating func hangAsIdea(_ id: UUID, under target: UUID) -> Bool {
        guard let i = index(of: id), let over = item(target), over.kind == .idea else { return false }
        let colour = colourInUse(of: id) ?? ""
        makePlain(i, kind: .idea)
        items[i].bothSides = false
        let size = Board.roughSize(for: items[i].text)
        items[i].w = Double(size.width)
        items[i].h = Double(size.height)
        items[i].colour = over.parent == nil && Palette.branches.contains(colour) ? colour : ""
        return reparent(id, under: target)
    }

    // MARK: Make a mind map (pick 11)

    /// The chosen things a mind map can be made of: sticky notes and texts.
    func mapMakers(_ ids: Set<UUID>) -> [Item] {
        guard thinkingIsOn else { return [] }
        return items.filter { ids.contains($0.id) && $0.unknownKind == nil && ($0.kind == .note || $0.kind == .text) }
    }

    /// Makes one mind map of the chosen sticky notes and texts (two or more). `middle` is the middle idea
    /// ("Ideas" when it is empty); it stands in the middle of where the notes lay. The notes become main branches
    /// in reading order. Notes that lie in a frame with a name hang under a branch that carries the frame's name;
    /// a frame that was chosen too and is left empty goes. Words, To do ticks and arrows stay. Returns the middle idea.
    @discardableResult
    mutating func makeMap(of ids: Set<UUID>, middle: String) -> UUID? {
        let notes = mapMakers(ids)
        guard notes.count >= 2, let first = notes.first else { return nil }
        let noteIDs = Set(notes.map(\.id))
        let box = notes.dropFirst().reduce(first.frame) { $0.union($1.frame) }

        // Which named frame each note lies in.
        var home: [UUID: UUID] = [:]
        for note in notes {
            guard let frameID = spot(of: note.id)?.frame, let frame = item(frameID),
                  !ParagonExport.oneLine(frame.text).isEmpty else { continue }
            home[note.id] = frameID
        }
        let frames = Set(home.values)
        // A chosen frame that held nothing but these notes is used up.
        let spent = frames.filter { ids.contains($0) && things(in: $0).allSatisfy { noteIDs.contains($0.id) } }

        let name = middle.trimmingCharacters(in: .whitespacesAndNewlines)
        let centre = addCentre(at: CGPoint(x: box.midX, y: box.midY), text: name.isEmpty ? "Ideas" : name)
        if let c = index(of: centre) {
            let size = Board.roughSize(for: items[c].text, centre: true)
            items[c].w = Double(size.width)
            items[c].h = Double(size.height)
            items[c].x = Double(box.midX) - items[c].w / 2
            items[c].y = Double(box.midY) - items[c].h / 2
        }

        // The branches in reading order: a loose note is one, a named frame with its notes is one.
        let units = Thinking.readingOrder(notes.filter { home[$0.id] == nil } + items.filter { frames.contains($0.id) })
        for unit in units {
            if unit.kind == .frame {
                guard let branch = addChild(of: centre, text: ParagonExport.oneLine(unit.text)), let b = index(of: branch) else { continue }
                let size = Board.roughSize(for: items[b].text)
                items[b].w = Double(size.width)
                items[b].h = Double(size.height)
                for note in Thinking.readingOrder(notes.filter { home[$0.id] == unit.id }) { _ = hangAsIdea(note.id, under: branch) }
            } else {
                _ = hangAsIdea(unit.id, under: centre)
            }
        }
        if !spent.isEmpty { remove(Set(spent)) }
        if let c = index(of: centre) { items[c].bothSides = children(of: centre).count > 4 }
        layoutMaps()
        return centre
    }

    // MARK: Break into notes (pick 11)

    /// The way back: the idea and every idea under it become sticky notes in one column, top left where the idea
    /// stood, 16 points apart, in the order of the list (an idea, then those under it), in the paper of the
    /// branch's colour. Words, To do ticks and arrows stay. Returns the notes from the top down.
    @discardableResult
    mutating func breakIntoNotes(_ id: UUID) -> [UUID] {
        guard thinkingIsOn, let top = item(id), top.kind == .idea else { return [] }
        var order: [UUID] = []
        var seen: Set<UUID> = []
        var open = [id]
        while let next = open.popLast() {
            guard seen.insert(next).inserted else { continue }
            order.append(next)
            open.append(contentsOf: children(of: next).map(\.id).reversed())
        }
        let papers = order.map { Thinking.notePaper(for: branchColour(of: $0)) }
        for (n, each) in order.enumerated() {
            guard let i = index(of: each) else { continue }
            makePlain(i, kind: .note)
            items[i].colour = papers[n]
            items[i].x = top.x
            items[i].y = top.y
        }
        stackColumn(order)
        layoutMaps()
        return order
    }

    /// Stands the things one under the other, 16 points apart, from the first one's place, left edges in line.
    /// (The app calls it again once the notes have the height their words need.)
    mutating func stackColumn(_ ids: [UUID]) {
        guard let first = ids.first.flatMap({ item($0) }) else { return }
        var y = first.y
        for id in ids {
            guard let i = index(of: id) else { continue }
            items[i].x = first.x
            items[i].y = y
            y += items[i].h + Thinking.gap
        }
    }

    // MARK: Sort a pile (pick 12)

    /// The chosen things that carry a colour of their own: sticky notes, shapes, frames and the ideas of a branch.
    func colourable(_ ids: Set<UUID>) -> [Item] {
        items.filter { ids.contains($0.id) && ($0.kind == .note || $0.kind.isShape || $0.kind == .frame || $0.kind == .drawing || ($0.kind == .idea && $0.parent != nil)) }
    }

    /// The one colour all the chosen things show ("" = no colour); nil when they differ or none carries a colour.
    func sharedColour(of ids: Set<UUID>) -> String? {
        let all = Set(colourable(ids).compactMap { colourInUse(of: $0.id) })
        return all.count == 1 ? all.first : nil
    }

    /// The colours several chosen things can take together: the six papers when a sticky note is among them,
    /// else all nine; "" (no colour) comes first when they are all shapes. Nothing when none carries a colour.
    func coloursOffered(for ids: Set<UUID>) -> [String] {
        let all = colourable(ids)
        guard thinkingIsOn, !all.isEmpty else { return [] }
        if all.contains(where: { $0.kind == .note }) { return Palette.notes }
        return (all.allSatisfy { $0.kind.isShape || $0.kind == .drawing } ? [""] : []) + Palette.names
    }

    /// One colour for all the chosen things that carry one. In a mind map the colour belongs to the whole branch.
    mutating func setColour(_ name: String, of ids: Set<UUID>) {
        guard thinkingIsOn else { return }
        for item in colourable(ids) {
            if item.kind == .idea {
                if let branch = mainBranch(of: item.id), let b = index(of: branch) { items[b].colour = name }
            } else if item.kind == .drawing {
                recolourSketch(item.id, to: name)
            } else if let i = index(of: item.id) {
                items[i].colour = name
            }
        }
    }

    /// The chosen things a grid is made of: sticky notes, flow shapes and texts.
    func gridable(_ ids: Set<UUID>) -> [Item] {
        guard thinkingIsOn else { return [] }
        return tidyable(ids).filter { $0.kind == .note || $0.kind.isShape || $0.kind == .text }
    }

    /// Tidy: the chosen notes and shapes (three or more) become a neat grid where the pile lies. Its top left
    /// corner stays; at most five lie side by side; 16 points between them; reading order is kept. Every
    /// column is as wide as its widest thing, every row as high as its tallest.
    mutating func tidyGrid(_ ids: Set<UUID>) {
        let all = Thinking.readingOrder(gridable(ids))
        guard all.count >= 3 else { return }
        let across = Thinking.across(all.count)
        let left = all.map(\.x).min() ?? 0, top = all.map(\.y).min() ?? 0
        var widths = Array(repeating: 0.0, count: across)
        var heights = Array(repeating: 0.0, count: (all.count + across - 1) / across)
        for (n, item) in all.enumerated() {
            widths[n % across] = max(widths[n % across], item.w)
            heights[n / across] = max(heights[n / across], item.h)
        }
        for (n, item) in all.enumerated() {
            guard let i = index(of: item.id) else { continue }
            items[i].x = left + widths[..<(n % across)].reduce(0, +) + Thinking.gap * Double(n % across)
            items[i].y = top + heights[..<(n / across)].reduce(0, +) + Thinking.gap * Double(n / across)
        }
    }

    /// By colour: the chosen notes and shapes (three or more) stand in one column per colour, the columns in
    /// the order of the colour dots (things without a colour last), each column in reading order. The top left
    /// corner of the pile stays; 16 points between the things and between the columns.
    mutating func tidyByColour(_ ids: Set<UUID>) {
        let all = Thinking.readingOrder(gridable(ids))
        guard all.count >= 3 else { return }
        let dots = all.allSatisfy { $0.kind == .note } ? Palette.notes : Palette.names
        func rank(_ item: Item) -> Int { dots.firstIndex(of: colourInUse(of: item.id) ?? "") ?? dots.count }
        let left = all.map(\.x).min() ?? 0, top = all.map(\.y).min() ?? 0
        var x = left
        for place in 0...dots.count {
            let column = all.filter { rank($0) == place }
            guard !column.isEmpty else { continue }
            var y = top
            for item in column {
                guard let i = index(of: item.id) else { continue }
                items[i].x = x
                items[i].y = y
                y += item.h + Thinking.gap
            }
            x += (column.map(\.w).max() ?? 0) + Thinking.gap
        }
    }

    /// "Choose all of this colour": every sticky note on the board with the paper of this one.
    func notes(colouredLike id: UUID) -> Set<UUID> {
        guard let me = item(id), me.kind == .note, let paper = colourInUse(of: id) else { return [] }
        return Set(items.filter { $0.kind == .note && colourInUse(of: $0.id) == paper }.map(\.id))
    }
}
