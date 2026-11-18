import XCTest

/// 0.2 picks 15 and 16: the plate with all flow shapes, and "Lanes" in the bar of a frame.
/// Every control is found by its identifier; every wait is for an element or a value.
final class ShapesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers (the same launch pattern as SeedboardUITests)

    @discardableResult
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

    private func waitForCount(_ app: XCUIApplication, _ words: String, file: StaticString = #filePath, line: UInt = #line) {
        let count = element(app, "board.count")
        XCTAssertTrue(count.waitForExistence(timeout: 15), "board.count did not appear", file: file, line: line)
        // The iPhone gives the words as the label, the Mac as the value.
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: count)
        let result = XCTWaiter().wait(for: [match], timeout: 10)
        XCTAssertEqual(result, .completed, "count line was \(count.label)\(String(describing: count.value)), expected \(words)", file: file, line: line)
    }

    /// Ends the typing in the thing just made. (0.2: on the Mac and the iPad the bar beside a
    /// thing is out of the way while its words are typed, and comes back afterwards.)
    private func endTyping(_ app: XCUIApplication) {
        #if os(macOS)
        element(app, "board.field").typeText("\n")
        #else
        // The Done button above the screen keyboard; with a real keyboard there is none: Return ends it.
        let done = element(app, "board.fieldDone")
        if done.waitForExistence(timeout: 5) { done.tap() } else { element(app, "board.field").typeText("\n") }
        #endif
    }

    // MARK: Tests

    func testTheShapePlateAddsAPersonAndAFrameHasLanes() {
        let app = launch([])
        press(app, "boards.new")
        press(app, "starter.blank")
        waitForCount(app, "Empty")

        // The plate with all shapes: the corner mark of the Box tile on the Mac, holding the tile on a touch screen.
        XCTAssertTrue(element(app, "tool.box").waitForExistence(timeout: 15), "tool.box did not appear")
        #if os(macOS)
        press(app, "tool.shapes")
        #else
        element(app, "tool.box").press(forDuration: 0.9)
        #endif
        XCTAssertTrue(element(app, "plate.shapes").waitForExistence(timeout: 10), "the shape plate did not open")
        for kind in ["box", "round", "oval", "diamond", "person", "document", "slanted", "store"] {
            XCTAssertTrue(element(app, "plate.shape.\(kind)").exists, "plate.shape.\(kind) is missing")
        }

        // Person: the plate goes, a thing is on the board, ready to type in.
        press(app, "plate.shape.person")
        waitForCount(app, "1 shape")
        XCTAssertTrue(element(app, "board.field").waitForExistence(timeout: 10), "the new Person is not ready to type in")

        // The bar of the chosen shape has ONE Shape button (it opens the same plate).
        endTyping(app)
        XCTAssertTrue(element(app, "sel.shape").waitForExistence(timeout: 10), "sel.shape did not appear")

        // A frame's bar has Lanes.
        press(app, "tool.frame")
        XCTAssertTrue(element(app, "board.field").waitForExistence(timeout: 10), "the new frame is not ready to type in")
        endTyping(app)
        XCTAssertTrue(element(app, "sel.lanes").waitForExistence(timeout: 10), "sel.lanes did not appear")
        waitForCount(app, "1 shape")
    }
}
