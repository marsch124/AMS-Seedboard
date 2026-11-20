import Foundation

// Seedboard 0.18: red means "late" on timelines, so a mind map's branches no longer take red by themselves
// (like purple in 0.17, which means PARAGON). One question covers both colours: purple and red main branches
// can be recoloured. A device that already answered the 0.17 purple question is asked about red only. Rules only.

public enum OddBranches {
    /// Asked once per device (0.18). The 0.17 key `PurpleBranches.askedKey` is read too.
    public static let askedKey = "ask.oddBranches.v1"
    /// The colours a branch never takes by itself.
    public static let all: Set<String> = ["purple", "red"]

    /// Which colours to ask about: red only when this device already answered about purple.
    public static func colours(purpleAsked: Bool) -> Set<String> { purpleAsked ? ["red"] : all }

    /// How many such main branches there are, and on how many boards (only boards that can be changed).
    public static func count(_ boards: [Board], colours: Set<String> = all) -> (branches: Int, maps: Int) {
        var branches = 0, maps = 0
        for board in boards where board.canBeChanged {
            let n = board.oddBranches(colours)
            if n > 0 { branches += n; maps += 1 }
        }
        return (branches, maps)
    }

    /// The question's title.
    public static func title(_ colours: Set<String>) -> String {
        colours == ["red"] ? "Recolour red branches?" : "Recolour purple and red branches?"
    }

    /// The words of the question, for example "3 branches on 2 mind maps are purple or red. …"
    public static func line(_ found: (branches: Int, maps: Int), colours: Set<String>) -> String {
        let b = found.branches == 1 ? "1 branch" : "\(found.branches) branches"
        let m = found.maps == 1 ? "1 mind map" : "\(found.maps) mind maps"
        let verb = found.branches == 1 ? "is" : "are"
        if colours == ["red"] {
            return "\(b) on \(m) \(verb) red. Red means late in Seedboard, and new branches skip it."
        }
        return "\(b) on \(m) \(verb) purple or red. Purple means PARAGON and red means late in Seedboard, and new branches skip both."
    }
}

public extension Board {
    /// Main branches (the ideas right next to a centre) in one of these colours. Ideas further out follow their branch.
    func oddBranches(_ colours: Set<String> = OddBranches.all) -> Int { oddBranchIDs(colours).count }

    private func oddBranchIDs(_ colours: Set<String>) -> [UUID] {
        guard !isTimeline, !isSequence else { return [] }
        return items.filter { item in
            guard item.kind == .idea, colours.contains(item.colour), let up = item.parent else { return false }
            return isCentre(up)
        }.map(\.id)
    }

    /// Every such main branch gets a branch colour its sisters do not use yet (else yellow). Other colours stay.
    mutating func recolourBranches(_ colours: Set<String> = OddBranches.all) {
        for id in oddBranchIDs(colours) {
            guard let i = items.firstIndex(where: { $0.id == id }), let up = items[i].parent else { continue }
            let used = Set(children(of: up).map(\.colour))
            items[i].colour = Palette.branches.first { !used.contains($0) } ?? "yellow"
        }
    }
}
