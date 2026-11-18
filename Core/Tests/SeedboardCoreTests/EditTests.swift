import XCTest
@testable import SeedboardCore

final class EditTests: XCTestCase {
    private func nextFrom(_ board: inout Board, _ id: UUID, _ d: Direction) -> Item {
        let n = board.addNext(from: id, direction: d)!
        return board.item(n)!
    }

    private func dup(_ board: inout Board, _ id: UUID) -> Item {
        let n = board.duplicate([id]).first!
        return board.item(n)!
    }

    func testRemovingAnIdeaTakesItsSubtreeAndItsArrows() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let a = board.addChild(of: c, text: "a")!
        let a1 = board.addChild(of: a, text: "a1")!
        let b = board.addChild(of: c, text: "b")!
        let s = board.add(.box, centre: CGPoint(x: 400, y: 0), text: "s")
        let t = board.add(.box, centre: CGPoint(x: 700, y: 0), text: "t")
        board.link(from: a1, to: s)
        board.link(from: b, to: s)
        board.link(from: s, to: t)
        board.sentTodos = [a1, b]
        board.remove([a])
        XCTAssertEqual(Set(board.items.map(\.id)), [c, b, s, t])
        XCTAssertEqual(board.links.count, 2)
        XCTAssertFalse(board.links.contains { $0.from == a1 || $0.to == a1 })
        XCTAssertEqual(board.sentTodos, [b])
    }

    func testRemovingAShapeTakesItsArrowsOnly() {
        var board = Board()
        let a = board.add(.box, centre: .zero), b = board.add(.box, centre: CGPoint(x: 300, y: 0)), c = board.add(.box, centre: CGPoint(x: 600, y: 0))
        board.link(from: a, to: b)
        board.link(from: b, to: c)
        board.remove([b])
        XCTAssertEqual(board.items.count, 2)
        XCTAssertTrue(board.links.isEmpty)
    }

    func testDuplicateCopiesASubtreeAndInnerArrowsOnly() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let a = board.addChild(of: c, text: "a")!
        let a1 = board.addChild(of: a, text: "a1")!
        let s = board.add(.box, centre: CGPoint(x: 500, y: 0), text: "s")
        board.link(from: a, to: a1)
        board.link(from: a1, to: s)
        let before = Set(board.items.map(\.id))
        let copies = board.duplicate([a])
        XCTAssertEqual(board.items.count, 6)
        XCTAssertEqual(board.links.count, 3)
        XCTAssertEqual(copies.count, 1)
        let newIDs = Set(board.items.map(\.id)).subtracting(before)
        XCTAssertEqual(newIDs.count, 2)
        let copyA = board.item(copies.first!)!
        XCTAssertEqual(copyA.text, "a")
        XCTAssertEqual(copyA.parent, c)
        let copyA1 = board.items.first { newIDs.contains($0.id) && $0.text == "a1" }!
        XCTAssertEqual(copyA1.parent, copyA.id)
        let newLinks = board.links.filter { newIDs.contains($0.from) || newIDs.contains($0.to) }
        XCTAssertEqual(newLinks.count, 1)
        XCTAssertEqual(newLinks[0].from, copyA.id)
        XCTAssertEqual(newLinks[0].to, copyA1.id)
        XCTAssertEqual(Set(board.links.map(\.id)).count, 3)
        XCTAssertGreaterThan(copyA.order, board.item(a)!.order)
    }

    func testDuplicateOfACentreMovesTheWholeMapAside() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        board.addChild(of: c, text: "a")
        let copies = board.duplicate([c], by: CGSize(width: 100, height: 40))
        XCTAssertEqual(board.items.count, 4)
        let copy = board.item(copies.first!)!
        XCTAssertEqual(copy.x, board.item(c)!.x + 100, accuracy: 0.001)
        XCTAssertEqual(copy.y, board.item(c)!.y + 40, accuracy: 0.001)
        XCTAssertEqual(board.children(of: copy.id).count, 1)
    }

    func testDuplicateOfAShapeMovesItByTheOffset() {
        var board = Board()
        let a = board.add(.box, centre: .zero, text: "a")
        let copy = dup(&board, a)
        XCTAssertNotEqual(copy.id, a)
        XCTAssertEqual(copy.x, board.item(a)!.x + 28, accuracy: 0.001)
        XCTAssertEqual(copy.y, board.item(a)!.y + 28, accuracy: 0.001)
    }

    func testCarriedByACentreTakesItsWholeMap() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let a = board.addChild(of: c, text: "a")!
        let a1 = board.addChild(of: a, text: "a1")!
        let other = board.add(.box, centre: .zero)
        XCTAssertEqual(board.carried(by: [c]), [c, a, a1])
        XCTAssertEqual(board.carried(by: [a]), [])
        XCTAssertEqual(board.carried(by: [other]), [other])
    }

    func testCarriedByAFrameTakesWhatLiesWhollyInside() {
        var board = Board()
        let frame = board.add(.frame, centre: CGPoint(x: 200, y: 150), text: "F")   // 440 x 300 → -20..420, 0..300
        let inside = board.add(.note, centre: CGPoint(x: 100, y: 100))
        let half = board.add(.note, centre: CGPoint(x: 420, y: 100))
        let outside = board.add(.box, centre: CGPoint(x: 900, y: 100))
        let mapCentre = board.addCentre(at: CGPoint(x: 250, y: 220), text: "M")
        let kid = board.addChild(of: mapCentre, text: "kid")!
        board.items[board.index(of: kid)!].x = 2000   // far outside, still travels with its map
        let carried = board.carried(by: [frame])
        XCTAssertEqual(carried, [frame, inside, mapCentre, kid])
        XCTAssertFalse(carried.contains(half))
        XCTAssertFalse(carried.contains(outside))
    }

    func testLinkRefusesSelfFramesAndDoubles() {
        var board = Board()
        let a = board.add(.box, centre: .zero), b = board.add(.box, centre: CGPoint(x: 300, y: 0))
        let f = board.add(.frame, centre: .zero)
        XCTAssertNil(board.link(from: a, to: a))
        XCTAssertNil(board.link(from: a, to: f))
        XCTAssertNil(board.link(from: f, to: a))
        XCTAssertNil(board.link(from: a, to: UUID()))
        let first = board.link(from: a, to: b, text: "x")
        XCTAssertNotNil(first)
        XCTAssertEqual(board.link(from: a, to: b), first)
        XCTAssertEqual(board.links.count, 1)
        XCTAssertNotNil(board.link(from: b, to: a))
        XCTAssertEqual(board.links.count, 2)
    }

    func testAddNextJoinsAndKeepsKindAndSize() {
        var board = Board()
        let a = board.add(.diamond, centre: .zero, colour: "blue")
        let n = board.addNext(from: a, direction: .right)!
        let src = board.item(a)!, next = board.item(n)!
        XCTAssertEqual(next.kind, .diamond)
        XCTAssertEqual(next.w, src.w); XCTAssertEqual(next.h, src.h)
        XCTAssertEqual(next.colour, "blue")
        XCTAssertEqual(next.x, src.x + src.w + 70, accuracy: 0.001)
        XCTAssertEqual(next.y, src.y, accuracy: 0.001)
        XCTAssertEqual(board.links.count, 1)
        XCTAssertEqual(board.links[0].from, a); XCTAssertEqual(board.links[0].to, n)
        let down = nextFrom(&board, a, .down)
        XCTAssertEqual(down.y, src.y + src.h + 70, accuracy: 0.001)
        XCTAssertEqual(down.x, src.x, accuracy: 0.001)
        let left = nextFrom(&board, a, .left)
        XCTAssertEqual(left.x, src.x - 70 - left.w, accuracy: 0.001)
        let up = nextFrom(&board, a, .up)
        XCTAssertEqual(up.y, src.y - 70 - up.h, accuracy: 0.001)
    }

    func testAddNextStepsAsideWhenThePlaceIsTaken() {
        var board = Board()
        let a = board.add(.box, centre: .zero)
        let first = board.addNext(from: a, direction: .right)!
        let second = board.addNext(from: a, direction: .right)!
        let x = board.item(first)!, y = board.item(second)!
        XCTAssertFalse(x.frame.intersects(y.frame))
        XCTAssertEqual(y.x, x.x, accuracy: 0.001)
        XCTAssertGreaterThan(y.y, x.y)
        let downFirst = board.addNext(from: a, direction: .down)!
        let downSecond = board.addNext(from: a, direction: .down)!
        XCTAssertFalse(board.item(downFirst)!.frame.intersects(board.item(downSecond)!.frame))
        XCTAssertGreaterThan(board.item(downSecond)!.x, board.item(downFirst)!.x)
    }

    func testAddNextNeedsAShape() {
        var board = Board()
        let idea = board.addCentre(at: .zero, text: "i")
        let frame = board.add(.frame, centre: CGPoint(x: 1000, y: 0))
        XCTAssertNil(board.addNext(from: idea, direction: .right))
        XCTAssertNil(board.addNext(from: frame, direction: .right))
    }

    func testHitFindsADiamondOnlyInsideTheDiamond() {
        var board = Board()
        let d = board.add(.diamond, centre: .zero)   // 160 x 104
        XCTAssertEqual(board.hit(.zero), d)
        XCTAssertEqual(board.hit(CGPoint(x: 40, y: 20)), d)
        XCTAssertNil(board.hit(CGPoint(x: 70, y: 40)))      // inside the box, outside the diamond
        XCTAssertNil(board.hit(CGPoint(x: -75, y: -48)))
        XCTAssertNil(board.hit(CGPoint(x: 200, y: 0)))
    }

    func testHitFindsAnOvalOnlyInsideTheOval() {
        var board = Board()
        let o = board.add(.oval, centre: .zero)   // 150 x 72
        XCTAssertEqual(board.hit(.zero), o)
        XCTAssertNil(board.hit(CGPoint(x: 70, y: 32)))
    }

    func testHitFindsAFrameOnlyAtItsBandOrEdge() {
        var board = Board()
        let f = board.add(.frame, centre: .zero)   // -220..220, -150..150
        XCTAssertNil(board.hit(.zero))
        XCTAssertNil(board.hit(CGPoint(x: 0, y: 50)))
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: -140)), f)      // name band
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: -125)), f)
        XCTAssertEqual(board.hit(CGPoint(x: 215, y: 50)), f)      // edge
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: 147)), f)
        XCTAssertNil(board.hit(CGPoint(x: 0, y: 200)))
        let n = board.add(.note, centre: CGPoint(x: 0, y: -130))
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: -130)), n)      // things inside win
    }

    func testHitPrefersTheTopmostAndSkipsHidden() {
        var board = Board()
        let a = board.add(.box, centre: .zero), b = board.add(.box, centre: .zero)
        XCTAssertEqual(board.hit(.zero), b)
        board.bringToFront(a)
        XCTAssertEqual(board.hit(.zero), a)
        var map = Board()
        let c = map.addCentre(at: .zero, text: "C", bothSides: false)
        let k = map.addChild(of: c, text: "k")!
        let g = map.addChild(of: k, text: "g")!
        map.layoutMaps()
        let at = map.item(g)!.centre
        XCTAssertEqual(map.hit(at), g)
        map.items[map.index(of: k)!].folded = true
        XCTAssertNil(map.hit(at))
    }

    func testHitLinkFindsAnArrowNearItsLine() {
        var board = Board()
        let a = board.add(.box, centre: .zero), b = board.add(.box, centre: CGPoint(x: 400, y: 0))
        let l = board.link(from: a, to: b)!
        XCTAssertEqual(board.hitLink(CGPoint(x: 200, y: 4)), l)
        XCTAssertNil(board.hitLink(CGPoint(x: 200, y: 40)))
    }

    func testItemsInABoxCatchesWhatItTouches() {
        var board = Board()
        let a = board.add(.box, centre: .zero)          // -75..75
        let b = board.add(.box, centre: CGPoint(x: 500, y: 0))
        let f = board.add(.frame, centre: CGPoint(x: 0, y: 500))   // -220..220, 350..650
        XCTAssertEqual(board.items(in: CGRect(x: 60, y: -10, width: 20, height: 20)), [a])
        XCTAssertEqual(board.items(in: CGRect(x: -100, y: -100, width: 700, height: 200)), [a, b])
        XCTAssertEqual(board.items(in: CGRect(x: -100, y: 400, width: 200, height: 100)), [])   // frame only when wholly inside
        XCTAssertEqual(board.items(in: CGRect(x: -300, y: 300, width: 600, height: 400)), [f])
    }

    func testBoundsIsTheBoxRoundEverythingVisible() {
        var board = Board()
        XCTAssertNil(board.bounds)
        board.add(.box, centre: .zero)                         // -75..75, -28..28
        board.add(.note, centre: CGPoint(x: 400, y: 200))      // 325..475, 145..255
        XCTAssertEqual(board.bounds, CGRect(x: -75, y: -28, width: 550, height: 283))
    }

    func testBoundsLeavesOutHiddenIdeas() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: false)
        let k = board.addChild(of: c, text: "k")!
        let g = board.addChild(of: k, text: "g")!
        board.layoutMaps()
        board.items[board.index(of: g)!].x = 5000
        board.items[board.index(of: k)!].folded = true
        XCTAssertLessThan(board.bounds!.maxX, 1000)
    }

    func testCountLineSaysWhatIsOnTheBoard() {
        var board = Board()
        XCTAssertEqual(board.countLine, "Empty")
        board.addCentre(at: .zero, text: "C")
        XCTAssertEqual(board.countLine, "1 idea")
        board.add(.box, centre: .zero); board.add(.oval, centre: .zero)
        board.add(.note, centre: .zero)
        board.add(.text, centre: .zero); board.add(.frame, centre: .zero)
        XCTAssertEqual(board.countLine, "1 idea · 2 shapes · 1 note")
        board.add(.note, centre: .zero)
        XCTAssertEqual(board.countLine, "1 idea · 2 shapes · 2 notes")
    }

    func testResizeKeepsAMinimumSize() {
        var board = Board()
        let a = board.add(.box, centre: .zero)
        board.resize(a, to: CGRect(x: 0, y: 0, width: 5, height: 5))
        XCTAssertEqual(board.item(a)?.w, 44); XCTAssertEqual(board.item(a)?.h, 28)
    }
}
