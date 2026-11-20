import XCTest

/// 0.17 (his pick "2 Coloured cards", 20 Nov 2026): the iPhone list has a big green heading, the gear alone at the
/// top right, a Starters card, and every card's heading folds it. Found by identifiers only.
final class List17UITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testCardsFoldAndStartersShow() throws {
        #if os(iOS)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "The Starters card is the iPhone's list only.")
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData"]
        app.launch()
        XCTAssertTrue(element(app, "boards.title").waitForExistence(timeout: 15), "the big heading did not appear")
        XCTAssertTrue(element(app, "boards.countLine").exists, "the count line is missing")
        XCTAssertTrue(element(app, "boards.card.starters").exists, "the Starters card is missing")
        XCTAssertFalse(element(app, "boards.version").exists, "the version is still on the list")

        let row = element(app, "boards.row.Summer cabin")
        let fold = element(app, "boards.fold.pinned")
        // Folds are kept per device: open Pinned first if an earlier run left it folded.
        if !row.waitForExistence(timeout: 5) { fold.tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the Pinned card shows no boards")
        fold.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "Pinned did not fold")
        fold.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Pinned did not unfold")
        #endif
    }
}
