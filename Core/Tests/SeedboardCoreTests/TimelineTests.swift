import XCTest
import CoreGraphics
@testable import SeedboardCore

final class TimelineTests: XCTestCase {
    private let dec1 = Day(year: 2026, month: 12, day: 1)   // a Tuesday

    /// Permit (1–5 Dec) → Foundation (8–12 Dec) → Walls (15–19 Dec), each in its own row.
    private func chain() -> (board: Board, permit: UUID, foundation: UUID, walls: UUID) {
        var board = Board.timeline(title: "Build")
        let permit = board.addBar("Permit", start: dec1, days: 5)
        let foundation = board.addBar("Foundation", start: dec1 + 7, days: 5)
        let walls = board.addBar("Walls", start: dec1 + 14, days: 5)
        board.comesAfter(foundation, after: permit)
        board.comesAfter(walls, after: foundation)
        return (board, permit, foundation, walls)
    }

    private func days(_ board: Board, _ id: UUID) -> String {
        guard let span = board.item(id)?.span else { return "none" }
        return "\(span.start.iso)…\(span.end.iso)"
    }

    // MARK: Days

    func testADayReadsAndWritesItsDateAndKnowsItsWeekday() {
        XCTAssertEqual(Day(iso: "2026-12-01"), dec1)
        XCTAssertEqual(dec1.iso, "2026-12-01")
        XCTAssertEqual(dec1.weekday, 1)                                   // Tuesday
        XCTAssertEqual(dec1.weekStart.iso, "2026-11-30")                  // its Monday
        XCTAssertEqual((dec1 + 31).iso, "2027-01-01")
        XCTAssertEqual(Day(iso: "2028-02-29")! + 1, Day(iso: "2028-03-01"))  // a leap year
        XCTAssertEqual(Day(iso: "2027-01-01")! - dec1, 31)
        XCTAssertEqual(dec1.short, "1 Dec")
        XCTAssertEqual(dec1.nextMonthStart.long, "1 Jan 2027")
        XCTAssertNil(Day(iso: "soon"))
        XCTAssertEqual(Day(number: 0).iso, "1970-01-01")
    }

    // MARK: Days ↔ x

    func testDayAndXAgreeOnAllThreeScales() {
        for scale in TimeScale.allCases {
            var g = TimelineGeometry(scale: scale, namesWidth: 170)
            g.slide = CGSize(width: g.slide(showing: dec1), height: 0)
            XCTAssertEqual(g.x(of: dec1), 170, accuracy: 0.001, "\(scale)")
            XCTAssertEqual(g.x(of: dec1 + 7) - g.x(of: dec1), 7 * scale.pointsPerDay, accuracy: 0.001, "\(scale)")
            // Anywhere inside a day's width is that day.
            XCTAssertEqual(g.day(atX: g.x(of: dec1 + 9) + scale.pointsPerDay * 0.5), dec1 + 9, "\(scale)")
            XCTAssertEqual(g.day(atX: g.x(of: dec1) - 0.1), dec1 - 1, "\(scale)")
        }
        XCTAssertEqual(TimeScale.days.pointsPerDay, 28)
        XCTAssertEqual(TimeScale.weeks.pointsPerDay * 7, 56)
        XCTAssertEqual(TimelineGeometry(scale: .weeks).days(forDrag: 13), 2)   // 13 points of 8 a day: nearer 2 than 1
        XCTAssertEqual(TimelineGeometry(scale: .weeks).days(forDrag: -3), 0)
    }

    func testABarIsAsWideAsItsDaysAndSitsInItsRow() {
        var g = TimelineGeometry(scale: .days, namesWidth: 100, headerHeight: 44, rowHeight: 34, barHeight: 22)
        g.slide = CGSize(width: g.slide(showing: dec1), height: 0)
        let bar = g.bar(from: dec1, to: dec1 + 2, row: 1)
        XCTAssertEqual(bar.minX, 101, accuracy: 0.001)
        XCTAssertEqual(bar.width, 3 * 28 - 2, accuracy: 0.001)
        XCTAssertEqual(bar.minY, 44 + 34 + 6, accuracy: 0.001)
        XCTAssertEqual(g.row(atY: 44 + 34 + 10), 1)
        XCTAssertEqual(g.diamond(on: dec1, row: 0).midX, 100 + 14, accuracy: 0.001)
        XCTAssertEqual(g.todayX(dec1), 114, accuracy: 0.001)
    }

