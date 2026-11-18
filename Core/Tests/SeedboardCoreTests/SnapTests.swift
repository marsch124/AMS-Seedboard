import XCTest
@testable import SeedboardCore

final class SnapTests: XCTestCase {
    private let a = CGRect(x: 0, y: 0, width: 100, height: 50)

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 100, _ h: CGFloat = 50) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    func testAThingThreePointsOffFallsInLineAndShowsTheLines() {
        // Dragged to 3 below the neighbour's line: it is pulled up by 3; top, middle and bottom are in line.
        let result = Snap.move([rect(300, 100)], by: CGSize(width: 0, height: -97), targets: [.init(a)], reach: 6)
        XCTAssertEqual(result.delta, CGSize(width: 0, height: -100))
        XCTAssertEqual(result.guides, [
            Snap.Guide(kind: .line, axis: .down, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 400, y: 0)),
            Snap.Guide(kind: .line, axis: .down, from: CGPoint(x: 0, y: 25), to: CGPoint(x: 400, y: 25)),
            Snap.Guide(kind: .line, axis: .down, from: CGPoint(x: 0, y: 50), to: CGPoint(x: 400, y: 50)),
        ])
    }

    func testSevenPointsOffIsLeftAlone() {
        let result = Snap.move([rect(300, 0)], by: CGSize(width: 0, height: 7), targets: [.init(a)], reach: 6)
        XCTAssertEqual(result.delta, CGSize(width: 0, height: 7))
        XCTAssertTrue(result.guides.isEmpty)
    }

    func testTheCatchIsSixScreenPointsSoItGrowsWhenZoomedOut() {
        // At 50 % zoom the reach is 6 / 0.5 = 12 board points: 10 off is caught, at life size it is not.
        let far = Snap.move([rect(300, 0)], by: CGSize(width: 0, height: 10), targets: [.init(a)], reach: 6 / 0.5)
        XCTAssertEqual(far.delta.height, 0)
        let near = Snap.move([rect(300, 0)], by: CGSize(width: 0, height: 10), targets: [.init(a)], reach: 6 / 1)
        XCTAssertEqual(near.delta.height, 10)
    }

    func testTheNearestCatchWinsAndSidewaysAndUpDownAreSeparate() {
        // A narrow thing: its left edge is 5 from the neighbour's left edge, its middle 2 from the middle.
        // Up-down it is far from everything, so only sideways is corrected.
        let result = Snap.move([rect(0, 200, 90, 30)], by: CGSize(width: 3, height: 40), targets: [.init(a)], reach: 6)
        XCTAssertEqual(result.delta, CGSize(width: 5, height: 40))
        XCTAssertEqual(result.guides, [
            Snap.Guide(kind: .line, axis: .across, from: CGPoint(x: 50, y: 0), to: CGPoint(x: 50, y: 270)),
        ])
    }

    func testEdgesCatchEdgesFromTheOtherSideToo() {
        // The dragged thing's left edge meets the neighbour's right edge.
        let result = Snap.move([rect(96, 300)], by: .zero, targets: [.init(a)], reach: 6)
        XCTAssertEqual(result.delta.width, 4)
        XCTAssertEqual(result.guides.first?.from.x, 100)
    }

    func testSeveralThingsSnapByTheBoxRoundThem() {
        let pair = [rect(300, 4), rect(300, 104)]
        let result = Snap.move(pair, by: .zero, targets: [.init(a)], reach: 6)
        // The box is 300…400 × 4…154: its top is 4 from the neighbour's top.
        XCTAssertEqual(result.delta, CGSize(width: 0, height: -4))
    }

    func testTheSameGapBetweenTwoNeighbours() {
        // Neighbours at 0…100 and 400…500; an 80 wide thing let go at 207 lands at 210 (gap 110 on both sides).
        let right = rect(400, 0)
        let result = Snap.move([rect(207, 12, 80, 10)], by: .zero, targets: [.init(a), .init(right)], reach: 6)
        XCTAssertEqual(result.delta, CGSize(width: 3, height: 0))
        XCTAssertEqual(result.guides, [
            Snap.Guide(kind: .gap, axis: .across, from: CGPoint(x: 100, y: 17), to: CGPoint(x: 210, y: 17)),
            Snap.Guide(kind: .gap, axis: .across, from: CGPoint(x: 290, y: 17), to: CGPoint(x: 400, y: 17)),
        ])
    }

    func testTheSameGapAfterTwoNeighboursInARowAndInAColumn() {
        // A row 0…100, 140…240 (gap 40): the third lands at 280.
        let second = rect(140, 0)
        let across = Snap.move([rect(283, 12, 100, 20)], by: .zero, targets: [.init(a), .init(second)], reach: 6)
        XCTAssertEqual(across.delta.width, -3)
        XCTAssertEqual(across.guides.filter { $0.kind == .gap }.count, 2)
        // A column 0…50, 80…130 (gap 30): the third lands at 160, coming from above it too.
        let below = rect(20, 80)
        let down = Snap.move([rect(30, 156, 60, 50)], by: .zero, targets: [.init(a), .init(below)], reach: 6)
        XCTAssertEqual(down.delta.height, 4)
        XCTAssertEqual(down.guides.filter { $0.kind == .gap && $0.axis == .down }.count, 2)
        let before = Snap.move([rect(30, -82, 60, 50)], by: .zero, targets: [.init(a), .init(below)], reach: 6)
        XCTAssertEqual(before.delta.height, 2)
    }

    func testAFrameIsCaughtByItsEdgesOnly() {
        let frame = Snap.Target(rect(0, 0, 400, 300), edgesOnly: true)
        // The middle of the frame (200, 150) does not catch …
        let middle = Snap.move([rect(152, 127)], by: .zero, targets: [frame], reach: 6)
        XCTAssertEqual(middle.delta, .zero)
        // … its left edge does.
        let edge = Snap.move([rect(4, 127)], by: .zero, targets: [frame], reach: 6)
        XCTAssertEqual(edge.delta, CGSize(width: -4, height: 0))
        // A dragged frame does not catch by its middle either.
        let dragged = Snap.move([rect(-150, 502, 400, 300)], by: .zero, targets: [.init(a)], reach: 6, middles: false)
        XCTAssertEqual(dragged.delta, .zero)
    }

    func testNoReachMeansNoCatch() {
        let result = Snap.move([rect(300, 2)], by: .zero, targets: [.init(a)], reach: 0)
        XCTAssertEqual(result.delta, .zero)
        XCTAssertTrue(result.guides.isEmpty)
    }

    func testWhileSizingTheMovingEdgeCatches() {
        // The right edge is pulled to 296: it catches the neighbour's left edge at 300. The bottom is far from anything.
        let neighbour = rect(300, 200)
        let result = Snap.resize(rect(100, 0, 196, 90), from: rect(100, 0, 150, 60), targets: [.init(neighbour)], reach: 6)
        XCTAssertEqual(result.rect, rect(100, 0, 200, 90))
        XCTAssertEqual(result.guides, [
            Snap.Guide(kind: .line, axis: .across, from: CGPoint(x: 300, y: 0), to: CGPoint(x: 300, y: 250)),
        ])
        // An edge that does not move does not catch: the left edge is 3 from the neighbour's right edge.
        let still = Snap.resize(rect(403, 0, 150, 80), from: rect(403, 0, 150, 60), targets: [.init(neighbour)], reach: 6)
        XCTAssertEqual(still.rect, rect(403, 0, 150, 80))
    }

    func testOnABoardIdeasOfAMapAreLeftOutAndItsCentreCounts() {
        var board = Board()
        let centre = board.addCentre(at: CGPoint(x: 0, y: 0), text: "Centre")
        let child = board.addChild(of: centre, text: "Child")!
        board.layoutMaps()
        let box = board.add(.box, centre: CGPoint(x: 0, y: 303))
        let targets = board.snapTargets(without: [box])
        XCTAssertEqual(targets.map(\.rect), [board.item(centre)!.frame])
        XCTAssertFalse(targets.contains { $0.rect == board.item(child)!.frame })

        // The box is 3 right of the centre's middle after the move: it is pulled onto it.
        let guides = board.moveSnapped([box], by: CGSize(width: 3, height: 0), reach: 6)
        XCTAssertEqual(board.item(box)!.centre.x, board.item(centre)!.centre.x)
        XCTAssertFalse(guides.isEmpty)

        // A frame is a target by its edges only, and a hidden idea is none.
        let frame = board.add(.frame, centre: CGPoint(x: 900, y: 0))
        XCTAssertEqual(board.snapTargets().first { $0.rect == board.item(frame)!.frame }?.edgesOnly, true)
        // Holding ⌘ (reach 0): a plain move.
        XCTAssertTrue(board.moveSnapped([box], by: CGSize(width: 2, height: 0), reach: 0).isEmpty)
        XCTAssertEqual(board.item(box)!.centre.x, board.item(centre)!.centre.x + 2)
    }

    func testAShapePulledOutOfAPlusLandsInLineSoTheArrowIsOneStraightPiece() {
        var board = Board()
        let from = board.add(.box, centre: CGPoint(x: 0, y: 0))
        // A taller neighbour whose top edge is nearer than the middle of the shape it comes from.
        board.add(.note, centre: CGPoint(x: 0, y: 200))
        let land = board.landing(from: from, at: CGPoint(x: 260, y: 4), reach: 6)!
        XCTAssertEqual(land.centre, CGPoint(x: 260, y: 0))
        let new = board.add(.box, centre: land.centre)
        let path = Route.path(from: board.item(from)!.frame, to: board.item(new)!.frame, style: .elbow)
        XCTAssertEqual(path.points.count, 2)
        // Let go over another thing the two are joined: nothing lands. An idea adds an idea.
        XCTAssertNil(board.landing(from: from, at: CGPoint(x: 0, y: 200), reach: 6))
        let idea = board.addCentre(at: CGPoint(x: 600, y: 600))
        XCTAssertNil(board.landing(from: idea, at: CGPoint(x: 900, y: 600), reach: 6))
    }

    func testSizingOnABoardDropsAGuideTheSmallestSizeHeldBack() {
        var board = Board()
        let box = board.add(.box, centre: CGPoint(x: 75, y: 28))            // 0…150 × 0…56
        board.add(.box, centre: CGPoint(x: 115, y: 300))                    // 40…190
        // Pulled in to 42 wide: the edge would catch 40, but a box is never narrower than 44.
        let guides = board.resizeSnapped(box, to: CGRect(x: 0, y: 0, width: 42, height: 56), reach: 6)
        XCTAssertEqual(board.item(box)!.frame.width, 44)
        XCTAssertTrue(guides.isEmpty)
        // Pulled out to 188: it catches the neighbour's right edge at 190.
        let caught = board.resizeSnapped(box, to: CGRect(x: 0, y: 0, width: 188, height: 56), reach: 6)
        XCTAssertEqual(board.item(box)!.frame.maxX, 190)
        XCTAssertEqual(caught.count, 1)
    }
}
