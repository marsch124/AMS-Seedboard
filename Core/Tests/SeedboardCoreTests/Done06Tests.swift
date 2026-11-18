import XCTest
@testable import SeedboardCore

/// 0.6: a timeline bar marked done goes to PARAGON already ticked, never as an open task.
final class Done06Tests: XCTestCase {
    private let dec1 = Day(year: 2026, month: 12, day: 1)

    private func plan() -> (Board, permit: UUID, walls: UUID) {
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: dec1, days: 5)
        let walls = board.addBar("Walls", start: dec1 + 7, days: 5)
        for i in board.items.indices { board.items[i].todo = true }
        board.setDone([permit], true, on: dec1 + 4)
        return (board, permit, walls)
    }

    func testADoneBarArrivesTickedWithItsDayAndAnOpenOneStaysOpen() {
        let (board, permit, walls) = plan()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for handover in [ParagonExport.noteHandover(board: board, title: "Build", picture: nil, now: now),
                         ParagonExport.projectHandover(board: board, title: "Build", picture: nil, now: now)] {
            let lines = handover.text.split(separator: "\n").map(String.init)
            XCTAssertTrue(lines.contains("- [x] Permit (starts 1 Dec) >2026-12-05 @done(2026-12-05)"), handover.text)
            XCTAssertTrue(lines.contains("- [ ] Walls (starts 8 Dec) >2026-12-12"), handover.text)
            XCTAssertFalse(lines.contains { $0.contains("Start: Permit") }, "a done bar gets no reminder of its start")
            // Both are remembered as sent, so neither comes again as a new task.
            XCTAssertEqual(Set(handover.tasks.map(\.id)), [permit, walls])
            // PARAGON's own reading: the done bar is done, under the same words Seedboard remembers.
            let read = ParagonRead.taskLines(in: handover.text)
            XCTAssertEqual(read.first { $0.words.hasPrefix("Permit") }?.mark, .done)
            XCTAssertEqual(read.first { $0.words.hasPrefix("Walls") }?.mark, .open)
            // The box on the Send page shows it ticked and counts it.
            let rows = ParagonExport.preview(ofNote: handover.text)
            let permitRow = rows.first { $0.kind == .task && $0.words.hasPrefix("Permit") }
            XCTAssertEqual(permitRow?.done, true)
            XCTAssertEqual(permitRow?.words, "Permit (starts 1 Dec)")
            XCTAssertEqual(rows.first { $0.kind == .task && $0.words.hasPrefix("Walls") }?.done, false)
            XCTAssertTrue(ParagonExport.countLine(rows).hasPrefix("2 tasks (1 done)"))
        }
    }

    func testADoneBarNeverGoesToTheInbox() {
        let (board, _, walls) = plan()
        XCTAssertEqual(ParagonExport.inboxTasks(board: board).map(\.id), [walls])
    }
}
