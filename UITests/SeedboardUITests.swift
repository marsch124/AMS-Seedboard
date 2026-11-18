import XCTest

/// One screen test, found by identifiers: the list of boards opens.
final class SeedboardUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testTheAppOpensWithItsBoards() {
        let app = XCUIApplication()
        var arguments = ["-sampleData"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(element(app, "boards.list").waitForExistence(timeout: 15))
    }
}
