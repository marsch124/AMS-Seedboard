import XCTest

/// The touch layer of iPhone and iPad (0.2, pick 24): what a screen test can prove of it.
/// Sliding and zooming with two fingers, the trackpad and the Pencil need a real device.
final class TouchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func press(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        target.tap()
    }

    /// Waits until the element's words (label on the iPhone, value on the Mac) are exactly these.
    private func waitFor(_ app: XCUIApplication, _ id: String, toSay words: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: target)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 10), .completed, "\(id) said \(target.label), expected \(words)", file: file, line: line)
    }

    /// A press through the new layer still reaches the board (it ends the typing), and two presses
    /// on empty board show the whole board again: 100 % → Bigger → 125 % → two presses → 100 %.
    func testTwoPressesOnEmptyBoardShowTheWholeBoard() throws {
        #if os(macOS)
        throw XCTSkip("iPhone and iPad only: on the Mac two clicks on empty board make a sticky note.")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData"]
        app.launch()
        press(app, "boards.new")
        press(app, "starter.blank")
        waitFor(app, "board.count", toSay: "Empty")
        waitFor(app, "zoom.value", toSay: "100 %")
        press(app, "zoom.in")
        waitFor(app, "zoom.value", toSay: "125 %")
        let canvas = element(app, "board.canvas")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).doubleTap()
        waitFor(app, "zoom.value", toSay: "100 %")
        // Nothing was made by the two presses (before 0.2 they made a sticky note).
        waitFor(app, "board.count", toSay: "Empty")
        #endif
    }
}
