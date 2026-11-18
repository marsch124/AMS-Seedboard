import XCTest

/// Pick 25: the menus. Written by the builder, run by the lead.
final class MenuUITests: XCTestCase {
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

    /// File ▸ New Board (⌘N) shows the starter choice as a page with Cancel; `-starters` opens it for pictures.
    func testTheStarterPageShowsItsChoicesAndCancel() {
        let app = launch(["-starters"])
        XCTAssertTrue(element(app, "starter.blank").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "starter.mindMap").exists)
        let cancel = element(app, "starters.cancel")
        XCTAssertTrue(cancel.exists)
        cancel.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "starters.cancel"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed)
    }

    #if os(macOS)
    /// The Insert menu lists every tool; View has the zoom lines; File has New Board.
    func testTheMacMenusListTheToolsAndTheZoom() {
        let app = launch(["-board", "Summer"])
        XCTAssertTrue(element(app, "board.canvas").waitForExistence(timeout: 15))
        let bar = app.menuBars.firstMatch

        let insert = bar.menuBarItems["Insert"]
        XCTAssertTrue(insert.waitForExistence(timeout: 10))
        insert.click()
        for name in ["Mind map", "Box", "Diamond", "Arrow", "Sticky note", "Text", "Frame"] {
            XCTAssertTrue(insert.menuItems[name].waitForExistence(timeout: 5), "Insert has no \(name)")
        }
        app.typeKey(.escape, modifierFlags: [])

        let view = bar.menuBarItems["View"]
        view.click()
        for name in ["Zoom In", "Zoom Out", "Actual Size", "Show the Whole Board"] {
            XCTAssertTrue(view.menuItems[name].waitForExistence(timeout: 5), "View has no \(name)")
        }
        app.typeKey(.escape, modifierFlags: [])

        let file = bar.menuBarItems["File"]
        file.click()
        XCTAssertTrue(file.menuItems["New Board"].waitForExistence(timeout: 5))
        XCTAssertTrue(file.menuItems["Send to PARAGON…"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }
    #endif
}
