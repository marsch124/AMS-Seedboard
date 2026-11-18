import XCTest
@testable import SeedboardCore

/// Better arrows and the keys of a flow (0.2).
final class ArrowTests: XCTestCase {
    private func box(_ x: Double, _ y: Double, _ w: Double = 100, _ h: Double = 50) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    private func made(_ board: inout Board, from id: UUID, _ direction: Direction) -> Item {
        let new = board.addNext(from: id, direction: direction)!
        return board.item(new)!
    }

    private func crossesAny(_ points: [CGPoint], _ rect: CGRect) -> Bool {
        for i in 1..<points.count where Route.crosses(points[i - 1], points[i], rect) { return true }
        return false
    }

    // MARK: The plain line stays as it was

    func testWithNothingInTheWayTheLineRunsAsBefore() {
        let a = box(0, 0)
        let others = [box(200, 0), box(200, 40), box(30, 150), box(-300, -200), box(-300, 10), box(20, -200)]
        for b in others {
            let sides = Route.sides(from: a, to: b)
            for style in LinkStyle.allCases {
                let old = Route.path(from: a, to: b, style: style)
                let new = Route.arrow(from: Route.End(rect: a, side: sides.leaves), to: Route.End(rect: b, side: sides.arrives), style: style)
                XCTAssertEqual(sides.leaves, old.leaves)
                XCTAssertEqual(sides.arrives, old.arrives)
                XCTAssertEqual(new.points, old.points, "\(style) to \(b)")
                XCTAssertFalse(new.detour)
            }
        }
    }

    // MARK: Rounded corners

