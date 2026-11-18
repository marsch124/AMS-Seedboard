import Foundation
import CoreGraphics
import SeedboardCore

/// Made-up boards for pictures and tests (`-sampleData`). Nothing is read or written.
enum Sample {
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
            ideas,
            made(.steps, "Garage shelves", "orange", daysAgo: 2),
            made(.prosCons, "Trip to Spain", "blue", daysAgo: 4),
            made(.flow, "Packing flow", "teal", daysAgo: 6),
            made(.mindMap, "Training year", "purple", daysAgo: 9),
            made(.steps, "Workshop bench", "green", daysAgo: 20, sent: true),
            lanes(now: now),
        ]
    }

    /// "Lanes and shapes" (`-board Lanes`): a frame with three named rows that holds a short flow
    /// made of the four shapes that are new in 0.2 — a Person, a Document, a Slanted box and a Store.
    static func lanes(now: Date = Date()) -> Board {
        var board = Board(title: "Lanes and shapes", created: now.addingTimeInterval(-86_400 * 5),
                          changed: now.addingTimeInterval(-86_400 * 3), colour: "teal")
        let frame = board.add(.frame, centre: CGPoint(x: 320, y: 210), text: "Web shop order")
        board.resize(frame, to: CGRect(x: 0, y: 0, width: 640, height: 420))   // rows 30…160…290…420
        board.setLanes(frame, way: .rows, count: 3)
        for (n, name) in ["Customer", "Shop", "Warehouse"].enumerated() { board.setLaneName(frame, lane: n, to: name) }

        let customer = board.add(.person, centre: CGPoint(x: 120, y: 95), text: "Customer", colour: "pink")
        let form = board.add(.document, centre: CGPoint(x: 330, y: 95), text: "Order form")
        let arrives = board.add(.slanted, centre: CGPoint(x: 330, y: 225), text: "Order comes in", colour: "orange")
        let pack = board.add(.box, centre: CGPoint(x: 530, y: 225), text: "Check and pack")
        let stock = board.add(.store, centre: CGPoint(x: 530, y: 355), text: "Stock", colour: "blue")
        if let i = board.index(of: pack) { board.items[i].todo = true }
        board.link(from: customer, to: form)
        board.link(from: form, to: arrives)
        board.link(from: arrives, to: pack)
        board.link(from: pack, to: stock, text: "takes from")
        return board
    }
}
