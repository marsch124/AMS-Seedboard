import Foundation

// 0.19 (pick 39): the last three pen colours used stand first in the Draw plate's colour row.
// Kept per device (never in a board). "" is plain ink.
public enum InkRecent {
    public static let count = 3

    /// `name` is now the newest; no doubles; at most three.
    public static func adding(_ name: String, to list: [String]) -> [String] {
        Array(([name] + list.filter { $0 != name }).prefix(count))
    }

    /// A stored list read back: no doubles, only colours the palette knows (or plain ink), at most three.
    public static func clean(_ list: [String]) -> [String] {
        var out: [String] = []
        for name in list where (name.isEmpty || Palette.names.contains(name)) && !out.contains(name) { out.append(name) }
        return Array(out.prefix(count))
    }

    /// The colour row: the recent ones first, then the rest in their usual order, nobody twice.
    public static func order(recent: [String], all: [String]) -> [String] {
        let first = clean(recent).filter { all.contains($0) }
        return first + all.filter { !first.contains($0) }
    }
}
