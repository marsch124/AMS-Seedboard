import XCTest
@testable import SeedboardCore

/// Drawing by hand (0.2, pick 2): the rules of Ink.swift as data.
final class InkTests: XCTestCase {
    private let boardID = "11111111-1111-1111-1111-111111111111"

    private func line(_ pairs: [(Double, Double)]) -> [CGPoint] { pairs.map { CGPoint(x: $0.0, y: $0.1) } }

    func testThinningKeepsTheCornersAndDropsWhatALineDoesNotNeed() {
        // A straight run of 101 points with a little wobble, then a corner, then another straight run.
        var raw: [CGPoint] = []
        for i in 0...100 { raw.append(CGPoint(x: Double(i), y: i % 2 == 0 ? 0.1 : -0.1)) }
        for i in 1...50 { raw.append(CGPoint(x: 100, y: Double(i))) }
        let thinned = Ink.thin(raw, tolerance: 0.4)
        XCTAssertEqual(thinned.points.count, 3)
        XCTAssertEqual(thinned.points.first, raw.first)
        XCTAssertEqual(thinned.points.last, raw.last)
        XCTAssertEqual(Double(thinned.points[1].x), 100, accuracy: 1.01)
        XCTAssertNil(thinned.pressure)
        // Every point left out lies within the tolerance of the kept line.
        for p in raw { XCTAssertLessThanOrEqual(Ink.distance(from: p, toLine: thinned.points), 0.4 + 1e-9) }
        // A straight line that swells in the middle keeps the swell.
        let flat = (0...40).map { CGPoint(x: Double($0), y: 0) }
        let force: [Double] = (0...40).map { i -> Double in
            let away: Double = abs(Double(i) - 20) / 20
            return 0.2 + 0.6 * (1 - away)
        }
        let swelling = Ink.thin(flat, pressure: force, tolerance: 0.4)
        XCTAssertEqual(swelling.points.count, 3)
        XCTAssertEqual(swelling.pressure, [0.2, 0.8, 0.2])
        // Zoomed in, a line is thinned more gently; never more coarsely than half a point.
        XCTAssertEqual(Ink.tolerance(scale: 1), 0.4, accuracy: 1e-9)
        XCTAssertEqual(Ink.tolerance(scale: 2), 0.2, accuracy: 1e-9)
        XCTAssertEqual(Ink.tolerance(scale: 0.2), 0.5, accuracy: 1e-9)
    }

    func testADrawingsBoxIsTheBoxOfItsStrokesAndGrowsWithThem() {
        var board = Board()
        let id = board.addStroke(line([(100, 200), (160.04, 230.06)]), colour: "blue", width: .thick)!
        var sketch = board.item(id)!
        XCTAssertEqual(sketch.kind, .drawing)
        XCTAssertEqual(sketch.frame, CGRect(x: 94, y: 194, width: 72, height: 42.1))
        // Measured from the corner, to a tenth.
        XCTAssertEqual(sketch.strokes?[0].points, [6, 6, 66, 36.1])
        XCTAssertEqual(sketch.strokes?[0].colour, "blue")
        XCTAssertEqual(sketch.strokes?[0].thickness, .thick)
        XCTAssertNil(sketch.strokes?[0].pressure)
        // A second stroke up and to the left: the box grows, the first stroke stays where it was on the board.
        XCTAssertEqual(board.addStroke(line([(80, 180), (90, 190)]), pressure: [0.304, 2], to: id), id)
        sketch = board.item(id)!
        XCTAssertEqual(board.items.count, 1)
        XCTAssertEqual(sketch.frame, CGRect(x: 74, y: 174, width: 92, height: 62.1))
        XCTAssertEqual(sketch.inkLines[0], line([(100, 200), (160, 230.1)]))
        XCTAssertEqual(sketch.strokes?[1].points, [6, 6, 16, 16])
        XCTAssertEqual(sketch.strokes?[1].pressure, [0.3, 1])
        // A press that went nowhere is one dot; nothing at all makes nothing.
        let dot = board.addStroke(line([(0, 0), (0.01, 0.02)]))!
        XCTAssertEqual(board.item(dot)?.strokes?[0].points, [6, 6])
        XCTAssertEqual(board.item(dot)?.frame.size, CGSize(width: 12, height: 12))
        XCTAssertNil(board.addStroke([]))
        XCTAssertNil(board.addStroke([CGPoint(x: Double.nan, y: 0)]))
        XCTAssertEqual(board.countLine, "2 sketches")
    }

