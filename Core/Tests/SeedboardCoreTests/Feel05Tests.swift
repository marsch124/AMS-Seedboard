import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.5, the feel lane: what the hand feels, how a button answers, Send as a hand-over, the inviting empty board.
final class Feel05Tests: XCTestCase {
    func testACatchIsFeltAtMostOnceInATwelfthOfASecondAndOnlyWhenAGuideAppears() {
        let then = Date(timeIntervalSince1970: 1000)
        XCTAssertFalse(FeelRules.mayCatch(last: then, now: then.addingTimeInterval(0.05)))
        XCTAssertTrue(FeelRules.mayCatch(last: then, now: then.addingTimeInterval(0.12)))
        XCTAssertTrue(FeelRules.guideAppeared(before: 0, now: 1))
        XCTAssertTrue(FeelRules.guideAppeared(before: 1, now: 2))
        // The same guides as before, or one fewer: nothing is felt.
        XCTAssertFalse(FeelRules.guideAppeared(before: 1, now: 1))
        XCTAssertFalse(FeelRules.guideAppeared(before: 2, now: 1))
    }

    func testAPinchFeelsLifeSizeWhenItPassesItFromEitherSide() {
        XCTAssertEqual(FeelRules.zoomMoment(from: 0.9, to: 1.05), .lifeSize)
        XCTAssertEqual(FeelRules.zoomMoment(from: 1.2, to: 0.97), .lifeSize)
        XCTAssertEqual(FeelRules.zoomMoment(from: 0.9, to: 1.0), .lifeSize)
        // Leaving 100 %, or moving on one side of it: nothing.
        XCTAssertNil(FeelRules.zoomMoment(from: 1.0, to: 1.1))
        XCTAssertNil(FeelRules.zoomMoment(from: 0.5, to: 0.8))
        XCTAssertNil(FeelRules.zoomMoment(from: 1.4, to: 1.4))
    }

    func testTheEndOfTheZoomIsFeltOnceAndIsTheEndTheViewKeepsTo() {
        XCTAssertEqual(FeelRules.zoomMoment(from: 0.25, to: 0.2), .theEnd)
        XCTAssertEqual(FeelRules.zoomMoment(from: 2.8, to: 3), .theEnd)
        // Pushing on at the end, and coming away from it: nothing more.
        XCTAssertNil(FeelRules.zoomMoment(from: 0.2, to: 0.2))
        XCTAssertNil(FeelRules.zoomMoment(from: 3, to: 3))
        XCTAssertNil(FeelRules.zoomMoment(from: 0.2, to: 0.3))
        // The two ends are the ones the view itself stops at.
        var view = Viewport()
        view.size = CGSize(width: 800, height: 600)
        view.zoom(to: 0.01)
        XCTAssertEqual(view.scale, FeelRules.zoomLeast)
        view.zoom(to: 99)
        XCTAssertEqual(view.scale, FeelRules.zoomMost)
    }

    func testADroppedIdeaIsFeltOnlyWhenItFoundANewPlaceInAMap() {
        XCTAssertTrue(FeelRules.ideaSetDown(hangs: true, lands: false))
        XCTAssertTrue(FeelRules.ideaSetDown(hangs: false, lands: true))
        XCTAssertFalse(FeelRules.ideaSetDown(hangs: false, lands: false))
        // An arrow's end: felt when it lands on another shape, not when it stays on its own one.
        let a = UUID(), b = UUID()
        XCTAssertTrue(FeelRules.arrowJoined(before: a, after: b))
        XCTAssertFalse(FeelRules.arrowJoined(before: a, after: a))
        XCTAssertFalse(FeelRules.arrowJoined(before: a, after: nil))
    }

    func testTheMainButtonPressedIsTwelvePercentDarkerAndNeverSeeThrough() {
        // Boards green, #2E8B57.
        let green = (red: 46.0 / 255, green: 139.0 / 255, blue: 87.0 / 255)
        let pressed = FeelRules.darker(green, by: FeelRules.mainDarker)
        XCTAssertEqual(pressed.red, green.red * 0.88, accuracy: 0.0001)
        XCTAssertEqual(pressed.green, green.green * 0.88, accuracy: 0.0001)
        XCTAssertEqual(pressed.blue, green.blue * 0.88, accuracy: 0.0001)
        XCTAssertEqual(FeelRules.mainPressed, 0.97)
        XCTAssertEqual(FeelRules.tilePressed, 0.95)
    }

