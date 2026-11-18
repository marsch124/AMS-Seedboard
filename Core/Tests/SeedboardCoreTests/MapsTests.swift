import XCTest
@testable import SeedboardCore

/// Picks 19 and 21 of 0.2: ideas in another order, "As a project" by the ticks, sending one branch.
final class MapsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A middle idea with the main branches a, b, c … on one side or on both, laid out.
    private func map(_ names: [String], bothSides: Bool) -> (board: Board, centre: UUID, ids: [UUID]) {
        var board = Board()
        let centre = board.addCentre(at: .zero, text: "C", bothSides: bothSides)
        let ids = names.map { board.addChild(of: centre, text: $0)! }
        board.layoutMaps()
        return (board, centre, ids)
    }

    private func names(_ board: Board, under id: UUID, side: Side? = nil) -> [String] {
        board.children(of: id).filter { side == nil || board.side(of: $0.id) == side }.map(\.text)
    }

    // MARK: Pick 19 — one place up or down

    func testShiftMovesOnePlaceAmongTheSistersAndStopsAtTheEnd() {
        var (board, centre, ids) = map(["a", "b", "c"], bothSides: false)
        XCTAssertFalse(board.canShiftIdea(ids[0], down: false))
        XCTAssertTrue(board.shiftIdea(ids[0], down: true))
        XCTAssertEqual(names(board, under: centre), ["b", "a", "c"])
        XCTAssertEqual(board.place(of: ids[0])?.at, 2)
        XCTAssertTrue(board.shiftIdea(ids[0], down: true))
        // The last one of a one-sided family has nowhere further to go; a middle idea has no sisters.
        XCTAssertFalse(board.canShiftIdea(ids[0], down: true))
        XCTAssertFalse(board.shiftIdea(ids[0], down: true))
        XCTAssertFalse(board.shiftIdea(centre, down: true))
        XCTAssertEqual(names(board, under: centre), ["b", "c", "a"])
    }

    func testAMainBranchMovesOnItsOwnSideAndCrossesAtTheEnd() {
        // a and c stand on the right, b and d on the left.
        var (board, centre, ids) = map(["a", "b", "c", "d"], bothSides: true)
        XCTAssertEqual(names(board, under: centre, side: .right), ["a", "c"])
        XCTAssertTrue(board.shiftIdea(ids[0], down: true))
        XCTAssertEqual(names(board, under: centre, side: .right), ["c", "a"])
        XCTAssertEqual(names(board, under: centre, side: .left), ["b", "d"])
        // At the bottom of the right side: over to the bottom of the left side.
        XCTAssertTrue(board.canShiftIdea(ids[0], down: true))
        XCTAssertTrue(board.shiftIdea(ids[0], down: true))
        XCTAssertEqual(names(board, under: centre, side: .right), ["c"])
        XCTAssertEqual(names(board, under: centre, side: .left), ["b", "d", "a"])
        XCTAssertTrue(board.shiftIdea(ids[0], down: false))
        XCTAssertEqual(names(board, under: centre, side: .left), ["b", "a", "d"])
        // The sides are remembered: laying the map out again moves nobody across.
        board.layoutMaps()
        XCTAssertEqual(names(board, under: centre, side: .left), ["b", "a", "d"])
    }

    // MARK: Pick 19 — where a dragged idea lands

    func testADraggedIdeaLandsBetweenSistersHangsTearsOffOrSpringsBack() {
        let (board, centre, ids) = map(["a", "b", "c"], bothSides: false)
        let a = board.item(ids[0])!, b = board.item(ids[1])!, c = board.item(ids[2])!
        let x = a.x + 20
        // In the gap between b and c: it lands before c.
        let gap = CGPoint(x: x, y: (b.y + b.h + c.y) / 2)
        XCTAssertEqual(board.ideaDrop(a.id, at: gap), .reorder(IdeaSlot(parent: centre, side: .right, before: c.id)))
        // The upper edge of c is still that gap; its lower edge and below it mean "after the last".
        XCTAssertEqual(board.ideaDrop(a.id, at: CGPoint(x: x, y: c.y + 2)), .reorder(IdeaSlot(parent: centre, side: .right, before: c.id)))
        XCTAssertEqual(board.ideaDrop(a.id, at: CGPoint(x: x, y: c.y + c.h + 30)), .reorder(IdeaSlot(parent: centre, side: .right, before: nil)))
        // The middle of c: it hangs under c.
        XCTAssertEqual(board.ideaDrop(a.id, at: c.centre), .hang(under: c.id))
        // Its own place (on itself, or the gap right below itself) and the idea it hangs under: nothing changes.
        XCTAssertEqual(board.ideaDrop(a.id, at: a.centre), .springBack)
        XCTAssertEqual(board.ideaDrop(a.id, at: CGPoint(x: x, y: (a.y + a.h + b.y) / 2)), .springBack)
        XCTAssertEqual(board.ideaDrop(a.id, at: board.item(centre)!.centre), .springBack)
        // Sideways: 100 points away is still the family, 200 points away it is torn off.
        let far = CGPoint(x: a.x + a.w + 100, y: gap.y)
        XCTAssertEqual(board.ideaDrop(a.id, at: far), .reorder(IdeaSlot(parent: centre, side: .right, before: c.id)))
        XCTAssertEqual(board.ideaDrop(a.id, at: CGPoint(x: a.x + a.w + 200, y: gap.y)), .tearOff)
        // An idea alone under its parent springs back near home and is torn off far away.
        let (alone, _, only) = map(["x"], bothSides: false)
        let one = alone.item(only[0])!
        XCTAssertEqual(alone.ideaDrop(one.id, at: CGPoint(x: one.x + 10, y: one.y + 60)), .springBack)
        XCTAssertEqual(alone.ideaDrop(one.id, at: CGPoint(x: one.x + 10, y: one.y + 400)), .tearOff)
    }

    func testPlacingAnIdeaInASlotAndTheLandingLine() {
        var (board, centre, ids) = map(["a", "b", "c"], bothSides: false)
        let b = board.item(ids[1])!, c = board.item(ids[2])!
        let slot = IdeaSlot(parent: centre, side: .right, before: ids[2])
        let line = board.landingLine(for: slot, moving: ids[0])
        XCTAssertEqual(line.map { Double($0.from.y) }, (b.y + b.h + c.y) / 2)
        XCTAssertEqual(line.map { Double($0.from.x) }, c.x)
        XCTAssertEqual(line.map { Double($0.to.x - $0.from.x) }, max(board.item(ids[0])!.w, MindMap.shortestLine))
        XCTAssertTrue(board.placeIdea(ids[0], in: slot))
        XCTAssertEqual(names(board, under: centre), ["b", "a", "c"])
        XCTAssertTrue(board.placeIdea(ids[1], in: IdeaSlot(parent: centre, side: .right, before: nil)))
        XCTAssertEqual(names(board, under: centre), ["a", "c", "b"])
        // A main branch dropped into the other side's column takes that side.
        var (two, middle, kids) = map(["a", "b", "c", "d"], bothSides: true)
        let d = two.item(kids[3])!
        let drop = two.ideaDrop(kids[0], at: CGPoint(x: d.x + 5, y: d.y - 2))
        XCTAssertEqual(drop, .reorder(IdeaSlot(parent: middle, side: .left, before: d.id)))
        XCTAssertTrue(two.placeIdea(kids[0], in: IdeaSlot(parent: middle, side: .left, before: d.id)))
        XCTAssertEqual(names(two, under: middle, side: .left), ["b", "a", "d"])
        XCTAssertEqual(names(two, under: middle, side: .right), ["c"])
    }

    // MARK: Pick 21 — "As a project"

    /// Centre "Cabin" with branches "Food" (Buy fish, Bake -> Flour) and "Book trip" (no ideas).
    private func cabin(ticked: Set<String> = []) -> Board {
        let centre = Item(kind: .idea, text: "Cabin")
        let food = Item(kind: .idea, text: "Food", parent: centre.id, order: 1)
        let trip = Item(kind: .idea, text: "Book trip", parent: centre.id, order: 2)
        let fish = Item(kind: .idea, text: "Buy fish", parent: food.id, order: 1)
        let bake = Item(kind: .idea, text: "Bake", parent: food.id, order: 2)
        let flour = Item(kind: .idea, text: "Flour", parent: bake.id, order: 1)
        var board = Board(title: "Summer cabin", items: [centre, food, trip, fish, bake, flour])
        for i in board.items.indices where ticked.contains(board.items[i].text) { board.items[i].todo = true }
        return board
    }

    func testNothingTickedEveryIdeaBecomesATaskAsBefore() {
        let board = cabin()
        let text = ParagonExport.project(board: board, title: "Summer cabin", picture: nil, now: now)
        XCTAssertTrue(text.contains("## Tasks\n\n- [ ] Book trip\n\n### Food\n- [ ] Buy fish\n- [ ] Bake\n  - [ ] Flour\n"))
        XCTAssertEqual(ParagonExport.projectLine(board: board), "Nothing is ticked: all 4 ideas become tasks.")
        // A ticked note alone does not switch the rule: no idea is ticked.
        var noted = board
        noted.items.append(Item(kind: .note, text: "Call Alex", todo: true))
        noted.items.append(Item(kind: .box, text: "Draft"))
        XCTAssertFalse(ParagonExport.ticksDecide(noted))
        XCTAssertEqual(ParagonExport.projectLine(board: noted), "No idea is ticked: all 4 ideas and 1 shape become tasks.")
        XCTAssertNil(ParagonExport.projectLine(board: Board(items: [Item(kind: .note, text: "Only a note")])))
    }

    func testTickedIdeasBecomeTasksTheOthersStayPlainLines() {
        var board = cabin(ticked: ["Buy fish", "Flour"])
        board.items.append(Item(kind: .box, text: "Draft"))
        board.items.append(Item(kind: .box, text: "Send", todo: true))
        let text = ParagonExport.project(board: board, title: "Summer cabin", picture: nil, now: now)
        // "Flour" hangs under the plain line "Bake": it stands at the left edge, so PARAGON does not
        // make it a sub-task of "Buy fish".
        XCTAssertTrue(text.contains("## Tasks\n\n- Book trip\n\n### Food\n- [ ] Buy fish\n- Bake\n- [ ] Flour\n\n### Steps\n- Draft\n- [ ] Send\n"))
        XCTAssertEqual(ParagonExport.projectTally(board: board),
                       ParagonExport.ProjectTally(ticks: true, ideaTasks: 2, ideaPlain: 2, shapeTasks: 1, shapePlain: 1, otherTasks: 0, anyTick: true))
        XCTAssertEqual(ParagonExport.projectLine(board: board), "3 ticked things become tasks, 3 stay as plain lines.")
        XCTAssertEqual(ParagonExport.projectLine(board: cabin(ticked: ["Flour"])), "1 ticked idea becomes a task, 3 stay as plain lines.")
        // A ticked main branch is a task with its ideas below it; a ticked idea under a ticked one is its sub-task.
        let nested = ParagonExport.project(board: cabin(ticked: ["Food", "Bake", "Flour"]), title: "T", picture: nil, now: now)
        XCTAssertTrue(nested.contains("## Tasks\n\n- [ ] Food\n  - Buy fish\n  - [ ] Bake\n    - [ ] Flour\n- Book trip\n\n## Notes"))
    }

    func testOnlyTheBranchIsASmallMapOfItsOwn() {
        var board = cabin(ticked: ["Flour"])
        board.items.append(Item(kind: .note, text: "Elsewhere", todo: true))
        board.sent = SentInfo(when: now, kind: "note", title: "Summer cabin", path: "Resources/Summer cabin.md")
        let food = board.items.first { $0.text == "Food" }!
        let part = board.branchOnly(food.id)!
        XCTAssertEqual(part.id, board.id)
        XCTAssertEqual(part.title, "Food")
        XCTAssertNil(part.sent)
        XCTAssertEqual(Set(part.items.map(\.text)), ["Food", "Buy fish", "Bake", "Flour"])
        XCTAssertTrue(part.isCentre(food.id))
        // The ideas under it keep the colour the branch had on the board.
        XCTAssertEqual(part.branchColour(of: part.items.first { $0.text == "Flour" }!.id), board.branchColour(of: food.id))
        let note = ParagonExport.note(board: part, title: "Food", picture: nil, now: now)
        XCTAssertTrue(note.contains("## Outline\n\n- Food\n  - Buy fish\n  - Bake\n    - Flour\n\n## Tasks\n\n- [ ] Flour\n"))
        XCTAssertFalse(note.contains("Elsewhere"))
        XCTAssertFalse(note.contains("Book trip"))
        XCTAssertTrue(note.contains("seedboard://board/\(board.id.uuidString)"))
        XCTAssertEqual(ParagonExport.inboxTasks(board: part).map(\.text), ["Flour"])
        XCTAssertNil(board.branchOnly(board.items.last!.id))
    }
}
