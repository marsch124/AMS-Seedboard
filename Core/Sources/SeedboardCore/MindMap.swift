import Foundation
import CoreGraphics

// Mind maps. An idea with no parent is the centre of a map; every other idea hangs under one.
// The centre stays where the owner put it; all other ideas are placed by `layoutMaps()`.

public enum Side: String, Sendable { case right, left }

public enum MindMap {
    /// Space between an idea and its children, sideways.
    public static let gapAcross: Double = 46
    /// Space between sister ideas, up and down.
    public static let gapDown: Double = 10
}

public extension Board {
    func item(_ id: UUID) -> Item? { items.first { $0.id == id } }

    func index(of id: UUID) -> Int? { items.firstIndex { $0.id == id } }

    /// The ideas hanging directly under this one, in their order.
    func children(of id: UUID) -> [Item] {
        items.filter { $0.kind == .idea && $0.parent == id }.sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
    }

    /// The centres of all mind maps on the board.
    var mapCentres: [Item] { items.filter { $0.kind == .idea && $0.parent == nil } }

    func isCentre(_ id: UUID) -> Bool { item(id).map { $0.kind == .idea && $0.parent == nil } ?? false }

    /// The centre of the map this idea belongs to (itself, for a centre).
    func centre(of id: UUID) -> UUID {
        var here = id
        var steps = 0
        while let up = item(here)?.parent, item(up) != nil, steps < 10_000 {
            here = up
            steps += 1
        }
        return here
    }

    /// How deep the idea sits: 0 for a centre, 1 for a main branch.
    func depth(of id: UUID) -> Int {
        var here = id
        var n = 0
        while let up = item(here)?.parent, item(up) != nil, n < 10_000 {
            here = up
            n += 1
        }
        return n
    }

    /// Every idea below this one, at any depth.
    func descendants(of id: UUID) -> [UUID] {
        var found: [UUID] = []
        // `seen` stops a damaged file (an idea hanging under itself) from going round for ever.
        var seen: Set<UUID> = [id]
        var queue = [id]
        while let next = queue.popLast() {
            for child in children(of: next) where !seen.contains(child.id) {
                seen.insert(child.id)
                found.append(child.id)
                queue.append(child.id)
            }
        }
        return found
    }

    /// The main branch (depth 1) this idea belongs to; nil for a centre.
    func mainBranch(of id: UUID) -> UUID? {
        var here = id
        var steps = 0
        while let up = item(here)?.parent, steps < 10_000 {
            if item(up)?.parent == nil { return here }
            here = up
            steps += 1
        }
        return nil
    }

    /// The colour of the idea's branch: a main branch has its own, everything under it follows.
    func branchColour(of id: UUID) -> String {
        guard let branch = mainBranch(of: id), let item = item(branch) else { return "" }
        return item.colour.isEmpty ? "pink" : item.colour
    }

    /// Which side of its centre the idea is on.
    func side(of id: UUID) -> Side {
        guard let branch = mainBranch(of: id), let centreID = item(branch)?.parent, let centre = item(centreID) else { return .right }
        guard centre.bothSides else { return .right }
        let all = children(of: centreID)
        guard let place = all.firstIndex(where: { $0.id == branch }) else { return .right }
        return place < (all.count + 1) / 2 ? .right : .left
    }

    /// True when the idea is out of sight because something above it is folded.
    func isHidden(_ id: UUID) -> Bool {
        var here = id
        var steps = 0
        while let up = item(here)?.parent, let upItem = item(up), steps < 10_000 {
            if upItem.folded { return true }
            here = up
            steps += 1
        }
        return false
    }

    // MARK: Adding

    /// A new centre of a new mind map, with its middle at the point.
    @discardableResult
    mutating func addCentre(at point: CGPoint, text: String = "", bothSides: Bool = true) -> UUID {
        var idea = Item(kind: .idea, text: text, bothSides: bothSides)
        idea.w = 150
        idea.h = 46
        idea.x = Double(point.x) - idea.w / 2
        idea.y = Double(point.y) - idea.h / 2
        items.append(idea)
        return idea.id
    }