    func testTheClosestScaleThatShowsEverythingIsChosen() {
        XCTAssertEqual(TimeScale.fitting(days: 20, width: 600), .days)
        XCTAssertEqual(TimeScale.fitting(days: 60, width: 600), .weeks)
        XCTAssertEqual(TimeScale.fitting(days: 200, width: 600), .months)
        XCTAssertEqual(TimeScale.fitting(days: 2000, width: 600), .months)
        XCTAssertEqual(TimeScale.months.closer, .weeks)
        XCTAssertNil(TimeScale.days.closer)
        XCTAssertEqual(TimeScale.days.further, .weeks)
    }

    func testTheDatesAlongTheTop() {
        let weeks = TimelineGeometry.ticks(from: dec1, to: dec1 + 20, scale: .weeks)
        XCTAssertEqual(weeks.map(\.label), ["7 Dec", "14 Dec", "21 Dec"])           // Mondays only
        let dayTicks = TimelineGeometry.ticks(from: dec1, to: dec1 + 6, scale: .days)
        XCTAssertEqual(dayTicks.map(\.label), ["1", "2", "3", "4", "5", "6", "7"])
        XCTAssertEqual(dayTicks.filter(\.strong).map(\.label), ["7"])               // the Monday
        let months = TimelineGeometry.ticks(from: dec1, to: dec1 + 70, scale: .months)
        XCTAssertEqual(months.map(\.label), ["Dec", "Jan", "Feb"])
        XCTAssertEqual(TimelineGeometry.heads(from: dec1, to: dec1 + 40, scale: .days).map(\.label), ["December 2026", "January 2027"])
        XCTAssertEqual(TimelineGeometry.heads(from: dec1, to: dec1 + 40, scale: .weeks).map(\.label), ["2026", "2027"])
    }

    // MARK: Moving and stretching

    func testMovingABarKeepsItsLengthInWholeDays() {
        var board = Board.timeline()
        let bar = board.addBar("Roof", start: dec1, days: 4)
        XCTAssertEqual(board.shift([bar], byDays: 3), 0)
        XCTAssertEqual(days(board, bar), "2026-12-04…2026-12-07")
        board.shift([bar], byDays: -10)
        XCTAssertEqual(days(board, bar), "2026-11-24…2026-11-27")
        XCTAssertEqual(board.item(bar)?.dayCount, 4)
    }

    func testStretchingNeverMakesABarShorterThanOneDay() {
        var board = Board.timeline()
        let bar = board.addBar("Roof", start: dec1, days: 4)                 // 1…4 Dec
        board.stretch(bar, .end, to: dec1 + 9)
        XCTAssertEqual(days(board, bar), "2026-12-01…2026-12-10")
        board.stretch(bar, .end, to: dec1 - 5)                                // pulled past its own start
        XCTAssertEqual(days(board, bar), "2026-12-01…2026-12-01")
        XCTAssertEqual(board.item(bar)?.dayCount, 1)
        board.stretch(bar, .end, to: dec1 + 3)
        board.stretch(bar, .start, to: dec1 + 20)                             // pulled past its own end
        XCTAssertEqual(days(board, bar), "2026-12-04…2026-12-04")
        board.stretch(bar, .start, to: dec1 - 2)
        XCTAssertEqual(days(board, bar), "2026-11-29…2026-12-04")
        XCTAssertEqual(board.addBar(start: dec1, days: 0).uuidString.isEmpty, false)
        XCTAssertEqual(board.items.last?.dayCount, 1)                         // a new bar of "no days" is one day
    }

    func testMovingABarPushesEveryBarThatComesAfterItAndSaysHowMany() {
        var (board, permit, foundation, walls) = chain()
        // Permit ends 5 Dec, Foundation starts 8 Dec: two free days between them.
        XCTAssertEqual(board.shift([permit], byDays: 2), 0)                   // room enough: nothing pushed
        XCTAssertEqual(days(board, foundation), "2026-12-08…2026-12-12")
        XCTAssertEqual(board.shift([permit], byDays: 5), 2)                   // Permit now 8…12 Dec
        XCTAssertEqual(days(board, permit), "2026-12-08…2026-12-12")
        XCTAssertEqual(days(board, foundation), "2026-12-13…2026-12-17")      // the day after, same length
        XCTAssertEqual(days(board, walls), "2026-12-18…2026-12-22")
        // Moving back pulls nothing along: bars are only ever pushed later.
        XCTAssertEqual(board.shift([permit], byDays: -7), 0)
        XCTAssertEqual(days(board, foundation), "2026-12-13…2026-12-17")
        // Stretching the end pushes too.
        XCTAssertEqual(board.stretch(foundation, .end, to: Day(iso: "2026-12-20")!), 1)
        XCTAssertEqual(days(board, walls), "2026-12-21…2026-12-25")
    }

