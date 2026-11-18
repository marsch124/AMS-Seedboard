import Foundation
import CoreGraphics
import SeedboardCore

/// Made-up boards for pictures and tests (`-sampleData`). Nothing is read or written.
enum Sample {
    /// A made-up timeline round today: two phases, seven bars, a milestone, five "comes after" arrows.
    /// `-board timeline` opens it (no other sample board has that word in its name).
    static func timeline(now: Date = Date()) -> Board {
        var board = Board.timeline(title: "Build timeline", created: now.addingTimeInterval(-86_400 * 5))
        board.colour = "orange"
        // Counted from the Monday of this week, so the picture looks the same on every day of a week.
        let monday = Day(now).weekStart
        board.addPhase("Groundwork", colour: "teal")
        let permit = board.addBar("Permit", start: monday - 21, days: 14, colour: "blue")
        let builder = board.addBar("Find builder", start: monday - 14, days: 12, colour: "pink")
        let foundation = board.addBar("Foundation", start: monday - 2, days: 12, colour: "teal")
        board.addPhase("Shell", colour: "orange")
        let walls = board.addBar("Walls", start: monday + 10, days: 14, colour: "orange")
        let roof = board.addBar("Roof", start: monday + 24, days: 9, colour: "green")
        board.addBar("Windows", start: monday + 28, days: 7, colour: "yellow")
        let moveIn = board.addMilestone("Move in", on: monday + 40)
        board.comesAfter(foundation, after: permit)
        board.comesAfter(foundation, after: builder)
        board.comesAfter(walls, after: foundation)
        board.comesAfter(roof, after: walls)
        board.comesAfter(moveIn, after: roof)
        if let i = board.index(of: builder) { board.items[i].todo = true }
        board.changed = now.addingTimeInterval(-3_600)
        return board
    }

    static func boards(now: Date = Date()) -> [Board] {
        var cabin = Board(title: "Summer cabin", created: now.addingTimeInterval(-86_400 * 3), changed: now, pinned: true, colour: "green")
        // Both sides is switched on after the branches are there: the first two go right, the last two left.
        let centre = cabin.addCentre(at: CGPoint(x: 0, y: 0), text: "Summer cabin", bothSides: false)
        let branches: [(String, [String])] = [
            ("Budget", ["Loan", "Savings"]),
            ("Build", ["Permit", "Builder"]),
            ("Place", ["Lake", "Forest"]),
            ("Who", ["Anna"]),
        ]
        for (name, ideas) in branches {
            guard let branch = cabin.addChild(of: centre, text: name) else { continue }
            for idea in ideas { cabin.addChild(of: branch, text: idea) }
        }
        if let i = cabin.index(of: centre) { cabin.items[i].bothSides = true }
        if let permit = cabin.items.first(where: { $0.text == "Permit" }), let i = cabin.index(of: permit.id) {
            cabin.items[i].todo = true
        }
        cabin.add(.note, centre: CGPoint(x: 470, y: -90), text: "Ask Anna about\nthe lake plot", colour: "yellow")
        let timber = cabin.add(.note, centre: CGPoint(x: 510, y: 40), text: "Check timber\nprices in May", colour: "pink")
        if let i = cabin.index(of: timber) { cabin.items[i].todo = true }
        let idea = cabin.add(.box, centre: CGPoint(x: -260, y: 250), text: "New idea")
        let worth = cabin.add(.diamond, centre: CGPoint(x: -40, y: 250), text: "Worth it?", colour: "purple")
        let plan = cabin.add(.box, centre: CGPoint(x: 200, y: 250), text: "Make a plan")
        let project = cabin.add(.round, centre: CGPoint(x: 440, y: 250), text: "PARAGON project", colour: "blue")
        let park = cabin.add(.box, centre: CGPoint(x: -40, y: 390), text: "Park it")
        cabin.link(from: idea, to: worth)
        cabin.link(from: worth, to: plan, text: "Yes")
        cabin.link(from: plan, to: project)
        cabin.link(from: worth, to: park, text: "No")
        if let l = cabin.links.firstIndex(where: { $0.text == "Yes" }) { cabin.links[l].colour = "teal" }
        if let l = cabin.links.firstIndex(where: { $0.text == "No" }) { cabin.links[l].colour = "red" }
        cabin.layoutMaps()

        func made(_ starter: Starter, _ title: String, _ colour: String, daysAgo: Double, sent: Bool = false) -> Board {
            var board = starter.board(title: title, now: now.addingTimeInterval(-86_400 * daysAgo))
            board.colour = colour
            board.changed = now.addingTimeInterval(-86_400 * daysAgo)
            if sent {
                board.sent = SentInfo(when: board.changed, kind: "project", title: title, path: "Projects/\(title).md")
            }
            return board
        }

        var ideas = made(.mindMap, "App ideas", "pink", daysAgo: 1)
        ideas.pinned = true
        return [
            cabin,
            timeline(now: now),
            ideas,
            made(.steps, "Garage shelves", "orange", daysAgo: 2),
            made(.prosCons, "Trip to Spain", "blue", daysAgo: 4),
            made(.flow, "Packing flow", "teal", daysAgo: 6),
            made(.mindMap, "Training year", "purple", daysAgo: 9),
            made(.steps, "Workshop bench", "green", daysAgo: 20, sent: true),
        ]
    }
}
