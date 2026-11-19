import Foundation

// 0.11: "Pictures nobody uses" in Settings › Your boards. Plain rules; the files are `PictureStore`'s.

public extension PictureKeeping {
    /// A picture written less than this many hours ago is never counted: its board's save may still be on its way.
    static let freshHours: Double = 1

    /// The pictures nobody uses right now: not named by any board, removed board, safety copy, earlier version
    /// or starter (`named` holds every such name), a plain `.jpg` or `.png` name, with a known date that is not brand new.
    /// `complete`: false when anything could not be read or still lies only in iCloud — then nothing is counted.
    /// Unlike the weekly tidy this does not wait 30 days: the owner asks for it.
    static func unusedNow(files: [(name: String, date: Date?, bytes: Int)], named: Set<String>,
                          now: Date = Date(), complete: Bool = true) -> (names: [String], bytes: Int) {
        guard complete else { return ([], 0) }
        let limit = now.addingTimeInterval(-freshHours * 3600)
        var names: [String] = []
        var bytes = 0
        for file in files {
            guard isPictureFileName(file.name),
                  !named.contains(file.name), let date = file.date, date < limit else { continue }
            if !names.contains(file.name) { names.append(file.name) }
            bytes += max(file.bytes, 0)
        }
        return (names.sorted(), bytes)
    }

    /// "Pictures nobody uses: 3 (12 MB)"; "Pictures nobody uses: none" for none.
    static func unusedLine(count: Int, bytes: Int) -> String {
        guard count > 0 else { return "Pictures nobody uses: none" }
        return "Pictures nobody uses: \(count) (\(sizeWords(bytes)))"
    }

    /// "under 1 MB", "4.2 MB", "12 MB".
    static func sizeWords(_ bytes: Int) -> String {
        let mb = Double(max(bytes, 0)) / 1_048_576
        if mb < 1 { return "under 1 MB" }
        if mb < 10 { return String(format: "%.1f MB", mb) }
        return "\(Int(mb.rounded())) MB"
    }

    /// The question before they go.
    static func removeQuestion(count: Int) -> String {
        "Remove \(count) \(count == 1 ? "picture" : "pictures") nobody uses? This cannot be undone."
    }
}
