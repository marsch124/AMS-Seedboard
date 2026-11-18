import XCTest

/// 0.5, pick 22: the Share plate. `-share` opens it a moment after the board is shown (as "Share…" in More and
/// in the File menu does). The sample board "Lanes and shapes" (`-board Lanes`) has one named frame, so
/// "Each frame a page" is offered; nothing is chosen, so "What is chosen" is not.
/// Every control is found by its identifier; every wait is for an element or a value. (Written, not run.)
final class ShareUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func words(of element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }

    private func waitFor(_ element: XCUIElement, toSay words: String) {
        let said = expectation(for: NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words), evaluatedWith: element)
        XCTAssertEqual(XCTWaiter().wait(for: [said], timeout: 10), .completed, "the line was “\(self.words(of: element))”, not “\(words)”")
    }

    func testTheSharePlateOffersWhatAndAsAndCancelClosesIt() {
        let app = XCUIApplication()
        var arguments = ["-sampleData", "-board", "Lanes", "-share"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif

        // What: the whole board and each frame a page; nothing is chosen, so that tile is not there.
        XCTAssertTrue(element(app, "share.what.whole").waitForExistence(timeout: 20), "the Share plate did not open")
        XCTAssertTrue(element(app, "share.what.frames").exists, "Each frame a page is missing")
        XCTAssertFalse(element(app, "share.what.chosen").exists, "nothing is chosen, so What is chosen must not be offered")

        // As: Picture, PDF, Words; it starts at the whole board as a picture.
        XCTAssertTrue(element(app, "share.as.picture").exists, "Picture is missing")
        XCTAssertTrue(element(app, "share.as.pdf").exists, "PDF is missing")
        XCTAssertTrue(element(app, "share.as.words").exists, "Words is missing")
        let line = element(app, "share.line")
        XCTAssertTrue(line.exists, "the line that says what is shared is missing")
        waitFor(line, toSay: "One picture of the whole board.")

        // The line follows the tiles.
        element(app, "share.as.pdf").tap()
        waitFor(line, toSay: "The whole board on one page")
        element(app, "share.what.frames").tap()
        waitFor(line, toSay: "One page with the named frame")

        // The main button is there and can be pressed; Cancel closes the plate and shares nothing.
        let share = element(app, "share.share")
        XCTAssertTrue(share.exists, "the Share button is missing")
        XCTAssertTrue(share.isEnabled, "the Share button cannot be pressed")
        element(app, "share.cancel").tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "share.cancel"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "the Share plate did not close")
        XCTAssertTrue(element(app, "board.more").exists, "the board is not back")
    }
}
