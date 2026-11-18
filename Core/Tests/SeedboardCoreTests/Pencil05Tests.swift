import XCTest
@testable import SeedboardCore

/// Tidy shapes and writing straight onto a shape (0.5, pick 30): the rules of InkShape.swift as data.
/// The lines are made here as a hand would draw them: dense points, a wobble, rounded corners, a
/// little turned, not quite closed or a little way over.
final class Pencil05Tests: XCTestCase {
    // MARK: Lines as a hand draws them

    /// Points every 3 or so along the straight pieces between the corners.
    private func walk(_ corners: [CGPoint], step: Double = 3) -> [CGPoint] {
        guard var here = corners.first else { return [] }
        var out = [here]
        for next in corners.dropFirst() {
            let way = Double(hypot(next.x - here.x, next.y - here.y))
            let parts = max(1, Int((way / step).rounded(.up)))
            for k in 1...parts {
                let t = CGFloat(Double(k) / Double(parts))
                out.append(CGPoint(x: here.x + (next.x - here.x) * t, y: here.y + (next.y - here.y) * t))
            }
            here = next
        }
        return out
    }

    /// A rectangle drawn round once from its top left corner, closed.
    private func rectangle(_ box: CGRect) -> [CGPoint] {
        walk([CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY),
              CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.minX, y: box.minY)])
    }

    private func diamond(_ box: CGRect) -> [CGPoint] {
        walk([CGPoint(x: box.midX, y: box.minY), CGPoint(x: box.maxX, y: box.midY), CGPoint(x: box.midX, y: box.maxY),
              CGPoint(x: box.minX, y: box.midY), CGPoint(x: box.midX, y: box.minY)])
    }

    /// An oval drawn from `from` (a share of the way round) for `round` times round.
    private func oval(_ box: CGRect, from: Double = 0, round: Double = 1, steps: Int = 120) -> [CGPoint] {
        (0...Int(Double(steps) * round)).map { i in
            let a = (from + Double(i) / Double(steps)) * 2 * .pi
            return CGPoint(x: Double(box.midX) + Double(box.width) / 2 * cos(a), y: Double(box.midY) + Double(box.height) / 2 * sin(a))
        }
    }

    /// A rectangle with its corners rounded, as a quick hand leaves them.
    private func softRectangle(_ box: CGRect, corner r: Double) -> [CGPoint] {
        func arc(_ cx: Double, _ cy: Double, _ start: Double) -> [CGPoint] {
            (0...8).map { i in
                let a = (start + Double(i) / 8 * 90) * .pi / 180
                return CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
            }
        }
        let x0 = Double(box.minX), x1 = Double(box.maxX), y0 = Double(box.minY), y1 = Double(box.maxY)
        var corners: [CGPoint] = [CGPoint(x: x0 + r, y: y0)]
        corners += arc(x1 - r, y0 + r, -90)
        corners += arc(x1 - r, y1 - r, 0)
        corners += arc(x0 + r, y1 - r, 90)
        corners += arc(x0 + r, y0 + r, 180)
        return walk(corners)
    }

    /// The same line with an unsteady hand: every point pushed up to about `by` off, smoothly, always the same way.
    private func wobbly(_ points: [CGPoint], by amount: Double) -> [CGPoint] {
        points.enumerated().map { i, p in
            let n = Double(i)
            let dx = sin(n * 0.37 + 1.3) * 0.6 + sin(n * 0.11) * 0.4
            let dy = cos(n * 0.29 + 0.4) * 0.6 + sin(n * 0.07 + 2) * 0.4
            return CGPoint(x: Double(p.x) + dx * amount, y: Double(p.y) + dy * amount)
        }
    }

    /// The same line turned by so many degrees round its middle.
    private func turned(_ points: [CGPoint], by degrees: Double) -> [CGPoint] {
        guard let box = Ink.bounds(of: points) else { return points }
        let a = degrees * .pi / 180
        return points.map { p in
            let x = Double(p.x - box.midX), y = Double(p.y - box.midY)
            return CGPoint(x: Double(box.midX) + x * cos(a) - y * sin(a), y: Double(box.midY) + x * sin(a) + y * cos(a))
        }
    }

    /// The line without its last part (not quite closed).
    private func short(_ points: [CGPoint], by share: Double) -> [CGPoint] {
        Array(points.prefix(Int(Double(points.count) * (1 - share))))
    }

    /// The line going on over its own beginning for a part of the way.
    private func over(_ points: [CGPoint], by share: Double) -> [CGPoint] {
        points + points.dropFirst().prefix(Int(Double(points.count) * share))
    }

    private func zigzag(_ box: CGRect, rows: Int) -> [CGPoint] {
        var corners: [CGPoint] = []
        for row in 0...rows {
            let y = Double(box.minY) + Double(box.height) * Double(row) / Double(rows)
            corners.append(CGPoint(x: row % 2 == 0 ? box.minX : box.maxX, y: y))
        }
        return walk(corners)
    }

    private func eight(_ box: CGRect) -> [CGPoint] {
        (0...160).map { i in
            let a = Double(i) / 160 * 2 * .pi
            return CGPoint(x: Double(box.midX) + Double(box.width) / 2 * sin(a), y: Double(box.midY) + Double(box.height) / 2 * sin(2 * a))
        }
    }

    private func spiral(_ box: CGRect) -> [CGPoint] {
        (0...240).map { i in
            let a = Double(i) / 120 * 2 * .pi
            let r = 1 - Double(i) / 300
            return CGPoint(x: Double(box.midX) + Double(box.width) / 2 * r * cos(a), y: Double(box.midY) + Double(box.height) / 2 * r * sin(a))
        }
    }

    private func closedLine(_ pairs: [(Double, Double)]) -> [CGPoint] {
        walk((pairs + [pairs[0]]).map { CGPoint(x: $0.0, y: $0.1) })
    }

    /// Where every loop of these tests is drawn: 160 wide, 90 high.
    private let place = CGRect(x: 200, y: 120, width: 160, height: 90)

    private func kind(_ line: [CGPoint]) -> ItemKind? { InkShape.shape(of: line)?.kind }

    /// The found shape lies where the loop was drawn, give or take `slack` on every edge.
    private func assertPlace(_ line: [CGPoint], _ kind: ItemKind, slack: Double, _ name: String, file: StaticString = #filePath, line at: UInt = #line) {
        guard let found = InkShape.shape(of: line) else { return XCTFail("\(name): no shape", file: file, line: at) }
        XCTAssertEqual(found.kind, kind, name, file: file, line: at)
        XCTAssertEqual(Double(found.frame.minX), Double(place.minX), accuracy: slack, name, file: file, line: at)
        XCTAssertEqual(Double(found.frame.minY), Double(place.minY), accuracy: slack, name, file: file, line: at)
        XCTAssertEqual(Double(found.frame.maxX), Double(place.maxX), accuracy: slack, name, file: file, line: at)
        XCTAssertEqual(Double(found.frame.maxY), Double(place.maxY), accuracy: slack, name, file: file, line: at)
    }

    // MARK: A loop that fits a shape

    func testADrawnRectangleOvalAndDiamondBecomeThatShapeOfThatSizeAndPlace() {
        for (line, kind) in [(rectangle(place), ItemKind.box), (oval(place), .oval), (diamond(place), .diamond)] {
            let found = InkShape.shape(of: line)
            XCTAssertEqual(found?.kind, kind)
            XCTAssertEqual(found?.frame, place, "\(kind)")
            // Clean, it lies on its own outline and far from the other two.
            XCTAssertEqual(InkShape.farness(of: line, from: kind), 0, accuracy: 0.002)
            for other in InkShape.kinds where other != kind {
                XCTAssertGreaterThan(InkShape.farness(of: line, from: other), InkShape.fit, "\(kind) against \(other)")
            }
        }
        // A square standing on its corner is a diamond; a circle is an oval.
        XCTAssertEqual(kind(turned(rectangle(CGRect(x: 0, y: 0, width: 100, height: 100)), by: 45)), .diamond)
        XCTAssertEqual(kind(oval(CGRect(x: 0, y: 0, width: 100, height: 100))), .oval)
        // The line as it is kept (thinned to its corners, to a tenth of a point) is found as well.
        let kept = Ink.thin(rectangle(place), tolerance: 0.4).points
        XCTAssertEqual(kept.count, 5)
        XCTAssertEqual(InkShape.shape(of: kept)?.kind, .box)
        XCTAssertEqual(InkShape.shape(of: kept)?.frame, place)
        XCTAssertEqual(InkShape.shape(of: Ink.thin(oval(place), tolerance: 0.4).points)?.kind, .oval)
    }

    func testAWobblyLeaningRoundCorneredLoopStillBecomesItsShape() {
        // An unsteady hand: every point up to 3 or 5 points off. The shape takes the size that was meant.
        assertPlace(wobbly(rectangle(place), by: 3), .box, slack: 3, "rectangle, wobble 3")
        assertPlace(wobbly(rectangle(place), by: 5), .box, slack: 5, "rectangle, wobble 5")
        assertPlace(wobbly(oval(place), by: 3), .oval, slack: 3, "oval, wobble 3")
        assertPlace(wobbly(oval(place), by: 5), .oval, slack: 5, "oval, wobble 5")
        assertPlace(wobbly(diamond(place), by: 3), .diamond, slack: 3, "diamond, wobble 3")
        assertPlace(wobbly(diamond(place), by: 5), .diamond, slack: 5, "diamond, wobble 5")
        // Corners a quick hand leaves round.
        assertPlace(softRectangle(place, corner: 12), .box, slack: 1, "round corners 12")
        assertPlace(softRectangle(place, corner: 20), .box, slack: 1, "round corners 20")
        // Leaning by up to 10 degrees: the shape stands straight, the size that was drawn.
        assertPlace(turned(rectangle(place), by: 5), .box, slack: 2, "rectangle leaning 5")
        assertPlace(turned(rectangle(place), by: -10), .box, slack: 2, "rectangle leaning 10")
        assertPlace(turned(diamond(place), by: 6), .diamond, slack: 2, "diamond leaning 6")
        assertPlace(turned(oval(place), by: 8), .oval, slack: 2, "oval leaning 8")
        // All of it at once.
        assertPlace(turned(wobbly(softRectangle(place, corner: 12), by: 3), by: 3), .box, slack: 4, "soft, wobbly, leaning")
    }

    func testALoopNotQuiteClosedOrALittleWayOverIsStillALoop() {
        // The last twentieth missing; 8 % and 10 % over where it began.
        assertPlace(short(rectangle(place), by: 0.05), .box, slack: 1, "rectangle, not closed")
        assertPlace(over(rectangle(place), by: 0.08), .box, slack: 1, "rectangle, a little over")
        assertPlace(short(oval(place, from: 0.3), by: 0.05), .oval, slack: 1, "oval, not closed")
        assertPlace(oval(place, from: 0.6, round: 1.1), .oval, slack: 1, "oval, a little over")
        assertPlace(short(diamond(place), by: 0.05), .diamond, slack: 1, "diamond, not closed")
        XCTAssertTrue(InkShape.closed(short(rectangle(place), by: 0.05)))
        // The ends meet within a fifth of the diagonal (184 here: 36 points); three sides of four do not.
        let threeSides = walk([CGPoint(x: 200, y: 120), CGPoint(x: 360, y: 120), CGPoint(x: 360, y: 210), CGPoint(x: 200, y: 210)])
        XCTAssertFalse(InkShape.closed(threeSides))
        XCTAssertNil(InkShape.shape(of: threeSides))
        // Once round, whichever way it was drawn.
        XCTAssertEqual(InkShape.turns(oval(place)), 1, accuracy: 0.02)
        XCTAssertEqual(InkShape.turns(Array(oval(place).reversed())), 1, accuracy: 0.02)
        XCTAssertEqual(InkShape.shape(of: Array(rectangle(place).reversed()))?.kind, .box)
    }

    // MARK: What stays a sketch

    func testWhatIsNoShapeStaysASketch() {
        let no: [(String, [CGPoint])] = [
            ("a triangle", closedLine([(280, 120), (360, 210), (200, 210)])),
            ("a wobbly triangle", wobbly(closedLine([(280, 120), (360, 210), (200, 210)]), by: 3)),
            ("a triangle with a square corner", closedLine([(200, 120), (360, 210), (200, 210)])),
            ("a house", closedLine([(200, 160), (280, 120), (360, 160), (360, 210), (200, 210)])),
            ("a rectangle leaning 25 degrees", turned(rectangle(place), by: 25)),
            ("a scribble to and fro", zigzag(place, rows: 6)),
            ("a scribble to and fro that ends where it began", zigzag(place, rows: 6) + [place.origin]),
            ("an oval drawn twice round", oval(place, round: 2)),
            ("a spiral", spiral(place)),
            ("a figure of eight", eight(place)),
            ("a straight line", walk([CGPoint(x: 200, y: 120), CGPoint(x: 360, y: 210)])),
            ("a line there and back", walk([CGPoint(x: 200, y: 120), CGPoint(x: 360, y: 210), CGPoint(x: 200, y: 120)])),
            ("a corner", walk([CGPoint(x: 200, y: 120), CGPoint(x: 360, y: 120), CGPoint(x: 360, y: 210)])),
            ("a small loop, as in handwriting", oval(CGRect(x: 0, y: 0, width: 30, height: 24))),
            ("a loop too flat", rectangle(CGRect(x: 0, y: 0, width: 200, height: 20))),
            ("a dot", [CGPoint(x: 5, y: 5)]),
            ("nothing", []),
            ("a line that is not a number", [CGPoint(x: Double.nan, y: 0), CGPoint(x: 0, y: Double.infinity)]),
        ]
        for (name, line) in no { XCTAssertNil(InkShape.shape(of: line), name) }
        // The smallest loop that does become a shape is the smallest a shape can be made: 44 by 28.
        XCTAssertEqual(InkShape.shape(of: rectangle(CGRect(x: 0, y: 0, width: 44, height: 28)))?.kind, .box)
        XCTAssertNil(InkShape.shape(of: rectangle(CGRect(x: 0, y: 0, width: 43, height: 28))))
        XCTAssertNil(InkShape.shape(of: rectangle(CGRect(x: 0, y: 0, width: 44, height: 27))))
    }

    func testALoopRoundSomethingThatIsThereStaysASketch() {
        var board = Board()
        board.add(.box, centre: CGPoint(x: 280, y: 165))
        // A ring drawn round the box is a ring, not a lid over it.
        XCTAssertNil(board.inkTidy(of: oval(place.insetBy(dx: -40, dy: -40)), reach: 14))
        // Beside it there is room.
        XCTAssertEqual(board.inkTidy(of: oval(place.offsetBy(dx: 400, dy: 0)), reach: 14), .shape(.oval, place.offsetBy(dx: 400, dy: 0)))
        // A frame is no obstacle: shapes are drawn inside frames all the time.
        var framed = Board()
        let frame = framed.add(.frame, centre: CGPoint(x: 280, y: 165))
        XCTAssertTrue(framed.item(frame)!.frame.contains(place))
        XCTAssertEqual(framed.inkTidy(of: rectangle(place), reach: 14), .shape(.box, place))
        // A sketch in the way counts as something that is there.
        var sketched = Board()
        sketched.addStroke([CGPoint(x: 250, y: 150), CGPoint(x: 300, y: 170)])
        XCTAssertNil(sketched.inkTidy(of: rectangle(place), reach: 14))
    }

    // MARK: A line from one thing to another

    func testAnOpenLineFromOneThingToAnotherBecomesAnArrow() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 100, y: 100))        // 25…175 × 72…128
        let b = board.add(.diamond, centre: CGPoint(x: 500, y: 100))    // 420…580 × 48…152
        let frame = board.add(.frame, centre: CGPoint(x: 300, y: 500))  // 80…520 × 350…650
        let sketch = board.addStroke([CGPoint(x: 700, y: 100), CGPoint(x: 760, y: 100)])!
        func line(_ from: (Double, Double), _ to: (Double, Double)) -> [CGPoint] {
            walk([CGPoint(x: from.0, y: from.1), CGPoint(x: to.0, y: to.1)])
        }
        // From inside the one to inside the other; a wobble does not matter.
        XCTAssertEqual(board.inkTidy(of: line((150, 100), (450, 100)), reach: 14), .arrow(from: a, to: b))
        XCTAssertEqual(board.inkTidy(of: wobbly(line((150, 100), (450, 100)), by: 4), reach: 14), .arrow(from: a, to: b))
        // The way it was drawn is the way the arrow points.
        XCTAssertEqual(board.inkTidy(of: line((450, 100), (150, 100)), reach: 14), .arrow(from: b, to: a))
        // Beginning and ending just beside them counts: within 14, not 15.
        XCTAssertEqual(board.inkTidy(of: line((189, 100), (406, 100)), reach: 14), .arrow(from: a, to: b))
        XCTAssertNil(board.inkTidy(of: line((190, 100), (406, 100)), reach: 14))
        XCTAssertNil(board.inkTidy(of: line((189, 100), (405, 100)), reach: 14))
        // A line that bends is an arrow; one that wanders (longer than 2.5 times the straight way) is a sketch.
        let bent = walk([CGPoint(x: 150, y: 100), CGPoint(x: 300, y: 250), CGPoint(x: 450, y: 100)])
        XCTAssertEqual(board.inkTidy(of: bent, reach: 14), .arrow(from: a, to: b))
        let wandering = walk([CGPoint(x: 150, y: 100), CGPoint(x: 300, y: 520), CGPoint(x: 450, y: 100)])
        XCTAssertNil(board.inkTidy(of: wandering, reach: 14))
        // From a thing to nothing, from nothing to a thing, from a thing back to itself: sketches.
        XCTAssertNil(board.inkTidy(of: line((150, 100), (300, 100)), reach: 14))
        XCTAssertNil(board.inkTidy(of: line((300, 100), (450, 100)), reach: 14))
        XCTAssertNil(board.inkTidy(of: line((40, 100), (160, 100)), reach: 14))
        // A frame takes no arrows, and a sketch is not joined this way.
        XCTAssertNil(board.inkTidy(of: line((100, 120), (100, 400)), reach: 14))
        XCTAssertEqual(board.item(frame)?.kind, .frame)
        XCTAssertNil(board.inkTidy(of: line((560, 100), (700, 100)), reach: 14))
        XCTAssertEqual(board.item(sketch)?.kind, .drawing)
        // The arrow that is there already is not drawn twice; the other way round is a new one.
        board.link(from: a, to: b)
        XCTAssertNil(board.inkTidy(of: line((150, 100), (450, 100)), reach: 14))
        XCTAssertEqual(board.inkTidy(of: line((450, 100), (150, 100)), reach: 14), .arrow(from: b, to: a))
        // Of two things as near, the one on top is meant.
        let c = board.add(.note, centre: CGPoint(x: 500, y: 100))
        XCTAssertEqual(board.inkEnd(at: CGPoint(x: 500, y: 100), reach: 14), c)
        XCTAssertEqual(board.inkEnd(at: CGPoint(x: 500, y: 100), reach: 14, except: c), b)
        XCTAssertNil(board.inkEnd(at: CGPoint(x: 300, y: 250), reach: 14))
    }

    // MARK: The swap

    func testTheSketchIsSwappedForTheShapeAndTheStepBeforeStillHoldsTheRawLine() {
        var board = Board()
        let note = board.add(.note, centre: CGPoint(x: 0, y: 0))
        let sketch = board.addStroke(wobbly(rectangle(place), by: 3), colour: "blue", width: .thick)!
        // The board as Undo puts it back: the raw line, untouched.
        let before = board
        guard case .shape(let made)? = board.tidyInk(sketch, reach: 14) else { return XCTFail("no shape") }
        XCTAssertNil(board.item(sketch))
        XCTAssertEqual(board.items.count, 2)
        XCTAssertEqual(board.items.last?.id, made)                      // on top of everything
        let box = board.item(made)!
        XCTAssertEqual(box.kind, .box)
        XCTAssertEqual(box.colour, "blue")                              // the line's colour
        XCTAssertEqual(box.text, "")
        XCTAssertEqual(Double(box.frame.minX), 200, accuracy: 3)
        XCTAssertEqual(Double(box.frame.minY), 120, accuracy: 3)
        XCTAssertEqual(Double(box.frame.width), 160, accuracy: 6)
        XCTAssertEqual(Double(box.frame.height), 90, accuracy: 6)
        XCTAssertEqual(board.item(note), before.item(note))
        XCTAssertEqual(before.item(sketch)?.strokes?.count, 1)
        XCTAssertEqual(before.item(sketch)?.kind, .drawing)
        // Nothing new is stored: the board holds an ordinary box and reads back the same.
        let again = try! JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board))
        XCTAssertEqual(again.items, board.items)

        // Plain ink gives the shape its own colour.
        var plain = Board()
        let ring = plain.addStroke(oval(place))!
        guard case .shape(let round)? = plain.tidyInk(ring, reach: 14) else { return XCTFail("no oval") }
        XCTAssertEqual(plain.item(round)?.kind, .oval)
        XCTAssertEqual(plain.item(round)?.colour, "")
        XCTAssertEqual(plain.item(round)?.frame, place)

        // A line between two things: the sketch goes, the arrow is there.
        var flow = Board()
        let a = flow.add(.box, centre: CGPoint(x: 100, y: 100))
        let b = flow.add(.box, centre: CGPoint(x: 500, y: 100))
        let line = flow.addStroke(walk([CGPoint(x: 150, y: 100), CGPoint(x: 450, y: 100)]))!
        guard case .arrow(let link)? = flow.tidyInk(line, reach: 14) else { return XCTFail("no arrow") }
        XCTAssertNil(flow.item(line))
        XCTAssertEqual(flow.links.map(\.id), [link])
        XCTAssertEqual(flow.links.first?.from, a)
        XCTAssertEqual(flow.links.first?.to, b)
        XCTAssertEqual(flow.items.count, 2)
    }

    func testOnlyASketchOfOneLineIsSwappedAndWhatIsNoShapeIsLeftExactlyAsItWas() {
        // A sketch he is still drawing (a second line went into it) is never touched.
        var board = Board()
        let sketch = board.addStroke(rectangle(place))!
        board.addStroke([CGPoint(x: 220, y: 140), CGPoint(x: 240, y: 150)], to: sketch)
        var same = board
        XCTAssertNil(same.tidyInk(sketch, reach: 14))
        XCTAssertEqual(same, board)
        // A scribble stays the scribble it is.
        var scribbled = Board()
        let scribble = scribbled.addStroke(zigzag(place, rows: 6))!
        same = scribbled
        XCTAssertNil(same.tidyInk(scribble, reach: 14))
        XCTAssertEqual(same, scribbled)
        // Not a sketch at all, or not there.
        var other = Board()
        let box = other.add(.box, centre: .zero)
        same = other
        XCTAssertNil(same.tidyInk(box, reach: 14))
        XCTAssertNil(same.tidyInk(UUID(), reach: 14))
        XCTAssertEqual(same, other)
    }

    func testNothingIsTidiedOnABoardThatPlacesItsThingsItselfOrCannotBeChanged() {
        var timeline = Board()
        timeline.kind = Board.timelineKind
        XCTAssertNil(timeline.inkTidy(of: rectangle(place), reach: 14))
        var who = Board()
        who.kind = Board.sequenceKind
        XCTAssertNil(who.inkTidy(of: rectangle(place), reach: 14))
        var newer = Board()
        newer.format = Board.currentFormat + 1
        XCTAssertNil(newer.inkTidy(of: rectangle(place), reach: 14))
        XCTAssertEqual(Board().inkTidy(of: rectangle(place), reach: 14), .shape(.box, place))
    }

    // MARK: The tip rests

    func testTheTipHasRestedWhenItStoodStillForFourTenthsOfASecond() {
        XCTAssertEqual(InkShape.rest, 0.4)
        XCTAssertEqual(InkShape.restWay, 6)
        var rest = InkRest(at: CGPoint(x: 0, y: 0), time: 10)
        // Drawing on: every real move starts the wait again.
        rest.moved(to: CGPoint(x: 30, y: 0), time: 10.2)
        rest.moved(to: CGPoint(x: 60, y: 0), time: 10.4)
        XCTAssertFalse(rest.rested(until: 10.5))
        XCTAssertFalse(rest.rested(until: 10.79))
        XCTAssertTrue(rest.rested(until: 10.8))
        // A tremble of up to 6 points round where it stands is still resting …
        rest.moved(to: CGPoint(x: 64, y: 3), time: 10.7)
        rest.moved(to: CGPoint(x: 57, y: -4), time: 10.75)
        XCTAssertTrue(rest.rested(until: 10.8))
        // … more is a move.
        rest.moved(to: CGPoint(x: 67, y: 0), time: 10.75)
        XCTAssertFalse(rest.rested(until: 10.8))
        XCTAssertTrue(rest.rested(until: 11.15))
        // Lifted straight from the move: never rested.
        let quick = InkRest(at: .zero, time: 5)
        XCTAssertFalse(quick.rested(until: 5.1))
    }

    // MARK: Writing straight onto a shape

    func testWhatThePencilMayWriteStraightInto() {
        var board = Board()
        let box = board.add(.box, centre: CGPoint(x: 100, y: 100))
        let note = board.add(.note, centre: CGPoint(x: 400, y: 100))
        let text = board.add(.text, centre: CGPoint(x: 700, y: 100))
        let idea = board.add(.idea, centre: CGPoint(x: 100, y: 400))
        let frame = board.add(.frame, centre: CGPoint(x: 400, y: 600))
        let sketch = board.addStroke([CGPoint(x: 600, y: 400), CGPoint(x: 700, y: 430)])!
        var picture = Item(kind: .picture, x: 800, y: 400)
        picture.picture = "A.jpg"
        var door = Item(kind: .door, x: 800, y: 700)
        door.door = UUID()
        board.items += [picture, door]
        for id in [box, note, text, idea] { XCTAssertTrue(board.takesWriting(id), "\(board.item(id)!.kind)") }
        // No words of its own, a caption with its own button, a frame that would swallow every line drawn in it, another board's name.
        for id in [sketch, picture.id, frame, door.id] { XCTAssertFalse(board.takesWriting(id), "\(board.item(id)!.kind)") }
        XCTAssertFalse(board.takesWriting(UUID()))
        // Only what lies in the part of the board that is asked for, bottom to top.
        XCTAssertEqual(board.writable(in: CGRect(x: 0, y: 0, width: 500, height: 200)), [box, note])
        XCTAssertEqual(Set(board.writable(in: CGRect(x: -2000, y: -2000, width: 4000, height: 4000))), [box, note, text, idea])
        XCTAssertEqual(board.writable(in: CGRect(x: 2000, y: 2000, width: 10, height: 10)), [])
        // An idea folded away cannot be written into.
        let child = board.addChild(of: idea)!
        XCTAssertTrue(board.takesWriting(child))
        board.items[board.index(of: idea)!].folded = true
        XCTAssertFalse(board.takesWriting(child))
        // Never on a board that cannot be changed, a timeline or a "Who does what" board.
        var newer = board
        newer.format = Board.currentFormat + 1
        XCTAssertFalse(newer.takesWriting(box))
        var timeline = board
        timeline.kind = Board.timelineKind
        XCTAssertFalse(timeline.takesWriting(box))
        // The Pencil landed on a thing and the system says he writes: writing wins up to 10 points from where it landed.
        XCTAssertTrue(InkShape.writingWins(strayed: 0))
        XCTAssertTrue(InkShape.writingWins(strayed: 10))
        XCTAssertFalse(InkShape.writingWins(strayed: 10.5))
    }
}
