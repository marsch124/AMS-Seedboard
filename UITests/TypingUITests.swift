import XCTest

// The Mac only: the simulator's test keyboard cannot press Shift and Return together.
#if os(macOS)
/// Shift and Return while typing make a new line and the typing goes on (0.3).
final class TypingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testShiftAndReturnMakeANewLineAndTheTypingGoesOn() {
        let app = XCUIApplication()
        var arguments: [String] = []
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif
        let new = element(app, "boards.new")
        XCTAssertTrue(new.waitForExistence(timeout: 15), "boards.new did not appear")
        new.tap()
        let blank = element(app, "starter.blank")
        XCTAssertTrue(blank.waitForExistence(timeout: 15), "starter.blank did not appear")
        blank.tap()
        let note = element(app, "tool.note")
        XCTAssertTrue(note.waitForExistence(timeout: 15), "tool.note did not appear")
        note.tap()

        let field = element(app, "board.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "board.field did not appear")
        field.typeText("One")
        field.typeKey(.return, modifierFlags: .shift)
        // Still typing: the field is there and takes the next words on the new line.
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Shift and Return ended the typing")
        field.typeText("Two")
        let want = "One\nTwo"
        let match = expectation(for: NSPredicate(format: "value == %@ OR label == %@", want, want), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 8), .completed,
                       "the field holds \(String(describing: field.value)), expected One, a new line, Two")
        // Return alone still ends the typing.
        field.typeKey(.return, modifierFlags: [])
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed, "Return did not end the typing")
    }
}
#endif
