import XCTest
@testable import SeedboardCore

final class BoardTests: XCTestCase {
    private let boardID = "11111111-1111-1111-1111-111111111111"

    private func decode(_ json: String) throws -> Board {
        try JSONDecoder().decode(Board.self, from: Data(json.utf8))
    }

    func testUnknownKindBecomesABox() throws {
        let board = try decode(#"{"id":"\#(boardID)","items":[{"kind":"hexagon","text":"x"}]}"#)
        XCTAssertEqual(board.items.count, 1)
        XCTAssertEqual(board.items[0].kind, .box)
        XCTAssertEqual(board.items[0].w, 150)
    }

    func testMissingFieldsTakeTheirDefaults() throws {
        let board = try decode(#"{"id":"\#(boardID)","items":[{"kind":"note"}]}"#)
        let note = board.items[0]
        XCTAssertEqual(note.text, "")
        XCTAssertEqual(note.w, 150)
        XCTAssertEqual(note.h, 110)
        XCTAssertFalse(note.todo)
        XCTAssertNil(note.parent)
        XCTAssertEqual(board.title, "Board")
        XCTAssertEqual(board.colour, "green")
        XCTAssertEqual(board.format, 1)
        XCTAssertTrue(board.links.isEmpty)
        XCTAssertTrue(board.sentTodos.isEmpty)
    }

    func testOneBrokenItemDoesNotLoseTheOthers() throws {
        let a = "22222222-2222-2222-2222-222222222222"
        let b = "33333333-3333-3333-3333-333333333333"
        let json = #"{"id":"\#(boardID)","items":[{"kind":"note","text":"keep 1"},5,"junk",{"kind":"box","text":"keep 2"}],"links":[{"from":"\#(a)","to":"\#(b)"},{"to":"\#(b)"},7]}"#
        let board = try decode(json)
        XCTAssertEqual(board.items.map(\.text), ["keep 1", "keep 2"])
        XCTAssertEqual(board.links.count, 1)
        XCTAssertEqual(board.links[0].style, .elbow)
        XCTAssertTrue(board.links[0].head)
    }

    func testFormatIsKeptAndNewerCannotBeChanged() throws {
        let newer = try decode(#"{"id":"\#(boardID)","format":\#(Board.currentFormat + 1),"futureThing":{"a":1}}"#)
        XCTAssertEqual(newer.format, Board.currentFormat + 1)
        XCTAssertFalse(newer.canBeChanged)
        let same = try decode(#"{"id":"\#(boardID)","format":\#(Board.currentFormat)}"#)
        XCTAssertTrue(same.canBeChanged)
        XCTAssertTrue(Board().canBeChanged)
        let data = try JSONEncoder().encode(newer)
        XCTAssertEqual(try JSONDecoder().decode(Board.self, from: data).format, Board.currentFormat + 1)
    }

    func testJSONRoundTripKeepsEverything() throws {
        var board = Board(title: "Trip", created: Date(timeIntervalSince1970: 1_700_000_000), pinned: true, colour: "blue")
        let centre = board.addMap(from: [OutlineNode("Root", [OutlineNode("A", [OutlineNode("A1")]), OutlineNode("B")])], title: nil, at: CGPoint(x: 5, y: 6))
        let a = board.add(.box, centre: .zero, text: "Start")
        let b = board.add(.diamond, centre: CGPoint(x: 300, y: 0), text: "Ok?")
        board.link(from: a, to: b, text: "go")
        board.add(.frame, centre: .zero, text: "Frame", colour: "red")
        board.items[board.index(of: a)!].todo = true
        board.sentTodos = [a]
        board.sent = SentInfo(when: Date(timeIntervalSince1970: 1_700_000_500), kind: "note", title: "Trip", path: "Projects/Trip.md")
        board.items[board.index(of: board.children(of: centre)[0].id)!].folded = true
        let data = try JSONEncoder().encode(board)
        XCTAssertEqual(try JSONDecoder().decode(Board.self, from: data), board)
    }

    func testBranchColoursWrapAround() {
        XCTAssertEqual(Palette.branch(0), Palette.branches[0])
        XCTAssertEqual(Palette.branch(Palette.branches.count), Palette.branches[0])
        XCTAssertEqual(Palette.branch(-1), Palette.branches.last)
    }
}
