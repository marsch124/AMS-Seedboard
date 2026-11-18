import XCTest

/// 0.5 pick 16: the small purple line under the top bar of a board that is a project in PARAGON.
/// Found by its identifiers. With made-up boards there is no PARAGON, so it says "not checked on this device yet".
final class EchoUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with made-up boards. `-sampleData` always goes last.
    private func launch(_ extra: [String]) -> XCUIApplication {
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

    /// A sent board carries the line with its words and "Open in PARAGON"; a board that was never sent has none.
    func testASentBoardSaysWhatItBecameInParagon() {
        let app = launch(["-board", "Workshop"])
        XCTAssertTrue(element(app, "board.sentLine").waitForExistence(timeout: 15), "the line under the top bar did not appear")
        let words = element(app, "board.sentLine.words")
        XCTAssertTrue(words.exists, "the line has no words")
        XCTAssertTrue(words.label.hasPrefix("Project “Workshop bench”"), "the line does not name the project: \(words.label)")
        XCTAssertTrue(words.label.contains("not checked on this device yet"), "without PARAGON the line must say so: \(words.label)")
        XCTAssertTrue(element(app, "board.sentLine.open").exists, "Open in PARAGON is missing")

        let other = launch(["-board", "Garage"])
        XCTAssertTrue(element(other, "board.canvas").waitForExistence(timeout: 15), "the board did not open")
        XCTAssertFalse(element(other, "board.sentLine").exists, "a board that was never sent must not carry the line")
    }
}
