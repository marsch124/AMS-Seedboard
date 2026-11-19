import XCTest

/// 0.14 idea 25: a table on an ordinary board — "Table" on the shapes plate, and the bar of the chosen table
/// (Add row, Add column, Remove row, Remove column). Every control is found by its identifier.
final class Table14UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testATableIsAddedFromTheShapesPlateAndItsBarHasFourLines() throws {
        #if os(iOS)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom != .phone, "The plate's corner takes presses on the Mac and the iPad.")
        #endif
        let app = XCUIApplication()
        var arguments = ["-board", "Summer", "-sampleData"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        app.launchArguments = arguments
        app.launch()

        let corner = element(app, "tool.shapes")
        XCTAssertTrue(corner.waitForExistence(timeout: 15), "no shapes corner")
        corner.tap()
        let table = element(app, "plate.shape.table")
        XCTAssertTrue(table.waitForExistence(timeout: 5), "no Table line on the plate")
        table.tap()

        let addRow = element(app, "sel.table.addRow")
        XCTAssertTrue(addRow.waitForExistence(timeout: 10), "no Add row in the bar of the new table")
        XCTAssertTrue(element(app, "sel.table.addColumn").exists, "no Add column")
        XCTAssertTrue(element(app, "sel.table.removeRow").exists, "no Remove row")
        XCTAssertTrue(element(app, "sel.table.removeColumn").exists, "no Remove column")
        addRow.tap()
        XCTAssertTrue(element(app, "sel.table.removeRow").waitForExistence(timeout: 5), "the bar went away after Add row")
    }
}
