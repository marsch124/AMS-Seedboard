import Foundation

// 0.11 (pick 12): what VoiceOver reads on an ordinary board. Every thing and every arrow is one entry, in
// outline order: the mind maps first (each map from its centre, branch by branch, a folded branch left out),
// then everything else row by row from the top left. Each entry has one spoken sentence.

public struct SpokenThing: Equatable, Sendable {
    public var id: UUID
    public var isArrow: Bool
    public var sentence: String
    /// Whether the thing can be moved by hand (a mind map's ideas place themselves; a pinned thing stays).
    public var canMove: Bool
    /// Whether its words can be changed (a sketch and a door have none).
    public var canEdit: Bool
}

public extension Board {
    /// "Idea: Roof, done, 2 votes" · "Sticky note: Call Alex, to do" · "Sketch" · "Arrow from Roof to Walls: after".
    func spoken(_ item: Item) -> String {
        let words = item.text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        var line = item.kind.word
        if !words.isEmpty { line += ": " + words }
        if !(item.doneDay ?? "").isEmpty { line += ", done" }
        if item.todo { line += ", to do" }
        if let votes = item.votes, votes > 0 { line += votes == 1 ? ", 1 vote" : ", \(votes) votes" }
        if item.locked == true { line += ", pinned" }
        if item.folded { line += ", folded" }
        return line
    }

    /// Everything on an ordinary board in the order it is read: things, then arrows.
    var spokenThings: [SpokenThing] {
        if isTimeline || isSequence { return [] }
        var seen = Set<UUID>()
        var order: [Item] = []
        func walk(_ idea: Item, depth: Int) {
            guard seen.insert(idea.id).inserted, depth < 200 else { return }
            order.append(idea)
            if idea.folded { return }
            for child in children(of: idea.id) { walk(child, depth: depth + 1) }
        }
        for centre in Thinking.readingOrder(mapCentres) { walk(centre, depth: 0) }
        // Ideas whose parent is gone are not lost; ideas under a folded branch are left out on purpose.
        for idea in Thinking.readingOrder(items.filter { $0.kind == .idea && !seen.contains($0.id) && $0.parent.map { item($0) == nil } == true }) {
            walk(idea, depth: 0)
        }
        for thing in Thinking.readingOrder(items.filter { $0.kind != .idea }) { order.append(thing) }
        var out = order.map { item in
            SpokenThing(id: item.id, isArrow: false, sentence: spoken(item),
                        canMove: item.kind != .idea && item.locked != true,
                        canEdit: item.kind != .drawing && item.kind != .door && item.kind != .picture)
        }
        for link in links {
            func name(_ id: UUID) -> String {
                let words = (self.item(id)?.text ?? "").components(separatedBy: .newlines).joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                return words.isEmpty ? (self.item(id)?.kind.word.lowercased() ?? "nothing") : words
            }
            var line = "Arrow from \(name(link.from)) to \(name(link.to))"
            let words = link.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !words.isEmpty { line += ": " + words }
            out.append(SpokenThing(id: link.id, isArrow: true, sentence: line, canMove: false, canEdit: true))
        }
        return out
    }
}
