import XCTest

/// 0.2 picks 7, 17 and 18: the bar for what is chosen (one row, whatever is chosen), the menu of a
/// thing and of empty board, and copy and paste between boards.
/// Every control is found by its identifier; every wait is for an element or a value.
final class BarUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers (the same launch pattern as SeedboardUITests)

    @discardableResult
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

    private func press(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 15), "\(id) did not appear", file: file, line: line)
        target.tap()
    }

    private func waitForCount(_ app: XCUIApplication, _ words: String, file: StaticString = #filePath, line: UInt = #line) {
        let count = element(app, "board.count")
        XCTAssertTrue(count.waitForExistence(timeout: 15), "board.count did not appear", file: file, line: line)
        // The iPhone gives the words as the label, the Mac as the value.
        let match = expectation(for: NSPredicate(format: "label == %@ OR value == %@", words, words), evaluatedWith: count)
        let result = XCTWaiter().wait(for: [match], timeout: 10)
        XCTAssertEqual(result, .completed, "count line was \(count.label)\(String(describing: count.value)), expected \(words)", file: file, line: line)
    }

    // MARK: Tests

    /// A shape, an idea, a note, an arrow, several things and a frame each have their bar, with
    /// their main buttons and Remove — and the bar is one row (on the iPhone too).
    func testEveryKindHasItsBarInOneRow() {
        let kinds: [(name: String, arguments: [String], has: [String])] = [
            ("shape", ["-board", "Summer", "-pick", "Worth"], ["sel.shape", "sel.remove"]),
            ("idea", ["-board", "Summer", "-pick", "Loan"], ["sel.child", "sel.sister", "sel.remove"]),
            ("note", ["-board", "Summer", "-pick", "timber"], ["sel.colour", "sel.remove"]),
            ("arrow", ["-board", "Summer", "-pickArrow", "Yes"], ["sel.words", "sel.line", "sel.ends", "sel.remove"]),
            ("several", ["-board", "Summer", "-pickAll", "New idea,Worth,plan"], ["sel.lineUp", "sel.todo", "sel.remove"]),
            ("frame", ["-board", "Lanes", "-pick", "Web shop"], ["sel.lanes", "sel.remove"]),
        ]
        for kind in kinds {
            let app = launch(kind.arguments)
            let bar = element(app, "board.selectionBar")
            XCTAssertTrue(bar.waitForExistence(timeout: 15), "the bar of the chosen \(kind.name) did not appear")
            for id in kind.has {
                XCTAssertTrue(element(app, id).waitForExistence(timeout: 5), "the bar of the chosen \(kind.name) has no \(id)")
            }
            // One row: a button (36 high on a touch screen, 28 on the Mac) and 5 points of plate above and below it.
            XCTAssertLessThan(bar.frame.height, 60, "the bar of the chosen \(kind.name) is more than one row")
            app.terminate()
        }
    }

    /// Copy in the menu of a thing, Paste in the menu of empty board — in ANOTHER board: the thing is there.
    func testPasteAfterCopyAddsTheThingInAnotherBoard() {
        // `-menu` opens the menu of the picked shape: the system's menu on the Mac, a plate on a touch screen.
        var app = launch(["-board", "Summer", "-pick", "Worth", "-menu"])
        waitForCount(app, "12 ideas · 5 shapes · 2 notes")
        press(app, "menu.copy")
        waitForCount(app, "12 ideas · 5 shapes · 2 notes")
        app.terminate()

        // The clipboard outlives the app. A new blank board: nothing on it.
        app = launch([])
        press(app, "boards.new")
        press(app, "starter.blank")
        waitForCount(app, "Empty")
        // The menu of empty board: a right-click on the Mac, a still press on a touch screen.
        let spot = element(app, "board.canvas").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        #if os(macOS)
        spot.rightClick()
        #else
        spot.press(forDuration: 0.9)
        #endif
        press(app, "menu.paste")
        waitForCount(app, "1 shape")
        // One step for Undo.
        press(app, "board.undo")
        waitForCount(app, "Empty")
    }
}
