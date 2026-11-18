import Foundation
import CoreGraphics
import SeedboardCore

extension Sample {
    /// 0.9 "marks" (`-board Marks`): vote dots, a colour legend, a sticky note with a tick list, a web address with its
    /// title, a pinned note, and the squares background. Made-up words only.
    static func marks(now: Date = Date()) -> Board {
        var board = Board(title: "Marks for the garden", created: now.addingTimeInterval(-86_400), changed: now, colour: "orange")
        board.backdropKind = .squares
        func note(_ words: String, _ x: Double, _ y: Double, _ colour: String, dots: Int = 0) -> UUID {
            let id = board.add(.note, centre: CGPoint(x: x, y: y), text: words, colour: colour)
            if let i = board.index(of: id), dots > 0 { board.items[i].votes = dots }
            return id
        }
        _ = note("Raised beds", -260, -120, "yellow", dots: 4)
        _ = note("Water butt", -80, -120, "yellow", dots: 2)
        _ = note("Greenhouse", 100, -120, "yellow", dots: 7)
        _ = note("Ask Alex about\nthe soil", 280, -120, "blue")
        let list = note("Saturday\n[x] Buy seeds\n[ ] Fix the fence\n[ ] Order compost", -260, 70, "green")
        if let i = board.index(of: list) { board.items[i].w = 190 }
        let link = note("Plans: https://example.com/garden", 0, 90, "pink")
        if let i = board.index(of: link) { board.items[i].linkTitle = "A small garden, month by month"; board.items[i].w = 200 }
        let pinned = note("Do not move: the path", 240, 90, "purple")
        if let i = board.index(of: pinned) { board.items[i].locked = true }
        board.setLegend(["yellow": "Ideas", "blue": "Questions", "green": "Jobs", "pink": "Links", "purple": "Fixed"])
        return board
    }
}
