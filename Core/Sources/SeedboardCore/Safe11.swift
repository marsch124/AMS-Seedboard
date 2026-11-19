import Foundation

// 0.11 safety: damaged files are read without a crash, nothing readable is lost, and a loss is said.

/// Numbers from a file that could crash a view are made safe here.
public enum SafeNumber {
    /// The biggest distance from the board's middle a thing may sit at (points).
    public static let farthest = 100_000.0
    /// The biggest width or height of a thing (points).
    public static let biggest = 20_000.0

    /// A whole number for any Double; never traps. Not a number = 0; too big = the nearest bound.
    public static func int(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let bound = 1_000_000_000.0
        return Int(min(max(value, -bound), bound).rounded(.down))
    }

    /// A position that can be drawn: finite and not absurdly far.
    public static func position(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -farthest), farthest)
    }

    /// A size that can be drawn: finite (else `fallback`), not negative, not absurdly big.
    public static func size(_ value: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, 0), biggest)
    }
}

extension Board {
    /// A reader can pass the file's own date here (`decoder.userInfo`), used when "created" cannot be read.
    public static let fileDateKey = CodingUserInfoKey(rawValue: "seedboard.fileDate")!

    /// How many things or arrows in this board file cannot be read (they are left out when the board is read).
    /// 0 for a file that is not a board at all: that is another matter.
    public static func unreadableCount(in data: Data) -> Int {
        struct Probe: Decodable {
            var lost = 0
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: Board.CodingKeys.self)
                for key in [Board.CodingKeys.items, .links] where c.contains(key) {
                    if (try? c.decodeNil(forKey: key)) == true { continue }
                    if key == .items {
                        if let list = try? c.decode([Lenient<Item>].self, forKey: key) { lost += list.filter { $0.value == nil }.count }
                        else { lost += 1 }
                    } else {
                        if let list = try? c.decode([Lenient<Link>].self, forKey: key) { lost += list.filter { $0.value == nil }.count }
                        else { lost += 1 }
                    }
                }
            }
        }
        return (try? JSONDecoder().decode(Probe.self, from: data))?.lost ?? 0
    }
}

/// Plain lines for the owner.
public enum SafetyWords {
    public static func damaged(count: Int, title: String) -> String {
        let what = count == 1 ? "1 thing" : "\(count) things"
        return "\(what) on “\(title)” could not be read. The whole board as it was is kept under Earlier versions."
    }

    /// The line after importing boards: files that are no board, and boards from a newer Seedboard, are told apart.
    public static func importSkipped(notBoards: Int, newer: Int) -> String? {
        var parts: [String] = []
        if notBoards > 0 {
            parts.append(notBoards == 1 ? "1 file was not a board this Seedboard can read." : "\(notBoards) files were not boards this Seedboard can read.")
        }
        if newer > 0 {
            parts.append(newer == 1 ? "1 board was made by a newer Seedboard — update Seedboard first." : "\(newer) boards were made by a newer Seedboard — update Seedboard first.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    public static let incompleteLink = "That board link is not complete."
}
