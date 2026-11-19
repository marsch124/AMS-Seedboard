import XCTest

/// 0.13: "Still thinking about these?" on the iPhone's list, Not now hides a board there, and Settings holds the
/// six switches. Every control is found by its identifier; every wait is for an element.
final class Switches13UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testStillThinkingAndTheSwitches() throws {
        #if os(iOS)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "The list's nudge is checked on the iPhone.")
        let app = XCUIApplication()
        // A clean slate for this device's "Not now" days and switches.
        app.launchArguments = ["-nudge.notNow.v1", "<dict/>", "-switch.nudge", "YES", "-sampleData"]
        app.launch()

        XCTAssertTrue(element(app, "home.heading.Still thinking about these?").waitForExistence(timeout: 15), "no nudge heading")
        let later = element(app, "nudge.notNow.Arrow looks")
        XCTAssertTrue(later.waitForExistence(timeout: 5), "no Not now on the old board")
        XCTAssertTrue(element(app, "nudge.putAway.Arrow looks").exists, "no Put away on the old board")
        later.tap()
        XCTAssertTrue(element(app, "nudge.board.Arrow looks").waitForNonExistence(timeout: 5), "Not now did not hide the board")

        element(app, "boards.settings").tap()
        for id in ["settings.taps", "settings.calendarAuto", "settings.nudge", "settings.doneTicksParagon", "settings.readParagon", "settings.search"] {
            let toggle = element(app, id)
            for _ in 0..<4 where !toggle.exists { app.swipeUp() }
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "\(id) is missing in Settings")
        }
        #endif
    }
}