    /// A new idea under this one, after its sisters. A main branch takes the next branch colour.
    @discardableResult
    mutating func addChild(of id: UUID, text: String = "") -> UUID? {
        guard let parent = item(id), parent.kind == .idea else { return nil }
        let sisters = children(of: id)
        var idea = Item(kind: .idea, text: text, parent: id, order: (sisters.last?.order ?? 0) + 1)
        if parent.parent == nil {
            let used = Set(sisters.map(\.colour))
            idea.colour = Palette.branches.first { !used.contains($0) } ?? Palette.branch(sisters.count)
        }
        idea.x = parent.x
        idea.y = parent.y
        items.append(idea)
        if let i = index(of: id) { items[i].folded = false }
        return idea.id
    }

    /// A new idea beside this one (under the same parent), right after it or right before it.
    /// For a centre this makes a first branch instead.
    @discardableResult
    mutating func addSister(of id: UUID, above: Bool = false) -> UUID? {
        guard let me = item(id), me.kind == .idea else { return nil }
        guard let parentID = me.parent else { return addChild(of: id) }
        guard let newID = addChild(of: parentID) else { return nil }
        // Put it straight after (or before) this idea, then give everyone whole numbers again.
        var order = children(of: parentID).map(\.id).filter { $0 != newID }
        let at = (order.firstIndex(of: id) ?? order.count - 1) + (above ? 0 : 1)
        order.insert(newID, at: min(max(at, 0), order.count))
        for (n, each) in order.enumerated() {
            if let i = index(of: each) { items[i].order = Double(n + 1) }
        }
        return newID
    }

    /// Hangs an idea (with everything under it) under another idea. Refused when the new
    /// parent is the idea itself or sits below it.
    @discardableResult
    mutating func reparent(_ id: UUID, under newParent: UUID) -> Bool {
        guard id != newParent, let me = item(id), me.kind == .idea,
              let target = item(newParent), target.kind == .idea,
              !descendants(of: id).contains(newParent), let i = index(of: id) else { return false }
        let sisters = children(of: newParent).filter { $0.id != id }
        items[i].parent = newParent
        items[i].order = (sisters.last?.order ?? 0) + 1
        if target.parent == nil {
            if items[i].colour.isEmpty {
                let used = Set(sisters.map(\.colour))
                items[i].colour = Palette.branches.first { !used.contains($0) } ?? Palette.branch(sisters.count)
            }
        } else {
            items[i].colour = ""
        }
        if let t = index(of: newParent) { items[t].folded = false }
        return true
    }

    /// Takes an idea out of its map: it becomes the centre of its own map at the point.
    mutating func detach(_ id: UUID, at point: CGPoint) {
        guard let i = index(of: id), items[i].kind == .idea, items[i].parent != nil else { return }
        items[i].parent = nil
        items[i].colour = ""
        items[i].bothSides = false
        items[i].x = Double(point.x) - items[i].w / 2
        items[i].y = Double(point.y) - items[i].h / 2
    }

    /// Moves an idea one place up or down among its sisters.
    mutating func shiftIdea(_ id: UUID, down: Bool) {
        guard let me = item(id), let parentID = me.parent else { return }
        var order = children(of: parentID).map(\.id)
        guard let at = order.firstIndex(of: id) else { return }
        let to = at + (down ? 1 : -1)
        guard order.indices.contains(to) else { return }
        order.swapAt(at, to)
        for (n, each) in order.enumerated() {
            if let i = index(of: each) { items[i].order = Double(n + 1) }
        }
    }

    // MARK: Layout

