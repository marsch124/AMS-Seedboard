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

    /// 0.9, for pictures (`-board "Timing sample"`): a late, an early and an on-time done bar round today, so the
    /// done day's plate sits over the red Today line; plus one bar not done and one late.
    static func timing(now: Date = Date()) -> Board {
        var board = Board.timeline(title: "Timing sample", created: now.addingTimeInterval(-86_400 * 5))
        let today = Day(now)
        let tiles = board.addBar("Order tiles", start: today - 8, days: 5, colour: "blue")
        let floor = board.addBar("Lay floor", start: today - 5, days: 6, colour: "teal")
        let paint = board.addBar("Paint hall", start: today - 6, days: 8, colour: "green")
        board.addBar("Hang doors", start: today + 3, days: 5, colour: "orange")
        board.addBar("Order lamps", start: today - 9, days: 4, colour: "pink")
        let gate = board.addMilestone("Alex signs off", on: today + 4)
        board.setDone([tiles, floor, paint, gate], true, on: today)
        board.changed = now.addingTimeInterval(-3_600)
        return board
    }

    /// 0.9, for pictures (`-board Midsummer -scale days -goDay 2027-06-21`): a week with Midsummer Eve, Midsummer
    /// Day and a weekend; with a done-late, a done-early and an on-time bar, far from today (the Today button).
    static func midsummer(now: Date = Date()) -> Board {
        var board = Board.timeline(title: "Midsummer sample", created: now.addingTimeInterval(-86_400 * 6))
        let first = Day(year: 2027, month: 6, day: 14)
        let order = board.addBar("Order boards", start: first, days: 5, colour: "blue")
        let paint = board.addBar("Paint fence", start: first + 3, days: 6, colour: "green")
        board.addBar("Alex builds the table", start: first + 5, days: 4, colour: "orange")
        let lamps = board.addBar("Hang lamps", start: first + 6, days: 2, colour: "yellow")
        board.addMilestone("Guests arrive", on: first + 11)
        board.setDone([order], true, on: first + 12)   // planned to end 18 Jun: 4 days late
        board.setDone([paint], true, on: first + 6)    // planned to end 22 Jun: 2 days early
        board.setDone([lamps], true, on: first + 7)    // planned to end 21 Jun: 1 day early
        board.changed = now.addingTimeInterval(-3_700)
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
            ("Who", ["Alex"]),
        ]
        for (name, ideas) in branches {
            guard let branch = cabin.addChild(of: centre, text: name) else { continue }
            for idea in ideas { cabin.addChild(of: branch, text: idea) }
        }
        if let i = cabin.index(of: centre) { cabin.items[i].bothSides = true }
        if let permit = cabin.items.first(where: { $0.text == "Permit" }), let i = cabin.index(of: permit.id) {
            cabin.items[i].todo = true
        }
        cabin.add(.note, centre: CGPoint(x: 470, y: -90), text: "Ask Alex about\nthe lake plot", colour: "yellow")
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

        // Every look an arrow can have (0.2), for pictures: `-board Arrow`.
        var looks = Board(title: "Arrow looks", created: now.addingTimeInterval(-86_400 * 30), colour: "blue")
        let order = looks.add(.box, centre: CGPoint(x: 0, y: 0), text: "Order")
        let stock = looks.add(.box, centre: CGPoint(x: 300, y: 0), text: "Stock")
        let supplier = looks.add(.box, centre: CGPoint(x: 620, y: 0), text: "Supplier", colour: "orange")
        let closed = looks.add(.note, centre: CGPoint(x: 620, y: -180), text: "Closed on\nSundays", colour: "yellow")
        let pack = looks.add(.box, centre: CGPoint(x: 0, y: 230), text: "Pack")
        let send = looks.add(.box, centre: CGPoint(x: 300, y: 230), text: "Send")
        let begin = looks.add(.round, centre: CGPoint(x: 0, y: 440), text: "Start", colour: "green")
        let wait = looks.add(.box, centre: CGPoint(x: 300, y: 440), text: "Wait a day")
        let done = looks.add(.box, centre: CGPoint(x: 620, y: 440), text: "Done")
        // Both ways, with a word beside the line.
        if let l = looks.link(from: order, to: stock, text: "checks"), let i = looks.links.firstIndex(where: { $0.id == l }) {
            looks.links[i].ends = .bothWays
            looks.links[i].colour = "blue"
        }
        // Dashed.
        if let l = looks.link(from: stock, to: supplier, text: "if low"), let i = looks.links.firstIndex(where: { $0.id == l }) {
            looks.links[i].isDashed = true
            looks.links[i].colour = "orange"
        }
        // A plain line, no ends.
        if let l = looks.link(from: closed, to: supplier), let i = looks.links.firstIndex(where: { $0.id == l }) {
            looks.links[i].ends = .none
        }
        looks.link(from: order, to: pack)
        // There and back: two lines side by side on the same sides, each with its own word.
        looks.link(from: pack, to: send, text: "ready")
        looks.link(from: send, to: pack, text: "missing")
        // Two arrows out of one side, and one of them goes round the shape in its way.
        looks.link(from: begin, to: wait)
        looks.link(from: wait, to: done)
        looks.link(from: begin, to: done, text: "skip")
        looks.changed = looks.created

        var ideas = made(.mindMap, "App ideas", "pink", daysAgo: 1)
        ideas.pinned = true
        // 0.9: two boards that were put away (the "Put away (2)" row, the Put away page).
        var oldYear = made(.mindMap, "Last year's trip", "blue", daysAgo: 200)
        oldYear.putAway = now.addingTimeInterval(-86_400 * 12)
        var oldBench = made(.steps, "Old bench plan", "orange", daysAgo: 150)
        oldBench.putAway = now.addingTimeInterval(-86_400 * 3)
        return [
            cabin,
            oldYear,
            oldBench,
            timeline(now: now),
            timing(now: now),
            midsummer(now: now),
            loanSteps(now: now),
            ideas,
            made(.steps, "Garage shelves", "orange", daysAgo: 2),
            made(.prosCons, "Trip to Spain", "blue", daysAgo: 4),
            made(.flow, "Packing flow", "teal", daysAgo: 6),
            made(.mindMap, "Training year", "purple", daysAgo: 9),
            made(.steps, "Workshop bench", "green", daysAgo: 20, sent: true),
            looks,
            lanes(now: now),
            // Drawing by hand (0.2), for pictures: `-board Sketch` (SampleSketch.swift).
            sketch(now: now),
            // Pictures on a board (0.3), for pictures: `-board balcony` (SamplePictures.swift).
            balcony(now: now),
            // 0.9: vote dots, legend, tick list, link title, pinned note — for pictures: `-board Marks` (SampleMarks.swift).
            marks(now: now),
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
