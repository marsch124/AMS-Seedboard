import XCTest

/// 0.19, timelines: the Weeks / Months switch, and the three small pages (Repeat, Who, Note) with Cancel and Save.
/// Found by identifiers only.
final class Timeline19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func press(_ app: XCUIApplication, _ id: String) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear")
        target.tap()
    }

    func testTheScaleSwitchAndTheSmallPagesShow() {
        let app = XCUIApplication()
        var arguments: [String] = []
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        press(app, "boards.new")
        press(app, "starter.timeline")
        XCTAssertTrue(element(app, "timeline.canvas").waitForExistence(timeout: 15))

        // Weeks and Months in one press; the zoom's own word follows.
        press(app, "timeline.months")
        let months = expectation(for: NSPredicate(format: "label == 'Months' OR value == 'Months'"), evaluatedWith: element(app, "zoom.value"))
        XCTAssertEqual(XCTWaiter().wait(for: [months], timeout: 10), .completed, "the zoom did not say Months")
        press(app, "timeline.weeks")

        // Add a bar: it is chosen, so its chips show Note, Repeat and Who.
        press(app, "tool.bar")
        let field = element(app, "board.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText("Gym\n")
        press(app, "sel.repeat")
        XCTAssertTrue(element(app, "repeat.every").waitForExistence(timeout: 10), "the Repeat page did not open")
        XCTAssertTrue(element(app, "repeat.times").exists)
        press(app, "repeat.cancel")
        press(app, "sel.who")
        XCTAssertTrue(element(app, "who.field").waitForExistence(timeout: 10), "the Who page did not open")
        press(app, "who.cancel")
        press(app, "sel.note")
        XCTAssertTrue(element(app, "note.field").waitForExistence(timeout: 10), "the Note page did not open")
        XCTAssertTrue(element(app, "note.save").exists)
        press(app, "note.cancel")
    }
}
