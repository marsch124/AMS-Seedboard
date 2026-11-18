import XCTest
@testable import SeedboardCore

/// 0.5, pick 16 (the reading half): what PARAGON's note says about a board's tasks. One test per rule.
final class Echo05Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Centre "Cabin" with branches "Food" (Buy fish, Bake) and "Book trip" (no ideas).
    private func mapBoard() -> (board: Board, fish: UUID, bake: UUID, trip: UUID) {
        let centre = Item(kind: .idea, text: "Cabin")
        let food = Item(kind: .idea, text: "Food", parent: centre.id, order: 1)
        let trip = Item(kind: .idea, text: "Book trip", parent: centre.id, order: 2)
        let fish = Item(kind: .idea, text: "Buy fish", parent: food.id, order: 1)
        let bake = Item(kind: .idea, text: "Bake", parent: food.id, order: 2)
        return (Board(title: "Summer cabin", items: [centre, food, trip, fish, bake]), fish.id, bake.id, trip.id)
    }

    // MARK: PARAGON's task lines

    func testTaskLinesAreReadByParagonsRule() {
        let note = """
        ---
        title: Summer cabin
        ---
        # Summer cabin

        ## Tasks

        - [ ] Buy fish
        * [x] Bake
          + [X] Flour @done(2026-11-18)
        - [-] Book trip
        - [>] Call Alex
        - [] Not a task
        - Not a task either
        -[x] Nor this
        ```
        - [x] Inside a block
        ```
        ~~~
        - [x] Inside the other block
        ~~~
        - [x]
        """
        let lines = ParagonRead.taskLines(in: note.replacingOccurrences(of: "\n", with: "\r\n"))
        XCTAssertEqual(lines.map(\.words), ["Buy fish", "Bake", "Flour", "Book trip", "Call Alex", ""])
        XCTAssertEqual(lines.map(\.mark), [.open, .done, .done, .cancelled, .open, .done])
    }

    func testWordsAreComparedWithoutParagonsOwnMarks() {
        // As Seedboard sends a bar, and as PARAGON writes the line back once it is ticked.
        let sent = "Permit (starts 1 Dec) >2026-12-05"
        let ticked = "Permit  (starts 1 Dec) !! ~1h30m >2026-12-05T14:30 @repeat(weekly) @since(2026-11-01) @deadline(2026-12-06) @done(2026-12-04 10:12) ^t3fa2c1"
        XCTAssertEqual(ParagonRead.words(sent), "Permit (starts 1 Dec)")
        XCTAssertEqual(ParagonRead.words(ticked), "Permit (starts 1 Dec)")
        // What is not one of PARAGON's marks stays: a tag, a mark inside a word, a bare "~", a second day.
        XCTAssertEqual(ParagonRead.words("Paint #cabin a>2026-12-05 wow! ~ ~0m >2026-12-05 >2026-12-06"),
                       "Paint #cabin a>2026-12-05 wow! ~ ~0m >2026-12-06")
    }

    // MARK: Matching by the words that were sent

    func testThingsAreMatchedByTheWordsThatWereSent() {
        var (board, fish, bake, trip) = mapBoard()
        let gone = UUID()
        board.noteSent(fish, words: "Buy fish", place: SentTask.note)
        board.noteSent(bake, words: "Bake", place: SentTask.note)
        board.noteSent(trip, words: "Book trip", place: SentTask.note)
        board.noteSent(gone, words: "Flour", place: SentTask.note)          // no longer on the board
        // Renamed on the board since: the words that were SENT still find the line.
        if let i = board.items.firstIndex(where: { $0.id == bake }) { board.items[i].text = "Bake bread" }
        let note = "- [ ] Buy fish\n- [x] Bake @done(2026-11-18) ^t3fa2c1\n- [-] Book trip\n- [x] Flour\n- [x] Something he added himself\n"
        let reading = ParagonRead.reading(board: board, note: note)
        XCTAssertEqual(reading.states, [fish: .inParagon, bake: .done, trip: .cancelled])
        // The cancelled one is left out of the count, as in PARAGON; so is the thing that is gone.
        XCTAssertEqual(reading.found, 2)
        XCTAssertEqual(reading.done, 1)
    }

    func testAReWordedTaskStaysInParagonAndTwinsTakeTheLinesInOrder() {
        var (board, fish, bake, trip) = mapBoard()
        board.noteSent(fish, words: "Call", place: SentTask.note)
        board.noteSent(bake, words: "Call", place: SentTask.note)
        board.noteSent(trip, words: "Book trip", place: SentTask.note)
        let reading = ParagonRead.reading(board: board, note: "- [x] Call\n- [ ] Call\n- [x] Book the trip to the cabin\n")
        // "Book trip" was re-worded in PARAGON: it is not found, so the board keeps showing it "in PARAGON".
        XCTAssertEqual(reading.states, [fish: .done, bake: .inParagon])
        XCTAssertNil(reading.states[trip])
        XCTAssertEqual(board.todoState(of: trip), .inParagon)
        XCTAssertEqual(reading.found, 2)
        XCTAssertEqual(reading.done, 1)
    }

    func testAnInboxToDoFiledIntoTheNoteIsFoundThere() {
        var (board, fish, bake, trip) = mapBoard()
        board.noteSent(fish, words: "Buy fish", place: SentTask.note)
        board.noteSent(bake, words: "Bake", place: SentTask.inbox)
        // "Book trip" was never sent. The board keeps words of a thing in the note, so nothing is guessed.
        let reading = ParagonRead.reading(board: board, note: "- [x] Buy fish\n- [x] Bake\n- [x] Book trip\n", kind: "project")
        XCTAssertEqual(reading.states, [fish: .done, bake: .done])
        XCTAssertNil(reading.states[trip])
    }

    // MARK: A board sent by 0.4

    func testABoardSentBy04IsMatchedByTheLinesItWouldSendNow() {
        // A project with nothing ticked: every idea under a branch and every branch without ideas is a task.
        let (board, fish, bake, trip) = mapBoard()
        XCTAssertTrue(board.sentTasks.isEmpty)
        let note = ParagonExport.project(board: board, title: "Summer cabin", picture: nil, now: now)
            .replacingOccurrences(of: "- [ ] Buy fish", with: "- [x] Buy fish @done(2026-11-18)")
        let reading = ParagonRead.reading(board: board, note: note, kind: "project")
        XCTAssertEqual(reading.states, [fish: .done, bake: .inParagon, trip: .inParagon])
        XCTAssertEqual(reading.found, 3)
        XCTAssertEqual(reading.done, 1)
        // As a note only the ticked things are tasks: nothing is ticked, so nothing is matched.
        XCTAssertEqual(ParagonRead.reading(board: board, note: note, kind: "note"), ParagonRead.Reading())
    }

    func testATimelineSentBy04IsMatchedWithItsDays() {
        var board = Board.timeline(title: "Build")
        let dec1 = Day(year: 2026, month: 12, day: 1)
        let permit = board.addBar("Permit", start: dec1, days: 5)
        let roof = board.addBar("Roof", start: dec1 + 7, days: 1)
        let sent = ParagonExport.project(board: board, title: "Build", picture: nil, now: now)
        XCTAssertTrue(sent.contains("- [ ] Permit (starts 1 Dec) >2026-12-05"))
        let note = sent.replacingOccurrences(of: "- [ ] Permit (starts 1 Dec) >2026-12-05",
                                             with: "- [x] Permit (starts 1 Dec) >2026-12-05 @done(2026-12-04)")
        let reading = ParagonRead.reading(board: board, note: note, kind: "project")
        XCTAssertEqual(reading.states, [permit: .done, roof: .inParagon])
        XCTAssertEqual(ParagonRead.doneWords(found: reading.found, done: reading.done), "1 of 2 done")
    }

    // MARK: The note

    func testTheNoteIsKnownByTheBoardsLinkAndItsTitle() {
        let (board, _, _, _) = mapBoard()
        let note = ParagonExport.project(board: board, title: "Summer cabin", picture: nil, now: now)
        XCTAssertTrue(ParagonRead.holdsLink(note, to: board.id))
        XCTAssertFalse(ParagonRead.holdsLink(note, to: UUID()))
        // The title is the head's `title:` line (PARAGON writes it at a rename), else the file name.
        XCTAssertEqual(ParagonRead.title(of: note, fileName: "Old name.md"), "Summer cabin")
        XCTAssertEqual(ParagonRead.title(of: "---\ntitle: \"[Plan] \\\"A\\\"\"\ntype: project\n---\n# x", fileName: "x.md"), "[Plan] \"A\"")
        XCTAssertEqual(ParagonRead.title(of: "# No head\n\ntitle: not this", fileName: "Cabin (archived 2026-11-12).md"), "Cabin (archived 2026-11-12)")
    }

    // MARK: Words on screen

    func testTheLineUnderTheTopBar() {
        XCTAssertEqual(ParagonRead.line(kind: "project", title: "Summer cabin", found: 13, done: 5, checked: "14:02"),
                       "Project “Summer cabin” · 5 of 13 done · checked 14:02")
        XCTAssertEqual(ParagonRead.line(kind: "note", title: "Ideas", found: 0, done: 0, checked: "14:02"),
                       "Note “Ideas” · checked 14:02")
        XCTAssertEqual(ParagonRead.line(kind: "project", title: "Summer cabin", found: 13, done: 5, checked: nil),
                       "Project “Summer cabin” · not checked on this device yet")
        XCTAssertEqual(ParagonRead.line(kind: "project", title: "Summer cabin", found: 0, done: 0, checked: "14:02", gone: true),
                       "Project “Summer cabin” · no longer in PARAGON's notes")
        XCTAssertEqual(ParagonRead.doneWords(found: 13, done: 5), "5 of 13 done")
        XCTAssertNil(ParagonRead.doneWords(found: 0, done: 0))
    }

    func testCheckedSaysTheTimeTodayAndTheDayBefore() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/Stockholm"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let at = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 14, minute: 2)))
        XCTAssertEqual(ParagonRead.checkedWords(at, now: at.addingTimeInterval(3_600), timeZone: zone), "14:02")
        XCTAssertEqual(ParagonRead.checkedWords(at, now: at.addingTimeInterval(86_400), timeZone: zone), "18 Nov 14:02")
    }

    func testAReadingIsKeptAndReadBackUnchanged() throws {
        let reading = ParagonRead.Reading(states: [UUID(): .done, UUID(): .cancelled, UUID(): .inParagon], found: 2, done: 1)
        let back = try JSONDecoder().decode(ParagonRead.Reading.self, from: JSONEncoder().encode(reading))
        XCTAssertEqual(back, reading)
    }
}
