import Foundation
import CoreGraphics

// Copy, cut and paste (0.2, pick 17). A `Clip` is what goes onto the clipboard in Seedboard's own
// form: the chosen things with the arrows between them. Pasting gives every thing a new identity,
// so the same clip can be pasted again and again, in the same board or another one.

public struct Clip: Codable, Equatable, Sendable {
    /// The name of Seedboard's own form on the system clipboard.
    public static let type = "com.schabbauer.seedboard.clip"

    /// The board format of the app that copied (`Board.currentFormat`).
    public var format: Int
    public var items: [Item]
    public var links: [Link]

    public init(format: Int = Board.currentFormat, items: [Item] = [], links: [Link] = []) {
        self.format = format
        self.items = items
        self.links = links
    }

    public var isEmpty: Bool { items.isEmpty }

    /// False for a clip copied in a newer Seedboard: it may hold things this version would spoil.
    public var canBePasted: Bool {
        format <= Board.currentFormat && !items.isEmpty
            && !items.contains { $0.unknownKind != nil } && !links.contains { $0.unknownStyle != nil }
    }

    /// True when the clip holds nothing but ideas (it can hang under an idea).
    public var isOnlyIdeas: Bool { !items.isEmpty && items.allSatisfy { $0.kind == .idea } }

    /// The ideas of the clip that hang under nothing in it: each is the top of a branch.
    public var topIdeas: [Item] {
        let ids = Set(items.map(\.id))
        return items.filter { $0.kind == .idea && ($0.parent.map { !ids.contains($0) } ?? true) }
    }

    /// The smallest box round everything in the clip, where it lay when it was copied.
    public var bounds: CGRect? {
        var all: CGRect?
        for item in items { all = all.map { $0.union(item.frame) } ?? item.frame }
        return all
    }

    /// How far the n-th paste of the same clip at the same spot is set off from the first
    /// (n = 0 for the first): 28 right and down each time, so no paste hides the one before.
    public static func step(again n: Int) -> CGSize {
        CGSize(width: 28 * Double(max(n, 0)), height: 28 * Double(max(n, 0)))
    }

    /// The clip as a small board of its own: for its words and its picture.
    public func asBoard() -> Board {
        var board = Board(title: "")
        board.paste(self, at: bounds.map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero)
        return board
    }

    /// The words of the clip for other apps: one thing gives just its words, several give the
    /// outline that "Copy the board as text" makes, for these things only.
    public var text: String {
        if items.count == 1 { return items[0].text }
        return asBoard().outlineText
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decoded(_ data: Data) -> Clip? { try? JSONDecoder().decode(Clip.self, from: data) }
}

public extension Board {
    /// The things to copy: the chosen ones — an idea with everything under it, folded or not — and
    /// the arrows that run between two of them. A timeline's rows and things of a kind this
    /// version does not know are left out. A branch remembers its colour.
    func clip(of ids: Set<UUID>) -> Clip {
        var whole = ids
        for id in ids where item(id)?.kind == .idea { whole.formUnion(descendants(of: id)) }
        var copied: [Item] = []
        for item in items where whole.contains(item.id) && item.unknownKind == nil && !item.kind.isTimeline && !item.kind.isSequence {
            var copy = item
            // The top idea of a copied branch carries the colour its branch had.
            if item.kind == .idea, let parent = item.parent, !whole.contains(parent) { copy.colour = branchColour(of: item.id) }
            copied.append(copy)
        }
        let kept = Set(copied.map(\.id))
        let arrows = links.filter { kept.contains($0.from) && kept.contains($0.to) && $0.unknownStyle == nil }
        return Clip(items: copied, links: arrows)
    }

    /// Puts a clip onto the board with its middle at the point. Every thing and every arrow gets a
    /// new identity; the arrows between the pasted things are kept. A branch that was copied without
    /// the idea it hung under becomes the middle of a small map of its own. Frames go underneath.
    /// Returns the pasted things that can be chosen (not the ideas under a pasted idea).
    @discardableResult
    mutating func paste(_ clip: Clip, at point: CGPoint) -> Set<UUID> {
        guard clip.canBePasted, canBeChanged, !placesItself, let box = clip.bounds else { return [] }
        let dx = Double(point.x) - Double(box.midX), dy = Double(point.y) - Double(box.midY)
        var newID: [UUID: UUID] = [:]
        for item in clip.items where !item.kind.isTimeline && !item.kind.isSequence { newID[item.id] = UUID() }
        var tops: Set<UUID> = []
        var frames: [Item] = [], others: [Item] = []
        var orphans: [(id: UUID, colour: String)] = []
        for item in clip.items {
            guard let id = newID[item.id] else { continue }
            var copy = item
            copy.id = id
            copy.x += dx
            copy.y += dy
            if item.kind == .idea {
                if let parent = item.parent, let mapped = newID[parent] {
                    copy.parent = mapped
                } else {
                    // The top of a branch: the middle of its own map now.
                    if item.parent != nil {
                        orphans.append((id, item.colour))
                        copy.colour = ""
                        copy.side = nil
                        copy.bothSides = false
                    }
                    copy.parent = nil
                    tops.insert(id)
                }
            } else {
                copy.parent = nil
                tops.insert(id)
            }
            if copy.kind == .frame { frames.append(copy) } else { others.append(copy) }
        }
        items.insert(contentsOf: frames, at: 0)
        items.append(contentsOf: others)
        // The ideas right under a branch that became a map keep the colour the branch had.
        for orphan in orphans {
            for child in children(of: orphan.id) {
                guard let c = index(of: child.id) else { continue }
                items[c].side = nil
                if items[c].colour.isEmpty { items[c].colour = orphan.colour }
            }
        }
        for link in clip.links {
            guard let from = newID[link.from], let to = newID[link.to] else { continue }
            var copy = link
            copy.id = UUID()
            copy.from = from
            copy.to = to
            links.append(copy)
        }
        layoutMaps()
        return tops
    }

    /// Pastes a clip of ideas under an idea of this board: each copied branch hangs there, after
    /// the ideas already under it. Returns the tops of the pasted branches; nothing when the clip
    /// holds other things too or `id` is no idea.
    @discardableResult
    mutating func paste(_ clip: Clip, under id: UUID) -> Set<UUID> {
        guard clip.isOnlyIdeas, let target = item(id), target.kind == .idea else { return [] }
        let before = Set(items.map(\.id))
        let tops = paste(clip, at: target.centre)
        guard !tops.isEmpty else { return [] }
        // In the order they had: the new things were appended in the clip's order.
        let made = items.filter { !before.contains($0.id) && tops.contains($0.id) }.map(\.id)
        var hung: Set<UUID> = []
        for top in made where reparent(top, under: id) { hung.insert(top) }
        layoutMaps()
        return hung.isEmpty ? tops : hung
    }

    /// Words from elsewhere land on the board (pasted or dropped): two lines or more — a list —
    /// become a mind map, anything else one sticky note, with its middle at the point.
    /// Returns the new thing; nothing for empty words.
    @discardableResult
    mutating func addWords(_ text: String, at point: CGPoint) -> UUID? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, canBeChanged, !placesItself else { return nil }
        let nodes = Outline.parse(clean)
        if Outline.isList(clean), !nodes.isEmpty { return addMap(from: nodes, title: nil, at: point) }
        return add(.note, centre: point, text: clean)
    }
}
