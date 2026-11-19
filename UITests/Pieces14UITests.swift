import XCTest

/// 0.14: the Pieces page (More ▸ Add a piece…) and the brainstorm timer's choices. Sample mode starts with no
/// pieces. Every control is found by its identifier; every wait is for an element. (Written, not run.)
final class Pieces14UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testPiecesPageAndTimerChoices() {
        let app = XCUIApplication()
        var arguments = ["-sampleData", "-board", "balcony"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif

        let more = element(app, "board.more")
        XCTAssertTrue(more.waitForExistence(timeout: 15), "no More button")
        more.tap()
        let add = element(app, "more.addPiece")
        XCTAssertTrue(add.waitForExistence(timeout: 5), "no Add a piece… line")
        add.tap()

        XCTAssertTrue(element(app, "pieces.page").waitForExistence(timeout: 5), "the Pieces page did not open")
        XCTAssertTrue(element(app, "pieces.empty").waitForExistence(timeout: 5), "no empty line")
        let close = element(app, "pieces.close")
        XCTAssertTrue(close.exists, "no Close")
        close.tap()
        XCTAssertTrue(element(app, "pieces.page").waitForNonExistence(timeout: 5), "the page did not close")

        // The timer: the choices come first, Stop after a start.
        more.tap()
        let timer = element(app, "more.brainstorm")
        XCTAssertTrue(timer.waitForExistence(timeout: 5), "no Brainstorm timer line")
        timer.tap()
        XCTAssertTrue(element(app, "timer.min.5").waitForExistence(timeout: 5), "no 5 min choice")
        XCTAssertTrue(element(app, "timer.min.10").exists, "no 10 min choice")
        element(app, "timer.min.5").tap()
        XCTAssertTrue(element(app, "timer.left").waitForExistence(timeout: 5), "no time left")
        element(app, "timer.stop").tap()
        XCTAssertTrue(element(app, "timer.pill").waitForNonExistence(timeout: 5), "the pill did not go")
    }
}
