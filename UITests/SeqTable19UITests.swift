import XCTest

/// 0.19: the "Note…" page of a chosen message in a "Who does what" board, and "Tick Column" of a chosen table.
/// Every control is found by its identifier.
final class SeqTable19UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = extra
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        return app
    }

    func testANoteOpensItsPageWithCancelAndSave() {
        let app = launch(["-board", "Loan", "-pick", "Ask for loan"])
        let note = element(app, "sel.note")
        XCTAssertTrue(note.waitForExistence(timeout: 15), "no Note… button on a chosen message")
        note.tap()
        XCTAssertTrue(element(app, "note.field").waitForExistence(timeout: 5), "no field on the note page")
        XCTAssertTrue(element(app, "note.cancel").exists, "no Cancel")
        XCTAssertTrue(element(app, "note.save").exists, "no Save")
        element(app, "note.cancel").tap()
        XCTAssertTrue(element(app, "sel.note").waitForExistence(timeout: 5), "the board did not come back after Cancel")
    }

    func testATableBarHasTickColumn() throws {
        #if os(iOS)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom != .phone, "The plate's corner takes presses on the Mac and the iPad.")
        #endif
        let app = launch(["-board", "Summer"])
        let corner = element(app, "tool.shapes")
        XCTAssertTrue(corner.waitForExistence(timeout: 15), "no shapes corner")
        corner.tap()
        let table = element(app, "plate.shape.table")
        XCTAssertTrue(table.waitForExistence(timeout: 5), "no Table line on the plate")
        table.tap()
        let tick = element(app, "sel.table.tick")
        XCTAssertTrue(tick.waitForExistence(timeout: 10), "no Tick Column in the bar of the new table")
        tick.tap()
        XCTAssertTrue(element(app, "sel.table.tick").waitForExistence(timeout: 5), "the bar went away after Tick Column")
    }
}
