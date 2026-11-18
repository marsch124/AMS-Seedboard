import Foundation
import CoreGraphics

// 0.9, lane "maps": balance a mind map, the "+5" badge of a folded idea, numbered steps of a flowchart,
// the colour and the count of a name on a "Who does what" board, the middle of an arrow's words.
// Plain rules, no screen.

public extension MindMap {
    /// The small round-edged badge of a folded idea ("+5"): outside its outer edge, level with its middle.
    /// `right`: the idea's outer edge is its right one (a centre always counts as right).
    static func badge(for frame: CGRect, right: Bool, count: Int) -> CGRect {
        let width = CGFloat(count >= 100 ? 36 : (count >= 10 ? 30 : 26))
        let height: CGFloat = 18
        let x = right ? frame.maxX + 6 : frame.minX - 6 - width
        return CGRect(x: x, y: frame.midY - height / 2, width: width, height: height)
    }
}

public extension Board {
    /// How many ideas hang below this one, at any depth (what a fold hides).
    func hiddenCount(of id: UUID) -> Int { descendants(of: id).count }

    /// The weight of a main branch: itself and everything under it.
    private func branchWeight(_ id: UUID) -> Int { 1 + descendants(of: id).count }

    /// True when this idea is the centre of a map that has at least two main branches to spread.
    func canBalance(_ id: UUID) -> Bool {
        isCentre(id) && children(of: id).count >= 2
    }

    /// Turns on both sides for the map and spreads the main branches so both sides weigh about the same
    /// (the number of ideas under each, greedy: the heaviest branch first, always onto the lighter side;
    /// the right side wins a tie). Branches keep their order on their side. True when something changed.
    @discardableResult
    mutating func balanceMap(_ centreID: UUID) -> Bool {
        guard isCentre(centreID), let c = index(of: centreID) else { return false }
        var changed = false
        if !items[c].bothSides {
            items[c].bothSides = true
            changed = true
        }
        let branches = children(of: centreID)
        let weights = Dictionary(uniqueKeysWithValues: branches.map { ($0.id, branchWeight($0.id)) })
        let heavyFirst = branches.enumerated().sorted {
            (weights[$0.element.id]!, -$0.offset) > (weights[$1.element.id]!, -$1.offset)
        }
        var right = 0, left = 0
        var chosen: [UUID: Side] = [:]
        for entry in heavyFirst {
            let weight = weights[entry.element.id]!
            if right <= left {
                chosen[entry.element.id] = .right
                right += weight
            } else {
                chosen[entry.element.id] = .left
                left += weight
            }
        }
        for branch in branches {
            guard let i = index(of: branch.id), items[i].side != chosen[branch.id] else { continue }
            items[i].side = chosen[branch.id]
            changed = true
        }
        return changed
    }

    /// True when some idea on the board is folded.
    var hasFolded: Bool { items.contains { $0.kind == .idea && $0.folded } }

    /// Opens every folded idea. True when something changed.
    @discardableResult
    mutating func unfoldAll() -> Bool {
        var changed = false
        for i in items.indices where items[i].kind == .idea && items[i].folded {
            items[i].folded = false
            changed = true
        }
        return changed
    }

    // MARK: Numbered steps

    /// The number of each flowchart shape, 1, 2, 3 …: it starts at the shapes that have an arrow leaving
    /// but none arriving (top first, then left), and follows the arrows breadth-first. A shape reached
    /// gets the next number; something no arrow reaches gets none. A ring of shapes with no start begins
    /// at its top-left shape.
    func stepNumbers() -> [UUID: Int] {
        let live = items.filter { !($0.kind == .idea && $0.parent != nil && isHidden($0.id)) }
        let byID = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let wires = links.filter { $0.from != $0.to && byID[$0.from] != nil && byID[$0.to] != nil }
        var out: [UUID: [UUID]] = [:]
        var arrives: Set<UUID> = []
        for link in wires {
            out[link.from, default: []].append(link.to)
            arrives.insert(link.to)
        }
        func firstThen(_ a: Item, _ b: Item) -> Bool { (a.y, a.x) < (b.y, b.x) }
        let shapes = live.filter { $0.kind.isShape }.sorted(by: firstThen)
        var numbers: [UUID: Int] = [:]
        var seen: Set<UUID> = []
        func walk(from start: UUID) {
            guard !seen.contains(start) else { return }
            var queue = [start]
            seen.insert(start)
            var at = 0
            while at < queue.count {
                let id = queue[at]
                at += 1
                if byID[id]?.kind.isShape == true { numbers[id] = numbers.count + 1 }
                for next in out[id] ?? [] where !seen.contains(next) {
                    seen.insert(next)
                    queue.append(next)
                }
            }
        }
        for shape in shapes where out[shape.id] != nil && !arrives.contains(shape.id) { walk(from: shape.id) }
        for shape in shapes where out[shape.id] != nil && !seen.contains(shape.id) { walk(from: shape.id) }
        return numbers
    }

    // MARK: Who does what

    /// The colour name of a name on a "Who does what" board: the colour it was given, else one by its
    /// place in the row, in the order of `Palette.branches`.
    func whoColour(_ id: UUID) -> String {
        guard let who = item(id) else { return "blue" }
        if !who.colour.isEmpty { return who.colour }
        let place = whoIndex(of: id) ?? 0
        return Palette.branch(place)
    }

    /// How many messages this name sends (answers count too; a message to itself counts once).
    func sendCount(of who: UUID) -> Int {
        items.filter { $0.kind == .message && $0.from == who && isDrawnMessage($0) }.count
    }
}

public extension Route.Arrow {
    /// The middle of the line itself (also of a curve): where the arrow's words are drawn.
    var middle: CGPoint { Route.middle(of: outline.isEmpty ? points : outline) }
}
