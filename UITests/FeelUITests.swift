import XCTest

/// 0.5 (the feel lane): an empty board invites — the sprout, "What is on your mind?" and three ways to begin.
/// One press begins, and the invitation goes. Every control is found by its identifier.
final class FeelUITests: XCTestCase {
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

    func testAnEmptyBoardInvitesAndOnePressBegins() {
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

        press(app, "boards.new")
        press(app, "starter.blank")
        for id in ["board.empty", "empty.words", "empty.mindmap", "empty.note", "empty.paste"] {
            XCTAssertTrue(element(app, id).waitForExistence(timeout: 15), "\(id) did not appear")
        }
        #if os(macOS)
        XCTAssertTrue(element(app, "empty.hint").exists, "the Mac's quiet line is missing")
        #endif

        // One press does what the tool does: a sticky note is there, and the invitation has gone.
        press(app, "empty.note")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "empty.note"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "the invitation stayed on a board that holds a note")
        let count = element(app, "board.count")
        let one = expectation(for: NSPredicate(format: "label == %@ OR value == %@", "1 note", "1 note"), evaluatedWith: count)
        XCTAssertEqual(XCTWaiter().wait(for: [one], timeout: 10), .completed, "the sticky note was not made")
    }
}
