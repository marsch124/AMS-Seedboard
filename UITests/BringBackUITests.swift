import XCTest

/// 0.2 pick 4: the page "Removed and earlier versions". Every control is found by its identifier.
final class BringBackUITests: XCTestCase {
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

    /// The page lists a removed example board; Bring back puts it into the boards list again.
    func testARemovedBoardIsListedAndComesBack() {
        // `-removed` opens the page over the main window.
        let app = launch(["-removed"])
        XCTAssertTrue(element(app, "kept.removed.Old garden plan").waitForExistence(timeout: 15), "the removed board is not listed")
        XCTAssertTrue(element(app, "kept.removed.Birthday party").exists, "the second removed board is not listed")
        XCTAssertTrue(element(app, "kept.board.Summer cabin").exists, "the board with earlier versions is not listed")
        XCTAssertFalse(element(app, "boards.row.Old garden plan").exists, "a removed board must not be in the boards list")

        press(app, "kept.bringBack.Old garden plan")
        // A short line confirms and offers "Open"; the board has left the Removed rows.
        XCTAssertTrue(element(app, "kept.open").waitForExistence(timeout: 10), "the line with Open did not appear")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "kept.removed.Old garden plan"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "the board is still among the removed")
        XCTAssertTrue(element(app, "kept.removed.Birthday party").exists, "the other removed board must stay")

        press(app, "kept.done")
        XCTAssertTrue(element(app, "boards.row.Old garden plan").waitForExistence(timeout: 10), "the board did not come back into the list")
    }
}
