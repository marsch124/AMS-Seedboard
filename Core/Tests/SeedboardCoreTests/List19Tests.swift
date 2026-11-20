import XCTest
@testable import SeedboardCore

/// 0.19, lane "list": the rules behind sort, Due soon, the done bar, the found line and the clipboard board.
final class List19Tests: XCTestCase {
    private func board(_ title: String, made: Double = 0, changed: Double = 0) -> Board {
        var b = Board(title: title)
        b.created = Date(timeIntervalSince1970: made)
        b.changed = Date(timeIntervalSince1970: changed)
        return b
    }

    func testSortOrders() {
        let a = board("beta", made: 1, changed: 30), b = board("Alpha", made: 3, changed: 10), c = board("Émile", made: 2, changed: 20)
        XCTAssertEqual(BoardSort.changed.sorted([a, b, c]).map(\.title), ["beta", "Émile", "Alpha"])
        XCTAssertEqual(BoardSort.made.sorted([a, b, c]).map(\.title), ["Alpha", "Émile", "beta"])
        XCTAssertEqual(BoardSort.name.sorted([a, b, c]).map(\.title), ["Alpha", "beta", "Émile"])
    }

    func testDueSoonWindowAndLate() {
        let today = Day(number: 20000)
        func due(_ n: Int) -> Board { var b = board("d\(n)"); b.setDue(today + n); return b }
        let boards = [due(8), due(7), due(0), due(-3), board("none")]
        let e = DueSoon.entries(boards, today: today)
        XCTAssertEqual(e.map(\.days), [-3, 0, 7])
        XCTAssertEqual(e.map(\.words), ["3 days late", "today", "in 7 days"])
        XCTAssertTrue(e[0].late); XCTAssertFalse(e[1].late)
        var away = due(1); away.putAway = Date()
        XCTAssertTrue(DueSoon.entries([away], today: today).isEmpty)
    }

    func testDoneShareAndLate() {
        let today = Day(number: 20000)
        var b = Board(title: "t")
        XCTAssertNil(b.doneShare())
        var t = Item(kind: .note, text: "x", x: 0, y: 0); t.todo = true
        b.items = [t]
        XCTAssertEqual(b.doneShare()?.total, 1)
        XCTAssertEqual(b.doneShare(doneThings: [t.id])?.done, 1)
        b.kind = Board.timelineKind
        var bar = Item(kind: .bar, text: "bar", x: 0, y: 0)
        bar.start = (today - 10).iso; bar.end = (today - 5).iso
        b.items.append(bar)
        XCTAssertEqual(b.lateThings(today: today), 1)
        XCTAssertEqual(b.doneShare()?.total, 2)
        b.setDone([bar.id], true, on: today)
        XCTAssertEqual(b.lateThings(today: today), 0)
        XCTAssertEqual(b.doneShare()?.done, 1)
    }

    func testFoundLineBoldsWords() {
        var b = Board(title: "Cabin")
        b.items = [Item(kind: .note, text: "Buy timber\nand nails for the roof", x: 0, y: 0)]
        let line = b.foundLine("Roof nails")
        XCTAssertEqual(line?.plain, "and nails for the roof")
        XCTAssertEqual(line?.pieces.filter(\.bold).map(\.text), ["nails", "roof"])
        XCTAssertNil(b.foundLine("zebra"))
        XCTAssertNil(b.foundLine(""))
    }

    func testClipboardBoard() {
        XCTAssertNil(ClipboardBoard.board(from: nil))
        XCTAssertNil(ClipboardBoard.board(from: "  \n "))
        let b = ClipboardBoard.board(from: "Plan\n  one\n  two")
        XCTAssertEqual(b?.title, "Plan")
        XCTAssertEqual(b?.items.count, 3)
        XCTAssertEqual(ClipboardBoard.board(from: "a\nb")?.title, "From the clipboard")
    }
}
