import XCTest
@testable import SeedboardCore

final class Boards14Tests: XCTestCase {
    func testJoinLaysThingsToTheRightKeepsArrowsAndRenewsClashingIds() throws {
        var a = Board(title: "Garden")
        let n1 = Item(kind: .note, text: "one", x: 0, y: 0, w: 100, h: 50)
        let n2 = Item(kind: .note, text: "two", x: 200, y: 100, w: 100, h: 50)
        a.items = [n1, n2]
        var b = Board(title: "Plan")
        var c1 = Item(kind: .note, text: "x", x: 500, y: 300, w: 100, h: 50)
        c1.id = n1.id   // a clash
        let c2 = Item(kind: .note, text: "y", x: 700, y: 300, w: 100, h: 50)
        b.items = [c1, c2]
        b.links = [Link(from: c1.id, to: c2.id)]
        let out = try XCTUnwrap(BoardJoin.join(b, into: a))
        XCTAssertEqual(out.id, a.id)
        XCTAssertEqual(out.items.count, 4)
        XCTAssertEqual(Set(out.items.map(\.id)).count, 4)
        let moved = out.items.filter { $0.text == "x" || $0.text == "y" }
        XCTAssertEqual(moved.map(\.x).min()!, 300 + BoardJoin.gap, accuracy: 0.01)
        XCTAssertEqual(moved.map(\.y).min()!, 0, accuracy: 0.01)
        XCTAssertEqual(out.links.count, 1)
        let ids = Set(out.items.map(\.id))
        XCTAssertTrue(ids.contains(out.links[0].from) && ids.contains(out.links[0].to))
        XCTAssertNotEqual(out.links[0].from, n1.id)
    }

    func testJoinRefusesTimelines() {
        var t = Board(title: "T"); t.kind = Board.timelineKind
        XCTAssertNil(BoardJoin.join(Board(title: "A"), into: t))
        XCTAssertTrue(BoardJoin.choices(for: Board(), in: [t, Board(title: "O")]).count == 1)
    }

    func testOpmlNestsAndTitles() throws {
        let xml = """
        <?xml version="1.0"?><opml version="2.0"><head><title>Trip</title></head><body>
        <outline text="Food"><outline text="Fika"/><outline text="Pizza &amp; wine"/></outline>
        <outline text="Sights"/></body></opml>
        """
        let r = OpmlOutline.parse(Data(xml.utf8))
        XCTAssertEqual(r.title, "Trip")
        XCTAssertEqual(r.nodes.map(\.text), ["Food", "Sights"])
        XCTAssertEqual(r.nodes[0].children.map(\.text), ["Fika", "Pizza & wine"])
        let read = try XCTUnwrap(OpmlOutline.read(Data("# Plan\n- a\n- b".utf8), fileName: "Notes", ext: "md"))
        XCTAssertEqual(read.title, "Notes")
        XCTAssertEqual(read.nodes.first?.children.count, 2)
    }

    func testLockedBoardIsFoundByNameOnly() {
        var board = Board(title: "Gift ideas", items: [Item(kind: .note, text: "Bicycle for Alex")])
        board.faceLock = true
        XCTAssertTrue(BoardSearch.find("bicycle", in: [board]).isEmpty)
        XCTAssertEqual(BoardSearch.find("gift", in: [board]).count, 1)
    }
}
