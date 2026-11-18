import XCTest
@testable import SeedboardCore

/// One small test per rule of the touch layer (pick 24) and the finger-size press areas (pick 10).
final class TouchTests: XCTestCase {
    // MARK: Pick 24 — two fingers slide and zoom together

    func testTwoFingersSlideAndZoomRoundThePointBetweenThem() {
        var view = Viewport()
        view.resized(to: CGSize(width: 400, height: 800), showing: nil)
        XCTAssertFalse(view.movedByOwner)
        // The fingers' middle goes from (100, 200) to (160, 260) while they spread to twice as far apart.
        let under = view.toBoard(CGPoint(x: 100, y: 200))
        view.pinch(from: CGPoint(x: 100, y: 200), to: CGPoint(x: 160, y: 260), by: 2)
        XCTAssertEqual(view.scale, 2, accuracy: 0.0001)
        let now = view.toBoard(CGPoint(x: 160, y: 260))
        XCTAssertEqual(Double(now.x), Double(under.x), accuracy: 0.0001)
        XCTAssertEqual(Double(now.y), Double(under.y), accuracy: 0.0001)
        XCTAssertTrue(view.movedByOwner)
        // Fingers that only move slide the board and leave the zoom alone.
        let offset = view.offset
        view.pinch(from: CGPoint(x: 160, y: 260), to: CGPoint(x: 150, y: 300), by: 1)
        XCTAssertEqual(view.scale, 2, accuracy: 0.0001)
        XCTAssertEqual(Double(view.offset.width), Double(offset.width) - 10, accuracy: 0.0001)
        XCTAssertEqual(Double(view.offset.height), Double(offset.height) + 40, accuracy: 0.0001)
        // The zoom stops at 300 %, the slide goes on.
        view.pinch(from: CGPoint(x: 150, y: 300), to: CGPoint(x: 170, y: 300), by: 5)
        XCTAssertEqual(view.scale, 3, accuracy: 0.0001)
    }

    func testTheFirstFingersShoveIsTakenBackAndALongMoveIsKept() {
        // The second finger came at once: taken back, however far the thing went.
        XCTAssertTrue(Fingers.isShove(moved: 80, after: 0.2))
        // Late, but the thing hardly moved: taken back.
        XCTAssertTrue(Fingers.isShove(moved: 12, after: 2))
        // A real move, and the second finger came later: kept.
        XCTAssertFalse(Fingers.isShove(moved: 80, after: 0.9))
    }

    // MARK: Pick 10 — finger-size press areas, counted on screen

