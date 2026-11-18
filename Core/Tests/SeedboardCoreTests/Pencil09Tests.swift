import XCTest
@testable import SeedboardCore

/// Highlighter, rubber sizes, typed words, marks on a picture and the lasso (0.9, picks 35 to 39) as data.
final class Pencil09Tests: XCTestCase {
    private func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> [CGPoint] {
        [CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y1)]
    }

    private func square(_ x: Double, _ y: Double, _ s: Double) -> [CGPoint] {
        [CGPoint(x: x, y: y), CGPoint(x: x + s, y: y), CGPoint(x: x + s, y: y + s), CGPoint(x: x, y: y + s)]
    }

    // MARK: 35 highlighter and rubber

    func testHighlighterIsStoredWideUnderAndInItsColours() {
        var board = Board(title: "t")
        let id = board.addStroke(line(0, 0, 100, 0), colour: "red", width: .thin, pen: Ink.highlighter)!
        _ = board.addStroke(line(0, 5, 100, 5), colour: "blue", width: .thin, to: id)
        let item = board.item(id)!
        XCTAssertEqual(item.strokes?[0].pen, "highlighter")
        XCTAssertEqual(item.strokes?[0].colour, "yellow", "a colour the highlighter lacks becomes yellow")
        XCTAssertEqual(item.strokes?[0].lineWidth, Ink.highlighterWidth)
        XCTAssertEqual(Ink.highlighterWidth, InkWidth.thick.points * 3)
        XCTAssertNil(item.strokes?[1].pen)
        // The highlighter line is painted first, so the ordinary ink lies over it.
        _ = board.addStroke(line(0, 9, 100, 9), colour: "green", pen: Ink.highlighter, to: id)
        XCTAssertEqual(board.item(id)!.paintedStrokes.map(\.isHighlighter), [true, true, false])
        XCTAssertEqual(Ink.highlighterColours, ["yellow", "green", "pink", "blue"])
    }

    func testRubberSizesReachDifferentDistances() {
        XCTAssertEqual(RubberSize.medium.screenReach, Ink.rubber)
        XCTAssertLessThan(RubberSize.small.screenReach, RubberSize.medium.screenReach)
        XCTAssertGreaterThan(RubberSize.large.screenReach, RubberSize.medium.screenReach)
        XCTAssertEqual(RubberSize.large.reach(scale: 2), RubberSize.large.screenReach / 2)
        var board = Board(title: "t")
        let id = board.addStroke(line(0, 0, 100, 0), width: .thin)!
        let near = CGPoint(x: 50, y: 15)   // 14 from the line's edge (thin is 2 wide)
        XCTAssertTrue(board.strokes(near: near, reach: RubberSize.small.reach(scale: 1)).isEmpty)
        XCTAssertTrue(board.strokes(near: near, reach: RubberSize.medium.reach(scale: 1)).isEmpty)
        XCTAssertEqual(board.strokes(near: near, reach: RubberSize.large.reach(scale: 1)), [InkMark(drawing: id, stroke: 0)])
        // A wide highlighter line is touched from further away than its centre line.
        let high = board.addStroke(line(0, 100, 100, 100), pen: Ink.highlighter)!
        XCTAssertEqual(board.strokes(near: CGPoint(x: 50, y: 108), reach: 1), [InkMark(drawing: high, stroke: 0)])
    }

    // MARK: 36 typed words

    func testCleanWordsAndSketchBecomesText() {
        XCTAssertEqual(InkText.clean(["  Buy   milk ", "", "and  eggs"]), "Buy milk\nand eggs")
        XCTAssertEqual(InkText.clean(["  ", ""]), "")
        XCTAssertEqual(InkText.imageScale(for: CGSize(width: 100, height: 50)), 4)
        XCTAssertEqual(InkText.imageScale(for: CGSize(width: 4000, height: 10)), 1)
        var board = Board(title: "t")
        let id = board.addStroke(line(40, 60, 140, 90))!
        let at = board.item(id)!.frame
        XCTAssertFalse(board.makeTyped(id, words: "  "))
        XCTAssertEqual(board.item(id)?.kind, .drawing)
        XCTAssertTrue(board.makeTyped(id, words: "Buy milk"))
        let text = board.item(id)!
        XCTAssertEqual(text.kind, .text)
        XCTAssertEqual(text.text, "Buy milk")
        XCTAssertNil(text.strokes)
        XCTAssertEqual(text.x, Double(at.minX))
        XCTAssertEqual(text.y, Double(at.minY))
    }

    // MARK: 37 marks on a picture

    private func pictureBoard() -> (Board, UUID) {
        var board = Board(title: "t")
        let id = board.addPicture(name: "a.jpg", pixelSize: CGSize(width: 200, height: 100), centre: CGPoint(x: 200, y: 100))!
        return (board, id)
    }

    func testMarksOnAPictureMoveScaleAndCropWithIt() {
        var (board, id) = pictureBoard()
        let corner = CGPoint(x: board.item(id)!.x, y: board.item(id)!.y)
        XCTAssertTrue(board.addPictureStroke([CGPoint(x: corner.x + 10, y: corner.y + 20), CGPoint(x: corner.x + 50, y: corner.y + 20)], on: id))
        XCTAssertEqual(board.item(id)?.strokes?.first?.points, [10, 20, 50, 20])
        // Moving: the points are measured from the corner, so nothing is written again.
        board.move([id], by: CGSize(width: 30, height: 30))
        XCTAssertEqual(board.item(id)?.strokes?.first?.points, [10, 20, 50, 20])
        XCTAssertEqual(board.inkLinesOnBoard(id).first?.first?.x, corner.x + 40)
        // Scaling to twice the width: the marks double.
        let f = board.item(id)!.frame
        board.resize(id, to: CGRect(x: f.minX, y: f.minY, width: f.width * 2, height: f.height * 2))
        XCTAssertEqual(board.item(id)?.strokes?.first?.points, [20, 40, 100, 40])
        XCTAssertEqual(board.item(id)?.strokes?.first?.thickness, .medium)
        // A crop that moves the corner right and down 50 keeps the marks on the same place of the picture.
        let before = board.inkLinesOnBoard(id)
        XCTAssertTrue(board.cropPicture(id, to: [0.25, 0.25, 0.5, 0.5]))
        XCTAssertEqual(board.inkLinesOnBoard(id).first?.first?.x ?? 0, before.first?.first?.x ?? 1, accuracy: 0.2)
        XCTAssertEqual(board.inkLinesOnBoard(id).first?.first?.y ?? 0, before.first?.first?.y ?? 1, accuracy: 0.2)
    }

    func testRubberRemovesPictureMarksAndNotThePicture() {
        var (board, id) = pictureBoard()
        let f = board.item(id)!.frame
        board.addPictureStroke([CGPoint(x: f.minX + 10, y: f.minY + 10), CGPoint(x: f.minX + 60, y: f.minY + 10)], on: id)
        XCTAssertEqual(board.strokes(near: CGPoint(x: f.minX + 30, y: f.minY + 10), reach: 5).count, 1)
        XCTAssertTrue(board.rub(at: CGPoint(x: f.minX + 30, y: f.minY + 10), reach: 5))
        XCTAssertEqual(board.item(id)?.kind, .picture)
        XCTAssertNil(board.item(id)?.strokes)
        // Marks go when the picture goes.
        board.addPictureStroke([CGPoint(x: f.minX, y: f.minY)], on: id)
        board.remove([id])
        XCTAssertNil(board.item(id))
        // Only a picture takes marks.
        var other = Board(title: "t")
        let note = other.add(.note, centre: CGPoint(x: 0, y: 0))
        XCTAssertFalse(other.addPictureStroke([CGPoint(x: 1, y: 1)], on: note))
    }

    // MARK: 39 lasso

    func testChosenSketchesTakeAColour() {
        var board = Board(title: "t")
        let id = board.addStroke(line(0, 0, 50, 0), colour: "red")!
        board.addStroke(line(0, 9, 50, 9), colour: "blue", pen: Ink.highlighter, to: id)
        XCTAssertEqual(board.item(id)?.sketchColour, "red")
        board.setColour("teal", of: [id])
        XCTAssertEqual(board.item(id)?.strokes?[0].colour, "teal")
        XCTAssertEqual(board.item(id)?.strokes?[1].colour, "blue", "the highlighter keeps a colour it has not got")
        board.setColour("", of: [id])
        XCTAssertEqual(board.item(id)?.sketchColour, "")
        XCTAssertEqual(board.coloursOffered(for: [id]).first, "")
    }

    func testLoopContainsAndShare() {
        let loop = square(0, 0, 100)
        XCTAssertTrue(Ink.loopContains(loop, CGPoint(x: 50, y: 50)))
        XCTAssertFalse(Ink.loopContains(loop, CGPoint(x: 150, y: 50)))
        XCTAssertFalse(Ink.loopContains([CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 5)], CGPoint(x: 1, y: 1)))
        XCTAssertEqual(Ink.share(of: line(10, 50, 90, 50), insideLoop: loop), 1, accuracy: 0.01)
        XCTAssertEqual(Ink.share(of: line(50, 50, 150, 50), insideLoop: loop), 0.5, accuracy: 0.05)
        XCTAssertEqual(Ink.share(of: line(120, 50, 190, 50), insideLoop: loop), 0)
        XCTAssertFalse(Ink.isLoop(square(0, 0, 5)))
        XCTAssertTrue(Ink.isLoop(loop))
    }

    func testLassoChoosesMostlyInsideAndSplitsPartOfASketch() {
        var board = Board(title: "t")
        let id = board.addStroke(line(10, 10, 90, 10))!            // inside
        board.addStroke(line(10, 30, 70, 30), to: id)              // 75 % inside
        board.addStroke(line(10, 50, 400, 50), to: id)             // mostly outside
        let other = board.addStroke(line(20, 70, 80, 70))!         // a second sketch, wholly inside
        let outside = board.addStroke(line(300, 300, 380, 300))!   // far away
        let loop = square(0, 0, 100)
        XCTAssertEqual(board.lassoMarks(loop: loop).count, 3)
        let chosen = board.lasso(loop: loop)
        XCTAssertEqual(chosen.count, 2)
        XCTAssertTrue(chosen.contains(other), "a sketch chosen whole keeps its own place and name")
        XCTAssertFalse(chosen.contains(id), "part of a sketch goes into a new one")
        let piece = chosen.subtracting([other]).first!
        XCTAssertEqual(board.item(piece)?.strokes?.count, 2)
        XCTAssertEqual(board.item(id)?.strokes?.count, 1, "the long line stays behind")
        XCTAssertEqual(board.item(outside)?.strokes?.count, 1)
        // The new sketch can move alone and its lines are where they were.
        XCTAssertEqual(board.inkLinesOnBoard(piece).first?.first?.x ?? 0, 10, accuracy: 0.2)
        board.move([piece], by: CGSize(width: 500, height: 0))
        XCTAssertEqual(board.inkLinesOnBoard(id).first?.first?.x ?? 0, 10, accuracy: 0.2)
        // A loop round nothing changes nothing.
        let before = board
        XCTAssertTrue(board.lasso(loop: square(700, 700, 50)).isEmpty)
        XCTAssertEqual(board, before)
    }
}

private extension Board {
    /// The marks of a sketch or a picture as they lie on the board.
    func inkLinesOnBoard(_ id: UUID) -> [[CGPoint]] { item(id)?.inkLines ?? [] }
}