    func testCornersAreRoundedByEightAndLessOnAShortLeg() {
        // Legs of 50, 40 and 50: both corners get the full 8.
        let wide = Route.rounded([CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 40), CGPoint(x: 100, y: 40)])
        XCTAssertEqual(wide, [
            .move(CGPoint(x: 0, y: 0)),
            .line(CGPoint(x: 42, y: 0)), .quad(to: CGPoint(x: 50, y: 8), control: CGPoint(x: 50, y: 0)),
            .line(CGPoint(x: 50, y: 32)), .quad(to: CGPoint(x: 58, y: 40), control: CGPoint(x: 50, y: 40)),
            .line(CGPoint(x: 100, y: 40)),
        ])
        // A middle leg of 10: the corners beside it get half of it, 5.
        let tight = Route.rounded([CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 10), CGPoint(x: 100, y: 10)])
        XCTAssertEqual(tight[1], .line(CGPoint(x: 45, y: 0)))
        XCTAssertEqual(tight[2], .quad(to: CGPoint(x: 50, y: 5), control: CGPoint(x: 50, y: 0)))
        // A straight line has no corner.
        XCTAssertEqual(Route.rounded([CGPoint(x: 0, y: 0), CGPoint(x: 9, y: 0)]), [.move(.zero), .line(CGPoint(x: 9, y: 0))])
    }

    // MARK: Arrows that share a side

    func testOffsetsStandFourteenApartRoundTheMiddle() {
        XCTAssertEqual(Route.offsets(count: 1, room: 40), [0])
        XCTAssertEqual(Route.offsets(count: 2, room: 40), [-7, 7])
        XCTAssertEqual(Route.offsets(count: 3, room: 40), [-14, 0, 14])
        // No room for 14: they share what there is.
        XCTAssertEqual(Route.offsets(count: 3, room: 20), [-10, 0, 10])
    }

    func testTwoArrowsOutOfOneSideStandApart() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0))
        let up = board.add(.box, centre: CGPoint(x: 300, y: -100))
        let low = board.add(.box, centre: CGPoint(x: 300, y: 100))
        // Made in the "wrong" order on purpose: the upper slot still goes to the upper shape.
        let toLow = board.link(from: a, to: low)!, toUp = board.link(from: a, to: up)!
        let all = board.arrows()
        let right = Double(board.item(a)!.frame.maxX)
        XCTAssertEqual(all[toUp]!.points[0], CGPoint(x: right, y: -7))
        XCTAssertEqual(all[toLow]!.points[0], CGPoint(x: right, y: 7))
        // Alone on its side an arrow stays in the middle.
        XCTAssertEqual(all[toUp]!.points.last!.y, -100)
    }

    func testAStraightArrowKeepsTheMiddleAndALoneEndSlidesToMeetItsLine() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0)), b = board.add(.diamond, centre: CGPoint(x: 300, y: 0))
        let c = board.add(.box, centre: CGPoint(x: 300, y: 200))
        // One of the two runs dead straight into the tip of a diamond: it keeps the middle, the other stands 14 below.
        let straight = board.link(from: a, to: b)!, bent = board.link(from: a, to: c)!
        var all = board.arrows()
        XCTAssertEqual(all[straight]!.points, [CGPoint(x: 75, y: 0), CGPoint(x: 220, y: 0)])
        XCTAssertEqual(all[bent]!.points[0], CGPoint(x: 75, y: 14))
        // Two straight arrows out of one side share it (7 up, 7 down); the box at the other end of
        // the upper one lets its end slide 7 up, so the line is straight and not a small step.
        var row = Board()
        let r1 = row.add(.box, centre: CGPoint(x: 0, y: 0)), r2 = row.add(.box, centre: CGPoint(x: 300, y: 0))
        let r3 = row.add(.box, centre: CGPoint(x: 600, y: 0))
        let near = row.link(from: r1, to: r2)!, far = row.link(from: r1, to: r3)!
        all = row.arrows()
        XCTAssertEqual(all[near]!.points, [CGPoint(x: 75, y: -7), CGPoint(x: 225, y: -7)])
        XCTAssertEqual(all[far]!.points.first, CGPoint(x: 75, y: 7))
        XCTAssertTrue(all[far]!.detour)                                     // round the box in the middle
    }

    func testThereAndBackAreTwoLinesSideBySide() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0)), b = board.add(.box, centre: CGPoint(x: 300, y: 80))
        let there = board.link(from: a, to: b, text: "asks")!
        let back = board.link(from: b, to: a, text: "answers")!
        XCTAssertEqual(board.links.count, 2)
        XCTAssertEqual(board.links.map(\.text), ["asks", "answers"])
        let all = board.arrows()
        let one = all[there]!.points, two = Array(all[back]!.points.reversed())
        XCTAssertEqual(one.count, 4)
        XCTAssertEqual(two.count, 4)
        // Each corner of the second line lies 14 down and 14 before the first: side by side all the way.
        XCTAssertEqual(one[0].y, -7); XCTAssertEqual(two[0].y, 7)
        XCTAssertEqual(one[1].x - two[1].x, 14, accuracy: 0.001)
        XCTAssertEqual(two[3].y - one[3].y, 14, accuracy: 0.001)
        for i in 1..<4 { for j in 1..<4 {
            // No piece of one line lies on a piece of the other.
            let p = CGPoint(x: (one[i - 1].x + one[i].x) / 2, y: (one[i - 1].y + one[i].y) / 2)
            XCTAssertGreaterThan(Route.distance(from: p, to: [two[j - 1], two[j]]), 6)
        } }
    }

    func testAnEndOnADiamondOrAnOvalLiesOnItsOutline() {
        let r = CGRect(x: 0, y: 0, width: 160, height: 104)
        XCTAssertEqual(Route.anchor(on: r, kind: .diamond, side: .right), CGPoint(x: 160, y: 52))
        // 13 off the middle of a 104-high diamond: a quarter of the way to the tip, so 20 in.
        XCTAssertEqual(Route.anchor(on: r, kind: .diamond, side: .right, offset: 13), CGPoint(x: 140, y: 65))
        XCTAssertEqual(Route.anchor(on: r, kind: .diamond, side: .up, offset: -20), CGPoint(x: 60, y: 13))
        let oval = Route.anchor(on: r, kind: .oval, side: .left, offset: 26)
        let dx = (Double(oval.x) - 80) / 80, dy = (Double(oval.y) - 52) / 52
        XCTAssertEqual(dx * dx + dy * dy, 1, accuracy: 0.0001)
        // A box keeps its straight side; a round box gives way at its round ends.
        XCTAssertEqual(Route.anchor(on: r, kind: .box, side: .down, offset: 7), CGPoint(x: 87, y: 104))
        XCTAssertLessThan(Route.anchor(on: r, kind: .round, side: .right, offset: 30).x, 160)
    }

    // MARK: Round a shape in the way

    func testCrossesMeansThroughTheInside() {
        let r = box(0, 0)
        XCTAssertTrue(Route.crosses(CGPoint(x: -10, y: 25), CGPoint(x: 110, y: 25), r))
        XCTAssertTrue(Route.crosses(CGPoint(x: -10, y: -10), CGPoint(x: 60, y: 60), r))
        XCTAssertFalse(Route.crosses(CGPoint(x: -10, y: 0), CGPoint(x: 110, y: 0), r))      // along the edge
        XCTAssertFalse(Route.crosses(CGPoint(x: -10, y: 60), CGPoint(x: 110, y: 60), r))    // past it
        XCTAssertFalse(Route.crosses(CGPoint(x: -40, y: 25), CGPoint(x: 0, y: 25), r))      // ends on the edge
        XCTAssertFalse(Route.crosses(CGPoint(x: -20, y: 20), CGPoint(x: 20, y: -20), r))    // through the corner only
    }

    func testABlockedArrowGoesRoundTheShape() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0)), b = board.add(.box, centre: CGPoint(x: 600, y: 0))
        let wall = board.add(.box, centre: CGPoint(x: 300, y: 0))
        let id = board.link(from: a, to: b)!
        let arrow = board.arrow(id)!
        XCTAssertTrue(arrow.detour)
        let block = board.item(wall)!.frame
        XCTAssertFalse(crossesAny(arrow.points, block.insetBy(dx: -2, dy: -2)))
        XCTAssertFalse(crossesAny(arrow.outline, block))
        // It still leaves and arrives at the sides it had, and passes 12 points above the shape.
        XCTAssertEqual(arrow.points.first, CGPoint(x: 75, y: 0))
        XCTAssertEqual(arrow.points.last, CGPoint(x: 525, y: 0))
        XCTAssertEqual(arrow.points.map(\.y).min(), block.minY - 12)
        // Take the shape away and the line is straight again.
        board.remove([wall])
        XCTAssertEqual(board.arrow(id)!.points, [CGPoint(x: 75, y: 0), CGPoint(x: 525, y: 0)])
        // Free text is passed over: the owner may have put it on the line as a label.
        board.add(.text, centre: CGPoint(x: 300, y: 0), text: "label")
        XCTAssertFalse(board.arrow(id)!.detour)
    }

    func testStraightAndCurvedLinesPassTheCornerOfTheShape() {
        let a = Route.End(rect: box(0, 0), side: .right), b = Route.End(rect: box(500, 0), side: .left)
        let wall = box(250, -20, 60, 60)
        // A small shape well off the middle of the line: one corner is enough.
        let nick = Route.arrow(from: a, to: b, style: .straight, obstacles: [box(280, 20, 40, 100)])
        XCTAssertEqual(nick.points, [CGPoint(x: 100, y: 25), CGPoint(x: 268, y: 8), CGPoint(x: 500, y: 25)])
        for style in [LinkStyle.straight, .curve] {
            let arrow = Route.arrow(from: a, to: b, style: style, obstacles: [wall])
            XCTAssertTrue(arrow.detour)
            // Along the nearer side of the shape, 12 off: past one corner the line would graze the other.
            XCTAssertEqual(arrow.points, [CGPoint(x: 100, y: 25), CGPoint(x: 238, y: 52), CGPoint(x: 322, y: 52), CGPoint(x: 500, y: 25)])
            XCTAssertFalse(crossesAny(arrow.outline, wall), "\(style)")
        }
    }

    func testWhenNoWayRoundIsFoundTheOldLineIsKept() {
        // The second shape stands inside a ring of four others: nothing gets in without touching one.
        let a = Route.End(rect: box(0, 0), side: .right), b = Route.End(rect: box(400, 0), side: .left)
        let ring = [box(340, -70, 220, 60), box(340, 60, 220, 60), box(330, -70, 60, 190), box(510, -70, 60, 190)]
        let arrow = Route.arrow(from: a, to: b, style: .elbow, obstacles: ring)
        XCTAssertFalse(arrow.detour)
        XCTAssertEqual(arrow.points, Route.path(from: a.rect, to: b.rect, style: .elbow).points)
    }

    func testThreeHundredShapesAreRoutedInAMoment() {
        var board = Board()
        var last: UUID?
        for n in 0..<300 {
            let id = board.add(.box, centre: CGPoint(x: Double(n % 20) * 220, y: Double(n / 20) * 130))
            if let last { board.link(from: last, to: id) }
            // Every tenth arrow runs right across the board, through many shapes.
            if n % 10 == 9, let first = board.items.first { board.link(from: id, to: first.id) }
            last = id
        }
        let began = Date()
        let all = board.arrows()
        XCTAssertEqual(all.count, board.links.count)
        XCTAssertLessThan(Date().timeIntervalSince(began), 1.5)
    }

    // MARK: A side the owner chose

    func testAChosenSideIsUsedAndStored() throws {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0)), b = board.add(.box, centre: CGPoint(x: 400, y: 0))
        let id = board.link(from: a, to: b)!
        XCTAssertEqual(board.arrow(id)!.leaves, .right)
        // Let go just above the first shape: the end moves to its top side, and that is kept.
        XCTAssertTrue(board.moveEnd(of: id, start: true, to: CGPoint(x: 0, y: -40)))
        XCTAssertEqual(board.links[0].fromSide, .up)
        XCTAssertNil(board.links[0].toSide)
        let arrow = board.arrow(id)!
        XCTAssertEqual(arrow.leaves, .up)
        XCTAssertEqual(arrow.arrives, .left)
        XCTAssertEqual(arrow.points.first, CGPoint(x: 0, y: -28))
        XCTAssertFalse(crossesAny(Array(arrow.points.dropFirst()), board.item(a)!.frame.insetBy(dx: 1, dy: 1)))
        // It survives the file.
        let copy = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board))
        XCTAssertEqual(copy.links[0].fromSide, .up)
        // Back on the side the app would find anyway: nothing is stored any more.
        XCTAssertTrue(board.moveEnd(of: id, start: true, to: CGPoint(x: 70, y: 0)))
        XCTAssertNil(board.links[0].fromSide)
    }

    func testAnEndMovesOntoAnotherShapeButNeverOntoTheOtherEnd() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0)), b = board.add(.box, centre: CGPoint(x: 400, y: 0))
        let c = board.add(.box, centre: CGPoint(x: 400, y: 300))
        let frame = board.add(.frame, centre: CGPoint(x: 0, y: 900))
        let id = board.link(from: a, to: b)!
        board.links[0].toSide = .up
        XCTAssertEqual(board.endTarget(of: id, start: false, at: CGPoint(x: 400, y: 300)), c)
        XCTAssertTrue(board.moveEnd(of: id, start: false, to: CGPoint(x: 400, y: 300)))
        XCTAssertEqual(board.links[0].to, c)
        XCTAssertNil(board.links[0].toSide)                                                  // found by the app there
        XCTAssertFalse(board.moveEnd(of: id, start: false, to: CGPoint(x: 0, y: 0)))         // its own start
        XCTAssertFalse(board.moveEnd(of: id, start: false, to: CGPoint(x: 900, y: 900)))     // empty board
        XCTAssertFalse(board.moveEnd(of: id, start: false, to: board.item(frame)!.frame.origin))
        XCTAssertNil(board.endTarget(of: id, start: false, at: CGPoint(x: 900, y: 900)))
        let second = board.link(from: a, to: b)!
        XCTAssertFalse(board.moveEnd(of: second, start: false, to: CGPoint(x: 400, y: 300))) // a→c is there already
        XCTAssertEqual(board.links.first { $0.id == second }!.to, b)
    }

    func testNearestSideCutsTheBoxByItsDiagonals() {
        let r = box(0, 0, 200, 100)
        XCTAssertEqual(Route.nearestSide(of: r, to: CGPoint(x: 190, y: 50)), .right)
        XCTAssertEqual(Route.nearestSide(of: r, to: CGPoint(x: 100, y: -30)), .up)
        XCTAssertEqual(Route.nearestSide(of: r, to: CGPoint(x: 120, y: 140)), .down)
        XCTAssertEqual(Route.nearestSide(of: r, to: CGPoint(x: -5, y: 60)), .left)
    }

    // MARK: Ends and dashes

    func testEndsAndDashesAreStoredBesideTheHead() throws {
        var link = Link(from: UUID(), to: UUID())
        XCTAssertEqual(link.ends, .oneWay)
        XCTAssertFalse(link.isDashed)
        link.ends = .bothWays
        XCTAssertTrue(link.head); XCTAssertEqual(link.tail, true)
        link.ends = .none
        XCTAssertFalse(link.head); XCTAssertNil(link.tail)
        link.ends = .bothWays
        link.isDashed = true
        link.toSide = .down
        let data = try JSONEncoder().encode(link)
        let back = try JSONDecoder().decode(Link.self, from: data)
        XCTAssertEqual(back, link)
        XCTAssertEqual(back.ends, .bothWays)
        XCTAssertTrue(back.isDashed)
        // A plain arrow writes none of the new fields, and a file of 0.1 reads as one way, not dashed.
        let plain = try JSONEncoder().encode(Link(from: UUID(), to: UUID()))
        let words = String(decoding: plain, as: UTF8.self)
        for key in ["fromSide", "toSide", "tail", "dashed"] { XCTAssertFalse(words.contains(key), key) }
        let old = try JSONDecoder().decode(Link.self, from: plain)
        XCTAssertEqual(old.ends, .oneWay)
        XCTAssertFalse(old.isDashed)
        XCTAssertNil(old.fromSide)
        // A side word this version does not know is read as "found by the app".
        let odd = #"{"id":"\#(UUID().uuidString)","from":"\#(UUID().uuidString)","to":"\#(UUID().uuidString)","fromSide":"north","tail":"yes"}"#
        let read = try JSONDecoder().decode(Link.self, from: Data(odd.utf8))
        XCTAssertNil(read.fromSide)
        XCTAssertNil(read.tail)
    }

    func testAHeadPointsAlongTheLine() {
        let a = Route.End(rect: box(0, 0), side: .right), b = Route.End(rect: box(300, 200), side: .left)
        let elbow = Route.arrow(from: a, to: b, style: .elbow)
        XCTAssertEqual(elbow.endHeading, CGVector(dx: 1, dy: 0))
        XCTAssertEqual(elbow.startHeading, CGVector(dx: -1, dy: 0))
        XCTAssertEqual(Route.head(tip: CGPoint(x: 300, y: 225), heading: elbow.endHeading),
                       [CGPoint(x: 291, y: 230.5), CGPoint(x: 300, y: 225), CGPoint(x: 291, y: 219.5)])
        // A straight line's head follows the slant, at both ends.
        let straight = Route.arrow(from: a, to: b, style: .straight)
        XCTAssertEqual(straight.endHeading.dx, 200 / (200 * 2.0.squareRoot()), accuracy: 0.0001)
        XCTAssertEqual(straight.endHeading.dy, straight.endHeading.dx, accuracy: 0.0001)
        XCTAssertEqual(straight.startHeading.dx, -straight.endHeading.dx, accuracy: 0.0001)
        // A curve arrives level, as it is drawn.
        let curve = Route.arrow(from: a, to: b, style: .curve)
        XCTAssertEqual(curve.endHeading, CGVector(dx: 1, dy: 0))
        XCTAssertEqual(curve.pieces, [.move(CGPoint(x: 100, y: 25)),
                                      .curve(to: CGPoint(x: 300, y: 225), control1: CGPoint(x: 200, y: 25), control2: CGPoint(x: 200, y: 225))])
    }

    // MARK: Words beside the line

    func testWordsSitBesideTheLineNearItsStart() {
        let a = box(0, 0)
        // A level line: above it, 12 along.
        let level = Route.arrow(from: Route.End(rect: a, side: .right), to: Route.End(rect: box(200, 0), side: .left), style: .elbow)
        XCTAssertEqual(level.words, Route.Words(at: CGPoint(x: 112, y: 21), leading: true, above: true))
        XCTAssertGreaterThan(Route.distance(from: level.words.at, to: level.outline), 3)
        // To the left: the words run leftwards from the start.
        let left = Route.arrow(from: Route.End(rect: a, side: .left), to: Route.End(rect: box(-300, 0), side: .right), style: .elbow)
        XCTAssertEqual(left.words, Route.Words(at: CGPoint(x: -12, y: 21), leading: false, above: true))
        // An upright line: to its right, hanging down from 10 below the start.
        let down = Route.arrow(from: Route.End(rect: a, side: .down), to: Route.End(rect: box(0, 150), side: .up), style: .elbow)
        XCTAssertEqual(down.words, Route.Words(at: CGPoint(x: 58, y: 60), leading: true, above: false))
        // A level line that then climbs: below it, out of the way of the climb.
        let climbs = Route.arrow(from: Route.End(rect: a, side: .right), to: Route.End(rect: box(200, -120), side: .left), style: .elbow)
        XCTAssertFalse(climbs.words.above)
        // The lower of two arrows on one side: below its line, away from the upper one.
        let lower = Route.arrow(from: Route.End(rect: a, side: .right, offset: 7), to: Route.End(rect: box(200, 0), side: .left, offset: 7), style: .elbow)
        XCTAssertEqual(lower.words, Route.Words(at: CGPoint(x: 112, y: 36), leading: true, above: false))
    }

    func testWordsOfASlantedLineStandOnTheSideItMovesAwayFrom() {
        // A straight line that leaves a left side and drops steeply: the words stand out to the
        // left and above — not on the shape, and not where the line goes.
        let b = Route.End(rect: box(-300, 300), side: .right)
        let straight = Route.arrow(from: Route.End(rect: box(0, 0), side: .left), to: b, style: .straight)
        XCTAssertEqual(straight.words, Route.Words(at: CGPoint(x: -12, y: 21), leading: false, above: true))
        // The lower of two on that side: above its start runs the neighbour, so the words stand 28 further along.
        let shared = Route.arrow(from: Route.End(rect: box(0, 0), side: .left, offset: 14), to: b, style: .straight)
        XCTAssertEqual(shared.words.at.x, -12 - 28 * 200 / hypot(200, 286), accuracy: 0.001)
        XCTAssertEqual(shared.words.at.y, 35 + 28 * 286 / hypot(200, 286), accuracy: 0.001)
        XCTAssertTrue(shared.words.above)
        // A curve that climbs to the right: the words hang below its start.
        let curve = Route.arrow(from: Route.End(rect: box(0, 0), side: .right), to: Route.End(rect: box(300, -200), side: .left), style: .curve)
        XCTAssertEqual(curve.words, Route.Words(at: CGPoint(x: 112, y: 29), leading: true, above: false))
    }

    func testWordsLeaveAShortFirstPieceThatTurnsIntoThem() {
        // Out 16, down 40, along 300: the words would stand below the first piece, where the line turns to.
        let line = [CGPoint(x: 0, y: 7), CGPoint(x: 16, y: 7), CGPoint(x: 16, y: 47), CGPoint(x: 316, y: 47), CGPoint(x: 316, y: 7), CGPoint(x: 332, y: 7)]
        XCTAssertEqual(Route.words(along: line, leaves: .right, offset: 7, elbow: true), Route.Words(at: CGPoint(x: 28, y: 51), leading: true, above: false))
        // The same piece with the words above it (the upper arrow of two): they stay at the start.
        XCTAssertEqual(Route.words(along: line, leaves: .right, offset: -7, elbow: true), Route.Words(at: CGPoint(x: 12, y: 3), leading: true, above: true))
    }

    // MARK: Tab makes the next shape

    func testTheFlowRunsTheWayItsArrowArrives() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0))
        XCTAssertEqual(board.flowDirection(at: a), .right)                 // nothing arrives: to the right
        let below = board.addNext(from: a, direction: .down)!
        XCTAssertEqual(board.flowDirection(at: below), .down)
        let left = board.addNext(from: a, direction: .left)!
        XCTAssertEqual(board.flowDirection(at: left), .left)
        // The oldest arriving arrow decides, not one drawn back later.
        board.link(from: left, to: below)
        XCTAssertEqual(board.flowDirection(at: below), .down)
    }

    func testAfterADiamondComesABoxWithYesThenNo() {
        var board = Board()
        let start = board.add(.round, centre: CGPoint(x: 0, y: 0), text: "Start", colour: "blue")
        // After a round box (a start): a plain Box, middle on middle, 70 away, no word.
        let step = made(&board, from: start, .right)
        XCTAssertEqual(step.kind, .box)
        XCTAssertEqual(step.colour, "")
        XCTAssertEqual(CGSize(width: step.w, height: step.h), ItemKind.box.defaultSize)
        XCTAssertEqual(step.x, 75 + 70, accuracy: 0.001)
        XCTAssertEqual(step.centre.y, 0, accuracy: 0.001)
        XCTAssertEqual(board.links[0].text, "")

        let ask = board.add(.diamond, centre: CGPoint(x: 600, y: 0), text: "Ready?")
        board.link(from: step.id, to: ask)
        // The flow runs to the right: the first answer goes on to the right and says Yes, 100 away.
        XCTAssertEqual(board.flowDirection(at: ask), .right)
        let yes = made(&board, from: ask, board.flowDirection(at: ask))
        XCTAssertEqual(yes.kind, .box)
        XCTAssertEqual(yes.x, 680 + 100, accuracy: 0.001)
        XCTAssertEqual(yes.centre.y, 0, accuracy: 0.001)
        XCTAssertEqual(board.links.last!.text, "Yes")
        // The right side is taken now: the second answer goes down and says No.
        XCTAssertEqual(board.flowDirection(at: ask), .down)
        let no = made(&board, from: ask, .down)
        XCTAssertEqual(no.kind, .box)
        XCTAssertEqual(no.y, 52 + 100, accuracy: 0.001)
        XCTAssertEqual(no.centre.x, 600, accuracy: 0.001)
        XCTAssertEqual(board.links.last!.text, "No")
        // The third and later arrows have no word and the plain 70.
        let third = made(&board, from: ask, .up)
        XCTAssertEqual(board.links.last!.text, "")
        XCTAssertEqual(third.y + third.h, -52 - 70, accuracy: 0.001)
        // An arrow drawn by hand out of a diamond gets its word the same way; words given are kept.
        let other = board.add(.diamond, centre: CGPoint(x: 0, y: 600))
        let l1 = board.link(from: other, to: start)!, l2 = board.link(from: other, to: step.id, text: "Maybe")!
        XCTAssertEqual(board.links.first { $0.id == l1 }!.text, "Yes")
        XCTAssertEqual(board.links.first { $0.id == l2 }!.text, "Maybe")
        XCTAssertEqual(ItemKind.oval.nextInFlow, .oval)
        XCTAssertEqual(ItemKind.note.nextInFlow, .note)
    }
}
