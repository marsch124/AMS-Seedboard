import XCTest
@testable import SeedboardCore

/// 0.7: a chosen bar that is done says the day it was done.
final class DoneDay07Tests: XCTestCase {
    func testTheDoneButtonAndTheDatesPageSayTheDay() {
        let today = Day(year: 2026, month: 11, day: 18)
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: today, days: 5)
        let walls = board.addBar("Walls", start: today + 7, days: 5)
        let roof = board.addBar("Roof", start: today + 14, days: 5)

        // Not done: just "Done", no line on the Dates page.
        XCTAssertEqual(board.doneWord(for: [permit], today: today), "Done")
        XCTAssertNil(board.doneLine(of: permit, today: today))

        board.setDone([permit], true, on: today)
        XCTAssertEqual(board.doneWord(for: [permit], today: today), "Done 18 Nov")
        XCTAssertEqual(board.doneLine(of: permit, today: today), "Done on 18 Nov")

        // Another year carries the year.
        board.setDone([walls], true, on: Day(year: 2025, month: 12, day: 3))
        XCTAssertEqual(board.doneWord(for: [walls], today: today), "Done 3 Dec 2025")

        // Several chosen, or one that is not done: the plain word.
        XCTAssertEqual(board.doneWord(for: [permit, walls], today: today), "Done")
        XCTAssertEqual(board.doneWord(for: [roof], today: today), "Done")

        // Mark taken off: the day goes with it.
        board.setDone([permit], false, on: today)
        XCTAssertEqual(board.doneWord(for: [permit], today: today), "Done")
        XCTAssertNil(board.doneLine(of: permit, today: today))
    }
}
