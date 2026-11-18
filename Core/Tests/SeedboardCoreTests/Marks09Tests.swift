import XCTest
@testable import SeedboardCore

final class Marks09Tests: XCTestCase {
    private func board(_ items: [Item]) -> Board {
        var b = Board(title: "T")
        b.items = items
        return b
    }

    func testVoteDots() {
        var a = Item(kind: .note, text: "A", x: 0, y: 0), b = Item(kind: .note, text: "B", x: 300, y: 0)
        a.votes = 2
        var board = board([a, b])
        board.addDot([a.id, b.id])
        XCTAssertEqual(board.dots(of: a.id), 3)
        XCTAssertEqual(board.dots(of: b.id), 1)
        board.removeDot([b.id])
        XCTAssertNil(board.item(b.id)?.votes)
        board.clearDots([a.id])
        XCTAssertFalse(board.hasDots)
    }

    func testSortByDotsOrdersAndStartsWhereFirstStood() {
        var a = Item(kind: .note, text: "A", x: 500, y: 40, w: 100, h: 50), b = Item(kind: .note, text: "B", x: 100, y: 300, w: 100, h: 50)
        var c = Item(kind: .note, text: "C", x: 900, y: 900, w: 100, h: 50)
        a.votes = 1; b.votes = 4
        let plain = Item(kind: .note, text: "none", x: 0, y: 0)
        var board = board([a, b, c, plain])
        XCTAssertEqual(board.sortByDots(), 2)
        // B (4 dots) first at A's old corner, A (1 dot) after it, 16 points to the right.
        XCTAssertEqual(board.item(b.id)?.x, 500); XCTAssertEqual(board.item(b.id)?.y, 40)
        XCTAssertEqual(board.item(a.id)?.x, 616); XCTAssertEqual(board.item(a.id)?.y, 40)
        XCTAssertEqual(board.item(c.id)?.x, 900)
        XCTAssertEqual(board.item(plain.id)?.x, 0)
    }

    func testPinnedThingsDoNotMove() {
        var a = Item(kind: .box, text: "A", x: 0, y: 0, w: 100, h: 50), b = Item(kind: .box, text: "B", x: 200, y: 0, w: 100, h: 50)
        a.locked = true
        var board = board([a, b])
        XCTAssertFalse(board.mayMove(a.id)); XCTAssertTrue(board.mayMove(b.id))
        board.move([a.id, b.id], by: CGSize(width: 10, height: 10))
        XCTAssertEqual(board.item(a.id)?.x, 0); XCTAssertEqual(board.item(b.id)?.x, 210)
        board.resize(a.id, to: CGRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertEqual(board.item(a.id)?.w, 100)
        XCTAssertFalse(board.tidyable([a.id, b.id]).contains { $0.id == a.id })
        board.setPinned([a.id], false)
        XCTAssertNil(board.item(a.id)?.locked)
        XCTAssertTrue(board.mayMove(a.id))
    }

    func testLegendRowsOnlyUsedColoursWithWords() {
        var blue = Item(kind: .note, text: "x"); blue.colour = "blue"
        let yellow = Item(kind: .note, text: "y")
        var board = board([blue, yellow])
        board.setLegend(["yellow": " Ideas ", "blue": "", "green": "Not used"])
        XCTAssertEqual(board.legendColours, ["yellow", "blue"])
        XCTAssertEqual(board.legendRows.map(\.colour), ["yellow"])
        XCTAssertEqual(board.legendRows.first?.words, "Ideas")
        board.setLegend([:])
        XCTAssertNil(board.legend)
        XCTAssertFalse(board.hasLegend)
    }

    func testTickLines() {
        XCTAssertEqual(TickList.parse("[ ] milk"), TickList.Line(words: "milk", ticked: false))
        XCTAssertEqual(TickList.parse("[x] eggs"), TickList.Line(words: "eggs", ticked: true))
        XCTAssertNil(TickList.parse("[x]eggs"))
        XCTAssertNil(TickList.parse("plain"))
        let text = "Shopping\n[ ] milk\n[x] eggs"
        XCTAssertEqual(TickList.toggled(text, line: 1), "Shopping\n[x] milk\n[x] eggs")
        XCTAssertEqual(TickList.toggled(text, line: 2), "Shopping\n[ ] milk\n[ ] eggs")
        XCTAssertEqual(TickList.toggled(text, line: 0), text)
        let all = TickList.turned("a\n\nb")
        XCTAssertEqual(all, "[ ] a\n\n[ ] b")
        XCTAssertEqual(TickList.turned(all), "a\n\nb")
        XCTAssertEqual(TickList.turned(""), "[ ] ")
        XCTAssertEqual(TickList.bullets("Shopping\n[ ] milk\n[x] eggs"), ["- Shopping", "- [ ] milk", "- [x] eggs"])
    }

    func testTickNoteGoesToParagonLineByLine() {
        var note = Item(kind: .note, text: "[ ] milk\n[x] eggs")
        note.colour = "blue"
        let line = ParagonExport.noteBullet(note, picture: false)
        XCTAssertEqual(line, "- [ ] milk\n- [x] eggs")
    }

    func testWebAddress() {
        XCTAssertEqual(WebAddress.first(in: "See https://www.example.com/a/b. Thanks"), "https://www.example.com/a/b")
        XCTAssertEqual(WebAddress.first(in: "(http://example.org)"), "http://example.org")
        XCTAssertNil(WebAddress.first(in: "no address, example.com"))
        XCTAssertEqual(WebAddress.tidy("https://www.example.com/a/"), "example.com/a")
        XCTAssertEqual(WebAddress.caption(title: nil, address: "https://example.com"), "example.com")
        XCTAssertEqual(WebAddress.caption(title: "A page", address: "https://example.com"), "A page")
        var note = Item(kind: .note, text: "https://example.com/x")
        let other = Item(kind: .note, text: "none")
        let board = board([note, other])
        XCTAssertEqual(board.linksToFetch(fetched: [:]).map(\.address), ["https://example.com/x"])
        XCTAssertTrue(board.linksToFetch(fetched: [note.id: "https://example.com/x"]).isEmpty)
        XCTAssertEqual(board.linksToFetch(fetched: [note.id: "https://old.com"]).count, 1)
        note.linkTitle = "Done"
        XCTAssertTrue(self.board([note]).linksToFetch(fetched: [:]).isEmpty)
    }

    func testBackdrop() {
        var b = Board(title: "T")
        XCTAssertEqual(b.backdropKind, .dots)   // what every board always had
        b.backdropKind = .squares
        XCTAssertEqual(b.backdrop, "squares")
        b.backdropKind = .plain
        XCTAssertEqual(b.backdrop, "plain")
        b.backdropKind = .dots
        XCTAssertNil(b.backdrop)
        XCTAssertEqual(Backdrop.squareStep(scale: 1), 48)
    }
}
