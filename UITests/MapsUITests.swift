import XCTest

/// Mind maps in 0.2: ideas in another order, and sending one branch.
/// Every control is found by its identifier; every wait is for an element or a value.
final class MapsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

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
        XCTAssertEqual(result, .completed, "\(id) said \(target.label) / \(String(describing: target.value)), expected \(words)", file: file, line: line)
    }

    // MARK: Tests

    /// With an idea chosen the Send page offers "Only the branch …"; switching it on names the note after the branch.
    func testTheSendPageOffersOnlyTheBranchOfTheChosenIdea() {
        let app = launch(["-board", "Summer", "-pick", "Budget", "-send"])
        let branch = element(app, "send.branchOnly")
        XCTAssertTrue(branch.waitForExistence(timeout: 15), "send.branchOnly did not appear")
        XCTAssertTrue(element(app, "send.kind.note").exists)
        waitFor(app, "send.title", toSay: "Summer cabin")
        branch.tap()
        waitFor(app, "send.title", toSay: "Budget")
        press(app, "send.cancel")
    }

    /// With nothing chosen the Send page has no branch switch.
    func testTheSendPageHasNoBranchSwitchWithNothingChosen() {
        let app = launch(["-board", "Summer", "-send"])
        XCTAssertTrue(element(app, "send.kind.note").waitForExistence(timeout: 15))
        XCTAssertFalse(element(app, "send.branchOnly").exists)
        press(app, "send.cancel")
    }

    /// "Loan" is the first of the two ideas under "Budget"; Move down makes it the second, Undo the first again.
    func testMoveDownChangesTheOrder() {
        let app = launch(["-board", "Summer", "-pick", "Loan"])
        waitFor(app, "board.chosenPlace", toSay: "1 of 2")
        #if os(macOS)
        // The Mac has no Move buttons in the bar: ⌘↓ (the Board menu's key) does it.
        app.typeKey(.downArrow, modifierFlags: .command)
        #else
        press(app, "sel.moveDown")
        #endif
        waitFor(app, "board.chosenPlace", toSay: "2 of 2")
        press(app, "board.undo")
        waitFor(app, "board.chosenPlace", toSay: "1 of 2")
    }
}
