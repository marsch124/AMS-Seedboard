import Foundation
import CoreGraphics

// Everything the owner can do to a board, as plain rules: add, join, move, copy, remove, find.

public enum Direction: String, CaseIterable, Sendable { case up, down, left, right }

public extension Board {
    // MARK: Adding

    /// A new shape, note, text or frame with its middle at the point.
    @discardableResult
    mutating func add(_ kind: ItemKind, centre: CGPoint, text: String = "", colour: String = "") -> UUID {
        if kind == .idea { return addCentre(at: centre, text: text) }
        var item = Item(kind: kind, text: text, colour: colour)
        if kind == .note && colour.isEmpty { item.colour = "yellow" }
        item.x = Double(centre.x) - item.w / 2
        item.y = Double(centre.y) - item.h / 2
        if kind == .frame {
            // A frame lies under everything else.
            items.insert(item, at: 0)
        } else {
            items.append(item)
        }
        return item.id
    }

    /// An arrow from one item to another. The same arrow is not made twice; a frame takes no arrows.
    @discardableResult
    mutating func link(from: UUID, to: UUID, text: String = "") -> UUID? {
        guard from != to, let a = item(from), let b = item(to), a.kind != .frame, b.kind != .frame else { return nil }
        if let same = links.first(where: { $0.from == from && $0.to == to }) { return same.id }
        let link = Link(from: from, to: to, text: text.isEmpty ? wordForNewArrow(from: from) : text)
        links.append(link)
        return link.id
    }

    /// The next shape in a flow: the same kind and size (a plain Box after a diamond or a round box),
    /// one step away in the direction, middle on middle, already joined by an arrow.
    /// It steps aside when the place is taken. An arrow that carries a word gets 30 more room.
    @discardableResult
    mutating func addNext(from id: UUID, direction: Direction, gap: Double = 70) -> UUID? {
        guard let source = item(id), source.kind != .idea, source.kind != .frame else { return nil }
        let kind = source.kind.nextInFlow
        var next = kind == source.kind ? Item(kind: kind, w: source.w, h: source.h, colour: source.colour) : Item(kind: kind)
        let word = wordForNewArrow(from: id)
        let gap = word.isEmpty ? gap : gap + 30
        switch direction {
        case .right: next.x = source.x + source.w + gap; next.y = source.y + (source.h - next.h) / 2
        case .left: next.x = source.x - gap - next.w; next.y = source.y + (source.h - next.h) / 2
        case .down: next.x = source.x + (source.w - next.w) / 2; next.y = source.y + source.h + gap
        case .up: next.x = source.x + (source.w - next.w) / 2; next.y = source.y - gap - next.h
        }
        // Step aside (down for sideways steps, right for up/down steps) until the place is free.
        var tries = 0
        while tries < 12, items.contains(where: { $0.kind != .frame && !isHidden($0.id) && $0.frame.insetBy(dx: -8, dy: -8).intersects(next.frame) }) {
            if direction == .left || direction == .right { next.y += next.h + 24 } else { next.x += next.w + 24 }
            tries += 1
        }
        items.append(next)
        links.append(Link(from: id, to: next.id, text: word))
        return next.id
    }

    // MARK: Removing and copying

    /// Removes items (an idea takes everything under it along) and arrows. Arrows that lose an end go too.
    mutating func remove(_ ids: Set<UUID>) {
        var gone = ids
        for id in ids where item(id)?.kind == .idea {
            gone.formUnion(descendants(of: id))
        }
        items.removeAll { gone.contains($0.id) }
        links.removeAll { gone.contains($0.id) || gone.contains($0.from) || gone.contains($0.to) }
        sentTodos.removeAll { gone.contains($0) }
        sentTasks.removeAll { gone.contains($0.id) }
    }

