import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.5, the timeline lane: picks 15 (a timeline of a board, a pasted list as bars) and 18 (done, late,
/// the progress line, Catch up, week numbers, a phase carries its rows, the view that comes back).
final class Timeline05Tests: XCTestCase {
    private let dec1 = Day(year: 2026, month: 12, day: 1)   // a Tuesday

    private func days(_ board: Board, _ id: UUID?) -> String {
        guard let id, let span = board.item(id)?.span else { return "none" }
        return "\(span.start.iso)…\(span.end.iso)"
    }

    private func names(_ board: Board) -> [String] { board.timelineRows.map { "\($0.kind == .phase ? "# " : "")\($0.text)" } }

    private func bar(_ board: Board, _ name: String) -> UUID? { board.items.first { $0.kind == .bar && $0.text == name }?.id }

    private func after(_ board: Board, _ name: String) -> [String] {
        guard let id = bar(board, name) else { return ["(no such bar)"] }
        return board.links.filter { $0.to == id }.compactMap { board.item($0.from)?.text }.sorted()
    }

    /// "Summer cabin": Budget (Loan, Savings › Sell the boat), Build (Permit, Builder), Garden (nothing under it).
    private func cabin() -> Board {
        var board = Board(title: "Summer cabin")
        let centre = board.addCentre(at: .zero, text: "Summer cabin")
        let budget = board.addChild(of: centre, text: "Budget")!
        board.addChild(of: budget, text: "Loan")
        let savings = board.addChild(of: budget, text: "Savings")!
        board.addChild(of: savings, text: "Sell the boat")
        let build = board.addChild(of: centre, text: "Build")!
        board.addChild(of: build, text: "Permit")
        board.addChild(of: build, text: "Builder")
        board.addChild(of: centre, text: "Garden")
        return board
    }

    private func tick(_ board: inout Board, _ words: String...) {
        for i in board.items.indices where words.contains(board.items[i].text) { board.items[i].todo = true }
    }

    // MARK: Pick 18 — week numbers

    func testAWeekHasItsNumberAsInSweden() {
        XCTAssertEqual(dec1.weekNumber, 49)
        XCTAssertEqual(dec1.weekWord, "w 49")
        XCTAssertEqual(Day(year: 2026, month: 1, day: 1).weekNumber, 1)      // a Thursday: week 1
        XCTAssertEqual(Day(year: 2027, month: 1, day: 1).weekNumber, 53)     // a Friday: still week 53 of 2026
        XCTAssertEqual(Day(year: 2027, month: 1, day: 4).weekNumber, 1)
        XCTAssertEqual(Day(year: 2024, month: 12, day: 30).weekNumber, 1)    // a Monday that belongs to 2025
        XCTAssertEqual(Day(year: 2026, month: 12, day: 6).weekNumber, 49)    // Sunday: the same week as its Monday
    }

    // MARK: Pick 18 — a phase carries its rows

    func testAPhaseCarriesItsRowsAndNeverSplitsAnotherPhase() {
        var board = Board.timeline(title: "Build")
        board.addBar("Loose", start: dec1)
        let one = board.addPhase("One")
        board.addBar("A", start: dec1)
        board.addBar("B", start: dec1)
        board.addPhase("Two")
        board.addBar("C", start: dec1)
        board.addBar("D", start: dec1)
        XCTAssertEqual(names(board), ["Loose", "# One", "A", "B", "# Two", "C", "D"])

        // Dragged one row down it would land inside "Two": it stays where it is. Dragged past the middle of
        // "Two" it goes past the whole of it, with its rows.
        var down = board
        down.carryRow(one, to: 2)
        XCTAssertEqual(names(down), names(board))
        down.carryRow(one, to: 3)
        XCTAssertEqual(names(down), ["Loose", "# Two", "C", "D", "# One", "A", "B"])
        // …and back up again: before "Two", with its rows.
        down.carryRow(one, to: 2)
        XCTAssertEqual(names(down), ["Loose", "# One", "A", "B", "# Two", "C", "D"])

        // Above the loose row at the top: allowed, the block lands there whole.
        var up = board
        up.carryRow(one, to: 0)
        XCTAssertEqual(names(up), ["# One", "A", "B", "Loose", "# Two", "C", "D"])

        // A bar still moves alone.
        var alone = board
        alone.carryRow(bar(board, "A")!, to: 3)
        XCTAssertEqual(names(alone), ["Loose", "# One", "B", "A", "# Two", "C", "D"])
        // Row numbers stay 0, 1, 2 … with no gap.
        XCTAssertEqual(down.timelineRows.compactMap(\.row), Array(0..<7))
    }

    // MARK: Pick 18 — done, late, the line

    func testDoneIsKeptWithItsDayAndACopyIsNotDone() {
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: dec1, days: 5)
        let walls = board.addBar("Walls", start: dec1 + 7, days: 5)
        let phase = board.addPhase("Shell")

        XCTAssertTrue(board.toggleDone([permit, phase], on: dec1 + 4))
        XCTAssertEqual(board.item(permit)?.doneDay, "2026-12-05")
        XCTAssertEqual(board.item(permit)?.doneOn, dec1 + 4)
        XCTAssertNil(board.item(phase)?.doneDay, "a phase is a heading: it carries no mark")
        // One done, one not: the button makes both done, and the first keeps its own day.
        XCTAssertTrue(board.toggleDone([permit, walls], on: dec1 + 9))
        XCTAssertEqual(board.item(permit)?.doneDay, "2026-12-05")
        XCTAssertEqual(board.item(walls)?.doneDay, "2026-12-10")
        // Both done: the mark comes off both.
        XCTAssertFalse(board.toggleDone([permit, walls], on: dec1 + 9))
        XCTAssertFalse(board.item(permit)?.isDone ?? true)

        board.setDone([permit], true, on: dec1)
        let copy = board.duplicateRows([permit]).first
        XCTAssertEqual(copy.flatMap { board.item($0)?.isDone }, false)
        // The mark survives a save and a load.
        let read = try? JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board))
        XCTAssertEqual(read?.item(permit)?.doneDay, "2026-12-01")
    }

    func testLateIsBehindTodayAndNotDoneAndTheLineSaysHowFarThePlanIs() {
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: dec1, days: 5)             // 1–5 Dec
        let builder = board.addBar("Builder", start: dec1 + 2, days: 6)       // 3–8 Dec
        let walls = board.addBar("Walls", start: dec1 + 9, days: 5)           // 10–14 Dec
        board.addMilestone("Move in", on: Day(year: 2027, month: 2, day: 20))
        board.addPhase("Shell")
        let today = dec1 + 8                                                   // 9 Dec
        XCTAssertEqual(board.lateBars(today: today), [permit, builder])
        XCTAssertFalse(board.timelineIsLate(walls, today: today))
        XCTAssertFalse(board.timelineIsLate(builder, today: dec1 + 7), "its last day is today: not late yet")
        XCTAssertEqual(board.timelineProgress(today: today).line(today: today), "0 of 4 done · 2 late · ends 20 Feb 2027")

        board.setDone([permit], true, on: today)
        XCTAssertEqual(board.lateBars(today: today), [builder])
        // Ticked off in PARAGON (read back on this device): done as well, without a word in the board.
        let progress = board.timelineProgress(today: today, also: [builder])
        XCTAssertEqual(progress, TimelineProgress(done: 2, total: 4, late: 0, ends: Day(year: 2027, month: 2, day: 20)))
        XCTAssertEqual(progress.parts(today: today), ["2 of 4 done", "ends 20 Feb 2027"])
        XCTAssertEqual(progress.line(today: Day(year: 2027, month: 1, day: 5)), "2 of 4 done · ends 20 Feb")
        XCTAssertEqual(Board.timeline().timelineProgress(today: today).line(today: today), "")
    }

    // MARK: Pick 18 — Catch up

    func testCatchUpStretchesLateBarsToTodayAndPushesWhatComesAfter() {
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: dec1, days: 5)                  // 1–5 Dec, late
        let foundation = board.addBar("Foundation", start: dec1 + 5, days: 4)      // 6–9 Dec, late, waits for Permit
        let walls = board.addBar("Walls", start: dec1 + 10, days: 5)               // 11–15 Dec, running
        let roof = board.addBar("Roof", start: dec1 + 20, days: 5)                 // 21–25 Dec, far ahead
        let paint = board.addBar("Paint", start: dec1 + 1, days: 3)                // 2–4 Dec, done
        let handover = board.addMilestone("Handover", on: dec1 + 3)                // 4 Dec, late
        board.comesAfter(foundation, after: permit)
        board.comesAfter(walls, after: foundation)
        board.comesAfter(roof, after: walls)
        board.setDone([paint], true, on: dec1 + 4)
        let today = dec1 + 11                                                       // 12 Dec

        let done = board.catchUp(today: today)
        XCTAssertEqual(days(board, permit), "2026-12-01…2026-12-12", "in work: stretched to end today")
        XCTAssertEqual(days(board, foundation), "2026-12-13…2026-12-16", "could not begin: as long as it was, right after Permit")
        XCTAssertEqual(days(board, walls), "2026-12-17…2026-12-21", "pushed along by the rule that is there")
        XCTAssertEqual(days(board, roof), "2026-12-22…2026-12-26")
        XCTAssertEqual(days(board, paint), "2026-12-02…2026-12-04", "done: left alone")
        XCTAssertEqual(days(board, handover), "2026-12-12…2026-12-12", "a late milestone moves to today")
        XCTAssertEqual(done, CatchUp(moved: 5, was: dec1 + 24, now: dec1 + 25))
        XCTAssertEqual(done?.line(today: today), "5 bars moved. The plan now ends 26 Dec (was 25 Dec).")
        XCTAssertTrue(board.lateBars(today: today).isEmpty)

        // Nothing late: nothing changes, and there is nothing to say.
        let settled = board
        XCTAssertNil(board.catchUp(today: today))
        XCTAssertEqual(board, settled)
        // A bar ticked off in PARAGON is not late either.
        var other = Board.timeline()
        let old = other.addBar("Old", start: dec1, days: 2)
        XCTAssertNil(other.catchUp(today: today, also: [old]))
        XCTAssertEqual(CatchUp(moved: 1, was: dec1, now: dec1).line(today: today), "1 bar moved. The plan still ends 1 Dec.")
    }

    // MARK: Pick 18 — the view comes back

    func testATimelineComesBackAtTheScaleAndDaysItWasLeftAt() {
        var wide = TimelineGeometry(scale: .days, namesWidth: 170)
        wide.slide = CGSize(width: wide.slide(showing: dec1), height: -68)
        let left = wide.left
        XCTAssertEqual(left.scale, "days")
        XCTAssertEqual(left.rows, -68)

        // Brought back in a narrower window (an iPhone's names column): the same day stands beside the names.
        let back = TimelineGeometry.comeBack(to: left)
        var narrow = TimelineGeometry(scale: back?.scale ?? .weeks, namesWidth: 104)
        narrow.slide = back?.slide ?? .zero
        XCTAssertEqual(narrow.scale, .days)
        XCTAssertEqual(narrow.day(atX: 104), dec1)
        XCTAssertEqual(narrow.x(of: dec1), 104, accuracy: 0.01)
        XCTAssertEqual(narrow.slide.height, -68)

        XCTAssertNil(TimelineGeometry.comeBack(to: TimelineLeft(scale: "years", day: 3, rows: 0)))
        XCTAssertNil(TimelineGeometry.comeBack(to: TimelineLeft(scale: "weeks", day: .infinity, rows: 0)))

        // The device's list: it is read back as written, and never grows past its limit.
        var views = TimelineViews()
        let first = UUID(), second = UUID(), third = UUID()
        views.note(left, of: first, now: Date(timeIntervalSince1970: 100), most: 2)
        views.note(left, of: second, now: Date(timeIntervalSince1970: 200), most: 2)
        views.note(left, of: third, now: Date(timeIntervalSince1970: 300), most: 2)
        XCTAssertNil(views.view(of: first), "the one looked at longest ago is forgotten")
        XCTAssertEqual(views.view(of: third), left)
        let read = try? JSONDecoder().decode(TimelineViews.self, from: JSONEncoder().encode(views))
        XCTAssertEqual(read, views)
        views.forget(third)
        XCTAssertNil(views.view(of: third), "shown whole again: nothing is brought back")
        XCTAssertEqual(try? JSONDecoder().decode(TimelineViews.self, from: Data("{\"views\":7}".utf8)), TimelineViews())
    }

    // MARK: Pick 15 — a timeline of a board

    func testAMindMapBecomesPhasesAndBarsExactlyAsAProjectWouldMakeTasks() throws {
        let board = cabin()
        let made = try XCTUnwrap(board.timelineOfIt(today: dec1))
        XCTAssertEqual(made.board.title, "Summer cabin timeline")
        XCTAssertTrue(made.board.isTimeline)
        // The branch with nothing under it stands above the first phase; deeper ideas come right after their parent.
        XCTAssertEqual(names(made.board), ["Garden", "# Budget", "Loan", "Savings", "Sell the boat", "# Build", "Permit", "Builder"])
        XCTAssertEqual(made.bars, 6)
        XCTAssertEqual(made.phases, 2)
        XCTAssertEqual(made.stayed, 0)
        XCTAssertEqual(made.line, "6 bars in 2 phases. Drag them to their days.")
        // The mirror of the project rule: as many bars as the project would have tasks.
        let tally = ParagonExport.projectTally(board: board)
        XCTAssertEqual(made.bars, tally.ideaTasks + tally.shapeTasks + tally.otherTasks)
        // 7 days each, one after the other inside a phase; the phases start together, today.
        XCTAssertEqual(days(made.board, bar(made.board, "Loan")), "2026-12-01…2026-12-07")
        XCTAssertEqual(days(made.board, bar(made.board, "Savings")), "2026-12-08…2026-12-14")
        XCTAssertEqual(days(made.board, bar(made.board, "Sell the boat")), "2026-12-15…2026-12-21")
        XCTAssertEqual(days(made.board, bar(made.board, "Permit")), "2026-12-01…2026-12-07")
        XCTAssertEqual(after(made.board, "Savings"), ["Loan"])
        XCTAssertEqual(after(made.board, "Permit"), [])
        // A timeline cannot be made of a timeline, and an empty board gives none.
        XCTAssertNil(made.board.timelineOfIt(today: dec1))
        XCTAssertNil(Board(title: "Empty").timelineOfIt(today: dec1))
        XCTAssertFalse(Board(title: "Empty").canBecomeTimeline())
    }

    func testTheTicksDecideAndTheLineSaysWhatStayedBehind() throws {
        var board = cabin()
        tick(&board, "Savings", "Permit", "Garden")
        board.add(.note, centre: CGPoint(x: 400, y: 0), text: "Ask Alex")
        let timber = board.add(.note, centre: CGPoint(x: 400, y: 120), text: "Check timber prices", colour: "pink")
        if let i = board.index(of: timber) { board.items[i].todo = true }

        let made = try XCTUnwrap(board.timelineOfIt(today: dec1))
        XCTAssertEqual(names(made.board), ["Garden", "Check timber prices", "# Budget", "Savings", "# Build", "Permit"])
        XCTAssertEqual(made.bars, 4)
        // Budget and Build are the phases; Loan, Sell the boat, Builder and the plain note stay on the board.
        XCTAssertEqual(made.stayed, 4)
        XCTAssertEqual(made.line, "4 bars in 2 phases. 4 things without a tick stayed on the board.")
        // Without ticks, a note that is not a to-do is what stays.
        var plain = cabin()
        plain.add(.note, centre: CGPoint(x: 400, y: 0), text: "Ask Alex")
        XCTAssertEqual(plain.timelineOfIt(today: dec1)?.line, "6 bars in 2 phases. 1 thing stayed on the board.")
        let tally = ParagonExport.projectTally(board: board)
        XCTAssertEqual(made.bars, tally.ideaTasks + tally.shapeTasks + tally.otherTasks)
        // A bar made of a ticked thing keeps the tick, so the timeline's note has it as a task too.
        XCTAssertEqual(made.board.items.filter { $0.kind == .bar && $0.todo }.count, 4)
        XCTAssertEqual(made.board.item(bar(made.board, "Check timber prices")!)?.colour, "pink")
    }

    func testWithThingsChosenOnlyThoseBecomeBars() throws {
        var board = cabin()
        tick(&board, "Loan")                       // a tick elsewhere does not count once something is chosen
        let build = board.items.first { $0.text == "Build" }!.id
        let boat = board.items.first { $0.text == "Sell the boat" }!.id
        let made = try XCTUnwrap(board.timelineOfIt(chosen: [build, boat], today: dec1))
        // The chosen branch with all that hangs under it, and the one chosen idea under its own branch.
        XCTAssertEqual(names(made.board), ["# Budget", "Sell the boat", "# Build", "Permit", "Builder"])
        XCTAssertEqual(made.stayed, 0)
        XCTAssertEqual(made.line, "3 bars in 2 phases. Drag them to their days.")
        XCTAssertTrue(board.canBecomeTimeline(chosen: [build]))
    }

    func testAFlowBecomesBarsThatFollowItsArrows() throws {
        var board = Board(title: "Plan in steps")
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0), text: "Measure")
        let b = board.add(.diamond, centre: CGPoint(x: 200, y: 0), text: "Enough room?")
        let c = board.add(.box, centre: CGPoint(x: 400, y: 0), text: "Order")
        let d = board.add(.box, centre: CGPoint(x: 400, y: 150), text: "Think again")
        board.add(.box, centre: CGPoint(x: 0, y: 300), text: "")
        board.link(from: a, to: b)
        board.link(from: b, to: c)
        board.link(from: b, to: d)

        let made = try XCTUnwrap(board.timelineOfIt(today: dec1))
        XCTAssertEqual(names(made.board), ["Measure", "Enough room?", "Order", "Think again"])
        XCTAssertEqual(after(made.board, "Enough room?"), ["Measure"])
        XCTAssertEqual(after(made.board, "Order"), ["Enough room?"])
        XCTAssertEqual(after(made.board, "Think again"), ["Enough room?"])
        // Both answers of the question start when the question is settled.
        XCTAssertEqual(days(made.board, bar(made.board, "Order")), "2026-12-15…2026-12-21")
        XCTAssertEqual(days(made.board, bar(made.board, "Think again")), "2026-12-15…2026-12-21")
        XCTAssertEqual(made.line, "4 bars. Drag them to their days.")

        // With the question left out (chosen without it), the order it stood in is kept.
        let part = try XCTUnwrap(board.timelineOfIt(chosen: [a, c], today: dec1))
        XCTAssertEqual(names(part.board), ["Measure", "Order"])
        XCTAssertEqual(after(part.board, "Order"), ["Measure"])
        let one = try XCTUnwrap(board.timelineOfIt(chosen: [a], today: dec1))
        XCTAssertEqual(one.line, "1 bar. Drag it to its days.")
    }

    // MARK: Pick 15 — a list pasted onto a timeline

    func testAPastedListBecomesBarsInAChainAndAnIndentedGroupAPhase() throws {
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: dec1, days: 5)                    // 1–5 Dec
        board.addPhase("Shell")
        board.addBar("Walls", start: dec1 + 20, days: 5)

        // Nothing chosen: under the last row, starting today, each after the one before.
        var plain = board
        let list = try XCTUnwrap(plain.pasteBars(Outline.parse("- Dig\n- Pour\n- Cure"), today: dec1 + 2))
        XCTAssertEqual(names(plain), ["Permit", "# Shell", "Walls", "Dig", "Pour", "Cure"])
        XCTAssertEqual(list.bars.count, 3)
        XCTAssertEqual(list.line, "3 bars pasted.")
        XCTAssertEqual(days(plain, bar(plain, "Dig")), "2026-12-03…2026-12-09")
        XCTAssertEqual(days(plain, bar(plain, "Cure")), "2026-12-17…2026-12-23")
        XCTAssertEqual(after(plain, "Pour"), ["Dig"])
        XCTAssertEqual(after(plain, "Dig"), [])

        // With a bar chosen: right under it, and the chain goes on from it. A line with lines under it is a
        // phase, put where it splits no phase that is there.
        var chosen = board
        let text = "Survey\nFoundation\n    Dig\n    Pour\n        Cure"
        let made = try XCTUnwrap(chosen.pasteBars(Outline.parse(text), under: permit, today: dec1 + 2))
        XCTAssertEqual(names(chosen), ["Permit", "Survey", "# Foundation", "Dig", "Pour", "Cure", "# Shell", "Walls"])
        XCTAssertEqual(made.line, "4 bars in 1 phase pasted.")
        XCTAssertEqual(after(chosen, "Survey"), ["Permit"])
        XCTAssertEqual(days(chosen, bar(chosen, "Survey")), "2026-12-06…2026-12-12")
        XCTAssertEqual(days(chosen, bar(chosen, "Dig")), "2026-12-06…2026-12-12")
        XCTAssertEqual(after(chosen, "Cure"), ["Pour"])
        XCTAssertEqual(chosen.item(bar(chosen, "Dig")!)?.colour, chosen.items.first { $0.text == "Foundation" }?.colour)

        // Nothing to paste, and an ordinary board takes no bars.
        XCTAssertNil(chosen.pasteBars([], today: dec1))
        var ordinary = Board(title: "Map")
        XCTAssertNil(ordinary.pasteBars(Outline.parse("One\nTwo"), today: dec1))
    }
}
