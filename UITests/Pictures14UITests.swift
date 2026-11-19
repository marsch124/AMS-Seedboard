import XCTest

/// 0.14: "Lift out" is in a chosen picture's bar; the PDF question ("This PDF has 6 pages", launch word `-askPDF`)
/// offers Only page 1, All pages and Cancel. Found by identifier. (Written, not run.)
final class Pictures14UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-sampleData", "-board", "balcony"] + extra
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif
        return app
    }

    func testAChosenPictureHasLiftOut() {
        let app = launch(["-pickPicture"])
        XCTAssertTrue(element(app, "picture.liftout").waitForExistence(timeout: 15), "Lift out did not appear")
    }

    func testThePDFQuestionOffersThreeAnswers() {
        let app = launch(["-askPDF"])
        XCTAssertTrue(element(app, "pdf.ask.first").waitForExistence(timeout: 15), "Only page 1 did not appear")
        XCTAssertTrue(element(app, "pdf.ask.all").exists, "All pages is missing")
        let cancel = element(app, "pdf.ask.cancel")
        XCTAssertTrue(cancel.exists, "Cancel is missing")
        cancel.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "pdf.ask.first"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "the question did not close")
    }
}