    func testASmallThingHasAFingerSizePressAreaAndTheNearestWins() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0))
        let b = board.add(.box, centre: CGPoint(x: 0, y: 60))
        for id in [a, b] { board.resize(id, to: CGRect(x: -30, y: (id == a ? 0 : 60) - 14, width: 60, height: 28)) }
        // At 50 % a box 28 high is 14 points on screen: its press area is 44, so 30 board points above and below.
        let above = CGPoint(x: 0, y: -40)
        XCTAssertNil(board.hit(above))
        XCTAssertEqual(board.hit(above, scale: 0.5), a)
        // Life size it is 28 on screen: 8 points above and below, no more.
        XCTAssertNil(board.hit(above, scale: 1))
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: -20), scale: 1), a)
        // Between the two, both press areas hold the point: the nearer one wins.
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: 25), scale: 0.5), a)
        XCTAssertEqual(board.hit(CGPoint(x: 0, y: 35), scale: 0.5), b)
        // A pointer (no extra area) catches nothing there.
        XCTAssertNil(board.hit(CGPoint(x: 0, y: 25), scale: 0.5, least: 0))
    }

    func testAHandleKeepsA32PointPressAreaAndNeverTakesAPressFromTheThing() {
        // A plus-handle drawn 10 points big (50 % zoom), and the size knob beside it.
        let plus = CGRect(x: 100, y: 100, width: 10, height: 10)
        let knob = CGRect(x: 130, y: 100, width: 7, height: 7)
        // 10.5 points left of the plus: outside the old 9, inside the 32-point area (11 each side of a 10-point box).
        let near = CGPoint(x: 89.5, y: 105)
        XCTAssertEqual(Fingers.control(at: near, boxes: [plus, knob], onThing: false), 0)
        // The Mac's size (no bigger area) does not reach it, and neither does a press that lies on a thing.
        XCTAssertNil(Fingers.control(at: near, boxes: [plus, knob], onThing: false, least: 0))
        XCTAssertNil(Fingers.control(at: near, boxes: [plus, knob], onThing: true))
        // Close to the box the handle is caught even over a thing.
        XCTAssertEqual(Fingers.control(at: CGPoint(x: 95, y: 105), boxes: [plus, knob], onThing: true), 0)
        // Between the two, the nearer one wins.
        XCTAssertEqual(Fingers.control(at: CGPoint(x: 118, y: 104), boxes: [plus, knob], onThing: false), 0)
        XCTAssertEqual(Fingers.control(at: CGPoint(x: 122, y: 104), boxes: [plus, knob], onThing: false), 1)
    }

    func testASmallScreenOpensReadableOnTheMainIdea() {
        // A wide board on an iPhone: fitted it would be at 50 %.
        let all = CGRect(x: -200, y: -300, width: 1400, height: 900)
        let main = CGRect(x: -75, y: -23, width: 150, height: 46)
        var view = Viewport()
        view.resized(to: CGSize(width: 393, height: 700), showing: all, readableAround: main)
        XCTAssertEqual(view.scale, 0.75, accuracy: 0.0001)
        XCTAssertFalse(view.movedByOwner)
        // The main idea would be in the middle, but the view goes no further than the board's own edge:
        // its left edge 40 points in, its top edge 70 points down (under the top bar).
        XCTAssertEqual(Double(view.offset.width), 40 - (-200) * 0.75, accuracy: 0.0001)
        XCTAssertEqual(Double(view.offset.height), 70 - (-300) * 0.75, accuracy: 0.0001)
        // On a board that reaches far to every side, the main idea is in the middle of the screen.
        var far = Viewport()
        far.resized(to: CGSize(width: 393, height: 700), showing: CGRect(x: -2000, y: -2000, width: 4000, height: 4000), readableAround: main)
        XCTAssertEqual(Double(far.offset.width), 196.5, accuracy: 0.0001)
        XCTAssertEqual(Double(far.offset.height), 350, accuracy: 0.0001)
        // A small board is shown whole, as before.
        var small = Viewport()
        let little = CGRect(x: 0, y: 0, width: 300, height: 200)
        small.resized(to: CGSize(width: 393, height: 700), showing: little, readableAround: CGRect(x: 0, y: 0, width: 100, height: 40))
        var fitted = Viewport()
        fitted.resized(to: CGSize(width: 393, height: 700), showing: little)
        XCTAssertEqual(small, fitted)
        XCTAssertEqual(small.scale, 1, accuracy: 0.0001)
    }

    func testTypingZoomsInToLifeSizeAndGoesBackAfterwards() {
        var view = Viewport()
        view.resized(to: CGSize(width: 393, height: 700), showing: nil)
        view.zoom(to: 0.5)
        let box = CGRect(x: 100, y: 40, width: 120, height: 30)
        let middle = CGPoint(x: 160, y: 55)
        let onScreen = CGPoint(x: Double(middle.x) * 0.5 + Double(view.offset.width), y: Double(middle.y) * 0.5 + Double(view.offset.height))
        view.typingBegan(round: box)
        XCTAssertEqual(view.scale, 1, accuracy: 0.0001)
        // The thing typed in stayed where it was on screen.
        XCTAssertEqual(Double(view.toBoard(onScreen).x), 160, accuracy: 0.0001)
        XCTAssertEqual(Double(view.toBoard(onScreen).y), 55, accuracy: 0.0001)
        // The next idea in a row does not zoom again, and the keyboard coming up does not fit the board.
        view.typingBegan(round: CGRect(x: 100, y: 80, width: 120, height: 30))
        XCTAssertEqual(view.scaleBeforeTyping, 0.5)
        XCTAssertTrue(view.typingEnded(round: box))
        XCTAssertEqual(view.scale, 0.5, accuracy: 0.0001)
        XCTAssertNil(view.scaleBeforeTyping)
        // Already life size: nothing happens, and there is nothing to go back to.
        view.zoom(to: 1.5)
        view.typingBegan(round: box)
        XCTAssertFalse(view.typingEnded(round: box))
        XCTAssertEqual(view.scale, 1.5, accuracy: 0.0001)
    }

    func testTheMainThingIsTheMiddleIdeaOrTheFirstShape() {
        var board = Board()
        XCTAssertNil(board.mainThing)
        let frame = board.add(.frame, centre: CGPoint(x: 0, y: 0))
        XCTAssertEqual(board.mainThing?.id, frame)
        let box = board.add(.box, centre: CGPoint(x: 300, y: 0))
        XCTAssertEqual(board.mainThing?.id, box)
        let centre = board.addCentre(at: CGPoint(x: 600, y: 0), text: "Trip")
        _ = board.addChild(of: centre, text: "Food")
        XCTAssertEqual(board.mainThing?.id, centre)
    }
}
