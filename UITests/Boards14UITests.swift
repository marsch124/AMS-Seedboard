import XCTest

/// 0.14: "Join with…" from a card's menu opens a page with Cancel and Join; Join stays off until a board is chosen.
final class Boards14UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testJoinPage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData"]
        app.launch()
        let card = element(app, "boards.row.Arrow looks")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "no board row")
        #if os(macOS)
        card.rightClick()
        #else
        card.press(forDuration: 1)
        #endif
        let join = element(app, "card.join")
        XCTAssertTrue(join.waitForExistence(timeout: 5), "no Join with… line")
        join.tap()
        XCTAssertTrue(element(app, "join.page").waitForExistence(timeout: 5), "no join page")
        XCTAssertTrue(element(app, "join.cancel").exists, "no Cancel")
        XCTAssertFalse(element(app, "join.join").isEnabled, "Join is on before a board is chosen")
        element(app, "join.cancel").tap()
        XCTAssertTrue(element(app, "join.page").waitForNonExistence(timeout: 5), "Cancel did not close the page")
    }
}
