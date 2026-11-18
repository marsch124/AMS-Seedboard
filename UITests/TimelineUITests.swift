import XCTest

/// The timeline board. Every control is found by its identifier; every wait is for an element or a value.
final class TimelineUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers (the same launch pattern as SeedboardUITests)

    /// Launches with made-up boards. `-sampleData` always goes last.
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

    /// Waits until the element says exactly these words (the iPhone gives them as the label, the Mac as the value).
    private func waitFor(_ app: XCUIApplication, _ id: String, toSay words: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: target)
        let result = XCTWaiter().wait(for: [match], timeout: 10)
        XCTAssertEqual(result, .completed, "\(id) said \(target.label)\(String(describing: target.value)), expected \(words)", file: file, line: line)
    }

    private func waitUntilGone(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, id))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "\(id) stayed", file: file, line: line)
    }

    // MARK: Test

    /// A new timeline opens with its example; the Bar tool adds a row whose name is typed; the chosen bar
    /// shows its bar with Dates; the Dates page has both days, Cancel and Save; zoom steps to months;
    /// Remove and Undo work as on any board.
    func testANewTimelineTakesABarShowsItsDatesAndZooms() {
        let app = launch([])
        press(app, "boards.new")
        press(app, "starter.timeline")
        waitFor(app, "board.count", toSay: "3 bars · 1 milestone")
        XCTAssertTrue(element(app, "timeline.canvas").exists)
        XCTAssertTrue(element(app, "today.button").exists)
        XCTAssertTrue(element(app, "tool.milestone").exists)
        XCTAssertTrue(element(app, "tool.phase").exists)
        XCTAssertTrue(element(app, "tool.after").exists)

        press(app, "tool.bar")
        waitFor(app, "board.count", toSay: "4 bars · 1 milestone")
        let field = element(app, "board.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the name field did not appear")
        field.typeText("Paint\n")                       // Return ends the typing; the bar stays chosen

        XCTAssertTrue(element(app, "board.selectionBar").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "sel.colour").exists)
        XCTAssertTrue(element(app, "sel.todo").exists)
        XCTAssertTrue(element(app, "sel.copy").exists)

        press(app, "sel.dates")
        XCTAssertTrue(element(app, "dates.start").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "dates.end").exists)
        XCTAssertTrue(element(app, "dates.save").exists)
        press(app, "dates.cancel")
        waitUntilGone(app, "dates.cancel")

        // Further away twice at most: whatever the screen's width chose first, it ends at months.
        for _ in 0..<2 where element(app, "zoom.out").isEnabled { press(app, "zoom.out") }
        waitFor(app, "zoom.value", toSay: "Months")
        press(app, "today.button")
        press(app, "zoom.fit")

        press(app, "sel.remove")
        waitFor(app, "board.count", toSay: "3 bars · 1 milestone")
        press(app, "board.undo")
        waitFor(app, "board.count", toSay: "4 bars · 1 milestone")
    }
}