    func testABarCannotStartBeforeTheBarItComesAfterHasEnded() {
        var (board, _, foundation, walls) = chain()
        board.shift([foundation], byDays: -30)                                // dragged far to the left
        XCTAssertEqual(days(board, foundation), "2026-12-06…2026-12-10")      // stops the day after Permit ends
        board.stretch(walls, .start, to: dec1)
        XCTAssertEqual(board.item(walls)?.span?.start.iso, "2026-12-11")      // the day after Foundation ends
        XCTAssertEqual(board.setDates(foundation, start: dec1, end: dec1 + 20), 1)
        XCTAssertEqual(days(board, foundation), "2026-12-06…2026-12-26")      // the Dates page keeps the rule too
        XCTAssertEqual(board.item(walls)?.span?.start.iso, "2026-12-27")
    }

    func testComesAfterIsRefusedForARingAPhaseAndTheSamePairTwice() {
        var (board, permit, foundation, walls) = chain()
        XCTAssertNil(board.comesAfter(permit, after: walls))                  // would close a ring
        XCTAssertNil(board.comesAfter(foundation, after: permit))             // there already
        let phase = board.addPhase("Shell")
        XCTAssertNil(board.comesAfter(phase, after: permit))
        XCTAssertEqual(board.links.count, 2)
        // Joining a bar that starts too early pushes it: one bar moved.
        let early = board.addBar("Paint", start: dec1, days: 2)
        XCTAssertEqual(board.comesAfter(early, after: walls), 1)
        XCTAssertEqual(board.item(early)?.span?.start.iso, "2026-12-20")
    }

    func testReturnMakesTheNextBarInTheRowBelowTheDayAfter() throws {
        var (board, permit, foundation, _) = chain()
        let next = try XCTUnwrap(board.addBarAfter(permit))
        XCTAssertEqual(days(board, next), "2026-12-06…2026-12-10")            // the day after, as long as Permit
        XCTAssertEqual(board.timelineRows.map(\.text), ["Permit", "", "Foundation", "Walls"])
        XCTAssertTrue(board.links.contains { $0.from == permit && $0.to == next })
        XCTAssertEqual(board.item(next)?.colour, board.item(permit)?.colour)
        XCTAssertEqual(board.timelineRow(of: foundation), 2)
    }

    // MARK: Rows

    func testRowsCanBeReordered() {
        var board = Board.timeline()
        let a = board.addBar("A", start: dec1)
        let b = board.addBar("B", start: dec1)
        let c = board.addMilestone("C", on: dec1)
        XCTAssertEqual(board.timelineRows.map(\.text), ["A", "B", "C"])
        board.moveRow(c, to: 0)
        XCTAssertEqual(board.timelineRows.map(\.text), ["C", "A", "B"])
        board.moveRow(c, to: 99)                                              // past the end: the last row
        XCTAssertEqual(board.timelineRows.map(\.text), ["A", "B", "C"])
        board.moveRow(a, to: 1)
        XCTAssertEqual(board.timelineRows.map(\.text), ["B", "A", "C"])
        XCTAssertEqual([b, a, c].map { board.item($0)?.row }, [0, 1, 2])
        let d = board.addBar("D", start: dec1, atRow: 1)                      // a new row in between
        XCTAssertEqual(board.timelineRow(of: d), 1)
        XCTAssertEqual(board.timelineRows.map(\.text), ["B", "D", "A", "C"])
        let copies = board.duplicateRows([b])
        XCTAssertEqual(board.timelineRows.map(\.text), ["B", "B", "D", "A", "C"])
        XCTAssertEqual(copies.count, 1)
    }

