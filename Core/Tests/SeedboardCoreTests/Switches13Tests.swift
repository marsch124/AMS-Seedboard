import XCTest
@testable import SeedboardCore

/// 0.13: the calendar that follows the timelines, and "Still thinking about these?".
final class Switches13Tests: XCTestCase {
    func testTheCalendarFollowsMovesRenamesDoneAndRemovals() {
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: Day(year: 2026, month: 12, day: 1), days: 5)
        let open = board.addMilestone("Open house", on: Day(year: 2027, month: 1, day: 10))
        var away = Board.timeline(title: "Away")
        _ = away.addBar("Hidden", start: Day(year: 2026, month: 12, day: 1), days: 2)
        away.putAway = Date()

        let first = CalendarFollow.wanted(boards: [board, away])
        XCTAssertEqual(first.map(\.title).sorted(), ["Open house", "Permit"])
        XCTAssertEqual(first.first { $0.title == "Permit" }?.last, Day(year: 2026, month: 12, day: 5))
        XCTAssertEqual(CalendarFollow.plan(wanted: first, existing: []).add.count, 2)
        XCTAssertTrue(CalendarFollow.plan(wanted: first, existing: first).isEmpty)

        // Done: the same event, "(done)" after the name. A removed row goes; someone else's event is never touched.
        board.setDone([permit], true, on: Day(year: 2026, month: 12, day: 5))
        board.items.removeAll { $0.id == open }
        let mine = FollowEvent(key: "https://example.com", title: "Dentist", first: Day(year: 2026, month: 12, day: 2),
                               last: Day(year: 2026, month: 12, day: 2), notes: "")
        let twin = first[0]
        let plan = CalendarFollow.plan(wanted: CalendarFollow.wanted(boards: [board]), existing: first + [mine, twin])
        XCTAssertEqual(plan.change.map(\.title), ["Permit (done)"])
        XCTAssertEqual(plan.remove, [CalendarFollow.key(board: board.id, item: open)])
        XCTAssertEqual(plan.twins.values.reduce(0, +), 1)
        XCTAssertTrue(plan.add.isEmpty)
        XCTAssertEqual(CalendarFollow.line(events: 1, updated: nil), "1 event in the Seedboard calendar")
    }

    func testStillThinkingShowsAtMostThreeOldBoards() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func board(_ title: String, daysAgo: Int) -> Board {
            var b = Board(title: title)
            b.changed = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            return b
        }
        var pinned = board("Pinned", daysAgo: 40); pinned.pinned = true
        var away = board("Away", daysAgo: 40); away.putAway = now
        let fresh = board("Fresh", daysAgo: 3)
        let old = (1...4).map { board("Old \($0)", daysAgo: 14 + $0) }
        let all = [pinned, away, fresh] + old

        XCTAssertEqual(Nudge.boards(all, now: now, notNow: [:]).map(\.title), ["Old 4", "Old 3", "Old 2"])
        // Not now: hidden for two weeks, then it may come up again.
        let wait = [old[3].id: Nudge.askAgain(after: now)]
        XCTAssertEqual(Nudge.boards(all, now: now, notNow: wait).map(\.title), ["Old 3", "Old 2", "Old 1"])
        XCTAssertEqual(Nudge.boards(all, now: now.addingTimeInterval(15 * 86_400), notNow: wait).first?.title, "Old 4")
        XCTAssertTrue(Nudge.tidy(wait, boards: all, now: now.addingTimeInterval(15 * 86_400)).isEmpty)
    }
}
