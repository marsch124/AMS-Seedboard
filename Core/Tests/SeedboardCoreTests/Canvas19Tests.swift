import XCTest
@testable import SeedboardCore

/// One small test per rule of 0.19's bar beside the chosen thing: last colours first, Stack, two note sizes, Put in a frame.
final class Canvas19Tests: XCTestCase {
    private func put(_ board: inout Board, _ kind: ItemKind, x: Double, y: Double) -> UUID {
        let id = board.add(kind, centre: .zero)
        let i = board.index(of: id)!
        board.items[i].x = x
        board.items[i].y = y
        return id
    }

    func testTheLastThreeColoursComeFirstOnlyThoseOfferedNoDoubles() {
        let offered = Palette.notes   // yellow pink blue green orange purple
        let row = Canvas19.colourRow(offered, recent: ["red", "green", "green", "purple", "pink", "blue"])
        XCTAssertEqual(row, ["green", "purple", "pink", "yellow", "blue", "orange"])
        XCTAssertEqual(Canvas19.colourRow(["", "pink", "teal"], recent: ["teal"]), ["", "teal", "pink"])
        XCTAssertEqual(Canvas19.remembered("pink", in: ["blue", "pink", "green"]), ["pink", "blue", "green"])
    }

    func testStackMakesOneColumnUnderTheTopLeftOneInReadingOrder() {
        var board = Board()
        let a = put(&board, .note, x: 300, y: 0)
        let b = put(&board, .note, x: 40, y: 200)
        let c = put(&board, .box, x: 10, y: 5)
        let frame = put(&board, .frame, x: 0, y: 0)
        XCTAssertTrue(board.stack([a, b, c, frame]))
        let first = board.item(c)!, second = board.item(a)!, third = board.item(b)!
        XCTAssertEqual([first.x, first.y], [10, 5])
        XCTAssertEqual([second.x, second.y], [10, 5 + first.h + 10])
        XCTAssertEqual([third.x, third.y], [10, 5 + first.h + 10 + second.h + 10])
        XCTAssertFalse(board.stack([a]))
    }

    func testSmallNoteIs96x64KeepsItsCornerAndTurnsBack() {
        var board = Board()
        let n = put(&board, .note, x: 50, y: 70)
        board.setNoteSize([n], small: true)
        var item = board.item(n)!
        XCTAssertEqual([item.x, item.y, item.w, item.h], [50, 70, 96, 64])
        XCTAssertEqual(item.textSize, "small")
        board.setNoteSize([n], small: false)
        item = board.item(n)!
        XCTAssertEqual([item.x, item.y, item.w, item.h], [50, 70, 150, 110])
        XCTAssertNil(item.textSize)
    }

    func testPutInAFrameGrows24AroundAndLiesUnderNeitherCutsAMap() {
        var board = Board()
        let a = put(&board, .note, x: 100, y: 100)
        let b = put(&board, .box, x: 400, y: 300)
        let before = board.items.count
        let f = board.putInFrame([a, b])!
        XCTAssertEqual(board.items.count, before + 1)
        XCTAssertEqual(board.items.first?.id, f)
        let frame = board.item(f)!, na = board.item(a)!, nb = board.item(b)!
        XCTAssertEqual(frame.frame, na.frame.union(nb.frame).insetBy(dx: -24, dy: -24))
        XCTAssertEqual(frame.text, "")
        XCTAssertTrue(Board.frame(frame, holds: na))
        // A map: one idea of it alone cannot be framed; its centre brings the whole map.
        var map = Board()
        let centre = map.addCentre(at: .zero, text: "Centre")
        let kid = map.addChild(of: centre)!
        XCTAssertFalse(map.canFrame([kid]))
        XCTAssertTrue(map.canFrame([centre]))
        XCTAssertNotNil(map.putInFrame([centre, kid]))
    }
}