    /// Copies the items (ideas with everything under them) a little to the side, with the arrows
    /// between them. Returns the copies.
    @discardableResult
    mutating func duplicate(_ ids: Set<UUID>, by offset: CGSize = CGSize(width: 28, height: 28)) -> Set<UUID> {
        var whole = ids
        for id in ids where item(id)?.kind == .idea {
            whole.formUnion(descendants(of: id))
        }
        var newID: [UUID: UUID] = [:]
        for id in whole { newID[id] = UUID() }
        var copies: [Item] = []
        for item in items where whole.contains(item.id) {
            var copy = item
            copy.id = newID[item.id]!
            copy.todo = item.todo
            if let parent = item.parent {
                if let mapped = newID[parent] {
                    copy.parent = mapped
                } else {
                    // A lone idea copied: it becomes the next sister.
                    copy.order = item.order + 0.5
                }
            }
            if item.kind != .idea || item.parent == nil {
                copy.x += Double(offset.width)
                copy.y += Double(offset.height)
            }
            copies.append(copy)
        }
        items.append(contentsOf: copies)
        for link in links where whole.contains(link.from) && whole.contains(link.to) {
            var copy = link
            copy.id = UUID()
            copy.from = newID[link.from]!
            copy.to = newID[link.to]!
            links.append(copy)
        }
        return Set(ids.compactMap { newID[$0] })
    }

    // MARK: Moving and sizing

    /// Everything that travels when these items are dragged: a map's centre takes its ideas along,
    /// a frame takes every thing whose middle is inside it (Lanes.swift). Ideas that are not centres are left out
    /// (they are placed by the map).
    func carried(by ids: Set<UUID>) -> Set<UUID> {
        var all: Set<UUID> = []
        for id in ids {
            guard let item = item(id) else { continue }
            switch item.kind {
            case .idea:
                if item.parent == nil {
                    all.insert(id)
                    all.formUnion(descendants(of: id))
                }
            case .frame:
                all.insert(id)
                for inner in items where inner.id != id && Board.frame(item, holds: inner) {
                    if inner.kind == .idea {
                        if inner.parent == nil {
                            all.insert(inner.id)
                            all.formUnion(descendants(of: inner.id))
                        }
                    } else {
                        all.insert(inner.id)
                    }
                }
            default:
                all.insert(id)
            }
        }
        return all
    }

    /// Moves exactly these items by the amount (use `carried(by:)` first).
    mutating func move(_ ids: Set<UUID>, by delta: CGSize) {
        for i in items.indices where ids.contains(items[i].id) {
            items[i].x += Double(delta.width)
            items[i].y += Double(delta.height)
        }
    }

    /// Gives an item a new size, never smaller than it can sensibly be.
    mutating func resize(_ id: UUID, to rect: CGRect) {
        guard let i = index(of: id) else { return }
        // A drawing's lines stretch with its box (Ink.swift).
        if items[i].kind == .drawing { scaleDrawing(id, to: rect); return }
        // A picture keeps its shape (Pictures.swift).
        if items[i].kind == .picture { scalePicture(id, to: rect); return }
        let least: CGSize = items[i].kind == .frame ? items[i].leastFrameSize : CGSize(width: 44, height: 28)
        var r = rect.standardized
        if r.width < least.width { r.size.width = least.width }
        if r.height < least.height { r.size.height = least.height }
        items[i].frame = r
    }

    /// Puts an item on top of the others (frames stay underneath).
    mutating func bringToFront(_ id: UUID) {
        guard let i = index(of: id), items[i].kind != .frame, items[i].kind != .idea else { return }
        let item = items.remove(at: i)
        items.append(item)
    }

    // MARK: Finding

    /// The item under the point, the topmost first. A frame is only caught at its name band
    /// or its edge, so things inside it stay easy to reach.
    func hit(_ point: CGPoint) -> UUID? {
        for item in items.reversed() where item.kind != .frame && !isHidden(item.id) {
            if Board.contains(item, point) { return item.id }
        }
        for item in items.reversed() where item.kind == .frame {
            let f = item.frame
            guard f.insetBy(dx: -6, dy: -6).contains(point) else { continue }
            let band = CGRect(x: f.minX, y: f.minY, width: f.width, height: 30)
            if band.contains(point) || !f.insetBy(dx: 8, dy: 8).contains(point) || item.laneName(at: point) != nil { return item.id }
        }
        return nil
    }

