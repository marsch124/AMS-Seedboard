import XCTest

/// 0.19 (canvas): the paper colour page and Read mode, found by identifiers only.
final class Paper19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testReadModePillAndPaperSwatches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData"]
        app.launch()
        XCTAssertTrue(element(app, "boards.new").waitForExistence(timeout: 15))
        element(app, "boards.new").tap()
        element(app, "starter.blank").tap()
        element(app, "board.more").tap()
        XCTAssertTrue(element(app, "more.paper").waitForExistence(timeout: 5), "Background colour… is missing")
        element(app, "more.paper").tap()
        XCTAssertTrue(element(app, "paper.swatch.warmGrey").waitForExistence(timeout: 5), "the swatches are missing")
        XCTAssertTrue(element(app, "paper.swatch.plain").exists)
        element(app, "paper.done").tap()
        element(app, "board.more").tap()
        XCTAssertTrue(element(app, "more.readMode").waitForExistence(timeout: 5), "Read mode is missing")
        element(app, "more.readMode").tap()
        XCTAssertTrue(element(app, "readmode.pill").waitForExistence(timeout: 5), "the Read mode pill is missing")
        element(app, "readmode.done").tap()
    }
}