    func testAPhaseHoldsTheRowsUnderItDownToTheNextPhase() {
        var board = Board.timeline()
        board.addBar("Loose", start: dec1)
        let ground = board.addPhase("Groundwork")
        board.addBar("Permit", start: dec1, days: 5)
        board.addBar("Foundation", start: dec1 + 7, days: 5)
        let shell = board.addPhase("Shell")
        let groups = board.phaseGroups
        XCTAssertEqual(groups.map(\.id), [ground, shell])
        XCTAssertEqual(groups[0].firstRow, 1)
        XCTAssertEqual(groups[0].lastRow, 3)
        XCTAssertEqual(groups[0].start, dec1)
        XCTAssertEqual(groups[0].end, dec1 + 11)
        XCTAssertEqual(groups[1].firstRow, 4)
        XCTAssertEqual(groups[1].lastRow, 4)
        XCTAssertNil(groups[1].start)
        XCTAssertEqual(board.countLine, "3 bars · 2 phases")
        XCTAssertEqual(Board.timeline().countLine, "Empty")
    }

    // MARK: What is seen

    func testTheDaysShownAlwaysHoldTodayAndAFewDaysOfAir() {
        let (board, _, _, _) = chain()                                        // 1…19 Dec
        let inside = board.timelineRange(today: dec1 + 3, air: 7)
        XCTAssertEqual(inside.first.iso, "2026-11-24")
        XCTAssertEqual(inside.last.iso, "2026-12-26")
        let before = board.timelineRange(today: Day(iso: "2026-10-01")!, air: 3)   // today long before the first bar
        XCTAssertEqual(before.first.iso, "2026-09-28")
        XCTAssertEqual(before.last.iso, "2026-12-22")
        let empty = Board.timeline().timelineRange(today: dec1, air: 7)
        XCTAssertEqual(empty.first.iso, "2026-11-24")
        XCTAssertEqual(empty.last.iso, "2026-12-08")
        let picture = board.timelinePicture(today: dec1 + 3, width: 1100)
        XCTAssertEqual(picture.geometry.scale, .days)                         // 19 days and air fit at the closest scale
        XCTAssertEqual(picture.box.height, 44 + 3 * 34 + 10)
        XCTAssertEqual(picture.geometry.x(of: Day(iso: "2026-11-23")!), picture.geometry.namesWidth, accuracy: 0.001)  // starts on a Monday
        XCTAssertNotNil(board.bounds)
    }

    func testTheArrowGoesOutDownAndInAtRightAngles() {
        let g = TimelineGeometry(scale: .weeks)
        let a = CGRect(x: 100, y: 50, width: 60, height: 22)
        let far = CGRect(x: 200, y: 84, width: 60, height: 22)
        XCTAssertEqual(g.arrow(from: a, to: far), [CGPoint(x: 160, y: 61), CGPoint(x: 168, y: 61), CGPoint(x: 168, y: 95), CGPoint(x: 200, y: 95)])
        // The next bar starts right under the end: back along the line between the two rows.
        let near = CGRect(x: 162, y: 84, width: 60, height: 22)
        let route = g.arrow(from: a, to: near)
        XCTAssertEqual(route.count, 6)
        XCTAssertEqual(route[2].y, 61 + 17)
        XCTAssertEqual(route.last, CGPoint(x: 162, y: 95))
        for (p, q) in zip(route, route.dropFirst()) { XCTAssertTrue(p.x == q.x || p.y == q.y, "a slanted piece") }
    }

    // MARK: The file