    /// Places every idea of every map around its centre. Sizes are taken as they are
    /// (the app measures the words first); only x and y of the non-centre ideas change.
    mutating func layoutMaps() {
        var kids: [UUID: [Int]] = [:]
        func gatherKids() {
            kids = [:]
            for (i, item) in items.enumerated() where item.kind == .idea {
                if let parent = item.parent { kids[parent, default: []].append(i) }
            }
            for key in kids.keys {
                kids[key]?.sort { (items[$0].order, items[$0].id.uuidString) < (items[$1].order, items[$1].id.uuidString) }
            }
        }
        // An idea whose parent is gone (or that hangs under itself) becomes a centre rather than vanishing.
        let ids = Set(items.map(\.id))
        for i in items.indices where items[i].kind == .idea {
            if let parent = items[i].parent, !ids.contains(parent) || parent == items[i].id { items[i].parent = nil }
        }
        gatherKids()
        // Ideas that hang in a ring (a damaged file) can be reached from no centre: each becomes a centre.
        var reached: Set<UUID> = []
        var open = items.filter { $0.kind == .idea && $0.parent == nil }.map(\.id)
        while let next = open.popLast() {
            guard reached.insert(next).inserted else { continue }
            for i in kids[next] ?? [] { open.append(items[i].id) }
        }
        var healed = false
        for i in items.indices where items[i].kind == .idea && !reached.contains(items[i].id) {
            items[i].parent = nil
            healed = true
        }
        if healed { gatherKids() }

        func height(_ i: Int) -> Double {
            let own = items[i].h
            guard !items[i].folded, let list = kids[items[i].id], !list.isEmpty else { return own }
            let below = list.map(height).reduce(0, +) + MindMap.gapDown * Double(list.count - 1)
            return max(own, below)
        }

        func place(_ list: [Int], beside parent: Int, side: Side) {
            guard !list.isEmpty else { return }
            let heights = list.map(height)
            let total = heights.reduce(0, +) + MindMap.gapDown * Double(list.count - 1)
            var top = items[parent].y + items[parent].h / 2 - total / 2
            for (n, i) in list.enumerated() {
                items[i].y = top + (heights[n] - items[i].h) / 2
                items[i].x = side == .right
                    ? items[parent].x + items[parent].w + MindMap.gapAcross
                    : items[parent].x - MindMap.gapAcross - items[i].w
                if !items[i].folded { place(kids[items[i].id] ?? [], beside: i, side: side) }
                top += heights[n] + MindMap.gapDown
            }
        }

        for c in items.indices where items[c].kind == .idea && items[c].parent == nil {
            let list = kids[items[c].id] ?? []
            guard !items[c].folded else { continue }
            if items[c].bothSides {
                let half = (list.count + 1) / 2
                place(Array(list.prefix(half)), beside: c, side: .right)
                place(Array(list.dropFirst(half)), beside: c, side: .left)
            } else {
                place(list, beside: c, side: .right)
            }
        }
    }

    // MARK: Walking with the arrow keys

    enum Step { case up, down, left, right }

    /// The idea the arrow key leads to from this one, if any.
    func idea(from id: UUID, step: Step) -> UUID? {
        guard let me = item(id), me.kind == .idea else { return nil }
        let mySide = side(of: id)
        let towardsChildren: Step = mySide == .right ? .right : .left
        switch step {
        case .up, .down:
            guard let parentID = me.parent else { return nil }
            let sisters = children(of: parentID).filter { side(of: $0.id) == mySide }.map(\.id)
            guard let at = sisters.firstIndex(of: id) else { return nil }
            let to = at + (step == .down ? 1 : -1)
            return sisters.indices.contains(to) ? sisters[to] : nil
        case .left, .right:
            if me.parent == nil {
                let wanted: Side = step == .right ? .right : .left
                return children(of: id).first { side(of: $0.id) == wanted }?.id
            }
            if step == towardsChildren {
                return me.folded ? nil : children(of: id).first?.id
            }
            return me.parent
        }
    }
}
