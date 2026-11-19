import Foundation

// 0.11, the memory lane (ideas 9 and 19). Plain rules; the stacks and the picture store are the app's.

/// Idea 9: the Undo list is limited by size as well as by count.
public enum UndoBudget {
    /// The most steps kept.
    public static let steps = 120
    /// The most room all steps may take together: about 40 MB.
    public static let bytes = 40 * 1024 * 1024
    /// The newest step is always kept, however big, so one Undo always works.
    public static let words = "Older steps were let go to save memory."

    /// A rough size of a board in memory, in bytes: what it holds, counted, not measured.
    public static func weight(of board: Board) -> Int {
        var total = 2_000 + board.links.count * 200
        for item in board.items {
            total += 700 + item.text.utf8.count
            for stroke in item.strokes ?? [] {
                total += 100 + stroke.points.count * 8 + (stroke.pressure?.count ?? 0) * 8
            }
        }
        return total
    }

    /// How many of the OLDEST steps go. `weights`: the size of each step, oldest first.
    public static func toLetGo(weights: [Int], maxSteps: Int = steps, maxBytes: Int = bytes) -> Int {
        var drop = max(0, weights.count - maxSteps)
        var total = weights.dropFirst(drop).reduce(0, +)
        while total > maxBytes, drop < weights.count - 1 {
            total -= weights[drop]
            drop += 1
        }
        return drop
    }
}

/// Idea 19: only this many full-size pictures are open at once on a board.
public extension PictureKeeping {
    static let sharpMost = 12

    /// Which full-size pictures stay open: the `most` asked for most lately (those nearest the view are asked
    /// for at every drawing). The rest fall back to their small copy.
    static func sharpToKeep(_ asked: [(name: String, wanted: Date)], most: Int = sharpMost) -> Set<String> {
        Set(asked.sorted { $0.wanted > $1.wanted }.prefix(most).map(\.name))
    }
}