    func testATilesTintDoublesWhilePressedAndGoesOneStepUnderThePointer() {
        for night in [false, true] {
            let down = FeelRules.tintStrength(pressed: true, over: false, night: night)
            let over = FeelRules.tintStrength(pressed: false, over: true, night: night)
            XCTAssertEqual(FeelRules.tintStrength(pressed: false, over: false, night: night), 0)
            XCTAssertEqual(over, down / 2, accuracy: 0.0001)
            // Pressed wins over the pointer; a button that cannot be pressed shows nothing.
            XCTAssertEqual(FeelRules.tintStrength(pressed: true, over: true, night: night), down)
            XCTAssertEqual(FeelRules.tintStrength(pressed: true, over: true, enabled: false, night: night), 0)
            // "Doubles": a soft plate is white with the part's colour at `soft` (6 % by day, 12 % by night);
            // the colour laid over it at `down` leaves about twice as much of the colour.
            let soft = night ? 0.12 : 0.06
            let after = soft * (1 - down) + down
            XCTAssertEqual(after, soft * 2, accuracy: 0.011)
        }
    }

    func testTheLineAfterSendStaysSixSecondsAndOffersOpenOnlyWhenANoteWasMade() {
        XCTAssertEqual(FeelRules.sendLine, 6)
        XCTAssertEqual(FeelRules.sendTick, 0.45)
        XCTAssertTrue(FeelRules.sendOffersOpen(madeNote: true))
        // "Only the to-do boxes": there is no note to open.
        XCTAssertFalse(FeelRules.sendOffersOpen(madeNote: false))
    }

    func testAnEmptyBoardInvitesWithThreeStartsButNotABoardThatPlacesItself() {
        XCTAssertEqual(FeelRules.Start.allCases.map(\.word), ["Mind map", "Sticky note", "Paste a list"])
        XCTAssertEqual(FeelRules.Start.allCases.map(\.id), ["empty.mindmap", "empty.note", "empty.paste"])
        var board = Board(title: "Plain")
        XCTAssertEqual(board.invitation(readOnly: false), .starts)
        // A board from a newer Seedboard cannot be changed here: no buttons.
        XCTAssertEqual(board.invitation(readOnly: true), .words)
        // While the Draw tool is on the board is left clear for the Pencil.
        XCTAssertEqual(board.invitation(readOnly: false, drawing: true), .none)
        _ = board.add(.note, centre: .zero)
        XCTAssertEqual(board.invitation(readOnly: false), .none)
        // A timeline and a "Who does what" board have their own tools.
        XCTAssertEqual(Board.sequence().invitation(readOnly: false), .none)
        XCTAssertEqual(FeelRules.invitation(empty: true, placesItself: true, readOnly: false), .none)
    }

    func testPasteAListIsPaleWhileNothingIsCopiedAndTheIPhonesFirstListShowsTheStarters() {
        XCTAssertTrue(FeelRules.startIsPale(.paste, wordsCopied: false))
        XCTAssertFalse(FeelRules.startIsPale(.paste, wordsCopied: true))
        XCTAssertFalse(FeelRules.startIsPale(.mindMap, wordsCopied: false))
        XCTAssertFalse(FeelRules.startIsPale(.note, wordsCopied: false))
        XCTAssertTrue(FeelRules.showsFirstSeeds(loaded: true, boards: 0, phone: true))
        XCTAssertFalse(FeelRules.showsFirstSeeds(loaded: false, boards: 0, phone: true))
        XCTAssertFalse(FeelRules.showsFirstSeeds(loaded: true, boards: 1, phone: true))
        XCTAssertFalse(FeelRules.showsFirstSeeds(loaded: true, boards: 0, phone: false))
    }
}
