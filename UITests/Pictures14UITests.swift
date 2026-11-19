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
        var arguments = ["-board", "balcony"] + extra + ["-sampleData"]
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
        XCTAssertTrue(element(app, "board.selectionBar").waitForExistence(timeout: 15), "the picture's bar did not appear")
        // On a narrow screen Lift out waits behind the "…".
        let lift = element(app, "picture.liftout")
        if !lift.waitForExistence(timeout: 3) {
            element(app, "sel.overflow").tap()
            XCTAssertTrue(lift.waitForExistence(timeout: 10), "Lift out is neither in the bar nor behind the …")
        }
    }

    /// The question is the system's own: on iPhone and iPad its buttons do not carry the identifiers given in
    /// SwiftUI, so they are found by identifier OR by their words.
    private func answer(_ app: XCUIApplication, _ id: String, _ words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ OR label == %@", id, words)).firstMatch
    }

    func testThePDFQuestionOffersItsAnswers() {
        let app = launch(["-askPDF"])
        let first = answer(app, "pdf.ask.first", "Only page 1")
        XCTAssertTrue(first.waitForExistence(timeout: 15), "Only page 1 did not appear")
        XCTAssertTrue(answer(app, "pdf.ask.all", "All pages").exists, "All pages is missing")
        first.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: first)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "the question did not close")
    }
}
