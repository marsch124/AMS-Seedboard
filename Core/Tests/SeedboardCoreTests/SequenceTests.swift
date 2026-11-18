import XCTest
import CoreGraphics
@testable import SeedboardCore

/// The "Who does what" board: one small data test per rule.
final class SequenceTests: XCTestCase {
    /// Anna, Bank, Builder with "1 Ask for loan" Anna → Bank, "2 Yes" Bank → Anna (an answer),
    /// "3 Order the build" Anna → Builder — the owner's sketch.
    private func sketch() -> (board: Board, anna: UUID, bank: UUID, builder: UUID) {
        let board = Board.sequenceStart()
        let who = board.whos.map(\.id)
        return (board, who[0], who[1], who[2])
    }

    private func words(_ board: Board) -> [String] { board.steps.map { board.stepLine($0.id) } }

    // MARK: What is kept

    func testASequenceBoardKeepsItsKindItsNamesAndItsMessagesThroughAFile() throws {
        var (board, anna, bank, _) = sketch()
        board.addBand("Bank closed on Sundays", at: 1)
        let back = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board))
        XCTAssertEqual(back, board)
        XCTAssertTrue(back.isSequence)
        XCTAssertTrue(back.placesItself)
        XCTAssertFalse(Board(title: "Plain").isSequence)
        XCTAssertEqual(back.whos.map(\.text), ["Anna", "Bank", "Builder"])
        let yes = try XCTUnwrap(back.steps.first { $0.text == "Yes" })
        XCTAssertEqual(yes.from, bank)
        XCTAssertEqual(yes.to, anna)
        XCTAssertTrue(yes.isAnswer)
        // An older file has none of the new fields: nothing is made up.
        let plain = try JSONDecoder().decode(Item.self, from: Data(#"{"id":"\#(UUID().uuidString)","kind":"box"}"#.utf8))
        XCTAssertNil(plain.from)
        XCTAssertNil(plain.to)
        XCTAssertNil(plain.answer)
        XCTAssertTrue(back.canBeChanged)
    }

    func testTheStarterIsTheSketch() {
        let (board, _, _, _) = sketch()
        XCTAssertEqual(board.title, "Who does what")
        XCTAssertEqual(words(board), ["1. Anna → Bank: Ask for loan", "2. Bank answers Anna: Yes", "3. Anna → Builder: Order the build"])
        XCTAssertEqual(board.countLine, "3 people · 3 messages")
        XCTAssertEqual(Board.sequence().countLine, "Empty")
        // Each name wears its own colour.
        XCTAssertEqual(board.whos.map(\.colour), ["blue", "teal", "orange"])
    }

    // MARK: Numbering and order

    func testMessagesAreNumberedFromTheTopAndNotesAndSectionsAreNot() {
        var (board, anna, _, builder) = sketch()
        let note = board.addBand("Bank closed on Sundays", at: 1)
        let part = board.addSection("If the loan is refused", at: 3)
        let last = board.addMessage("Wait", from: builder, to: anna)!
        XCTAssertEqual(board.steps.map(\.kind), [.message, .band, .message, .section, .message, .message])
        XCTAssertEqual(board.steps.compactMap { board.messageNumbers[$0.id] }, [1, 2, 3, 4])
        XCTAssertNil(board.messageNumbers[note])
        XCTAssertNil(board.messageNumbers[part])
        XCTAssertEqual(board.messageNumbers[last], 4)
        XCTAssertEqual(board.countLine, "3 people · 4 messages · 1 note · 1 section")
    }

    func testAMessagePutAtAPlacePushesTheLaterOnesDown() {
        var (board, anna, bank, builder) = sketch()
        board.addMessage("Sign", from: anna, to: bank, at: 1)
        XCTAssertEqual(words(board).map { String($0.prefix(2)) }, ["1.", "2.", "3.", "4."])
        XCTAssertEqual(board.steps.map(\.text), ["Ask for loan", "Sign", "Yes", "Order the build"])
        // A place past the end is the end; one before the start is the start.
        board.addMessage("Thanks", from: builder, to: anna, at: 99)
        board.addMessage("Hello", from: anna, to: bank, at: -3)
        XCTAssertEqual(board.steps.first?.text, "Hello")
        XCTAssertEqual(board.steps.last?.text, "Thanks")
        // Not a name on this board: no message.
        XCTAssertNil(board.addMessage("Lost", from: anna, to: UUID()))
        XCTAssertEqual(board.steps.count, 6)
    }

    func testReturnOnAMessageAddsTheNextOneBelowGoingTheOtherWay() {
        var (board, anna, bank, _) = sketch()
        let ask = board.steps[0].id
        // After a question: its answer.
        let replyID = board.addMessageAfter(ask)!
        let reply = board.item(replyID)!
        XCTAssertEqual(board.stepIndex(of: reply.id), 1)
        XCTAssertEqual(reply.from, bank)
        XCTAssertEqual(reply.to, anna)
        XCTAssertTrue(reply.isAnswer)
        // After an answer: the next question, back the other way.
        let nextID = board.addMessageAfter(reply.id)!
        let next = board.item(nextID)!
        XCTAssertEqual(board.stepIndex(of: next.id), 2)
        XCTAssertEqual(next.from, anna)
        XCTAssertEqual(next.to, bank)
        XCTAssertFalse(next.isAnswer)
        // A note has no next message.
        let note = board.addBand("Note")
        XCTAssertNil(board.addMessageAfter(note))
    }

    func testAPulledMessageIsAnAnswerWhenTheOneAboveGoesTheOtherWay() {
        let (board, anna, bank, builder) = sketch()
        XCTAssertTrue(board.wouldAnswer(from: bank, to: anna, at: 1))        // right under "Ask for loan" Anna → Bank
        XCTAssertFalse(board.wouldAnswer(from: anna, to: bank, at: 1))       // the same way: a second question
        XCTAssertFalse(board.wouldAnswer(from: builder, to: anna, at: 1))    // other names
        XCTAssertFalse(board.wouldAnswer(from: anna, to: bank, at: 2))       // above it is an answer already
        XCTAssertFalse(board.wouldAnswer(from: bank, to: anna, at: 0))       // nothing above
        XCTAssertTrue(board.wouldAnswer(from: builder, to: anna))            // no place: under the last one
    }

    func testAStepDraggedToAHeightLandsBetweenTheStepsThere() {
        var (board, _, _, _) = sketch()
        let layout = board.sequenceLayout()
        let rows = layout.rows
        XCTAssertEqual(rows.map(\.number), [1, 2, 3])
        // Evenly spaced: every one-line message is as tall as the next.
        XCTAssertEqual(rows[1].top - rows[0].top, rows[2].top - rows[1].top, accuracy: 0.001)
        XCTAssertEqual(rows[0].top, layout.firstTop, accuracy: 0.001)
        // The new order from a y, with the dragged step left out.
        let first = rows[0].id
        XCTAssertEqual(layout.slot(atY: rows[0].middle - 1, moving: first), 0)
        XCTAssertEqual(layout.slot(atY: rows[1].middle + 1, moving: first), 1)
        XCTAssertEqual(layout.slot(atY: rows[2].bottom + 50, moving: first), 2)
        XCTAssertEqual(layout.slot(atY: rows[1].middle + 1), 2)              // a new message: nothing is left out
        // The landing line stands on the edge between the two steps.
        XCTAssertEqual(layout.landingY(slot: 1, moving: first), rows[2].top, accuracy: 0.001)
        XCTAssertEqual(layout.landingY(slot: 2, moving: first), rows[2].bottom, accuracy: 0.001)
        XCTAssertEqual(layout.landingY(slot: 0), layout.firstTop, accuracy: 0.001)
        // Dropped there: "Ask for loan" is now the last, and the numbers follow.
        XCTAssertTrue(board.moveStep(first, to: 2))
        XCTAssertEqual(words(board), ["1. Bank answers Anna: Yes", "2. Anna → Builder: Order the build", "3. Anna → Bank: Ask for loan"])
        XCTAssertFalse(board.moveStep(first, to: 2))                         // its own place: nothing changes
        XCTAssertFalse(board.moveStep(UUID(), to: 0))
    }

    func testANameDraggedSidewaysTakesItsPlaceInTheRowAndItsMessagesGoAlong() {
        var (board, anna, bank, builder) = sketch()
        let layout = board.sequenceLayout()
        XCTAssertEqual(layout.whoSlot(atX: layout.x[bank]! + 5, moving: anna), 1)
        XCTAssertEqual(layout.whoSlot(atX: layout.x[builder]! + 5, moving: anna), 2)
        XCTAssertEqual(layout.whoSlot(atX: 0, moving: builder), 0)
        // The upright landing line stands in the gap between the two boxes.
        let gap = layout.whoLandingX(slot: 1, moving: anna)
        XCTAssertGreaterThan(gap, Double(layout.boxes[bank]!.maxX))
        XCTAssertLessThan(gap, Double(layout.boxes[builder]!.minX))
        XCTAssertTrue(board.moveWho(anna, to: 2))
        XCTAssertEqual(board.whos.map(\.text), ["Bank", "Builder", "Anna"])
        XCTAssertFalse(board.moveWho(anna, to: 2))
        // Nothing about the messages changed: they still say who to whom.
        XCTAssertEqual(words(board).first, "1. Anna → Bank: Ask for loan")
        let after = board.sequenceLayout()
        XCTAssertEqual(after.rows[0].fromX, after.x[anna])
        XCTAssertEqual(after.rows[0].toX, after.x[bank])
        XCTAssertLessThan(after.rows[0].toX, after.rows[0].fromX)            // the arrow now points left
    }

    func testTurningRoundSwapsWhoItComesFrom() {
        var (board, anna, bank, _) = sketch()
        let ask = board.steps[0].id
        board.turnMessageRound(ask)
        XCTAssertEqual(board.item(ask)?.from, bank)
        XCTAssertEqual(board.item(ask)?.to, anna)
        XCTAssertEqual(board.stepLine(ask), "1. Bank → Anna: Ask for loan")
    }

    // MARK: Removing and copying

    func testRemovingANameRemovesItsMessagesAndSaysHowMany() {
        var (board, anna, bank, builder) = sketch()
        XCTAssertEqual(board.messageCount(of: bank), 2)
        XCTAssertEqual(board.messageCount(of: builder), 1)
        let note = board.addBand("Stays")
        XCTAssertEqual(board.removeFromSequence([bank]), 2)
        XCTAssertEqual(board.whos.map(\.text), ["Anna", "Builder"])
        XCTAssertEqual(words(board), ["1. Anna → Builder: Order the build", "Stays"])
        XCTAssertEqual(board.whos.map(\.order), [1, 2])
        // A message chosen together with its name is not counted as "went along".
        let order = board.steps[0].id
        XCTAssertEqual(board.removeFromSequence([builder, order]), 0)
        XCTAssertEqual(board.steps.map(\.id), [note])
        XCTAssertEqual(board.removeFromSequence([note, anna]), 0)
        XCTAssertTrue(board.isEmpty)
    }

    func testACopiedStepStandsRightUnderItsOwn() {
        var (board, anna, _, _) = sketch()
        let yes = board.steps[1].id
        let copies = board.duplicateInSequence([yes])
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(board.steps.map(\.text), ["Ask for loan", "Yes", "Yes", "Order the build"])
        XCTAssertEqual(board.stepIndex(of: copies.first!), 2)
        XCTAssertTrue(board.item(copies.first!)!.isAnswer)
        // A copied name stands beside its own and has no messages yet.
        let twin = board.duplicateInSequence([anna]).first!
        XCTAssertEqual(board.whos.map(\.text), ["Anna", "Anna", "Bank", "Builder"])
        XCTAssertEqual(board.messageCount(of: twin), 0)
    }

    // MARK: Where everything is

    func testNamesStandEvenlyAndAGapGrowsWhereTheWordsNeedIt() {
        var (board, anna, bank, builder) = sketch()
        let m = SequenceMetrics()
        var layout = board.sequenceLayout()
        XCTAssertEqual(layout.whos, [anna, bank, builder])
        XCTAssertEqual(layout.x[bank]! - layout.x[anna]!, m.laneGap, accuracy: 0.5)
        XCTAssertEqual(layout.x[builder]! - layout.x[bank]!, m.laneGap, accuracy: 0.5)
        XCTAssertEqual(Double(layout.boxes[anna]!.minX), m.margin, accuracy: 0.5)
        XCTAssertEqual(Double(layout.size.width), Double(layout.boxes[builder]!.maxX) + m.margin, accuracy: 0.5)
        XCTAssertGreaterThan(Double(layout.size.height), layout.rows.last!.bottom)

        // Long words between Bank and Builder: only that gap grows, just enough for them.
        let long = board.addMessage("Send the signed papers by Friday", from: bank, to: builder)!
        let wide = board.item(long)!.w
        layout = board.sequenceLayout()
        XCTAssertEqual(layout.x[bank]! - layout.x[anna]!, m.laneGap, accuracy: 0.5)
        XCTAssertEqual(layout.x[builder]! - layout.x[bank]!, m.badge + m.badgeGap + wide + 2 * m.wordsPad, accuracy: 1)
        // The words stand above their arrow, in the middle between the two lines.
        let row = layout.row(long)!
        XCTAssertLessThan(Double(row.words.maxY), row.lineY)
        XCTAssertEqual(Double(row.box.midX), (row.fromX + row.toX) / 2, accuracy: 0.5)

        // Long words across two gaps: the two gaps share what is missing.
        var far = Board.sequenceStart()
        let ids = far.whos.map(\.id)
        let across = far.addMessage("Tell the builder everything about the loan", from: ids[0], to: ids[2])!
        far.items[far.index(of: across)!].w = 400                            // as the app measures very long words
        let both = far.sequenceLayout()
        let need = m.badge + m.badgeGap + far.item(across)!.w + 2 * m.wordsPad
        XCTAssertEqual(both.x[ids[2]]! - both.x[ids[0]]!, need, accuracy: 1)
        XCTAssertEqual(both.x[ids[1]]! - both.x[ids[0]]!, both.x[ids[2]]! - both.x[ids[1]]!, accuracy: 1)
    }

    func testAMessageToItselfIsALoopOnItsOwnLine() {
        var (board, _, bank, builder) = sketch()
        let check = board.addMessage("Check the papers", from: bank, to: bank)!
        XCTAssertTrue(board.item(check)!.isToItself)
        var layout = board.sequenceLayout()
        let row = layout.row(check)!
        XCTAssertTrue(row.loop)
        XCTAssertEqual(row.fromX, layout.x[bank])
        XCTAssertEqual(row.toX, layout.x[bank])
        // Its words stand right of the loop and before the next line.
        XCTAssertGreaterThan(Double(row.box.minX), layout.x[bank]! + SequenceMetrics().loopWidth)
        XCTAssertLessThan(Double(row.box.maxX), layout.x[builder]!)
        XCTAssertEqual(board.stepLine(check), "4. Bank, by itself: Check the papers")
        // On the last line the diagram grows to the right instead.
        let before = layout.size.width
        board.addMessage("Plan the build, week by week", from: builder, to: builder)
        layout = board.sequenceLayout()
        XCTAssertGreaterThan(layout.size.width, before)
        XCTAssertLessThanOrEqual(Double(layout.rows.last!.box.maxX), layout.right)
    }

    func testANoteIsABandAcrossTheLinesAndASectionALineAcrossEverything() {
        var (board, anna, _, builder) = sketch()
        let note = board.addBand("Bank closed on Sundays", at: 1)
        let part = board.addSection("If the loan is refused")
        let layout = board.sequenceLayout()
        let band = layout.row(note)!
        XCTAssertLessThanOrEqual(Double(band.box.minX), Double(layout.boxes[anna]!.minX))
        XCTAssertGreaterThanOrEqual(Double(band.box.maxX), Double(layout.boxes[builder]!.maxX))
        XCTAssertTrue(band.box.contains(band.words))
        XCTAssertNil(band.number)
        let line = layout.row(part)!
        XCTAssertEqual(line.fromX, 0)
        XCTAssertEqual(line.toX, Double(layout.size.width), accuracy: 0.5)
        // The steps never overlap: each begins where the one before ends.
        for (a, b) in zip(layout.rows, layout.rows.dropFirst()) { XCTAssertEqual(a.bottom, b.top, accuracy: 0.001) }
    }

    func testTheNearestLineIsFoundAndTheNamesStayPinned() {
        let (board, anna, bank, _) = sketch()
        let layout = board.sequenceLayout()
        XCTAssertEqual(layout.who(nearX: layout.x[bank]! + 20, reach: 40), bank)
        XCTAssertEqual(layout.who(nearX: layout.x[anna]! - 30, reach: 40), anna)
        XCTAssertNil(layout.who(nearX: (layout.x[anna]! + layout.x[bank]!) / 2, reach: 40))
        // Not slid: the names stand where they are. Slid up by 200: they move down by as much as is hidden.
        XCTAssertEqual(layout.pinShift(top: nil), 0)
        XCTAssertEqual(layout.pinShift(top: -50), 0)
        XCTAssertEqual(layout.pinShift(top: 200, inset: 8), 200 + 8 - layout.boxTop, accuracy: 0.001)
        // An empty board still has a size, and lines long enough to pull from once a name is there.
        XCTAssertGreaterThan(Board.sequence().sequenceLayout().size.width, 200)
        XCTAssertNil(Board.sequence().bounds)
        XCTAssertEqual(board.bounds, CGRect(origin: .zero, size: layout.size))
        // A message whose name is gone (a file from elsewhere) is left out, and the rest still stands.
        var torn = board
        torn.items.removeAll { $0.id == bank }
        XCTAssertEqual(torn.sequenceLayout().rows.map(\.number), [1])
    }

    // MARK: The hand-over

    private func loan() -> Board {
        var (board, anna, bank, _) = sketch()
        board.addBand("Bank closed on Sundays", at: 1)
        board.addMessage("Check the papers", from: bank, to: bank, at: 2)
        board.addSection("If the loan is refused")
        board.addMessage("Ask again", from: anna, to: bank)
        return board
    }

    func testAsANoteItIsANumberedListWithNotesAndSectionsInPlace() {
        var board = loan()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ParagonExport.sequenceList(board), [
            "1. Anna → Bank: Ask for loan",
            "",
            "> Bank closed on Sundays",
            "",
            "2. Bank, by itself: Check the papers",
            "3. Bank answers Anna: Yes",
            "4. Anna → Builder: Order the build",
            "",
            "### If the loan is refused",
            "",
            "5. Anna → Bank: Ask again",
        ])
        var note = ParagonExport.note(board: board, title: "Loan", picture: "Seedboard Loan.png", now: now)
        XCTAssertTrue(note.contains("type: resource"))
        XCTAssertTrue(note.contains("![Picture](../Pictures/Seedboard%20Loan.png)"))
        XCTAssertTrue(note.contains("## Who\n\nAnna · Bank · Builder\n\n"))
        XCTAssertTrue(note.contains("## Who does what\n\n1. Anna → Bank: Ask for loan\n\n> Bank closed on Sundays\n\n2. Bank"))
        XCTAssertFalse(note.contains("## Tasks"))
        // A ticked message is a task under the list.
        let order = board.steps.first { $0.text == "Order the build" }!.id
        board.items[board.index(of: order)!].todo = true
        note = ParagonExport.note(board: board, title: "Loan", picture: nil, now: now)
        XCTAssertTrue(note.hasSuffix("## Tasks\n\n- [ ] Anna → Builder: Order the build\n\n"))
        // "Only the to-do boxes": the ticked message's own words.
        XCTAssertEqual(ParagonExport.inboxTasks(board: board).map(\.text), ["Order the build"])
        // Copied as text: the same order in plain lines.
        XCTAssertTrue(board.outlineText.hasPrefix("Who: Anna, Bank, Builder\n\n1. Anna → Bank: Ask for loan\n   Note: Bank closed on Sundays\n2. Bank"))
        XCTAssertTrue(board.outlineText.hasSuffix("If the loan is refused:\n5. Anna → Bank: Ask again"))
        // Found by its words on the home page.
        XCTAssertTrue(board.holds("sundays loan"))
    }

    func testAsAProjectTheTicksDecideWhichMessagesBecomeTasks() {
        var board = loan()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Nothing ticked: every message is a task.
        var plan = ParagonExport.sequenceTaskLines(board)
        XCTAssertEqual(plan.tasks, 5)
        XCTAssertEqual(plan.plain, 0)
        XCTAssertEqual(ParagonExport.projectLine(board: board), "Nothing is ticked: all 5 messages become tasks.")
        // Two ticked: only those are tasks, the others stay as plain lines in their places.
        for text in ["Ask for loan", "Order the build"] {
            let id = board.steps.first { $0.text == text }!.id
            board.items[board.index(of: id)!].todo = true
        }
        plan = ParagonExport.sequenceTaskLines(board)
        XCTAssertEqual(plan.lines, [
            "- [ ] Anna → Bank: Ask for loan",
            "- Bank, by itself: Check the papers",
            "- Bank answers Anna: Yes",
            "- [ ] Anna → Builder: Order the build",
            "",
            "### If the loan is refused",
            "",
            "- Anna → Bank: Ask again",
        ])
        XCTAssertEqual(ParagonExport.projectLine(board: board), "2 ticked messages become tasks, 3 stay as plain lines.")
        let project = ParagonExport.project(board: board, title: "Loan", picture: nil, now: now)
        XCTAssertTrue(project.contains("type: project\nstatus: active"))
        XCTAssertTrue(project.contains("## Tasks\n\n- [ ] Anna → Bank: Ask for loan\n"))
        XCTAssertTrue(project.contains("## Notes\n\nWho: Anna · Bank · Builder\n\n- Bank closed on Sundays\n\n## Log"))
        XCTAssertNil(ParagonExport.projectLine(board: Board.sequence()))
    }
}
