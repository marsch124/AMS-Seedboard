import XCTest

/// The "Who does what" board. Every control is found by its identifier; every wait is for an element or a value.
final class SequenceUITests: XCTestCase {
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

    // MARK: Test

    /// The made-up "Loan steps" board opens with its first message chosen: the bar for a message turns
    /// it round and makes it an answer; the Who tool adds a name that is typed in place and shows the
    /// bar for a name; a note is counted; Remove and Undo work as on any board.
    func testALoanBoardTurnsAMessageAddsANameAndANote() {
        let app = launch(["-board", "Loan", "-pick", "Ask for loan"])
        waitFor(app, "board.count", toSay: "4 people · 9 messages · 1 note · 1 section")
        XCTAssertTrue(element(app, "sequence.canvas").exists)
        XCTAssertTrue(element(app, "tool.who").exists)
        XCTAssertTrue(element(app, "tool.message").exists)
        XCTAssertTrue(element(app, "tool.note").exists)
        XCTAssertTrue(element(app, "tool.section").exists)
        XCTAssertTrue(element(app, "zoom.fit").exists)

        // The chosen message and its bar.
        waitFor(app, "sequence.chosen", toSay: "1. Anna → Bank: Ask for loan")
        XCTAssertTrue(element(app, "board.selectionBar").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "sel.words").exists)
        XCTAssertTrue(element(app, "sel.colour").exists)
        XCTAssertTrue(element(app, "sel.todo").exists)
        XCTAssertTrue(element(app, "sel.copy").exists)
        press(app, "sel.turn")
        waitFor(app, "sequence.chosen", toSay: "1. Bank → Anna: Ask for loan")
        press(app, "sel.answer")
        waitFor(app, "sequence.chosen", toSay: "1. Bank answers Anna: Ask for loan")

        // A new name, typed in place; it stays chosen and shows the bar for a name.
        press(app, "tool.who")
        waitFor(app, "board.count", toSay: "5 people · 9 messages · 1 note · 1 section")
        let field = element(app, "board.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the name field did not appear")
        field.typeText("Shop\n")                        // Return ends the typing
        waitFor(app, "sequence.chosen", toSay: "Who: Shop")
        XCTAssertTrue(element(app, "sel.name").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "sel.messageTo").exists)

        // Remove and Undo.
        press(app, "sel.remove")
        waitFor(app, "board.count", toSay: "4 people · 9 messages · 1 note · 1 section")
        press(app, "board.undo")
        waitFor(app, "board.count", toSay: "5 people · 9 messages · 1 note · 1 section")

        // A note across the lines is counted with the rest.
        press(app, "tool.note")
        let note = element(app, "board.field")
        XCTAssertTrue(note.waitForExistence(timeout: 10), "the note field did not appear")
        note.typeText("Bring the papers\n")
        waitFor(app, "board.count", toSay: "5 people · 9 messages · 2 notes · 1 section")
    }
}
