import XCTest

/// 0.19 (pick 44): the Send page has a Preview of the text it writes. `-send` opens the page (as Send to PARAGON does).
/// Found by identifiers only. (Written, not run.)
final class Share19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testTheSendPageShowsAPreview() {
        let app = XCUIApplication()
        var arguments = ["-board", "Summer cabin", "-send", "-sampleData"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif
        XCTAssertTrue(element(app, "send.preview").waitForExistence(timeout: 20), "the Preview did not appear")
        XCTAssertTrue(element(app, "send.preview.text").exists, "the Preview shows no text")
    }
}
