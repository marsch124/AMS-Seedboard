import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.9, the `paragon` lane: one small data test per rule.
final class Paragon09Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func boardWithFrame() -> (board: Board, frame: UUID, inside: [UUID], outside: UUID) {
        let frame = Item(kind: .frame, text: "Pros", x: 0, y: 0, w: 300, h: 200)
        let a = Item(kind: .note, text: "Cheap", x: 20, y: 40, w: 80, h: 60, todo: true)
        let b = Item(kind: .box, text: "Quiet", x: 150, y: 40, w: 80, h: 60)
        let out = Item(kind: .note, text: "Far away", x: 600, y: 40, w: 80, h: 60)
        var board = Board(title: "Cabin", items: [frame, a, b, out])
        board.links = [Link(from: a.id, to: b.id), Link(from: a.id, to: out.id)]
        return (board, frame.id, [a.id, b.id], out.id)
    }

    // TF 40: only the things inside the frame
    func testFrameOnlyKeepsThingsInsideAndNamesTheBoardAfterTheFrame() throws {
        let t = boardWithFrame()
        let part = try XCTUnwrap(t.board.frameOnly(t.frame))
        XCTAssertEqual(Set(part.items.map(\.id)), Set(t.inside))
        XCTAssertEqual(part.title, "Pros")
        XCTAssertEqual(part.links.count, 1)
        XCTAssertEqual(part.id, t.board.id)
        XCTAssertNil(part.sent)
        // The picture keeps the frame itself.
        XCTAssertEqual(try XCTUnwrap(t.board.frameOnly(t.frame, keepFrame: true)).items.count, 3)
        // The words that are sent come only from what is inside.
        let text = ParagonExport.noteHandover(board: part, title: "Pros", picture: nil, now: now).text
        XCTAssertTrue(text.contains("Cheap"))
        XCTAssertFalse(text.contains("Far away"))
        // An empty frame, and a thing that is no frame, give nothing.
        XCTAssertNil(Board(items: [Item(kind: .frame, w: 100, h: 100)]).frameOnly(try XCTUnwrap(t.board.item(t.frame)).id))
        XCTAssertNil(t.board.frameOnly(t.inside[0]))
    }

    // TF 41: the due day read from the task line, and how it is shown
    func testDueDayIsReadFromThePlaceParagonWritesIt() {
        XCTAssertEqual(ParagonRead.dueDay("Permit >2026-12-05 @done(2026-12-04) ^t3fa2c1"), "2026-12-05")
        XCTAssertEqual(ParagonRead.dueDay("Call >2026-12-05T09:30 !!"), "2026-12-05")
        XCTAssertNil(ParagonRead.dueDay("Call about >2026-13-45"))
        XCTAssertNil(ParagonRead.dueDay("Plain words"))
        let note = "- [ ] Order timber >2027-01-02\n- [x] Book trip >2026-11-01 @done(2026-11-01)\n- [-] Old >2026-10-10\n- [ ] No day\n"
        let lines = ParagonRead.taskLines(in: note)
        XCTAssertEqual(lines.map(\.due), ["2027-01-02", "2026-11-01", "2026-10-10", nil])
        // The reading carries the day of each thing it found (not of a cancelled one).
        let timber = Item(kind: .box, text: "Order timber"), trip = Item(kind: .box, text: "Book trip"), old = Item(kind: .box, text: "Old")
        var board = Board(title: "B", items: [timber, trip, old])
        board.sent = SentInfo(when: now, kind: "note", title: "B", path: "Resources/B.md")
        board.noteSent([MadeTask(id: timber.id, words: "Order timber"), MadeTask(id: trip.id, words: "Book trip"),
                        MadeTask(id: old.id, words: "Old")], place: SentTask.note)
        let reading = ParagonRead.reading(board: board, note: note)
        XCTAssertEqual(reading.due, [timber.id: "2027-01-02", trip.id: "2026-11-01"])
        // Kept on the device and read back unchanged.
        let again = try? JSONDecoder().decode(ParagonRead.Reading.self, from: JSONEncoder().encode(reading))
        XCTAssertEqual(again, reading)
    }

    func testDueLookSaysDayTodayAndLate() {
        let today = Day(year: 2026, month: 12, day: 5)
        XCTAssertEqual(DueLook.of("2026-12-05", state: .inParagon, today: today), DueLook(words: "Today", tone: .today))
        XCTAssertEqual(DueLook.of("2026-12-24", state: .inParagon, today: today), DueLook(words: "24 Dec", tone: .later))
        XCTAssertEqual(DueLook.of("2026-12-01", state: .inParagon, today: today), DueLook(words: "1 Dec", tone: .late))
        XCTAssertEqual(DueLook.of("2026-12-01", state: .done, today: today), DueLook(words: "1 Dec", tone: .later))
        XCTAssertNil(DueLook.of(nil, state: .inParagon, today: today))
        XCTAssertNil(DueLook.of("soon", state: .inParagon, today: today))
    }

    // TF 42: Today's three
    func testTodayThreeBuildsInboxLinesDueToday() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let a = Item(kind: .idea, text: "Call the  plumber"), b = Item(kind: .note, text: "Pay rent"), c = Item(kind: .box, text: "Book trip")
        let d = Item(kind: .box, text: "Fourth"), frame = Item(kind: .frame, text: "Frame"), blank = Item(kind: .box, text: "")
        var board = Board(title: "Today", items: [a, b, c, d, frame, blank])
        let day = Day.today(now, calendar: cal).iso
        let lines = try XCTUnwrap(ParagonExport.todayThree(board: board, chosen: [a.id, c.id, frame.id], now: now, calendar: cal))
        XCTAssertEqual(lines.lines, ["Call the plumber >\(day)", "Book trip >\(day)"])
        XCTAssertEqual(lines.tasks.map(\.id), [a.id, c.id])
        XCTAssertEqual(lines.place, SentTask.inbox)
        // More than three: not offered. Nothing that can be a task: nothing.
        XCTAssertNil(ParagonExport.todayThree(board: board, chosen: [a.id, b.id, c.id, d.id], now: now, calendar: cal))
        XCTAssertNil(ParagonExport.todayThree(board: board, chosen: [frame.id, blank.id], now: now, calendar: cal))
        // With the way back, the day stays last.
        let back = try XCTUnwrap(ParagonExport.todayThree(board: board, chosen: [b.id], now: now, way: .board(title: "Today", id: board.id), calendar: cal))
        XCTAssertTrue(back.lines[0].hasPrefix("Pay rent [Today](seedboard://board/") && back.lines[0].hasSuffix(" >\(day)"))
        // Remembered as sent: not sent twice.
        board.noteSent(lines.tasks, place: SentTask.inbox)
        XCTAssertNil(ParagonExport.todayThree(board: board, chosen: [a.id, c.id], now: now, calendar: cal))
        XCTAssertEqual(board.todoState(of: a.id), .inParagon)
        // The line is a task line for PARAGON's own reader, with its day.
        let read = ParagonRead.taskLines(in: "- [ ] " + lines.lines[0])
        XCTAssertEqual(read.first?.due, day)
        XCTAssertEqual(read.first?.words, "Call the plumber")
    }
}
