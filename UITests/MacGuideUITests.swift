import XCTest

/// 0.5 pick 29: Help ▸ How Seedboard Works and What's New open the guide in a small window of its own (the Mac).
/// Every control is found by its identifier; every wait is for an element.
final class MacGuideUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    #if os(macOS)
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testTheGuideWindowOpensAndSwitchesBetweenItsTwoPages() {
        let app = XCUIApplication()
        // `-guide` opens the window as Help ▸ How Seedboard Works does.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-guide", "-sampleData"]
        app.launch()
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }

        XCTAssertTrue(element(app, "guide.window").waitForExistence(timeout: 15), "the guide window did not open")
        let how = element(app, "guide.tab.how"), news = element(app, "guide.tab.news")
        XCTAssertTrue(how.waitForExistence(timeout: 5))
        XCTAssertTrue(news.exists)
        news.click()
        XCTAssertTrue(news.waitForExistence(timeout: 5))
        how.click()
        // Escape closes it, as it closes every page of the app.
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element(app, "guide.window").waitForNonExistence(timeout: 5), "Escape did not close the guide")
    }
    #endif
}
