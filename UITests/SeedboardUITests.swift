import XCTest

/// First screen tests. Every control is found by its identifier; every wait is for an element or a value.
final class SeedboardUITests: XCTestCase {
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

    /// Waits until the board's count line holds exactly this text.
    private func waitForCount(_ app: XCUIApplication, _ words: String, file: StaticString = #filePath, line: UInt = #line) {
        let count = element(app, "board.count")
        XCTAssertTrue(count.waitForExistence(timeout: 15), "board.count did not appear", file: file, line: line)
        // The iPhone gives the words as the label, the Mac as the value.
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: count)
        let result = XCTWaiter().wait(for: [match], timeout: 10)
        XCTAssertEqual(result, .completed, "count line was \(count.label)\(String(describing: count.value)), expected \(words)", file: file, line: line)
    }

    /// A new blank board, open on its canvas.
    private func openBlankBoard(_ app: XCUIApplication) {
        press(app, "boards.new")
        press(app, "starter.blank")
        waitForCount(app, "Empty")
    }

    private func type(_ app: XCUIApplication, _ text: String) {
        let field = element(app, "board.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "board.field did not appear")
        field.typeText(text)
    }

    /// Press near the top-left corner of the canvas, away from anything on it.
    private func pressElsewhere(_ app: XCUIApplication) {
        element(app, "board.canvas").coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12)).tap()
    }

    // MARK: Tests

    func testTheAppOpensWithItsBoards() {
        let app = launch([])
        XCTAssertTrue(element(app, "boards.list").waitForExistence(timeout: 15))
    }

    func testANewBlankBoardOpensEmpty() {
        let app = launch([])
        openBlankBoard(app)
        waitForCount(app, "Empty")
    }

    func testANoteToolAddsANote() {
        let app = launch([])
        openBlankBoard(app)
        press(app, "tool.note")
        type(app, "Milk")
        pressElsewhere(app)
        waitForCount(app, "1 note")
    }

    /// Return on the centre makes a first branch, Return on a branch makes a sister,
    /// and Return on an empty new idea takes that idea away again: Trip, Food = 2 ideas.
    func testReturnInAMindMapMakesTheNextIdea() {
        let app = launch([])
        openBlankBoard(app)
        press(app, "tool.mindmap")
        type(app, "Trip\n")
        waitForCount(app, "2 ideas")      // the centre and its first branch (empty, being typed)
        type(app, "Food\n")
        waitForCount(app, "3 ideas")      // a sister of Food, empty, being typed
        type(app, "\n")
        waitForCount(app, "2 ideas")      // the empty idea went away
    }

    /// Adding a note is one step, typing its words is a second step: two undos reach Empty.
    func testUndoTakesTheLastThingAway() {
        let app = launch([])
        openBlankBoard(app)
        press(app, "tool.note")
        type(app, "Milk")
        pressElsewhere(app)
        waitForCount(app, "1 note")
        press(app, "board.undo")          // takes the words away; the empty note stays
        waitForCount(app, "1 note")
        press(app, "board.undo")          // takes the note away
        waitForCount(app, "Empty")
        XCTAssertFalse(element(app, "board.undo").isEnabled, "nothing is left to undo")
    }

    func testTheSendPageShowsItsThreeChoices() {
        let app = launch(["-board", "Summer", "-send"])
        XCTAssertTrue(element(app, "send.kind.note").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "send.kind.project").exists)
        XCTAssertTrue(element(app, "send.kind.todos").exists)
        let send = element(app, "send.send")
        XCTAssertTrue(send.exists)
        XCTAssertFalse(send.isEnabled)
        press(app, "send.cancel")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "send.cancel"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed)
    }

    func testSettingsShowsHelpAndTheVersion() {
        let app = launch(["-settings"])
        XCTAssertTrue(element(app, "settings.howItWorks").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "settings.whatsNew").exists)
        XCTAssertTrue(element(app, "settings.version").exists)
    }

    func testChoosingAShapeShowsItsBar() {
        let app = launch(["-board", "Summer", "-pick", "Worth"])
        XCTAssertTrue(element(app, "board.selectionBar").waitForExistence(timeout: 15))
        waitForCount(app, "12 ideas · 5 shapes · 2 notes")
        press(app, "sel.remove")
        waitForCount(app, "12 ideas · 4 shapes · 2 notes")
    }

    #if os(macOS)
    /// Tab makes an idea under the chosen one; Return the next one; Escape cancels the one being typed.
    func testTabMakesAnIdeaUnderTheChosenOne() {
        let app = launch([])
        openBlankBoard(app)
        press(app, "tool.mindmap")
        type(app, "Trip")
        type(app, "\t")
        waitForCount(app, "2 ideas")
        type(app, "Food")
        type(app, "\n")
        waitForCount(app, "3 ideas")
        type(app, "Bed")
        // Escape is Cancel: the idea just made goes away again.
        type(app, String(XCUIKeyboardKey.escape.rawValue))
        waitForCount(app, "2 ideas")
    }
    #endif
}
