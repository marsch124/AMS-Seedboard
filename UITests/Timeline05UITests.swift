import XCTest

/// 0.5 on the timeline board: the line that says how far the plan is, Done on a bar, and Catch up.
/// Every control is found by its identifier; every wait is for an element or a value.
final class Timeline05UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with made-up boards. `-sampleData` always goes last.
    private func launch(_ extra: [String]) -> XCUIApplication {
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

    /// Waits until the element's words begin with these (the iPhone gives them as the label, the Mac as the value).
    private func waitFor(_ app: XCUIApplication, _ id: String, toBeginWith words: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        let match = expectation(for: NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", words, words), evaluatedWith: target)
        let result = XCTWaiter().wait(for: [match], timeout: 10)
        XCTAssertEqual(result, .completed, "\(id) said \(target.label)\(String(describing: target.value)), expected it to begin with \(words)", file: file, line: line)
    }

    private func waitUntilGone(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, id))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "\(id) stayed", file: file, line: line)
    }

    /// The made-up timeline has 6 bars and a milestone, two of the bars behind today. The line says so;
    /// Done on the chosen late bar makes it "1 of 7 done · 1 late"; Catch up then leaves nothing late,
    /// says how many bars moved, and goes away; Undo brings the late bar and the button back.
    func testTheLineSaysHowFarThePlanIsAndDoneAndCatchUpChangeIt() {
        let app = launch(["-board", "timeline", "-pick", "Permit"])
        waitFor(app, "timeline.progress", toBeginWith: "0 of 7 done · 2 late · ends ")
        XCTAssertTrue(element(app, "timeline.catchUp").waitForExistence(timeout: 10), "Catch up shows while something is late")

        press(app, "sel.done")
        waitFor(app, "timeline.progress", toBeginWith: "1 of 7 done · 1 late · ends ")

        press(app, "timeline.catchUp")
        waitFor(app, "timeline.progress", toBeginWith: "1 of 7 done · ends ")
        waitUntilGone(app, "timeline.catchUp")
        let flash = element(app, "board.flash")
        XCTAssertTrue(flash.waitForExistence(timeout: 10), "Catch up says what it did")

        press(app, "board.undo")
        waitFor(app, "timeline.progress", toBeginWith: "1 of 7 done · 1 late · ends ")
        XCTAssertTrue(element(app, "timeline.catchUp").waitForExistence(timeout: 10), "Undo brings the late bar back")
    }
}
