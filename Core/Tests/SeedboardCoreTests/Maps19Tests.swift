import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.19 (maps): bent arrows, tapered branches, the look of a map, numbered branches, the other side, grown ideas.
final class Maps19Tests: XCTestCase {
    private func twoBoxes() -> (Board, UUID, UUID, UUID) {
        var b = Board(title: "Flow")
        let a = b.add(.box, centre: CGPoint(x: 0, y: 0), text: "A")
        let c = b.add(.box, centre: CGPoint(x: 300, y: 0), text: "B")
        let l = b.link(from: a, to: c)!
        return (b, a, c, l)
    }

    func testBendRuleCurvePointAndHit() {
        var (b, _, _, l) = twoBoxes()
        let plain = b.arrow(l)!
        XCTAssertFalse(plain.isBent)
        let mid = plain.middle
        XCTAssertTrue(b.bendLink(l, to: CGPoint(x: mid.x, y: mid.y + 60)))
        XCTAssertEqual(b.links[0].bend ?? [], [0, 60])
        let bent = b.arrow(l)!
        XCTAssertTrue(bent.isBent)
        XCTAssertEqual(bent.knob.y, mid.y + 60, accuracy: 0.01)
        // The curve passes through the knob and is smooth there (the two control points are level with it).
        guard case .curve(let m, _, let c2) = bent.pieces[1], case .curve(_, let c3, _) = bent.pieces[2] else { return XCTFail("two curves") }
        XCTAssertEqual(Double(m.y), Double(mid.y) + 60, accuracy: 0.01)
        XCTAssertEqual(Double(c2.y), Double(c3.y), accuracy: 0.01)
        XCTAssertTrue(bent.outline.contains { abs($0.y - (mid.y + 60)) < 0.5 })
        // Hit test of the knob, and of the line under it.
        XCTAssertTrue(b.knobHit(of: l, at: CGPoint(x: bent.knob.x + 8, y: bent.knob.y), reach: 13))
        XCTAssertFalse(b.knobHit(of: l, at: CGPoint(x: bent.knob.x + 40, y: bent.knob.y), reach: 13))
        XCTAssertEqual(b.hitLink(bent.knob), l)
        // Dragging the knob again measures from the plain middle; a tiny bend is straight again.
        XCTAssertTrue(b.bendLink(l, to: CGPoint(x: mid.x + 1, y: mid.y + 1)))
        XCTAssertNil(b.links[0].bend)
        XCTAssertTrue(b.bendLink(l, to: CGPoint(x: mid.x, y: mid.y - 40)))
        XCTAssertTrue(b.straightenLink(l))
        XCTAssertFalse(b.straightenLink(l))
        XCTAssertEqual(b.arrow(l)!.pieces, plain.pieces)
    }

    func testBranchesTaperAndLooks() {
        XCTAssertEqual(Route.branchTaper(depth: 1).near, 5)
        XCTAssertEqual(Route.branchTaper(depth: 1).far, 3.4)
        XCTAssertEqual(Route.branchTaper(depth: 2).near, 3.4)
        XCTAssertEqual(Route.branchTaper(depth: 5).far, 1.8)
        let line = (start: CGPoint(x: 0, y: 0), near: CGPoint(x: 50, y: 40), end: CGPoint(x: 120, y: 40))
        let outline = Route.taperedOutline(Route.branchPoints(line, look: .lines), near: 5, far: 3.4)
        XCTAssertEqual(outline.count, 6)
        XCTAssertGreaterThan(Route.branchPoints(line, look: .curves).count, 10)
        var b = Board(title: "Map")
        XCTAssertEqual(b.look, .curves)                                             // nothing stored = what 0.18 drew
        XCTAssertTrue(b.setMapLook(.boxes)); XCTAssertEqual(b.mapLook, "boxes")
        XCTAssertTrue(b.setMapLook(.curves)); XCTAssertNil(b.mapLook)
        XCTAssertFalse(b.setMapLook(.curves))
        let box = Route.boxLine(from: CGRect(x: 0, y: 0, width: 80, height: 30), to: CGRect(x: 126, y: 60, width: 60, height: 20), side: .right)
        XCTAssertEqual(box.count, 4)
        XCTAssertEqual(box[1].x, 103)
    }

    private func map() -> (Board, UUID, [UUID]) {
        var b = Board(title: "Map")
        let c = b.addCentre(at: .zero, text: "Centre", bothSides: true)
        let kids = ["Travel", "Food", "Places", "Money"].map { b.addChild(of: c, text: $0)! }
        b.layoutMaps()
        return (b, c, kids)
    }

    func testNumberBranchesReadingOrderAndOtherSide() {
        var (b, _, kids) = map()
        XCTAssertTrue(b.branchNumbers().isEmpty)
        b.numberBranches = true
        let n = b.branchNumbers()
        XCTAssertEqual(Set(n.values), [1, 2, 3, 4])
        let right = kids.filter { b.item($0)?.side != .left }.sorted { b.item($0)!.y < b.item($1)!.y }
        for (i, id) in right.enumerated() { XCTAssertEqual(n[id], i + 1) }      // right side first, top to bottom
        XCTAssertEqual(b.numberedWords(of: kids[0], in: n), "\(n[kids[0]]!). Travel")
        XCTAssertTrue(b.outlineText.contains("\(n[kids[1]]!). Food"))
        let target = right[0]
        XCTAssertTrue(b.canMoveToOtherSide(target))
        XCTAssertTrue(b.moveToOtherSide(target))
        XCTAssertEqual(b.item(target)?.side, .left)
        XCTAssertEqual(b.side(of: target), .left)
        XCTAssertFalse(b.canMoveToOtherSide(b.addChild(of: target, text: "Deeper")!))
        var one = Board(title: "One side")
        let c1 = one.addCentre(at: .zero, text: "C", bothSides: false)
        XCTAssertFalse(one.canMoveToOtherSide(one.addChild(of: c1, text: "x")!))
    }

    func testGrowIdeasWordRule() {
        let out = GrowIdeas.clean(["  Bakery ", "bakery", "1. Old town", "Travel", "- Lake.", "\"Museum\"", "Extra", ""], idea: "Travel", children: ["Lake"])
        XCTAssertEqual(out, ["Bakery", "Old town", "Museum"])        // doubles, own word, a child, empty, and a fourth are out
        XCTAssertEqual(GrowIdeas.clean(["Café", "cafe"], idea: "x", children: []), ["Café"])
        var (b, _, kids) = map()
        let ids = b.addIdeas(["One", "Two"], under: kids[0])
        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(b.childWords(of: kids[0]), ["One", "Two"])
    }
}
