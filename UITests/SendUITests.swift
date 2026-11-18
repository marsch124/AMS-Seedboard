import XCTest

/// 0.5, the Send page: the row "Add what is new", the box "What PARAGON gets" and the switches.
/// Every control is found by its identifier; every wait is for an element.
final class SendUITests: XCTestCase {
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

    /// A board that went to PARAGON before (`-sentBefore`): "Add what is new" is the first row, the box and its
    /// count line are there, what cannot follow is said, and "Send a fresh copy" goes to the whole-note rows.
    func testTheSendPageOffersWhatIsNewAndShowsWhatParagonGets() {
        let app = launch(["-board", "Summer", "-send", "-sentBefore"])
        XCTAssertTrue(element(app, "send.kind.add").waitForExistence(timeout: 15), "send.kind.add did not appear")
        XCTAssertTrue(element(app, "send.kind.note").exists)
        XCTAssertTrue(element(app, "send.kind.project").exists)
        XCTAssertTrue(element(app, "send.kind.todos").exists)
        XCTAssertTrue(element(app, "send.gets").exists)
        XCTAssertTrue(element(app, "send.count").exists)
        XCTAssertTrue(element(app, "send.cannotFollow").exists)
        // Adding has no name of its own: the name field belongs to a whole note or project.
        XCTAssertFalse(element(app, "send.title").exists)

        press(app, "send.freshCopy")
        XCTAssertTrue(element(app, "send.title").waitForExistence(timeout: 10), "send.title did not appear")

        // Inbox to-dos can say where they come from.
        press(app, "send.kind.todos")
        XCTAssertTrue(element(app, "send.sayOrigin").waitForExistence(timeout: 10), "send.sayOrigin did not appear")
        press(app, "send.cancel")
    }

    /// A board that was never sent has no such row; a timeline ("Build timeline") has the switch for its start days.
    func testATimelineHasTheStartSwitchAndNoAddRow() {
        let app = launch(["-board", "Build", "-send"])
        XCTAssertTrue(element(app, "send.kind.note").waitForExistence(timeout: 15), "send.kind.note did not appear")
        XCTAssertFalse(element(app, "send.kind.add").exists)
        XCTAssertTrue(element(app, "send.gets").exists)
        press(app, "send.remindStarts")
        press(app, "send.cancel")
    }
}