    private static func contains(_ item: Item, _ p: CGPoint) -> Bool {
        let f = item.frame
        switch item.kind {
        case .diamond:
            let dx = abs(Double(p.x) - Double(f.midX)) / max(Double(f.width) / 2, 1)
            let dy = abs(Double(p.y) - Double(f.midY)) / max(Double(f.height) / 2, 1)
            return dx + dy <= 1.02
        case .oval:
            let dx = (Double(p.x) - Double(f.midX)) / max(Double(f.width) / 2, 1)
            let dy = (Double(p.y) - Double(f.midY)) / max(Double(f.height) / 2, 1)
            return dx * dx + dy * dy <= 1.03
        case .idea, .text:
            return f.insetBy(dx: -5, dy: -4).contains(p)
        case .picture:
            // The caption under it belongs to it.
            return f.contains(p) || (item.captionFrame?.contains(p) ?? false)
        case .drawing:
            // Only on its lines (2 points to either side), never anywhere in its box.
            return f.insetBy(dx: -2, dy: -2).contains(p) && (item.inkDistance(to: p) ?? .infinity) <= 2
        default:
            return f.contains(p)
        }
    }

    /// The arrow under the point, if one passes within the distance.
    func hitLink(_ point: CGPoint, within distance: Double = 8) -> UUID? {
        let all = arrows()
        for link in links.reversed() {
            guard let arrow = all[link.id] else { continue }
            if Route.distance(from: point, to: arrow.outline) <= distance { return link.id }
        }
        return nil
    }

    /// The items a dragged box catches: anything it touches; a frame only when wholly inside.
    func items(in rect: CGRect) -> Set<UUID> {
        var found: Set<UUID> = []
        for item in items where !isHidden(item.id) {
            if item.kind == .frame {
                if rect.contains(item.frame) { found.insert(item.id) }
            } else if rect.intersects(item.frame) {
                found.insert(item.id)
            }
        }
        return found
    }

    /// The smallest box round everything that can be seen; nil for an empty board.
    var bounds: CGRect? {
        if isTimeline { return isEmpty ? nil : timelinePicture().box }
        if isSequence { return isEmpty ? nil : CGRect(origin: .zero, size: sequenceLayout().size) }
        var all: CGRect?
        for item in items where !isHidden(item.id) {
            all = all.map { $0.union(item.reach) } ?? item.reach
        }
        return all
    }

    /// True when nothing is on the board.
    var isEmpty: Bool { items.isEmpty }

    /// Short words for the list: "12 ideas · 4 shapes · 2 notes".
    var countLine: String {
        if isTimeline { return timelineCountLine }
        if isSequence { return sequenceCountLine }
        let ideas = items.filter { $0.kind == .idea }.count
        let shapes = items.filter { $0.kind.isShape }.count
        let notes = items.filter { $0.kind == .note }.count
        let sketches = items.filter { $0.kind == .drawing }.count
        let pictures = pictureCount
        var parts: [String] = []
        if ideas > 0 { parts.append(ideas == 1 ? "1 idea" : "\(ideas) ideas") }
        if shapes > 0 { parts.append(shapes == 1 ? "1 shape" : "\(shapes) shapes") }
        if notes > 0 { parts.append(notes == 1 ? "1 note" : "\(notes) notes") }
        if sketches > 0 { parts.append(sketches == 1 ? "1 sketch" : "\(sketches) sketches") }
        if pictures > 0 { parts.append(pictures == 1 ? "1 picture" : "\(pictures) pictures") }
        return parts.isEmpty ? "Empty" : parts.joined(separator: " · ")
    }
}
