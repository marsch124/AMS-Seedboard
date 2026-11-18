import XCTest

/// 0.5, the owner's pick for the home page: his boards come first. The starters are ONE strip above "Pinned",
/// and the first board cards are in sight without sliding the page.
/// Every control is found by its identifier; every wait is for an element.
final class HomeStripUITests: XCTestCase {
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

    private func found(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        return target
    }

    func testTheStartersAreOneStripAbovePinnedAndTheFirstBoardsAreInSight() throws {
        let app = launch()
        XCTAssertTrue(element(app, "boards.list").waitForExistence(timeout: 15), "the list did not appear")
        // Mac and iPad: the home page is beside the list. On the iPhone the list itself is the home.
        guard element(app, "board.none").waitForExistence(timeout: 3) else {
            throw XCTSkip("The iPhone has no home page: its list is the home.")
        }

        let strip = found(app, "home.starterStrip")
        let blank = found(app, "home.starter.blank")
        let mindMap = found(app, "home.starter.mindMap")
        let flow = found(app, "home.starter.flow")
        let pinned = found(app, "home.heading.Pinned")
        let recent = found(app, "home.heading.Recent")
        let firstPinned = found(app, "home.board.Summer cabin")
        let firstRecent = found(app, "home.board.Build timeline")

        // ONE strip: the starters stand side by side in one row, the Blank board first.
        XCTAssertEqual(blank.frame.minY, mindMap.frame.minY, accuracy: 1, "the starters are not in one row")
        XCTAssertEqual(blank.frame.minY, flow.frame.minY, accuracy: 1, "the starters are not in one row")
        XCTAssertLessThan(blank.frame.minX, mindMap.frame.minX, "the Blank board is not the first starter")
        XCTAssertLessThan(mindMap.frame.minX, flow.frame.minX)
        XCTAssertLessThan(strip.frame.height, 160, "the strip is higher than one row of cards")

        // His boards come right under it: the strip, then Pinned, then Recent.
        XCTAssertLessThanOrEqual(strip.frame.maxY, pinned.frame.minY, "the starters are not above Pinned")
        XCTAssertLessThan(pinned.frame.minY, firstPinned.frame.minY)
        XCTAssertLessThan(firstPinned.frame.maxY, recent.frame.maxY)
        XCTAssertLessThan(recent.frame.minY, firstRecent.frame.minY)

        // The first board cards are whole in sight without sliding the page.
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(firstPinned.frame.maxY, window.maxY, "the first pinned board is not in sight")
        XCTAssertLessThanOrEqual(firstRecent.frame.maxY, window.maxY, "the first recent board is not in sight")
        XCTAssertGreaterThanOrEqual(firstPinned.frame.minY, window.minY)

        // The header has no button of its own any more; the strip's first card begins a board at one press.
        XCTAssertFalse(element(app, "empty.newBoard").exists, "the header still has its New board button")
        blank.tap()
        XCTAssertTrue(element(app, "board.canvas").waitForExistence(timeout: 15), "the new board did not open")
    }
}
