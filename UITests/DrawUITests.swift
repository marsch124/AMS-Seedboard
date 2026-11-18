import XCTest

/// Drawing by hand (0.2, pick 2): what a screen test can prove of it. The Pencil itself — drawing
/// with no tool chosen, pressure, the resting hand, its double-tap — needs a real iPad.
final class DrawUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with made-up boards. `-sampleData` always goes last.
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = extra
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func press(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        target.tap()
    }

    /// Waits until the board's count line (label on the iPhone, value on the Mac) is exactly these words.
    private func waitForCount(_ app: XCUIApplication, _ words: String, file: StaticString = #filePath, line: UInt = #line) {
        let count = element(app, "board.count")
        XCTAssertTrue(count.waitForExistence(timeout: 15), "board.count did not appear", file: file, line: line)
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: count)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 10), .completed,
                       "count line was \(count.label)\(String(describing: count.value)), expected \(words)", file: file, line: line)
    }

    /// The Draw tool shows its plate; with it on, a drag over empty board (a finger on iPhone and
    /// iPad, the mouse on the Mac) leaves one drawing; Undo takes the whole line back in one step;
    /// Done puts the plate away.
    func testTheDrawToolShowsItsPlateAndADragLeavesADrawing() {
        let app = launch()
        press(app, "boards.new")
        press(app, "starter.blank")
        waitForCount(app, "Empty")

        press(app, "tool.draw")
        for id in ["draw.pen", "draw.rubber", "draw.thin", "draw.medium", "draw.thick", "draw.colour.ink", "draw.colour.red", "draw.done"] {
            XCTAssertTrue(element(app, id).waitForExistence(timeout: 10), "\(id) did not appear")
        }
        press(app, "draw.thick")
        press(app, "draw.colour.red")

        let canvas = element(app, "board.canvas")
        let from = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.30))
        let to = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.42))
        from.press(forDuration: 0.1, thenDragTo: to)
        waitForCount(app, "1 sketch")

        // One line is one step for Undo.
        press(app, "board.undo")
        waitForCount(app, "Empty")
        press(app, "board.redo")
        waitForCount(app, "1 sketch")

        // The rubber takes the whole line when it crosses it.
        press(app, "draw.rubber")
        let above = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: 0.26))
        let below = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: 0.46))
        above.press(forDuration: 0.1, thenDragTo: below)
        waitForCount(app, "Empty")

        press(app, "draw.done")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "draw.pen"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "the plate stayed after Done")
    }

    /// The made-up board with drawings on it opens, and its drawings are counted.
    func testTheSketchBoardShowsItsDrawings() {
        let app = launch(["-board", "Sketch"])
        waitForCount(app, "2 notes · 3 sketches")
    }
}
