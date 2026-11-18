import XCTest
import CoreGraphics
@testable import SeedboardCore

final class HomeTests: XCTestCase {
    /// The search finds a board by its name and by the words on it; every word must be there.
    func testSearchFindsBoardsByNameAndByTheWordsOnThem() {
        var cabin = Board(title: "Summer cabin")
        let note = cabin.add(.note, centre: .zero, text: "Check timber\nprices in May")
        let box = cabin.add(.box, centre: CGPoint(x: 300, y: 0), text: "Malmö")
        cabin.link(from: note, to: box, text: "Then")
        var trip = Board(title: "Trip to Spain")
        trip.add(.text, centre: .zero, text: "What are we deciding?")
        let all = [cabin, trip]

        XCTAssertEqual(BoardSearch.find("", in: all).map(\.title), ["Summer cabin", "Trip to Spain"])
        XCTAssertEqual(BoardSearch.find("   ", in: all).count, 2)
        XCTAssertEqual(BoardSearch.find("spain", in: all).map(\.title), ["Trip to Spain"])          // by name
        XCTAssertEqual(BoardSearch.find("TIMBER", in: all).map(\.title), ["Summer cabin"])          // by a word on it
        XCTAssertEqual(BoardSearch.find("timb", in: all).map(\.title), ["Summer cabin"])            // by the start of a word
        XCTAssertEqual(BoardSearch.find("malmo", in: all).map(\.title), ["Summer cabin"])           // accents do not matter
        XCTAssertEqual(BoardSearch.find("then", in: all).map(\.title), ["Summer cabin"])            // the words on an arrow
        XCTAssertEqual(BoardSearch.find("cabin may", in: all).map(\.title), ["Summer cabin"])       // name and note together
        XCTAssertEqual(BoardSearch.find("cabin spain", in: all).map(\.title), [])                   // every word must be there
        XCTAssertEqual(BoardSearch.find("s", in: all).count, 2)
        XCTAssertTrue(cabin.holds("prices"))
        XCTAssertFalse(trip.holds("prices"))
    }

    /// "Changed 2 days ago" in plain words; days count by the calendar, a time ahead is "just now".
    func testChangedWordsArePlain() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 11, minute: 30))!
        func words(_ back: TimeInterval) -> String {
            Board(title: "B", created: now.addingTimeInterval(-back)).changedWords(now: now, calendar: calendar)
        }
        XCTAssertEqual(words(-500), "Changed just now")
        XCTAssertEqual(words(20), "Changed just now")
        XCTAssertEqual(words(60), "Changed 1 minute ago")
        XCTAssertEqual(words(45 * 60), "Changed 45 minutes ago")
        XCTAssertEqual(words(3600), "Changed 1 hour ago")
        XCTAssertEqual(words(5 * 3600), "Changed 5 hours ago")
        XCTAssertEqual(words(12 * 3600), "Changed yesterday")          // 23:30 the evening before
        XCTAssertEqual(words(86_400), "Changed yesterday")
        XCTAssertEqual(words(2 * 86_400), "Changed 2 days ago")
        XCTAssertEqual(words(6 * 86_400), "Changed 6 days ago")
        XCTAssertEqual(words(9 * 86_400), "Changed last week")
        XCTAssertEqual(words(20 * 86_400), "Changed 2 weeks ago")
        XCTAssertEqual(words(100 * 86_400), "Changed 3 months ago")
        XCTAssertEqual(words(400 * 86_400), "Changed a year ago")
        XCTAssertEqual(words(800 * 86_400), "Changed 2 years ago")
    }

    /// The starters come coloured: in Flow the Start is green, the decision purple, the steps blue.
    func testStartersComeColoured() {
        let flow = Starter.flow.board()
        XCTAssertEqual(flow.items.first { $0.text == "Start" }?.colour, "green")
        XCTAssertEqual(flow.items.first { $0.kind == .diamond }?.colour, "purple")
        XCTAssertEqual(Set(flow.items.filter { $0.kind == .box }.map(\.colour)), ["blue"])
        XCTAssertEqual(flow.links.first { $0.text == "Yes" }?.colour, "green")
        XCTAssertEqual(flow.links.first { $0.text == "No" }?.colour, "red")
        XCTAssertEqual(Set(flow.links.filter { $0.text.isEmpty }.map(\.colour)), [""])

        let steps = Starter.steps.board()
        XCTAssertEqual(Set(steps.items.filter { $0.kind == .box }.map(\.colour)), ["blue"])
        XCTAssertEqual(Set(steps.items.filter { $0.kind == .note }.map(\.colour)), ["yellow"])

        let pros = Starter.prosCons.board()
        XCTAssertEqual(pros.items.first { $0.kind == .text }?.colour, "")
        XCTAssertEqual(Set(pros.items.filter { $0.kind == .note }.map(\.colour)), ["green", "pink"])

        // Every colour a starter uses is one the app can paint.
        for starter in Starter.allCases {
            let board = starter.board()
            for name in board.items.map(\.colour) + board.links.map(\.colour) where !name.isEmpty {
                XCTAssertTrue(Palette.names.contains(name), "\(starter.name): \(name)")
            }
        }
    }

    /// The ring in the colour row sits on the colour a thing really shows.
    func testColourInUse() {
        var board = Board(title: "B")
        let box = board.add(.box, centre: .zero, text: "Box")
        let blue = board.add(.box, centre: CGPoint(x: 300, y: 0), text: "Blue", colour: "blue")
        let note = board.add(.note, centre: CGPoint(x: 0, y: 300))
        let frame = board.add(.frame, centre: CGPoint(x: 0, y: 900))
        let arrow = board.link(from: box, to: blue)!
        let centre = board.addCentre(at: CGPoint(x: 0, y: -600), text: "Centre")
        let branch = board.addChild(of: centre, text: "Branch")!
        let leaf = board.addChild(of: branch, text: "Leaf")!

        XCTAssertEqual(board.colourInUse(of: box), "")
        XCTAssertEqual(board.colourInUse(of: blue), "blue")
        XCTAssertEqual(board.colourInUse(of: note), "yellow")
        XCTAssertEqual(board.colourInUse(of: frame), "teal")
        XCTAssertEqual(board.colourInUse(of: arrow), "")
        XCTAssertEqual(board.colourInUse(of: leaf), board.branchColour(of: branch))
        XCTAssertFalse(board.colourInUse(of: leaf)!.isEmpty)
        XCTAssertNil(board.colourInUse(of: UUID()))
    }
}
