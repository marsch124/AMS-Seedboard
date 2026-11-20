import XCTest

/// 0.19 (maps): a mind map's More menu offers Number the branches and Map look. Found by identifiers only.
final class Maps19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testMoreMenuOffersNumberBranchesAndMapLook() {
        let app = XCUIApplication()
        var arguments = ["-board", "Summer"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        let more = element(app, "board.more")
        XCTAssertTrue(more.waitForExistence(timeout: 15), "the More button did not appear")
        more.tap()
        XCTAssertTrue(element(app, "more.numberBranches").waitForExistence(timeout: 5), "Number the branches is missing")
        XCTAssertTrue(element(app, "more.mapLook").exists, "Map look is missing")
    }
}
