import XCTest

/// 0.5 pick 11: "Make a mind map" of chosen sticky notes — its button in the bar, the small question for the
/// middle idea (filled in with the board's name; Cancel, Save), and the map that Save makes.
/// Every control is found by its identifier; every wait is for an element or a value.
final class ThinkingUITests: XCTestCase {
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

    private func waitForCount(_ app: XCUIApplication, _ words: String, file: StaticString = #filePath, line: UInt = #line) {
        let count = element(app, "board.count")
        XCTAssertTrue(count.waitForExistence(timeout: 15), "board.count did not appear", file: file, line: line)
        // The iPhone gives the words as the label, the Mac as the value.
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: count)
        let result = XCTWaiter().wait(for: [match], timeout: 10)
        XCTAssertEqual(result, .completed, "count line was \(count.label)\(String(describing: count.value)), expected \(words)", file: file, line: line)
    }

    // MARK: Tests

    /// Two sticky notes chosen: "Make a mind map" asks for the middle idea with the board's name filled in;
    /// Save turns the two notes into the branches of a new map (three ideas more, no notes left).
    func testMakeAMindMapAsksForTheMiddleIdeaAndSaveMakesTheMap() {
        let app = launch(["-board", "Summer", "-pickAll", "Alex about,timber"])
        waitForCount(app, "12 ideas · 5 shapes · 2 notes")
        XCTAssertTrue(element(app, "board.selectionBar").waitForExistence(timeout: 15), "the bar of the chosen notes did not appear")

        // On a narrow screen the button waits behind the "…".
        let make = element(app, "sel.makeMap")
        if !make.waitForExistence(timeout: 3) {
            element(app, "sel.overflow").tap()
            XCTAssertTrue(make.waitForExistence(timeout: 10), "Make a mind map is neither in the bar nor behind the …")
        }
        make.tap()

        let field = element(app, "makeMap.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the question for the middle idea did not open")
        XCTAssertEqual(field.value as? String, "Summer cabin", "the middle idea is not filled in with the board's name")
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists, "the question has no Cancel")
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.exists, "the question has no Save")
        save.tap()

        waitForCount(app, "15 ideas · 5 shapes")
    }
}