    func testStrokesCloseInTimeAndPlaceJoinOneDrawing() {
        let sketch = CGRect(x: 0, y: 0, width: 100, height: 60)
        // Over it, or within 40 points of its box, and within 5 seconds: the same drawing.
        XCTAssertTrue(Ink.joins(CGRect(x: 20, y: 20, width: 10, height: 10), drawing: sketch, after: 1))
        XCTAssertTrue(Ink.joins(CGRect(x: 139, y: 0, width: 30, height: 10), drawing: sketch, after: 4.9))
        // Too far, or too late: a new drawing begins.
        XCTAssertFalse(Ink.joins(CGRect(x: 141, y: 0, width: 30, height: 10), drawing: sketch, after: 1))
        XCTAssertFalse(Ink.joins(CGRect(x: 20, y: 20, width: 10, height: 10), drawing: sketch, after: 5.1))
        XCTAssertEqual(Ink.gap(sketch, CGRect(x: 130, y: 100, width: 5, height: 5)), 50, accuracy: 1e-9)
        var board = Board()
        let first = board.addStroke(line([(0, 0), (100, 60)]))!
        let note = board.add(.note, centre: CGPoint(x: 400, y: 400))
        XCTAssertEqual(board.drawingToJoin(CGRect(x: 10, y: 10, width: 5, height: 5), last: first, after: 2), first)
        XCTAssertNil(board.drawingToJoin(CGRect(x: 10, y: 10, width: 5, height: 5), last: first, after: 9))
        XCTAssertNil(board.drawingToJoin(CGRect(x: 10, y: 10, width: 5, height: 5), last: nil, after: 0))
        // The last drawing was removed (or undone) in between, or is no drawing: a new one.
        XCTAssertNil(board.drawingToJoin(CGRect(x: 400, y: 400, width: 5, height: 5), last: note, after: 0))
        board.remove([first])
        XCTAssertNil(board.drawingToJoin(CGRect(x: 10, y: 10, width: 5, height: 5), last: first, after: 2))
    }

