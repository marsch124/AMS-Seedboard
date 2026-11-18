import XCTest
@testable import SeedboardCore

/// 0.9, timeline-b: a phase folds its rows away (picks 7) and milestones go into the calendar (pick 12).
final class Phases09Tests: XCTestCase {
    private let dec1 = Day(year: 2026, month: 12, day: 1)

    /// Plan(# A: Dig, Pour, Done♦) (# B: Roof) and a bar above the first phase.
    private func board() -> (Board, [String: UUID]) {
        var b = Board.timeline(title: "Cabin")
        var ids: [String: UUID] = [:]
        ids["Prep"] = b.addBar("Prep", start: dec1, days: 2)
        ids["A"] = b.addPhase("A")
        ids["Dig"] = b.addBar("Dig", start: dec1 + 2, days: 3)
        ids["Pour"] = b.addBar("Pour", start: dec1 + 6, days: 2)
        ids["Done"] = b.addMilestone("Done", on: dec1 + 10)
        ids["B"] = b.addPhase("B")
        ids["Roof"] = b.addBar("Roof", start: dec1 + 12, days: 4)
        return (b, ids)
    }

    private func names(_ rows: [Item]) -> [String] { rows.map(\.text) }

    func testFoldedPhaseHidesItsRowsAndRowsKeepTheirNumbers() {
        var (b, ids) = board()
        let before = b.timelineRows.map { $0.row }
        XCTAssertEqual(names(b.shownTimelineRows), ["Prep", "A", "Dig", "Pour", "Done", "B", "Roof"])
        b.setFolded(ids["A"]!, true)
        XCTAssertEqual(names(b.shownTimelineRows), ["Prep", "A", "B", "Roof"])
        XCTAssertEqual(b.timelineRows.map { $0.row }, before, "folding never renumbers")
        XCTAssertEqual(b.shownRow(of: ids["B"]!), 2)
        XCTAssertNil(b.shownRow(of: ids["Pour"]!))
        // The group as counted on screen: the folded phase is one row, the next starts under it.
        let groups = b.shownPhaseGroups
        XCTAssertEqual(groups.map { [$0.firstRow, $0.lastRow] }, [[1, 1], [2, 3]])
        XCTAssertEqual(groups[0].foldWords, "2 bars, 1 milestone")
        XCTAssertEqual(groups[0].start, dec1 + 2)
        XCTAssertEqual(groups[0].end, dec1 + 10)
        // The bar above the first phase is never hidden; the stored place of a shown row.
        XCTAssertEqual(b.storedRow(forShown: 2), 5)
        XCTAssertEqual(b.storedRow(forShown: 9), 7)
    }

    func testFoldAllAndUnfoldAll() {
        var (b, ids) = board()
        XCTAssertTrue(b.canFoldAny)
        XCTAssertFalse(b.canUnfoldAny)
        XCTAssertEqual(b.foldAllPhases(true), 2)
        XCTAssertEqual(names(b.shownTimelineRows), ["Prep", "A", "B"])
        XCTAssertFalse(b.canFoldAny)
        XCTAssertEqual(b.foldAllPhases(false), 2)
        XCTAssertEqual(b.shownTimelineRows.count, 7)
        // An empty phase cannot fold; only a phase can.
        b.addPhase("Empty")
        XCTAssertFalse(b.canFold(b.items.last!.id))
        b.setFolded(ids["Dig"]!, true)
        XCTAssertFalse(b.item(ids["Dig"]!)!.folded)
        // Folding is kept in the file.
        b.setFolded(ids["A"]!, true)
        let again = try? JSONDecoder().decode(Board.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(again?.item(ids["A"]!)?.folded, true)
    }

    func testCalendarEventsAndWhatWasAdded() {
        var (b, ids) = board()
        let choices = b.calendarChoices(memory: CalendarMemory())
        XCTAssertEqual(choices.milestones.map(\.event.title), ["Done"])
        XCTAssertEqual(choices.bars.map(\.event.title), ["Prep", "Dig", "Pour", "Roof"])
        XCTAssertEqual(choices.milestones.map(\.ticked), [true])
        XCTAssertEqual(choices.bars.map(\.ticked), [false, false, false, false])
        let dig = choices.bars[1].event
        XCTAssertEqual(dig.dayCount, 3)
        XCTAssertEqual(dig.notes, "From the Seedboard board “Cabin”")
        XCTAssertEqual(choices.milestones[0].event.dayCount, 1)

        var memory = CalendarMemory()
        memory.remember([choices.milestones[0].event, dig], on: Day(year: 2026, month: 11, day: 18))
        XCTAssertEqual(memory.words(of: b.item(ids["Done"]!)!), "Added 18 Nov")
        XCTAssertEqual(b.calendarChoices(memory: memory).milestones.map(\.ticked), [false])
        // The day moves: it says so and is ticked again; a bar that got longer says "Days changed".
        b.setDates(ids["Done"]!, start: dec1 + 11, end: dec1 + 11)
        b.setDates(ids["Dig"]!, start: dec1 + 2, end: dec1 + 6)
        XCTAssertEqual(memory.words(of: b.item(ids["Done"]!)!), "Day changed — add again")
        XCTAssertEqual(memory.words(of: b.item(ids["Dig"]!)!), "Days changed — add again")
        XCTAssertEqual(b.calendarChoices(memory: memory).milestones.map(\.ticked), [true])
        // What the device keeps survives being written and read.
        let back = try? JSONDecoder().decode(CalendarMemory.self, from: JSONEncoder().encode(memory))
        XCTAssertEqual(back, memory)
    }
}
