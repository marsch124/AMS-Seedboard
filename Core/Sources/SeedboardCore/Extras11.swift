import Foundation

// 0.11, lane "extras": names of colours in the bar and in PARAGON's note (30), a map folded to its main
// branches (33), the Mac's list of recently opened boards (43). Plain rules, no screen.

// MARK: 30 — names for colours

public extension Board {
    /// What the legend says this colour means ("Question"), or nil when it has no words. Colour names as in the palette;
    /// a note with no colour is yellow.
    func legendWord(forColour colour: String) -> String? {
        guard let legend else { return nil }
        let words = (legend[colour.isEmpty ? "yellow" : colour] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? nil : words
    }

    /// The legend's words for a sticky note's colour; nil for anything else or when the colour has no words.
    func legendWord(ofNote id: UUID) -> String? {
        guard let item = item(id), item.kind == .note else { return nil }
        return legendWord(forColour: item.colour)
    }
}

// MARK: 33 — a map folded to its main branches

public extension Board {
    /// The main branches of this map that have ideas under them (the only ones a fold changes).
    private func foldableMainBranches(_ centre: UUID) -> [Item] {
        children(of: centre).filter { !children(of: $0.id).isEmpty }
    }

    /// True when "Main branches only" is how this map stands: it has main branches with ideas under them, and all of
    /// those are folded. The button then says "Open all".
    func showsMainBranchesOnly(_ centre: UUID) -> Bool {
        guard isCentre(centre) else { return false }
        let folding = foldableMainBranches(centre)
        return !folding.isEmpty && folding.allSatisfy(\.folded)
    }

    /// True when the map of this centre has anything to fold (or to open).
    func canFoldToMainBranches(_ centre: UUID) -> Bool {
        isCentre(centre) && (!foldableMainBranches(centre).isEmpty || descendants(of: centre).contains { item($0)?.folded == true })
    }

    /// One press: when the map is not at its main branches, every main branch with ideas under it folds (the centre
    /// opens); when it is, every folded idea of the map opens. Uses the fold of 0.9 (`folded`). True when something changed.
    @discardableResult
    mutating func toggleMainBranchesOnly(_ centre: UUID) -> Bool {
        guard isCentre(centre), let c = index(of: centre) else { return false }
        var changed = false
        if showsMainBranchesOnly(centre) {
            for d in descendants(of: centre) {
                if let i = index(of: d), items[i].folded { items[i].folded = false; changed = true }
            }
        } else {
            if items[c].folded { items[c].folded = false; changed = true }
            for b in foldableMainBranches(centre) {
                if let i = index(of: b.id), !items[i].folded { items[i].folded = true; changed = true }
            }
        }
        return changed
    }
}

// MARK: 43 — recently opened boards

public enum RecentBoards {
    /// How many boards "Open Recent" lists.
    public static let limit = 5

    /// The list after this board was opened: it goes first, an older mention of it goes, at most five stay.
    public static func opened(_ id: UUID, in list: [UUID]) -> [UUID] {
        Array(([id] + list.filter { $0 != id }).prefix(limit))
    }

    /// What the menus show: the remembered ids that are still boards that can be opened (not removed, not put away).
    public static func shown(_ list: [UUID], among boards: [Board]) -> [Board] {
        let byID = Dictionary(boards.filter { !$0.isPutAway }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return list.compactMap { byID[$0] }.prefix(limit).map { $0 }
    }
}

public extension ParagonExport {
    /// A note's line in PARAGON's note, with the legend's word for its colour after it: "- Call Alex (Question)".
    /// A tick list goes line by line as before; a thing with no legend word is today's line.
    static func namedBullet(_ item: Item, in board: Board, picture: Bool) -> String {
        let line = noteBullet(item, picture: picture)
        guard item.kind == .note, !TickList.hasTicks(item.text), let word = board.legendWord(ofNote: item.id) else { return line }
        return line + " (\(oneLine(word)))"
    }
}
