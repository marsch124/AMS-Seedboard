import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.5, the `send` lane: one small data test per rule of the hand-over to PARAGON.
final class Send05Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let dec1 = Day(year: 2026, month: 12, day: 1)

    /// Centre "Cabin" with branches "Food" (Buy fish, Bake -> Flour) and "Book trip" (no ideas).
    private func mapBoard() -> (board: Board, fish: UUID, bake: UUID, flour: UUID, trip: UUID) {
        let centre = Item(kind: .idea, text: "Cabin")
        let food = Item(kind: .idea, text: "Food", parent: centre.id, order: 1)
        let trip = Item(kind: .idea, text: "Book trip", parent: centre.id, order: 2)
        let fish = Item(kind: .idea, text: "Buy fish", parent: food.id, order: 1)
        let bake = Item(kind: .idea, text: "Bake", parent: food.id, order: 2)
        let flour = Item(kind: .idea, text: "Flour", parent: bake.id, order: 1)
        return (Board(title: "Summer cabin", items: [centre, food, trip, fish, bake, flour]), fish.id, bake.id, flour.id, trip.id)
    }

    /// Phase "Ground" with Permit (1–5 Dec) and Foundation (8–21 Dec), then the milestone "Move in" (10 Jan).
    private func plan() -> (board: Board, permit: UUID, foundation: UUID, moveIn: UUID) {
        var board = Board.timeline(title: "Build")
        board.addPhase("Ground")
        let permit = board.addBar("Permit", start: dec1, days: 5)
        let foundation = board.addBar("Foundation", start: dec1 + 7, days: 14)
        let moveIn = board.addMilestone("Move in", on: Day(year: 2027, month: 1, day: 10))
        return (board, permit, foundation, moveIn)
    }

    private func tick(_ board: inout Board, _ ids: UUID...) {
        for id in ids { if let i = board.index(of: id) { board.items[i].todo = true } }
    }

    /// The task lines of a text, without the box, in order.
    private func taskLines(_ text: String) -> [String] {
        text.split(separator: "\n").map { $0.drop { $0 == " " } }.filter { $0.hasPrefix("- [ ] ") }.map { String($0.dropFirst(6)) }
    }

    // MARK: TF 1 — a named frame is a heading

    func testANamedFrameIsAHeadingInTheNoteTheProjectAndTheBoardAsText() {
        var board = Starter.prosCons.board()
        board.title = "Decide"
        let pros = board.items.filter { $0.text == "A good thing" }.map(\.id)
        let cons = board.items.filter { $0.text == "A bad thing" }.map(\.id)
        board.items[board.index(of: pros[0])!].text = "Cheap"
        board.items[board.index(of: pros[1])!].text = "Near"
        board.items[board.index(of: cons[0])!].text = "Small"
        board.items[board.index(of: cons[1])!].text = "Loud"

        let note = ParagonExport.note(board: board, title: "Decide", picture: nil, now: now)
        // What lies in no frame first (after the last heading it would read as a part of that frame), then the frames.
        XCTAssertTrue(note.contains("## Notes\n\n- What are we deciding?\n\n### Pros\n\n- Cheap\n- Near\n\n### Cons\n\n- Small\n- Loud\n\n"), note)

        tick(&board, pros[1], cons[0])
        let project = ParagonExport.project(board: board, title: "Decide", picture: nil, now: now)
        XCTAssertTrue(project.contains("### Pros\n- [ ] Near\n\n### Cons\n- [ ] Small\n\n## Notes\n\n- What are we deciding?\n\n### Pros\n\n- Cheap\n- Near\n\n"), project)
        XCTAssertFalse(project.contains("### To do"))

        XCTAssertTrue(board.outlineText.contains("Notes:\n- What are we deciding?\n\nPros:\n- Cheap\n- Near\n\nCons:\n- Small\n- Loud"), board.outlineText)

        // A frame with no name gives no heading: its things are listed with the others.
        for i in board.items.indices where board.items[i].kind == .frame { board.items[i].text = "" }
        XCTAssertFalse(ParagonExport.note(board: board, title: "Decide", picture: nil, now: now).contains("###"))
    }

    func testThingsAreListedInReadingOrderNotInTheOrderTheyWereMade() {
        var board = Board(title: "Pile")
        // Made in the order D, B, C, A; they lie A B in the first row and C D in the second.
        board.add(.note, centre: CGPoint(x: 300, y: 210), text: "D")
        board.add(.note, centre: CGPoint(x: 300, y: 10), text: "B")
        board.add(.note, centre: CGPoint(x: 0, y: 200), text: "C")
        board.add(.note, centre: CGPoint(x: 0, y: 0), text: "A")
        let note = ParagonExport.note(board: board, title: "Pile", picture: nil, now: now)
        XCTAssertTrue(note.contains("## Notes\n\n- A\n- B\n- C\n- D\n"), note)
    }

    // MARK: What became a task is noted down

    func testEveryTaskLineOfANoteAndAProjectIsNotedDownWithItsThing() {
        // A mind map, nothing ticked: every idea under a branch is a task.
        let map = mapBoard()
        let project = ParagonExport.projectHandover(board: map.board, title: "Summer cabin", picture: nil, now: now)
        XCTAssertEqual(project.tasks.map(\.words), taskLines(project.text))
        XCTAssertEqual(project.tasks.map(\.id), [map.trip, map.fish, map.bake, map.flour])
        XCTAssertEqual(project.text, ParagonExport.project(board: map.board, title: "Summer cabin", picture: nil, now: now))

        // The ticks decide: only the ticked ones are noted down; the note holds the same two as tasks.
        var ticked = map.board
        tick(&ticked, map.fish, map.flour)
        let some = ParagonExport.projectHandover(board: ticked, title: "Summer cabin", picture: nil, now: now)
        XCTAssertEqual(some.tasks, [MadeTask(id: map.fish, words: "Buy fish"), MadeTask(id: map.flour, words: "Flour")])
        XCTAssertEqual(ParagonExport.noteHandover(board: ticked, title: "Summer cabin", picture: nil, now: now).tasks.map(\.id), [map.fish, map.flour])

        // A timeline: every bar and milestone with its days.
        let build = plan()
        let timeline = ParagonExport.projectHandover(board: build.board, title: "Build", picture: nil, now: now)
        XCTAssertEqual(timeline.tasks.map(\.words), taskLines(timeline.text))
        XCTAssertEqual(timeline.tasks, [MadeTask(id: build.permit, words: "Permit (starts 1 Dec) >2026-12-05"),
                                        MadeTask(id: build.foundation, words: "Foundation (starts 8 Dec) >2026-12-21"),
                                        MadeTask(id: build.moveIn, words: "Move in >2027-01-10")])
        XCTAssertEqual(timeline.text, ParagonExport.timelineProject(board: build.board, title: "Build", picture: nil, now: now))

        // "Who does what": every message.
        let who = Board.sequenceStart()
        let steps = ParagonExport.projectHandover(board: who, title: "Loan", picture: nil, now: now)
        XCTAssertEqual(steps.tasks.map(\.words), taskLines(steps.text))
        XCTAssertEqual(steps.tasks.count, 3)
        XCTAssertEqual(steps.text, ParagonExport.sequenceProject(board: who, title: "Loan", picture: nil, now: now))
        XCTAssertEqual(ParagonExport.noteHandover(board: who, title: "Loan", picture: nil, now: now).text,
                       ParagonExport.sequenceNote(board: who, title: "Loan", picture: nil, now: now))

        // The board remembers them.
        var board = map.board
        board.noteSent(project.tasks, place: SentTask.note)
        XCTAssertEqual(board.sentTask(map.flour), SentTask(id: map.flour, words: "Flour", place: SentTask.note))
        XCTAssertEqual(board.todoState(of: map.fish), .inParagon)
    }

    // MARK: TA 2, the bug — a box that is in the Inbox is not a task a second time

    func testABoxAlreadyInTheInboxIsAPlainLineInANoteAndAProject() {
        var map = mapBoard()
        tick(&map.board, map.fish, map.bake, map.flour)
        // "Bake" went to the Inbox with "Only the to-do boxes".
        map.board.noteSent(map.bake, words: "Bake", place: SentTask.inbox)
        XCTAssertTrue(map.board.isInInbox(map.bake))
        XCTAssertFalse(map.board.isInInbox(map.fish))

        let project = ParagonExport.projectHandover(board: map.board, title: "Summer cabin", picture: nil, now: now)
        // "Flour" is not set in under the plain line: PARAGON would hang it under "Buy fish".
        XCTAssertTrue(project.text.contains("### Food\n- [ ] Buy fish\n- Bake (already in the Inbox)\n- [ ] Flour\n"), project.text)
        XCTAssertEqual(project.tasks.map(\.id), [map.fish, map.flour])
        XCTAssertEqual(project.inInbox, 1)

        let note = ParagonExport.noteHandover(board: map.board, title: "Summer cabin", picture: nil, now: now)
        XCTAssertTrue(note.text.contains("## Tasks\n\n- [ ] Buy fish\n- Bake (already in the Inbox)\n- [ ] Flour\n"), note.text)

        // A tick kept by 0.4 (no words) on a board that was never a note or a project can only be an Inbox one …
        var old = mapBoard()
        tick(&old.board, old.fish)
        old.board.sentTodos = [old.fish]
        XCTAssertTrue(old.board.isInInbox(old.fish))
        // … on a board that was sent as a note it may stand in that note: it stays a task in a fresh copy.
        old.board.sent = SentInfo(when: now, kind: "note", title: "Summer cabin", path: "Resources/Summer cabin.md")
        XCTAssertFalse(old.board.isInInbox(old.fish))

        // … and in a branch of that board, sent alone, it is no Inbox tick either.
        let food = old.board.items.first { $0.text == "Food" }!.id
        XCTAssertEqual(old.board.branchOnly(food)?.isInInbox(old.fish), false)

        // A timeline's bar is named without its days on the plain line.
        var build = plan()
        tick(&build.board, build.permit)
        build.board.noteSent(build.permit, words: "Permit (starts 1 Dec) >2026-12-05", place: SentTask.inbox)
        let timeline = ParagonExport.projectHandover(board: build.board, title: "Build", picture: nil, now: now)
        XCTAssertTrue(timeline.text.contains("### Ground\n- Permit (already in the Inbox)\n- [ ] Foundation (starts 8 Dec) >2026-12-21\n"), timeline.text)
    }

    // MARK: TA 6 — Inbox to-dos keep their day and say where they come from

    /// PARAGON's own way with a waiting task (a copy of the part of `TaskParser.parse(line:)` and `serialized` that
    /// matters here, AMS-PARA build 340): the day is taken out of the words and written at the end.
    private func asParagonWritesIt(_ text: String) -> String {
        var rest = text
        var day = ""
        if let found = rest.range(of: #"(?<!\S)>(\d{4}-\d{2}-\d{2})(?:T(\d{1,2}:\d{2}))?(?!\S)"#, options: .regularExpression) {
            day = " " + String(rest[found])
            rest.replaceSubrange(found, with: " ")
        }
        return rest.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ") + day
    }

    func testInboxToDosKeepTheirDaysAndEndWithTheirWayBack() {
        var build = plan()
        tick(&build.board, build.permit, build.moveIn)
        let link = "seedboard://board/\(build.board.id.uuidString)"

        let sent = ParagonExport.inboxSend(board: build.board)
        XCTAssertEqual(sent.lines, ["Permit (starts 1 Dec) [Build](\(link)) >2026-12-05", "Move in [Build](\(link)) >2027-01-10"])
        XCTAssertEqual(sent.tasks.map(\.id), [build.permit, build.moveIn])
        XCTAssertEqual(sent.tasks.map(\.words), sent.lines)
        XCTAssertEqual(sent.place, SentTask.inbox)
        XCTAssertNil(sent.notePath)
        // The words the board remembers are the words PARAGON writes into its Inbox.
        XCTAssertEqual(sent.lines.map(asParagonWritesIt), sent.lines)

        // The switch off: bare words, the days stay.
        let bare = ParagonExport.inboxSend(board: build.board, choices: SendChoices(sayOrigin: false))
        XCTAssertEqual(bare.lines, ["Permit (starts 1 Dec) >2026-12-05", "Move in >2027-01-10"])

        // The board is a project in PARAGON and the project is at its place: the way back is the project.
        build.board.sent = SentInfo(when: now, kind: "project", title: "Build", path: "Projects/Build.md")
        XCTAssertEqual(ParagonExport.inboxSend(board: build.board, look: .notFetched).lines.first, "Permit (starts 1 Dec) — [[Build]] >2026-12-05")
        // The project is gone from its place: the link to the board again.
        XCTAssertEqual(ParagonExport.inboxSend(board: build.board, look: .gone).lines.first, "Permit (starts 1 Dec) [Build](\(link)) >2026-12-05")

        // A plain board: words and way back; square brackets in the board's name cannot end the link early.
        var board = Board(title: "Trip [draft]")
        let pack = board.add(.note, centre: .zero, text: "Pack\nthe bags")
        tick(&board, pack)
        XCTAssertEqual(ParagonExport.inboxSend(board: board).lines, ["Pack the bags [Trip (draft)](seedboard://board/\(board.id.uuidString))"])

        // What is in PARAGON already is not sent again: a tick sent before, a thing that is a task in the project.
        build.board.sentTodos = [build.permit]
        build.board.noteSent(build.moveIn, words: "Move in >2027-01-10", place: SentTask.note)
        XCTAssertTrue(ParagonExport.inboxSend(board: build.board).lines.isEmpty)
    }

    // MARK: TA 9 — a bar shows when it starts

    func testABarLongerThanThreeDaysGetsAStartLineWhenTheSwitchIsOn() {
        var build = plan()
        let short = build.board.addBar("Inspection", start: dec1 + 30, days: 3)
        let starts = SendChoices(remindStarts: true)

        // Off at first: nothing changes.
        XCTAssertFalse(ParagonExport.projectHandover(board: build.board, title: "Build", picture: nil, now: now).text.contains("Start:"))

        let project = ParagonExport.projectHandover(board: build.board, title: "Build", picture: nil, now: now, choices: starts)
        // Under the same heading, before the bar's own task; not for the 3-day bar, not for the milestone.
        XCTAssertTrue(project.text.contains("""
        ### Ground
        - [ ] Start: Permit >2026-12-01
        - [ ] Permit (starts 1 Dec) >2026-12-05
        - [ ] Start: Foundation >2026-12-08
        - [ ] Foundation (starts 8 Dec) >2026-12-21
        - [ ] Inspection (starts 31 Dec 2026) >2027-01-02
        - [ ] Move in >2027-01-10

        """), project.text)
        // The board remembers the bar's own task, not its start line.
        XCTAssertEqual(project.tasks.map(\.id), [build.permit, build.foundation, short, build.moveIn])

        // In a note and in the Inbox the ticked bars get theirs too.
        tick(&build.board, build.foundation)
        XCTAssertTrue(ParagonExport.noteHandover(board: build.board, title: "Build", picture: nil, now: now, choices: starts).text
            .contains("## Tasks\n\n- [ ] Start: Foundation >2026-12-08\n- [ ] Foundation (starts 8 Dec) >2026-12-21\n"))
        XCTAssertEqual(ParagonExport.inboxSend(board: build.board, choices: SendChoices(sayOrigin: false, remindStarts: true)).lines,
                       ["Start: Foundation >2026-12-08", "Foundation (starts 8 Dec) >2026-12-21"])
    }

    func testAsAProjectATimelineSaysThatEveryBarBecomesATask() {
        let build = plan()
        XCTAssertEqual(ParagonExport.projectLine(board: build.board), "All 2 bars and 1 milestone become tasks with their days.")
        var one = Board.timeline(title: "One")
        one.addBar("Permit", start: dec1, days: 5)
        XCTAssertEqual(ParagonExport.projectLine(board: one), "The bar becomes a task with its days.")
        XCTAssertNil(ParagonExport.projectLine(board: Board.timeline(title: "Empty")))
    }

    // MARK: TA 2 — add what is new

    func testSendAgainAddsOnlyWhatIsNewAimedAtTheNote() {
        // The mind map went to PARAGON as a project (0.5: every task is remembered).
        var map = mapBoard()
        let first = ParagonExport.projectHandover(board: map.board, title: "Summer cabin", picture: nil, now: now)
        map.board.noteSent(first.tasks, place: SentTask.note)
        map.board.sent = SentInfo(when: now, kind: "project", title: "Summer cabin", path: "Projects/Summer cabin.md")
        let there = NoteLook.there(text: first.text)

        // Nothing new: nothing is offered. A board that was never sent: nothing either.
        XCTAssertEqual(ParagonExport.newTasks(board: map.board, look: there), NewTasks(new: [], there: [], renamed: 0, moved: 0))
        XCTAssertNil(ParagonExport.addSend(board: map.board, look: there))
        XCTAssertNil(ParagonExport.newTasks(board: mapBoard().board, look: there))

        // Two new ideas, one old one renamed.
        let food = map.board.items.first { $0.text == "Food" }!.id
        let timber = Item(kind: .idea, text: "Order timber", parent: food, order: 3)
        let paint = Item(kind: .idea, text: "Buy paint", parent: timber.id, order: 1)
        map.board.items.append(contentsOf: [timber, paint])
        map.board.items[map.board.index(of: map.fish)!].text = "Buy salmon"

        let found = ParagonExport.newTasks(board: map.board, look: there)
        XCTAssertEqual(found?.new, [MadeTask(id: timber.id, words: "Order timber"), MadeTask(id: paint.id, words: "Buy paint")])
        XCTAssertEqual(found?.renamed, 1)
        XCTAssertEqual(found?.moved, 0)

        // The note is at its place: the lines are aimed at it, bare, as they stand in a note.
        let add = ParagonExport.addSend(board: map.board, look: there)
        XCTAssertEqual(add?.lines, ["Order timber", "Buy paint"])
        XCTAssertEqual(add?.notePath, "Projects/Summer cabin.md")
        XCTAssertEqual(add?.place, SentTask.note)
        XCTAssertEqual(ParagonExport.addSend(board: map.board, look: .notFetched)?.notePath, "Projects/Summer cabin.md")

        // The note is gone from its place: the Inbox, each line with its way back to the board.
        let gone = ParagonExport.addSend(board: map.board, look: .gone)
        XCTAssertEqual(gone?.lines.first, "Order timber [Summer cabin](seedboard://board/\(map.board.id.uuidString))")
        XCTAssertNil(gone?.notePath)
        XCTAssertEqual(gone?.place, SentTask.inbox)

        // Once sent and remembered, they are not new any more.
        map.board.noteSent(add?.tasks ?? [], place: SentTask.note)
        XCTAssertNil(ParagonExport.addSend(board: map.board, look: there))

        // The words of the row and of what cannot follow.
        XCTAssertEqual(ParagonExport.addRowWords(count: 3, sentAs: "project", noteThere: true),
                       "3 new tasks go into the project. Nothing that is there is touched.")
        XCTAssertEqual(ParagonExport.addRowWords(count: 1, sentAs: "note", noteThere: true),
                       "1 new task goes into the note. Nothing that is there is touched.")
        XCTAssertEqual(ParagonExport.addRowWords(count: 3, sentAs: "project", noteThere: false),
                       "The project is not where it was: the 3 tasks go to the Inbox.")
        let nov18 = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12))!
        XCTAssertEqual(ParagonExport.cannotFollowLine(renamed: 2, moved: 1, since: nov18),
                       "2 things were renamed and 1 bar moved since 18 Nov. PARAGON keeps the old ones.")
        XCTAssertEqual(ParagonExport.cannotFollowLine(renamed: 0, moved: 1, since: nov18), "1 bar moved since 18 Nov. PARAGON keeps the old one.")
        XCTAssertNil(ParagonExport.cannotFollowLine(renamed: 0, moved: 0, since: nov18))
    }

    func testABoardSentByAnOlderVersionAsksTheNoteWhatIsThere() {
        // 0.4 kept no list of what became a task: only `sent` and the ticks.
        var map = mapBoard()
        let old = ParagonExport.project(board: map.board, title: "Summer cabin", picture: nil, now: now)
        map.board.sent = SentInfo(when: now, kind: "project", title: "Summer cabin", path: "Projects/Summer cabin.md")
        let timber = Item(kind: .idea, text: "Order timber", parent: map.board.items.first { $0.text == "Food" }!.id, order: 3)
        map.board.items.append(timber)

        // PARAGON has ticked one off and given two their own marks since: they are still found by their words.
        let inParagon = old.replacingOccurrences(of: "- [ ] Buy fish", with: "- [x] Buy fish @done(2026-11-17) ^t1a2b3c")
            .replacingOccurrences(of: "- [ ] Bake", with: "- [ ] Bake ^t9f8e7d")
        let found = ParagonExport.newTasks(board: map.board, look: .there(text: inParagon))
        XCTAssertEqual(found?.new.map(\.words), ["Order timber"])
        XCTAssertEqual(found?.there.map(\.words), ["Book trip", "Buy fish", "Bake", "Flour"])

        // The note cannot be read on this device: nothing is offered, rather than every old task a second time.
        XCTAssertNil(ParagonExport.newTasks(board: map.board, look: .notFetched))
        XCTAssertNil(ParagonExport.addSend(board: map.board, look: .gone))

        // After the first adding the board remembers all of them, and goes by its own list from then on.
        let add = ParagonExport.addSend(board: map.board, look: .there(text: inParagon))!
        map.board.noteSent(add.tasks + add.there, place: add.place)
        XCTAssertEqual(map.board.sentTasks.count, 5)
        XCTAssertEqual(ParagonExport.newTasks(board: map.board, look: .gone)?.new, [])
    }

    func testAMovedBarIsSaidAndANewBarGoesWithItsDays() {
        var build = plan()
        let first = ParagonExport.projectHandover(board: build.board, title: "Build", picture: nil, now: now)
        build.board.noteSent(first.tasks, place: SentTask.note)
        build.board.sent = SentInfo(when: now, kind: "project", title: "Build", path: "Projects/Build.md")

        let i = build.board.index(of: build.permit)!
        build.board.items[i].start = (dec1 + 2).iso
        let roof = build.board.addBar("Roof", start: dec1 + 40, days: 10)
        let found = ParagonExport.newTasks(board: build.board, look: .notFetched)
        XCTAssertEqual(found?.moved, 1)
        XCTAssertEqual(found?.renamed, 0)
        XCTAssertEqual(found?.new.map(\.id), [roof])

        let add = ParagonExport.addSend(board: build.board, look: .notFetched, choices: SendChoices(remindStarts: true))
        XCTAssertEqual(add?.lines, ["Start: Roof >2027-01-10", "Roof (starts 10 Jan) >2027-01-19"])
        XCTAssertEqual(add?.tasks, [MadeTask(id: roof, words: "Roof (starts 10 Jan) >2027-01-19")])
    }

    // MARK: The waiting line aimed at a note

    /// A copy of PARAGON's reader (`CaptureItem` and `CaptureTarget` in AMS-PARA, Core/Sources/ParagonCore/Vault/Capture.swift,
    /// read on 18 Nov 2026, build 340). If PARAGON changes its line, change this copy with it.
    private enum ParagonCaptureTarget: Codable, Equatable {
        case inbox
        case today
        case note(path: String)
    }

    private struct ParagonCaptureItem: Codable, Equatable {
        var id: UUID
        var text: String
        var url: URL?
        var target: ParagonCaptureTarget
        var asTask: Bool
        var createdAt: Date
        var files: [String]?
    }

    func testALineAimedAtANoteIsReadByParagonsOwnReader() throws {
        let lines = ParagonExport.waitingLines(["Order timber", "Roof (starts 10 Jan) >2027-01-19"],
                                               notePath: "Projects/Summer cabin åäö.md", now: now)
            + ParagonExport.waitingLines(["Pack"], notePath: nil, now: now)
        let data = try ParagonExport.waitingData(lines)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let read = try data.split(separator: 0x0A).map { try decoder.decode(ParagonCaptureItem.self, from: $0) }
        XCTAssertEqual(read.map(\.target), [.note(path: "Projects/Summer cabin åäö.md"), .note(path: "Projects/Summer cabin åäö.md"), .inbox])
        XCTAssertEqual(read.map(\.text), ["Order timber", "Roof (starts 10 Jan) >2027-01-19", "Pack"])
        XCTAssertEqual(read.map(\.asTask), [true, true, true])
        // One second apart, so PARAGON files them in their order.
        XCTAssertEqual(read.map(\.createdAt), [now, now.addingTimeInterval(1), now])
    }

    // MARK: TA 5 — the box "What PARAGON gets"

    func testTheBoxShowsTheRowsOfTheVeryTextThatIsSent() {
        var build = plan()
        tick(&build.board, build.permit)
        build.board.noteSent(build.permit, words: "Permit", place: SentTask.inbox)
        let project = ParagonExport.projectHandover(board: build.board, title: "Build", picture: "p.png", now: now)
        let rows = ParagonExport.preview(ofNote: project.text)
        XCTAssertEqual(Array(rows.prefix(8)), [
            PreviewRow(kind: .picture, words: ""),
            PreviewRow(kind: .heading(level: 2), words: "Outcome"),
            PreviewRow(kind: .plain, words: "Build"),
            PreviewRow(kind: .heading(level: 2), words: "Tasks"),
            PreviewRow(kind: .heading(level: 3), words: "Ground"),
            PreviewRow(kind: .plain, words: "Permit (already in the Inbox)"),
            PreviewRow(kind: .task, words: "Foundation (starts 8 Dec)", day: "21 Dec", date: Day(iso: "2026-12-21")),
            PreviewRow(kind: .task, words: "Move in", day: "10 Jan", date: Day(iso: "2027-01-10")),
        ])
        XCTAssertEqual(ParagonExport.countLine(rows, inInbox: project.inInbox), "2 tasks · 1 heading · 1 already in the Inbox · last day 10 Jan")

        // A sub-task is set in; a note without tasks says so.
        let map = mapBoard()
        let ideas = ParagonExport.preview(ofNote: ParagonExport.project(board: map.board, title: "Summer cabin", picture: nil, now: now))
        XCTAssertEqual(ideas.first { $0.words == "Flour" }?.indent, 1)
        XCTAssertEqual(ParagonExport.countLine(ideas), "4 tasks · 1 heading")
        XCTAssertEqual(ParagonExport.countLine(ParagonExport.preview(ofNote: ParagonExport.note(board: map.board, title: "Summer cabin", picture: nil, now: now))), "No tasks")

        // The Inbox to-dos: a link shows as its name, the day at the right.
        let inbox = ParagonExport.preview(ofTasks: ["Permit (starts 1 Dec) [Build](seedboard://board/X) >2026-12-05", "Pack — [[Trip]]"])
        XCTAssertEqual(inbox, [PreviewRow(kind: .task, words: "Permit (starts 1 Dec) Build", day: "5 Dec", date: Day(iso: "2026-12-05")),
                               PreviewRow(kind: .task, words: "Pack — Trip")])
        XCTAssertEqual(ParagonExport.countLine(inbox), "2 tasks · last day 5 Dec")
    }

    // MARK: What became a task is never carried into a copy

    func testACopyCarriesNoSentTasksAndARemovedThingIsForgotten() {
        var (board, fish, bake, _, _) = mapBoard()
        board.sent = SentInfo(when: now, kind: "project", title: "Summer cabin", path: "Projects/Summer cabin.md")
        board.noteSent(fish, words: "Buy fish", place: SentTask.note)
        board.noteSent(bake, words: "Bake", place: SentTask.inbox)
        XCTAssertTrue(ExportRules.imported(board, taken: []).sentTasks.isEmpty)
        XCTAssertTrue(KeptRules.asCopy(board, now: now).sentTasks.isEmpty)
        XCTAssertTrue(StarterShelf.fresh(board, titled: "Cabin", now: now).sentTasks.isEmpty)
        board.remove([fish])
        XCTAssertEqual(board.sentTasks.map(\.id), [bake])
    }
}
