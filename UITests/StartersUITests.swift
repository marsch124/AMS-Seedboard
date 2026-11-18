import XCTest

/// 0.3: the Starters page — all starters in order (the seven built-in ones and the two own starters of
/// sample mode), a row with its Edit menu for each, and Done. Every control is found by its identifier.
final class StartersUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testTheStartersPageListsEveryStarterAndClosesWithDone() {
        let app = XCUIApplication()
        var arguments = ["-sampleData", "-starterPage"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif

        XCTAssertTrue(element(app, "starters.page").waitForExistence(timeout: 20), "the Starters page did not open")
        for id in ["blank", "mindMap", "flow", "prosCons", "steps", "timeline", "sequence",
                   "00000000-0000-0000-0000-0000000000A1", "00000000-0000-0000-0000-0000000000A2"] {
            XCTAssertTrue(element(app, "starters.row.\(id)").waitForExistence(timeout: 10), "no row for \(id)")
        }
        XCTAssertTrue(element(app, "starters.more.mindMap").exists, "a row has its Edit menu")

        let done = element(app, "starters.done")
        XCTAssertTrue(done.exists)
        done.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "starters.page"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "Done did not close the page")
    }
}
