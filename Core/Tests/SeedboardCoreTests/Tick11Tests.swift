import XCTest
@testable import SeedboardCore

/// 0.11, pick 28: ticking a sent bar on the board writes one line for PARAGON's waiting list.
final class Tick11Tests: XCTestCase {
    /// A copy of PARAGON's reader before build 341 (`CaptureItem`): the line must NOT be readable by it.
    private struct OldParagonItem: Codable {
        var id: UUID
        var text: String
        var target: String?
        var asTask: Bool
        var createdAt: Date
    }

    func testATickedSentBarWritesOneLineAndOlderParagonSkipsIt() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: Day(year: 2026, month: 12, day: 1), days: 5)
        let other = board.addBar("Foundation", start: Day(year: 2026, month: 12, day: 8), days: 5)
        board.noteSent(permit, words: "Permit >2026-12-01", place: SentTask.inbox)
        let old = board
        var ticked = board
        ticked.setDone([permit, other], true, on: Day(year: 2026, month: 11, day: 19))
        let lines = ticked.doneLines(since: old, now: now)
        // Only the sent one; unticking and ticking again give nothing new.
        XCTAssertEqual(lines.map(\.words), ["Permit >2026-12-01"])
        XCTAssertEqual(lines[0].place, "inbox")
        XCTAssertTrue(board.doneLines(since: ticked, now: now).isEmpty)
        XCTAssertTrue(ticked.doneLines(since: ticked, now: now).isEmpty)

        let data = try ParagonExport.doneData(lines)
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        let json = try JSONSerialization.jsonObject(with: data.split(separator: 0x0A)[0]) as? [String: Any]
        XCTAssertEqual(json?["kind"] as? String, "seedboardDone")
        XCTAssertEqual(json?["board"] as? String, "Build")
        XCTAssertNil(json?["text"])
        XCTAssertThrowsError(try d.decode(OldParagonItem.self, from: data.split(separator: 0x0A)[0]))
        XCTAssertEqual(data.last, 0x0A)

        // A task that went into a note carries the note's place.
        var inNote = board
        inNote.noteSent(permit, words: "Permit", place: SentTask.note)
        inNote.sent = SentInfo(when: now, kind: "project", title: "Build", path: "Projects/Build.md")
        var tickedNote = inNote
        tickedNote.setDone([permit], true, on: Day(year: 2026, month: 11, day: 19))
        XCTAssertEqual(tickedNote.doneLines(since: inNote, now: now).first?.path, "Projects/Build.md")
    }
}
