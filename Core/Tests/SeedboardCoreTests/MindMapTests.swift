import XCTest
@testable import SeedboardCore

final class MindMapTests: XCTestCase {
    @discardableResult
    private func kids(_ board: inout Board, _ parent: UUID, _ n: Int) -> [UUID] {
        (0..<n).map { board.addChild(of: parent, text: "k\($0)")! }
    }

    private func overlap(_ a: Item, _ b: Item) -> Bool {
        a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
    }

    private func assertNoOverlap(_ board: Board, file: StaticString = #filePath, line: UInt = #line) {
        let visible = board.items.filter { $0.kind == .idea && !board.isHidden($0.id) }
        for i in visible.indices { for j in visible.indices where j > i {
            XCTAssertFalse(overlap(visible[i], visible[j]), "\(visible[i].text) / \(visible[j].text)", file: file, line: line)
        } }
    }

    /// A map whose branches have subtrees of very different sizes and heights.
    private func unevenMap(bothSides: Bool) -> (Board, UUID) {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: bothSides)
        let main = kids(&board, c, 6)
        let deep = kids(&board, main[0], 4)
        kids(&board, deep[1], 3)
        kids(&board, main[2], 1)
        kids(&board, main[4], 5)
        board.items[board.index(of: main[3])!].h = 90
        board.items[board.index(of: deep[0])!].h = 70
        board.layoutMaps()
        return (board, c)
    }

    func testSistersNeverOverlapOneSide() {
        let (board, _) = unevenMap(bothSides: false)
        assertNoOverlap(board)
    }

    func testSistersNeverOverlapBothSides() {
        let (board, _) = unevenMap(bothSides: true)
        assertNoOverlap(board)
    }

    func testChildrenSitRightOfTheParentWithTheGap() {
        var board = Board()
        let c = board.addCentre(at: CGPoint(x: 10, y: 20), text: "C", bothSides: false)
        let k = kids(&board, c, 3)
        kids(&board, k[1], 2)
        board.layoutMaps()
        for id in board.descendants(of: c) {
            let me = board.item(id)!, parent = board.item(me.parent!)!
            XCTAssertEqual(me.x, parent.x + parent.w + MindMap.gapAcross, accuracy: 0.001)
        }
        // The children are centred on the parent.
        let first = board.item(k[0])!, last = board.item(k[2])!
        let mid = (first.y + last.y + last.h) / 2
        XCTAssertEqual(mid, board.item(c)!.centre.y, accuracy: 0.001)
    }

    func testLeftSideIsMirroredWhenBothSides() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: true)
        let k = kids(&board, c, 5)
        let grand = kids(&board, k[3], 2)
        board.layoutMaps()
        XCTAssertEqual(k.map { board.side(of: $0) }, [.right, .right, .right, .left, .left])
        let centre = board.item(c)!
        for id in k[3...] {
            let me = board.item(id)!
            XCTAssertEqual(me.x + me.w, centre.x - MindMap.gapAcross, accuracy: 0.001)
        }
        for id in grand {
            let me = board.item(id)!, parent = board.item(k[3])!
            XCTAssertEqual(me.x + me.w, parent.x - MindMap.gapAcross, accuracy: 0.001)
            XCTAssertEqual(board.side(of: id), .left)
        }
    }

    func testFoldedIdeaHidesItsChildrenAndTakesNoRoom() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: false)
        let k = kids(&board, c, 3)
        kids(&board, k[0], 4)
        board.items[board.index(of: k[0])!].folded = true
        board.layoutMaps()
        for id in board.descendants(of: k[0]) { XCTAssertTrue(board.isHidden(id)) }
        XCTAssertFalse(board.isHidden(k[0]))
        let top = board.item(k[0])!, bottom = board.item(k[2])!
        XCTAssertEqual(bottom.y + bottom.h - top.y, 3 * 30 + 2 * MindMap.gapDown, accuracy: 0.001)
    }

    func testAddSisterGoesRightAfterOrBefore() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let k = kids(&board, c, 3)
        let after = board.addSister(of: k[0])!
        XCTAssertEqual(board.children(of: c).map(\.id), [k[0], after, k[1], k[2]])
        let before = board.addSister(of: k[1], above: true)!
        XCTAssertEqual(board.children(of: c).map(\.id), [k[0], after, before, k[1], k[2]])
        let last = board.addSister(of: k[2])!
        XCTAssertEqual(board.children(of: c).last?.id, last)
        let firstOfAll = board.addSister(of: k[0], above: true)!
        XCTAssertEqual(board.children(of: c).first?.id, firstOfAll)
        XCTAssertEqual(board.children(of: c).map(\.order), (1...7).map(Double.init))
    }

    func testSisterOfACentreMakesABranch() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let n = board.addSister(of: c)!
        XCTAssertEqual(board.item(n)?.parent, c)
    }

    func testReparentRefusesItselfAndItsOwnDescendants() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let k = kids(&board, c, 2)
        let g = kids(&board, k[0], 1)[0]
        XCTAssertFalse(board.reparent(k[0], under: k[0]))
        XCTAssertFalse(board.reparent(k[0], under: g))
        XCTAssertFalse(board.reparent(c, under: g))
        XCTAssertEqual(board.item(k[0])?.parent, c)
        XCTAssertTrue(board.reparent(g, under: k[1]))
        XCTAssertEqual(board.item(g)?.parent, k[1])
        XCTAssertEqual(board.children(of: k[0]).count, 0)
    }

    func testReparentKeepsBranchColoursRight() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let k = kids(&board, c, 2)
        let g = kids(&board, k[0], 1)[0]
        XCTAssertEqual(board.item(g)?.colour, "")
        XCTAssertTrue(board.reparent(g, under: c))
        XCTAssertFalse(board.item(g)!.colour.isEmpty)
        XCTAssertEqual(Set(board.children(of: c).map(\.colour)).count, 3)
        XCTAssertTrue(board.reparent(g, under: k[1]))
        XCTAssertEqual(board.item(g)?.colour, "")
    }

    func testDetachMakesACentreAndKeepsItsIdeas() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let k = kids(&board, c, 2)
        let g = kids(&board, k[0], 2)
        board.detach(k[0], at: CGPoint(x: 500, y: 300))
        XCTAssertTrue(board.isCentre(k[0]))
        XCTAssertEqual(board.item(k[0])!.centre.x, 500, accuracy: 0.001)
        XCTAssertEqual(board.item(k[0])!.centre.y, 300, accuracy: 0.001)
        XCTAssertEqual(board.item(k[0])?.colour, "")
        XCTAssertEqual(board.centre(of: g[0]), k[0])
        XCTAssertEqual(board.mapCentres.count, 2)
        XCTAssertEqual(board.children(of: c).map(\.id), [k[1]])
        board.detach(c, at: .zero)   // a centre stays as it is
        XCTAssertTrue(board.isCentre(c))
    }

    func testBranchColourFollowsTheMainBranch() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let k = kids(&board, c, 2)
        let g = kids(&board, k[0], 1)[0]
        let gg = kids(&board, g, 1)[0]
        XCTAssertEqual(board.branchColour(of: k[0]), board.item(k[0])!.colour)
        XCTAssertEqual(board.branchColour(of: gg), board.item(k[0])!.colour)
        XCTAssertNotEqual(board.branchColour(of: gg), board.branchColour(of: k[1]))
        XCTAssertEqual(board.branchColour(of: c), "")
        XCTAssertEqual(board.mainBranch(of: gg), k[0])
        XCTAssertEqual(board.depth(of: gg), 3)
    }

    func testMainBranchesGetDifferentColours() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let k = kids(&board, c, Palette.branches.count)
        XCTAssertEqual(Set(k.map { board.item($0)!.colour }).count, Palette.branches.count)
        let more = kids(&board, c, 1)[0]   // out of colours: wraps round, never empty
        XCTAssertFalse(board.item(more)!.colour.isEmpty)
    }

    func testArrowKeysWalkBothSides() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: true)
        let k = kids(&board, c, 4)
        let rg = kids(&board, k[0], 2)
        let lg = kids(&board, k[2], 1)
        XCTAssertEqual(board.idea(from: c, step: .right), k[0])
        XCTAssertEqual(board.idea(from: c, step: .left), k[2])
        XCTAssertNil(board.idea(from: c, step: .up))
        XCTAssertEqual(board.idea(from: k[0], step: .down), k[1])
        XCTAssertNil(board.idea(from: k[0], step: .up))
        XCTAssertNil(board.idea(from: k[1], step: .down))
        XCTAssertEqual(board.idea(from: k[0], step: .right), rg[0])
        XCTAssertEqual(board.idea(from: k[0], step: .left), c)
        XCTAssertEqual(board.idea(from: rg[1], step: .left), k[0])
        XCTAssertEqual(board.idea(from: rg[0], step: .down), rg[1])
        XCTAssertEqual(board.idea(from: k[2], step: .left), lg[0])
        XCTAssertEqual(board.idea(from: k[2], step: .right), c)
        XCTAssertEqual(board.idea(from: k[2], step: .down), k[3])
        XCTAssertNil(board.idea(from: k[2], step: .up))
        XCTAssertEqual(board.idea(from: lg[0], step: .right), k[2])
        XCTAssertNil(board.idea(from: k[3], step: .left))
    }

    func testArrowKeyDoesNotEnterAFoldedIdea() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: false)
        let k = kids(&board, c, 1)[0]
        kids(&board, k, 2)
        board.items[board.index(of: k)!].folded = true
        XCTAssertNil(board.idea(from: k, step: .right))
    }

    func testShiftIdeaMovesOnePlace() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C")
        let k = kids(&board, c, 3)
        board.shiftIdea(k[1], down: true)
        XCTAssertEqual(board.children(of: c).map(\.id), [k[0], k[2], k[1]])
        board.shiftIdea(k[1], down: true)   // already last
        XCTAssertEqual(board.children(of: c).map(\.id), [k[0], k[2], k[1]])
        board.shiftIdea(k[1], down: false)
        XCTAssertEqual(board.children(of: c).map(\.id), [k[0], k[1], k[2]])
        board.shiftIdea(k[0], down: false)   // already first
        XCTAssertEqual(board.children(of: c).map(\.id), [k[0], k[1], k[2]])
    }
}
