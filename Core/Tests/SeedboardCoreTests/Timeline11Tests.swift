import XCTest
@testable import SeedboardCore

final class Timeline11Tests: XCTestCase {
    func testWrongYearsAreRefusedAndMarksAreCapped() {
        XCTAssertFalse(DayRange.sane(Day(year: 1, month: 1, day: 1)))
        XCTAssertFalse(DayRange.sane(Day(year: 9999, month: 12, day: 31)))
        XCTAssertTrue(DayRange.sane(Day(year: 2026, month: 12, day: 1)))
        let ticks = TimelineGeometry.ticks(from: Day(year: 1, month: 1, day: 1), to: Day(year: 9999, month: 1, day: 1), scale: .days)
        XCTAssertEqual(ticks.count, DayRange.mostMarks)
    }

    func testDueDayWordsAndProjectText() {
        var board = Board(title: "Trip")
        board.setDue(Day(year: 2027, month: 1, day: 12))
        let today = Day(year: 2026, month: 11, day: 19)
        XCTAssertEqual(board.dueWords(today: today)?.text, "Due 12 Jan 2027")
        XCTAssertEqual(board.dueWords(today: today)?.past, false)
        XCTAssertEqual(board.dueWords(today: Day(year: 2027, month: 1, day: 20))?.text, "Due 12 Jan")
        XCTAssertEqual(board.dueWords(today: Day(year: 2027, month: 1, day: 20))?.past, true)
        let text = ProjectHandoverCheck.text(board)
        XCTAssertTrue(text.contains("due: 2027-01-12\n---\n"))
        XCTAssertEqual(text.components(separatedBy: "due:").count, 2)
        board.setDue(nil)
        XCTAssertNil(board.dueWords())
    }

    func testStarterPictureShowsDaysFromToday() throws {
        var board = Board(title: "Plan")
        let now = Date()
        let tl = Starter.timeline.board(now: now)
        board = tl
        board.changed = now.addingTimeInterval(-10 * 86_400)
        let shown = StarterShelf.shownBoard(board, now: now)
        let a = board.items.compactMap { $0.start }.compactMap { Day(iso: $0) }.min()!
        let b = shown.items.compactMap { $0.start }.compactMap { Day(iso: $0) }.min()!
        XCTAssertEqual(b - a, 10)
    }
}

enum ProjectHandoverCheck {
    static func text(_ board: Board) -> String {
        ParagonExport.projectHandover(board: board, title: "Trip", picture: nil, now: Date()).text
    }
}
