import Foundation
import CoreGraphics
import SeedboardCore

extension Sample {
    /// Made-up removed boards for pictures and tests: two, with different days left (18 and 3).
    static func removed(now: Date = Date()) -> [RemovedCopy] {
        var garden = Board(title: "Old garden plan", created: now.addingTimeInterval(-86_400 * 40),
                           changed: now.addingTimeInterval(-86_400 * 14), colour: "teal")
        let centre = garden.addCentre(at: .zero, text: "Garden")
        for (name, ideas) in [("Beds", ["Herbs", "Tomatoes", "Berries"]), ("Paths", ["Gravel"]), ("Shed", ["Tools", "Paint"])] {
            guard let branch = garden.addChild(of: centre, text: name) else { continue }
            for idea in ideas { garden.addChild(of: branch, text: idea) }
        }
        garden.add(.note, centre: CGPoint(x: 380, y: -70), text: "Ask the neighbour\nabout the hedge", colour: "green")
        garden.layoutMaps()

        var party = Starter.steps.board(title: "Birthday party", now: now.addingTimeInterval(-86_400 * 35))
        party.colour = "pink"
        party.changed = now.addingTimeInterval(-86_400 * 28)
        return [
            RemovedCopy(board: garden, removed: now.addingTimeInterval(-86_400 * 12)),
            RemovedCopy(board: party, removed: now.addingTimeInterval(-86_400 * 27)),
        ]
    }

    /// Made-up earlier versions of one board (three): one that another device set aside two hours ago,
    /// and two daily copies. Each is the board with a little less on it.
    static func earlier(of board: Board, now: Date = Date()) -> [(version: EarlierVersion, board: Board)] {
        func version(_ hoursAgo: Double, without words: [String], path: String, kept: Date, _ source: EarlierVersion.Source)
            -> (version: EarlierVersion, board: Board) {
            var old = board
            let gone = Set(old.items.filter { item in words.contains { item.text.localizedCaseInsensitiveContains($0) } }.map(\.id))
            old.items.removeAll { gone.contains($0.id) }
            old.links.removeAll { gone.contains($0.from) || gone.contains($0.to) }
            old.changed = now.addingTimeInterval(-3_600 * hoursAgo)
            return (EarlierVersion(path: path, board: old, kept: kept, source: source), old)
        }
        return [
            version(2, without: ["timber"], path: "sample-away", kept: now.addingTimeInterval(-3_600), .setAside(.away)),
            version(27, without: ["timber", "Park it", "PARAGON project"], path: "sample-daily-1",
                    kept: now.addingTimeInterval(-86_400), .daily),
            version(75, without: ["timber", "Park it", "PARAGON project", "Make a plan", "Worth it", "New idea", "lake plot"],
                    path: "sample-daily-2", kept: now.addingTimeInterval(-86_400 * 3), .daily),
        ]
    }
}

/// The kept copies of the example boards (`-sampleData`): in memory only, nothing is read or written.
@MainActor
final class SampleKept {
    static let shared = SampleKept()

    private var removed: [RemovedCopy]?
    private var versions: [(version: EarlierVersion, board: Board)]?

    /// Made at the first look, so the earlier versions belong to the "Summer cabin" that is in the list.
    func listing(boards: [Board]) -> KeptListing {
        if removed == nil { removed = Sample.removed() }
        if versions == nil {
            versions = (boards.first { $0.title == "Summer cabin" } ?? boards.first).map { Sample.earlier(of: $0) } ?? []
        }
        var listing = KeptListing()
        listing.removed = removed ?? []
        listing.versions = (versions ?? []).map(\.version)
        return listing
    }

    func bringBack(_ id: UUID) -> Board? {
        guard var board = removed?.first(where: { $0.id == id })?.board else { return nil }
        removed?.removeAll { $0.id == id }
        board.touch()
        return board
    }

    func removeForGood(_ id: UUID) {
        removed?.removeAll { $0.id == id }
    }

    func board(of version: EarlierVersion) -> Board? {
        versions?.first { $0.version.path == version.path }?.board
    }
}