    func testResizingADrawingScalesItsStrokes() {
        var board = Board()
        let id = board.addStroke(line([(0, 0), (100, 50)]))!
        _ = board.addStroke(line([(50, 25), (100, 0)]), to: id)
        XCTAssertEqual(board.item(id)?.frame, CGRect(x: -6, y: -6, width: 112, height: 62))
        // Twice as wide, three times as high (the margin round the lines stays 6).
        board.resize(id, to: CGRect(x: -6, y: -6, width: 212, height: 162))
        let big = board.item(id)!
        XCTAssertEqual(big.frame, CGRect(x: -6, y: -6, width: 212, height: 162))
        XCTAssertEqual(big.inkLines[0], line([(0, 0), (200, 150)]))
        XCTAssertEqual(big.inkLines[1], line([(100, 75), (200, 0)]))
        // Never smaller than 4 points of drawing; "Same size" leaves a drawing alone.
        board.resize(id, to: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(board.item(id)?.frame, CGRect(x: 0, y: 0, width: 16, height: 16))
        // A flat line stays flat.
        let flat = board.addStroke(line([(0, 300), (80, 300)]))!
        board.resize(flat, to: CGRect(x: 0, y: 300, width: 172, height: 90))
        XCTAssertEqual(board.item(flat)?.frame, CGRect(x: 0, y: 300, width: 172, height: 12))
        XCTAssertEqual(board.item(flat)?.inkLines[0], line([(6, 306), (166, 306)]))
        let note = board.add(.note, centre: CGPoint(x: 600, y: 0))
        XCTAssertEqual(board.sizeable([id, flat, note]).map(\.id), [note])
    }

    func testADrawingIsCaughtNearItsLinesNotAnywhereInItsBox() {
        var board = Board()
        // A big L: down the left side, then along the bottom. The middle of its box is empty.
        let id = board.addStroke(line([(0, 0), (0, 200), (200, 200)]), width: .medium)!
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: 100)), id)
        XCTAssertEqual(board.hit(CGPoint(x: 3.5, y: 100)), id)          // 2 points past the line's edge
        XCTAssertNil(board.hit(CGPoint(x: 100, y: 100)))                // inside the box, on no line
        XCTAssertNil(board.hit(CGPoint(x: 9, y: 100)))
        // A mouse or the Pencil: 6 screen points round the line, at every zoom.
        XCTAssertEqual(board.hit(CGPoint(x: 7.5, y: 100), scale: 1, least: 0), id)
        XCTAssertNil(board.hit(CGPoint(x: 9, y: 100), scale: 1, least: 0))
        XCTAssertEqual(board.hit(CGPoint(x: 13, y: 100), scale: 0.5, least: 0), id)
        XCTAssertNil(board.hit(CGPoint(x: 7.5, y: 100), scale: 2, least: 0))
        // A finger: 22 screen points; still never the empty middle.
        XCTAssertEqual(board.hit(CGPoint(x: 23, y: 100), scale: 1), id)
        XCTAssertNil(board.hit(CGPoint(x: 100, y: 100), scale: 1))
        XCTAssertEqual(board.item(id)?.inkDistance(to: CGPoint(x: 12, y: 100)), 10)
        // A box under the middle of the drawing is reached through it.
        let box = board.add(.box, centre: CGPoint(x: 100, y: 100))
        XCTAssertEqual(board.hit(CGPoint(x: 100, y: 100), scale: 1), box)
        // A dragged choosing box takes it by its box, like a note.
        XCTAssertTrue(board.items(in: CGRect(x: 150, y: 20, width: 20, height: 20)).contains(id))
    }

    func testTheRubberTakesWholeStrokesAndAnEmptyDrawingDisappears() {
        var board = Board()
        let id = board.addStroke(line([(0, 0), (100, 0)]))!
        _ = board.addStroke(line([(0, 50), (100, 50)]), to: id)
        let other = board.addStroke(line([(300, 0), (300, 100)]))!
        let box = board.add(.box, centre: CGPoint(x: 50, y: 300))
        board.link(from: box, to: id)
        // Beside every line: nothing goes.
        XCTAssertFalse(board.rub(at: CGPoint(x: 50, y: 25), reach: 10))
        XCTAssertEqual(board.item(id)?.strokes?.count, 2)
        // On the lower line: the whole stroke goes, the box shrinks to what is left.
        XCTAssertTrue(board.rub(at: CGPoint(x: 90, y: 55), reach: 10))
        XCTAssertEqual(board.item(id)?.strokes?.count, 1)
        XCTAssertEqual(board.item(id)?.frame, CGRect(x: -6, y: -6, width: 112, height: 12))
        // The rubber's way crosses a line between two samples: the stroke goes too.
        XCTAssertEqual(board.strokes(near: CGPoint(x: 250, y: 50), reach: 10), [])
        XCTAssertEqual(board.strokes(near: CGPoint(x: 350, y: 50), from: CGPoint(x: 250, y: 50), reach: 10),
                       [InkMark(drawing: other, stroke: 0)])
        // The last stroke of a drawing: the drawing disappears, and the arrow joined to it.
        XCTAssertEqual(board.links.count, 1)
        XCTAssertTrue(board.rub(at: CGPoint(x: 10, y: 0), reach: 10))
        XCTAssertNil(board.item(id))
        XCTAssertTrue(board.links.isEmpty)
        XCTAssertEqual(board.drawings.map(\.id), [other])
    }

    func testADrawingGoesToTheFileAndBackAndAnOlderFileStillOpens() throws {
        var board = Board()
        let id = board.addStroke(line([(10, 10), (20.26, 30.04), (40, 10)]), pressure: [0.1, 0.456, 0.9], colour: "red", width: .thin)!
        _ = board.addStroke(line([(0, 0), (5, 5)]), to: id)
        board.add(.note, centre: .zero, text: "n")
        let data = try JSONEncoder().encode(board)
        XCTAssertEqual(try JSONDecoder().decode(Board.self, from: data), board)
        // The names in the file — they must never change, an older app tells a drawing by them.
        let file = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let item = (file["items"] as! [[String: Any]])[0]
        XCTAssertEqual(item["kind"] as? String, "drawing")
        XCTAssertEqual(ItemKind.drawing.rawValue, "drawing")
        let stroke = (item["strokes"] as! [[String: Any]])[0]
        XCTAssertEqual(stroke.keys.sorted(), ["colour", "points", "pressure", "width"])
        XCTAssertEqual(Stroke.CodingKeys.allCases.map(\.rawValue).sorted(), ["colour", "points", "pressure", "width"])
        XCTAssertEqual(stroke["colour"] as? String, "red")
        XCTAssertEqual(stroke["width"] as? String, "thin")
        XCTAssertEqual(stroke["points"] as? [Double], [16, 16, 26.3, 36, 46, 16])
        XCTAssertEqual(stroke["pressure"] as? [Double], [0.1, 0.46, 0.9])
        // A finger's stroke has no pressure in the file; a note has no strokes.
        XCTAssertEqual((item["strokes"] as! [[String: Any]])[1].keys.sorted(), ["colour", "points", "width"])
        XCTAssertNil((file["items"] as! [[String: Any]])[1]["strokes"])
        XCTAssertEqual(board.format, Board.currentFormat)
        // Tenths stay tenths in the file (no 26.299999999).
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("26.3,36,"))

        // A file from 0.1 (format 1, no strokes anywhere) opens as before.
        let old = try JSONDecoder().decode(Board.self, from: Data(#"{"id":"\#(boardID)","format":1,"items":[{"kind":"note","text":"x"}]}"#.utf8))
        XCTAssertNil(old.items[0].strokes)
        XCTAssertTrue(old.canBeChanged)
        // A drawing written by a newer app: what this version does not know is carried, a thickness it
        // does not know is drawn medium and kept, a broken list of numbers loses only its odd end.
        let newer = #"{"id":"\#(boardID)","items":[{"kind":"drawing","x":5,"y":5,"w":30,"h":30,"strokes":[{"colour":"teal","width":"brush","points":[6,6,20,20,9],"tilt":[0.5,0.6],"pressure":[1]}]}]}"#
        let read = try JSONDecoder().decode(Board.self, from: Data(newer.utf8))
        XCTAssertTrue(read.canBeChanged)
        XCTAssertEqual(read.items[0].strokes?[0].points, [6, 6, 20, 20])
        XCTAssertEqual(read.items[0].strokes?[0].thickness, .medium)
        XCTAssertNil(read.items[0].strokes?[0].pressure)
        let again = try JSONSerialization.jsonObject(with: JSONEncoder().encode(read)) as! [String: Any]
        let carried = ((again["items"] as! [[String: Any]])[0]["strokes"] as! [[String: Any]])[0]
        XCTAssertEqual(carried["width"] as? String, "brush")
        XCTAssertEqual(carried["tilt"] as? [Double], [0.5, 0.6])
    }

    func testADrawingIsMovedCopiedFramedAndRemovedLikeANote() {
        var board = Board()
        let frame = board.add(.frame, centre: CGPoint(x: 0, y: 0))
        let id = board.addStroke(line([(-50, -50), (50, 50)]), colour: "green")!
        // Moving the frame takes the drawing along; its lines go with it.
        board.move(board.carried(by: [frame]), by: CGSize(width: 100, height: 10))
        XCTAssertEqual(board.item(id)?.inkLines[0], line([(50, -40), (150, 60)]))
        // A copy has the same lines, a little to the side.
        let copy = board.duplicate([id]).first!
        XCTAssertEqual(board.item(copy)?.strokes, board.item(id)?.strokes)
        XCTAssertEqual(board.item(copy)?.inkLines[0], line([(78, -12), (178, 88)]))
        // It falls in line with its neighbours like any thing.
        XCTAssertTrue(board.snapTargets().contains { $0.rect == board.item(id)!.frame })
        board.remove([id])
        XCTAssertEqual(board.drawings.map(\.id), [copy])
    }

    func testALineIsDrawnSmoothWhereTheHandBendsAndSharpWhereItTurns() {
        // A right angle between two long pieces: the corner is rounded by less than a point.
        let corner = Ink.runs(line([(0, 0), (100, 0), (100, 100)]), base: 4)
        XCTAssertEqual(corner.count, 1)
        XCTAssertEqual(corner[0].width, 4)
        guard case .line(let before) = corner[0].steps[1], case .curve(let after, let control) = corner[0].steps[2] else { return XCTFail("no corner") }
        XCTAssertEqual(control, CGPoint(x: 100, y: 0))
        XCTAssertEqual(Double(before.x), 100 - 2 * Ink.rounding / (0.5).squareRoot(), accuracy: 1e-6)
        XCTAssertEqual(Double(after.y), 2 * Ink.rounding / (0.5).squareRoot(), accuracy: 1e-6)
        // A gentle bend: the curve runs from the middle of one piece to the middle of the next.
        let bend = Ink.runs(line([(0, 0), (10, 0), (20, 1)]), base: 4)
        guard case .line(let mid) = bend[0].steps[1], case .curve(let next, _) = bend[0].steps[2] else { return XCTFail("no bend") }
        XCTAssertEqual(mid, CGPoint(x: 5, y: 0))
        XCTAssertEqual(Double(next.x), 15, accuracy: 0.03)
        // One point is a dot.
        XCTAssertEqual(Ink.runs(line([(3, 4)]), base: 2), [InkRun(width: 2, steps: [.move(CGPoint(x: 3, y: 4)), .line(CGPoint(x: 3, y: 4))])])
        XCTAssertTrue(Ink.runs([], base: 2).isEmpty)
    }

    func testPressureMakesALineUpTo35PercentThinnerOrThicker() {
        XCTAssertEqual(Ink.width(4, pressure: nil), 4)
        XCTAssertEqual(Ink.width(4, pressure: 0), 4 * 0.65, accuracy: 1e-9)
        XCTAssertEqual(Ink.width(4, pressure: 0.6), 4 * 1.35, accuracy: 1e-9)
        XCTAssertEqual(Ink.width(4, pressure: 1), 4 * 1.35, accuracy: 1e-9)
        // Ordinary writing is about the chosen width.
        XCTAssertEqual(Ink.width(4, pressure: 0.25), 4, accuracy: 0.2)
        XCTAssertEqual(InkWidth.allCases.map(\.points), [2, 4, 7.5])
        // A line that is pressed harder along its way is drawn in runs, each a little wider than the last.
        let runs = Ink.runs(line([(0, 0), (50, 0), (100, 0)]), pressure: [0, 0.3, 0.6], base: 4)
        XCTAssertGreaterThan(runs.count, 4)
        XCTAssertEqual(runs.map(\.width), runs.map(\.width).sorted())
        XCTAssertEqual(runs.first!.width, 4 * 0.65, accuracy: 0.25)
        XCTAssertEqual(runs.last!.width, 4 * 1.35, accuracy: 0.25)
        for (a, b) in zip(runs, runs.dropFirst()) { XCTAssertLessThanOrEqual(b.width - a.width, 0.25) }
    }

    func testANoteForParagonSaysASketchWhereADrawingIs() {
        var board = Board(title: "Plan")
        board.add(.note, centre: .zero, text: "Ask Anna")
        let id = board.addStroke(line([(0, 0), (10, 10)]))!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let note = ParagonExport.note(board: board, title: "Plan", picture: "p.png", now: now)
        XCTAssertTrue(note.contains("## Notes\n\n- Ask Anna\n- A sketch (see the picture)\n"))
        XCTAssertTrue(ParagonExport.project(board: board, title: "Plan", picture: "p.png", now: now).contains("- A sketch (see the picture)\n"))
        XCTAssertTrue(ParagonExport.note(board: board, title: "Plan", picture: nil, now: now).contains("- A sketch (on the board)\n"))
        // A drawing never becomes a task, ticked or not.
        board.items[board.index(of: id)!].todo = true
        XCTAssertTrue(ParagonExport.inboxTasks(board: board).isEmpty)
        XCTAssertFalse(ParagonExport.note(board: board, title: "Plan", picture: nil, now: now).contains("## Tasks"))
    }
}
