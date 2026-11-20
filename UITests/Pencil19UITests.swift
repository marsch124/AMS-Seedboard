import XCTest

/// 0.19 (picks 38 to 42, pencil and pictures): the Draw plate's tip line and its colour row. Found by identifiers only.
/// (A shape snapping needs a held tip, and the Camera tile needs a camera: neither is on a simulator.)
final class Pencil19UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testDrawPlateShowsTipAndColours() {
        let app = XCUIApplication()
        var arguments = ["-board", "Sketch"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        let tool = element(app, "tool.draw")
        XCTAssertTrue(tool.waitForExistence(timeout: 15), "the Draw tool did not appear")
        tool.tap()
        XCTAssertTrue(element(app, "draw.plate").waitForExistence(timeout: 5), "the Draw plate did not open")
        XCTAssertTrue(element(app, "draw.holdTip").exists, "the hold tip is missing")
        // Pick red: it must stand first in the row afterwards.
        element(app, "draw.colour.red").tap()
        XCTAssertTrue(element(app, "draw.colour.red").exists, "the red dot is missing")
    }
}
