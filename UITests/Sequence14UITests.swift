import XCTest

/// 0.14: a block round messages in a "Who does what" board. Every control is found by its identifier.
final class Sequence14UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitFor(_ app: XCUIApplication, _ id: String, toSay words: String) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear")
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: target)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 10), .completed, "\(id) said \(target.label), expected \(words)")
    }

    /// The made-up "Loan steps" board: a chosen message gets a "repeat" block (counted, chosen, with its own bar);
    /// Remove block takes the frame away again and leaves the messages.
    func testABlockIsMadeAndRemoved() {
        let app = XCUIApplication()
        var arguments = ["-board", "Loan", "-pick", "Ask for loan"]
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments.append("-sampleData")
        app.launchArguments = arguments
        app.launch()
        waitFor(app, "board.count", toSay: "4 people · 9 messages · 1 note · 1 section")

        let block = element(app, "sel.block")
        XCTAssertTrue(block.waitForExistence(timeout: 15), "no Block button")
        block.tap()
        for id in ["sel.block.repeat", "sel.block.if", "sel.block.maybe", "sel.block.other"] {
            XCTAssertTrue(element(app, id).waitForExistence(timeout: 5), "\(id) is missing in the Block menu")
        }
        element(app, "sel.block.repeat").tap()
        waitFor(app, "board.count", toSay: "4 people · 9 messages · 1 note · 1 section · 1 block")
        waitFor(app, "sequence.chosen", toSay: "repeat")
        XCTAssertTrue(element(app, "sel.words").exists)
        XCTAssertTrue(element(app, "sel.colour").exists)

        element(app, "sel.removeBlock").tap()
        waitFor(app, "board.count", toSay: "4 people · 9 messages · 1 note · 1 section")
    }
}
