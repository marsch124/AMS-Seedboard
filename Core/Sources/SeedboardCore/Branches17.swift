import Foundation

// Seedboard 0.17: a mind map's 5th main branch used to be purple by itself, and purple means PARAGON.
// New branches take yellow there. One question (and a More menu line) recolours the purple ones. Rules only.

public enum PurpleBranches {
    /// Asked once per device.
    public static let askedKey = "ask.purpleBranches.v1"

    /// How many purple main branches there are, and on how many boards (only boards that can be changed).
    public static func count(_ boards: [Board]) -> (branches: Int, maps: Int) {
        var branches = 0, maps = 0
        for board in boards where board.canBeChanged {
            let n = board.purpleBranches
            if n > 0 { branches += n; maps += 1 }
        }
        return (branches, maps)
    }

    /// The words of the question, for example "3 branches on 2 mind maps are purple."
    public static func line(_ found: (branches: Int, maps: Int)) -> String {
        let b = found.branches == 1 ? "1 branch" : "\(found.branches) branches"
        let m = found.maps == 1 ? "1 mind map" : "\(found.maps) mind maps"
        return "\(b) on \(m) \(found.branches == 1 ? "is" : "are") purple. Purple means PARAGON in Seedboard, and new branches skip it."
    }
}

public extension Board {
    /// Main branches (the ideas right next to a centre) drawn purple. Ideas further out follow their branch.
    var purpleBranches: Int { purpleBranchIDs.count }

    private var purpleBranchIDs: [UUID] {
        guard !isTimeline, !isSequence else { return [] }
        return items.filter { item in
            guard item.kind == .idea, item.colour == "purple", let up = item.parent else { return false }
            return isCentre(up)
        }.map(\.id)
    }

    /// Every purple main branch gets a colour its sisters do not use yet (else yellow). Other colours stay.
    mutating func recolourPurpleBranches() {
        for id in purpleBranchIDs {
            guard let i = items.firstIndex(where: { $0.id == id }), let up = items[i].parent else { continue }
            let used = Set(children(of: up).map(\.colour))
            items[i].colour = Palette.branches.first { !used.contains($0) } ?? "yellow"
        }
    }
}
