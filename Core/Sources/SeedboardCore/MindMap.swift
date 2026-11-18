import Foundation
import CoreGraphics

// Mind maps. An idea with no parent is the centre of a map; every other idea hangs under one.
// The centre stays where the owner put it; all other ideas are placed by `layoutMaps()`.

public enum Side: String, Codable, Sendable { case right, left }

public enum MindMap {
    /// Space between an idea and its children, sideways.
    public static let gapAcross: Double = 46
    /// Space between sister ideas, up and down.
    public static let gapDown: Double = 10

    /// The side of each main branch of one map, in the branches' order.
    /// A branch stays on the side it remembers. A branch that remembers none goes to the emptier
    /// side (right when both are even), so adding one never makes another jump across the middle.
    /// A map in which no branch remembers a side (made before sides were kept) is split as it
    /// always was: the first half right, the rest left.
    public static func sides(of branches: [Item], bothSides: Bool) -> [Side] {
        guard bothSides else { return branches.map { _ in .right } }
        if branches.allSatisfy({ $0.side == nil }) {
            let half = (branches.count + 1) / 2
            return branches.indices.map { $0 < half ? .right : .left }
        }
        var right = branches.filter { $0.side == .right }.count
        var left = branches.filter { $0.side == .left }.count
        return branches.map { branch in
            if let side = branch.side { return side }
            if left < right {
                left += 1
                return .left
            }
            right += 1
            return .right
        }
    }
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
        return MindMap.sides(of: all, bothSides: true)[place]
    }

    /// Writes down the side of every main branch of a both-sides map, so each one stays there.
    mutating func settleSides(of centreID: UUID) {
        guard let centre = item(centreID), centre.kind == .idea, centre.parent == nil, centre.bothSides else { return }
        let all = children(of: centreID)
        let sides = MindMap.sides(of: all, bothSides: true)
        for (n, branch) in all.enumerated() where branch.side != sides[n] {
            if let i = index(of: branch.id) { items[i].side = sides[n] }
        }
    }

    /// The topmost idea under the point that can be seen, leaving some ideas out
    /// (the ones being dragged).
    func idea(at point: CGPoint, notIn left: Set<UUID>) -> UUID? {
        for item in items.reversed() where item.kind == .idea && !left.contains(item.id) && !isHidden(item.id) {
            if item.frame.insetBy(dx: -5, dy: -4).contains(point) { return item.id }
        }
        return nil
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

    /// A new idea under this one, after its sisters. A main branch takes the next branch colour
    /// and, in a both-sides map, the emptier side; the branches already there stay where they are.
    @discardableResult
    mutating func addChild(of id: UUID, text: String = "") -> UUID? {
        guard let parent = item(id), parent.kind == .idea else { return nil }
        if parent.parent == nil { settleSides(of: id) }
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
        if parent.parent == nil { settleSides(of: id) }
        return idea.id
    }

    /// A new idea beside this one (under the same parent), right after it or right before it.
    /// For a centre this makes a first branch instead.
    @discardableResult
    mutating func addSister(of id: UUID, above: Bool = false) -> UUID? {
        guard let me = item(id), me.kind == .idea else { return nil }
        guard let parentID = me.parent else { return addChild(of: id) }
        // A new main branch goes to the emptier side; when both sides are even it stays beside this one.
        settleSides(of: parentID)
        let branches = children(of: parentID)
        let even = branches.filter { $0.side == .left }.count * 2 == branches.count
        guard let newID = addChild(of: parentID) else { return nil }
        if even, let mine = item(id)?.side, let n = index(of: newID), items[n].side != nil { items[n].side = mine }
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
    /// parent is the idea itself or sits below it. The middle of a map can be hung too: its
    /// whole map then becomes a branch, and its ideas follow the colour of the branch they are in.
    @discardableResult
    mutating func reparent(_ id: UUID, under newParent: UUID) -> Bool {
        guard id != newParent, let me = item(id), me.kind == .idea,
              let target = item(newParent), target.kind == .idea,
              !descendants(of: id).contains(newParent), let i = index(of: id) else { return false }
        if target.parent == nil { settleSides(of: newParent) }
        let sisters = children(of: newParent).filter { $0.id != id }
        let stays = me.parent == newParent
        if me.parent == nil {
            // What was a map of its own: its main branches are ordinary ideas now.
            items[i].bothSides = false
            for below in descendants(of: id) {
                if let b = index(of: below) {
                    items[b].colour = ""
                    items[b].side = nil
                }
            }
        }
        items[i].parent = newParent
        items[i].order = (sisters.last?.order ?? 0) + 1
        if target.parent == nil {
            if !stays { items[i].side = nil }
            if items[i].colour.isEmpty {
                let used = Set(sisters.map(\.colour))
                items[i].colour = Palette.branches.first { !used.contains($0) } ?? Palette.branch(sisters.count)
            }
        } else {
            items[i].colour = ""
            items[i].side = nil
        }
        if let t = index(of: newParent) { items[t].folded = false }
        if target.parent == nil { settleSides(of: newParent) }
        return true
    }

    /// Takes an idea out of its map: it becomes the centre of its own map at the point.
    /// The ideas right under it become main branches and take branch colours.
    mutating func detach(_ id: UUID, at point: CGPoint) {
        guard let i = index(of: id), items[i].kind == .idea, items[i].parent != nil else { return }
        items[i].parent = nil
        items[i].colour = ""
        items[i].side = nil
        items[i].bothSides = false
        items[i].x = Double(point.x) - items[i].w / 2
        items[i].y = Double(point.y) - items[i].h / 2
        let branches = children(of: id)
        var used = Set(branches.map(\.colour).filter { !$0.isEmpty })
        for (n, branch) in branches.enumerated() where branch.colour.isEmpty {
            guard let b = index(of: branch.id) else { continue }
            items[b].colour = Palette.branches.first { !used.contains($0) } ?? Palette.branch(n)
            used.insert(items[b].colour)
        }
    }

    /// Moves an idea out one level: it becomes the next sister of the idea it hung under.
    /// Refused for a centre and for a main branch (there is no level further out).
    @discardableResult
    mutating func moveOut(_ id: UUID) -> Bool {
        guard let me = item(id), me.kind == .idea, let parentID = me.parent,
              let grand = item(parentID)?.parent else { return false }
        guard reparent(id, under: grand) else { return false }
        var order = children(of: grand).map(\.id).filter { $0 != id }
        let at = (order.firstIndex(of: parentID) ?? order.count - 1) + 1
        order.insert(id, at: min(max(at, 0), order.count))
        for (n, each) in order.enumerated() {
            if let i = index(of: each) { items[i].order = Double(n + 1) }
        }
        // A new main branch stays on the side it was on.
        if let side = item(parentID)?.side, let i = index(of: id), items[i].side != nil { items[i].side = side }
        return true
    }

    /// Moves an idea one place up or down among its sisters. A main branch of a both-sides map
    /// moves among the branches of its own side; at the end of a side it crosses to the other
    /// side (down: to the bottom there, up: to the top). False when there is nowhere to go.
    @discardableResult
    mutating func shiftIdea(_ id: UUID, down: Bool) -> Bool {
        guard let me = item(id), me.kind == .idea, let parentID = me.parent, let parent = item(parentID) else { return false }
        let twoSided = parent.parent == nil && parent.bothSides
        if twoSided { settleSides(of: parentID) }
        var order = children(of: parentID).map(\.id)
        let mySide = side(of: id)
        let column = order.filter { side(of: $0) == mySide }
        guard let at = order.firstIndex(of: id), let place = column.firstIndex(of: id) else { return false }
        let to = place + (down ? 1 : -1)
        if column.indices.contains(to), let other = order.firstIndex(of: column[to]) {
            order.swapAt(at, other)
        } else if twoSided {
            order.remove(at: at)
            order.insert(id, at: down ? order.count : 0)
            if let i = index(of: id) { items[i].side = mySide == .right ? .left : .right }
        } else {
            return false
        }
        for (n, each) in order.enumerated() {
            if let i = index(of: each) { items[i].order = Double(n + 1) }
        }
        return true
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
                // Every main branch keeps its side from now on.
                let sides = MindMap.sides(of: list.map { items[$0] }, bothSides: true)
                for (n, i) in list.enumerated() { items[i].side = sides[n] }
                place(list.filter { items[$0].side != .left }, beside: c, side: .right)
                place(list.filter { items[$0].side == .left }, beside: c, side: .left)
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
