import XCTest

/// Tidy shapes (0.5, pick 30): what a screen test can prove of it — the switch in the Draw plate.
/// The rule itself is proved as data (Pencil05Tests); the hand's line, the rest of the tip and the
/// Pencil need a real iPad.
final class PencilUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with made-up boards. `-sampleData` always goes last.
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = extra
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 5) { app.activate() }
        #endif
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitForValue(_ target: XCUIElement, _ words: String, file: StaticString = #filePath, line: UInt = #line) {
        let match = expectation(for: NSPredicate(format: "value == %@", words), evaluatedWith: target)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 10), .completed,
                       "the switch said \(String(describing: target.value)), expected \(words)", file: file, line: line)
    }

    /// The Draw plate holds the switch "Tidy shapes" between the colours and Done. It is off at
    /// first (0.5 ships with it off), a press turns it on, another off again.
    func testTheDrawPlateHoldsTheTidyShapesSwitchOffAtFirst() {
        let app = launch(["-board", "Sketch", "-draw"])
        let tidy = element(app, "draw.tidy")
        XCTAssertTrue(tidy.waitForExistence(timeout: 15), "draw.tidy did not appear")
        XCTAssertEqual(tidy.label, "Tidy shapes")
        waitForValue(tidy, "Off")
        tidy.tap()
        waitForValue(tidy, "On")
        tidy.tap()
        waitForValue(tidy, "Off")
        XCTAssertTrue(element(app, "draw.done").exists)
    }

    /// With the launch word `-tidyShapes` the switch is on from the start.
    func testTheLaunchWordTurnsTheSwitchOn() {
        let app = launch(["-board", "Sketch", "-draw", "-tidyShapes"])
        let tidy = element(app, "draw.tidy")
        XCTAssertTrue(tidy.waitForExistence(timeout: 15), "draw.tidy did not appear")
        waitForValue(tidy, "On")
    }
}