    func testATimelineIsKeptInTheFileAndAnOlderBoardStaysOrdinary() throws {
        var (board, permit, _, _) = chain()
        board.addMilestone("Move in", on: dec1 + 30)
        XCTAssertEqual(Board.currentFormat, 2)
        XCTAssertEqual(board.format, 2)
        let data = try JSONEncoder().encode(board)
        let back = try JSONDecoder().decode(Board.self, from: data)
        XCTAssertEqual(back, board)
        XCTAssertTrue(back.isTimeline)
        XCTAssertEqual(back.item(permit)?.start, "2026-12-01")
        XCTAssertEqual(back.item(permit)?.end, "2026-12-05")
        XCTAssertEqual(back.item(permit)?.row, 0)
        XCTAssertNil(back.items.last?.end)                                    // a milestone keeps one day
        // A 0.1 file: no kind, no days — an ordinary board, and nothing new is written into it.
        let old = try JSONDecoder().decode(Board.self, from: Data(#"{"id":"11111111-1111-1111-1111-111111111111","format":1,"items":[{"kind":"box","text":"Old"}]}"#.utf8))
        XCTAssertFalse(old.isTimeline)
        XCTAssertNil(old.items[0].start)
        XCTAssertTrue(old.canBeChanged)
        let written = String(decoding: try JSONEncoder().encode(old), as: UTF8.self)
        XCTAssertFalse(written.contains("\"start\""))
        XCTAssertFalse(written.contains("\"kind\":\"timeline\""))
        // The 0.1 app's own rule (format above the one it knows = look, do not change) still holds for the next format.
        let newer = try JSONDecoder().decode(Board.self, from: Data(#"{"id":"11111111-1111-1111-1111-111111111111","format":3,"kind":"timeline"}"#.utf8))
        XCTAssertFalse(newer.canBeChanged)
    }

    func testTheTimelineStarterBeginsTodayAndIsOnTheList() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let board = Starter.timeline.board(now: now)
        XCTAssertTrue(Starter.allCases.contains(.timeline))
        XCTAssertEqual(Starter.timeline.hint, "Bars on days, with what comes after what")
        XCTAssertTrue(board.isTimeline)
        XCTAssertEqual(board.title, "Timeline")
        XCTAssertEqual(board.countLine, "3 bars · 1 milestone")
        XCTAssertEqual(board.timelineRows.first?.span?.start, Day(now))
        XCTAssertEqual(board.links.count, 3)
        // Every arrow is kept: nothing starts before its forerunner ends.
        for link in board.links {
            XCTAssertGreaterThan(board.item(link.to)!.span!.start, board.item(link.from)!.span!.end)
        }
    }

    // MARK: PARAGON

    func testAsAProjectPhasesAreHeadingsAndBarsAreTasksInDateOrder() {
        var board = Board.timeline(title: "Cabin")
        board.addBar("Order windows", start: Day(iso: "2026-12-28")!, days: 10)     // above the first phase, over New Year
        board.addPhase("Groundwork")
        board.addBar("Foundation", start: dec1 + 7, days: 5)                        // made first, but later in time
        board.addBar("Permit", start: dec1, days: 5)
        board.addBar("Call the bank", start: dec1 + 2, days: 1)
        board.addPhase("Shell")
        board.addMilestone("Roof on", on: Day(iso: "2027-02-20")!)
        let text = ParagonExport.project(board: board, title: "Cabin", picture: nil, now: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertTrue(text.contains("type: project\nstatus: active\n"))
        XCTAssertTrue(text.contains("\ndue: 2027-02-20\n---\n# Cabin\n"))
        XCTAssertTrue(text.contains("""
        ## Tasks

        - [ ] Order windows (starts 28 Dec 2026) >2027-01-06

        ### Groundwork
        - [ ] Permit (starts 1 Dec) >2026-12-05
        - [ ] Call the bank >2026-12-03
        - [ ] Foundation (starts 8 Dec) >2026-12-12

        ### Shell
        - [ ] Roof on >2027-02-20

        ## Notes
        """), text)
        XCTAssertTrue(text.contains("[Open the board in Seedboard](seedboard://board/\(board.id.uuidString))"))
    }

    func testAsANoteTheBarsAreListedWithTheirDates() {
        var (board, permit, _, _) = chain()
        if let i = board.index(of: permit) { board.items[i].todo = true }
        board.addPhase("Finish")
        board.addMilestone("Move in", on: Day(iso: "2027-01-10")!)
        let text = ParagonExport.note(board: board, title: "Build", picture: "Seedboard Build.png", now: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertTrue(text.contains("type: resource\n"))
        XCTAssertTrue(text.contains("![Picture](../Pictures/Seedboard%20Build.png)"))
        XCTAssertTrue(text.contains("""
        ## Timeline

        - Permit: 1 Dec – 5 Dec 2026 · 5 days
        - Foundation: 8 Dec – 12 Dec 2026 · 5 days
        - Walls: 15 Dec – 19 Dec 2026 · 5 days
        - **Finish**
          - Move in (milestone): 10 Jan 2027

        ## Comes after

        - Foundation comes after Permit
        - Walls comes after Foundation

        ## Tasks

        - [ ] Permit (starts 1 Dec) >2026-12-05
        """), text)
        // Only the to-do boxes: as before, the ticked bar is the one Inbox task.
        XCTAssertEqual(ParagonExport.inboxTasks(board: board).map(\.text), ["Permit"])
        XCTAssertTrue(board.outlineText.hasPrefix("- Permit: 1 Dec – 5 Dec 2026 · 5 days"))
    }
}
