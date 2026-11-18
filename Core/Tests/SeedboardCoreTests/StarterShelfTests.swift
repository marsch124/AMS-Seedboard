import XCTest
@testable import SeedboardCore

final class StarterShelfTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testShelfIsTheSevenBuiltInsInOrder() {
        let shelf = StarterShelf()
        XCTAssertEqual(shelf.shown.map(\.id), Starter.allCases.map(\.id))
        XCTAssertEqual(shelf.shown.map(\.name), Starter.allCases.map(\.name))
        XCTAssertFalse(shelf.missingBuiltins)
    }

    func testRenameOverridesNameAndHint() {
        var shelf = StarterShelf()
        shelf.rename("flow", name: "My flow", hint: "Mine", now: now)
        let s = shelf.starter("flow")
        XCTAssertEqual(s?.name, "My flow")
        XCTAssertEqual(s?.hint, "Mine")
        XCTAssertEqual(shelf.shown.count, Starter.allCases.count)
    }

    func testMoveGoesBetweenNeighbours() {
        var shelf = StarterShelf()
        shelf.move("timeline", to: 1, now: now)
        XCTAssertEqual(shelf.shown.map(\.id).prefix(3), ["blank", "timeline", "mindMap"])
        shelf.move("blank", to: 99, now: now)
        XCTAssertEqual(shelf.shown.last?.id, "blank")
        shelf.move("sequence", to: 0, now: now)
        XCTAssertEqual(shelf.shown.first?.id, "sequence")
    }

    func testRemoveAndBringBack() {
        var shelf = StarterShelf()
        XCTAssertTrue(shelf.remove("steps", now: now))
        XCTAssertEqual(shelf.shown.count, Starter.allCases.count - 1)
        XCTAssertTrue(shelf.missingBuiltins)
        shelf.bringBackBuiltins(now: now.addingTimeInterval(5))
        XCTAssertEqual(shelf.shown.count, Starter.allCases.count)
        XCTAssertFalse(shelf.missingBuiltins)
    }

    func testBlankCannotBeRemoved() {
        var shelf = StarterShelf()
        XCTAssertFalse(shelf.remove("blank", now: now))
        XCTAssertEqual(shelf.shown.count, Starter.allCases.count)
        shelf.rename("blank", name: "Empty", hint: "", now: now)
        XCTAssertEqual(shelf.shown.first?.name, "Empty")
    }

    func testChangedBuiltInGoesBackToTheOriginal() {
        var shelf = StarterShelf()
        var b = Starter.mindMap.board(now: now)
        b.items[0].text = "Changed"
        shelf.change("mindMap", board: b, now: now)
        XCTAssertTrue(shelf.starter("mindMap")?.isChangedBuiltin ?? false)
        XCTAssertEqual(shelf.makeBoard(from: "mindMap", now: now)?.items.contains { $0.text == "Changed" }, true)
        shelf.backToOriginal("mindMap", now: now.addingTimeInterval(1))
        XCTAssertFalse(shelf.starter("mindMap")?.isChangedBuiltin ?? true)
        XCTAssertEqual(shelf.makeBoard(from: "mindMap", now: now)?.items.contains { $0.text == "Changed" }, false)
    }

    func testUntouchedBuiltInMakesTheBoardAsBefore() {
        let shelf = StarterShelf()
        let made = shelf.makeBoard(from: "flow", now: now)!
        let plain = Starter.flow.board(now: now)
        XCTAssertEqual(made.title, "Flow")
        XCTAssertEqual(made.items.map(\.text), plain.items.map(\.text))
        XCTAssertEqual(shelf.makeBoard(from: "blank", now: now)?.title, "New board")
    }

    func testFreshBoardHasNewIdsAndEveryReferenceRepointed() {
        var shelf = StarterShelf()
        var old = Starter.sequence.board(now: now)
        old.pinned = true
        old.sentTodos = [UUID()]
        old.sent = SentInfo(when: now, kind: "note", title: "x", path: "x.md")
        let id = shelf.saveAs(old, name: "Mine", now: now)
        let made = shelf.makeBoard(from: id, now: now.addingTimeInterval(100))!
        XCTAssertNotEqual(made.id, old.id)
        XCTAssertEqual(made.title, "Mine")
        XCTAssertTrue(Set(made.items.map(\.id)).isDisjoint(with: Set(old.items.map(\.id))))
        let ids = Set(made.items.map(\.id))
        for item in made.items {
            if let f = item.from { XCTAssertTrue(ids.contains(f)) }
            if let t = item.to { XCTAssertTrue(ids.contains(t)) }
        }
        XCTAssertEqual(made.items.filter { $0.from != nil }.count, old.items.filter { $0.from != nil }.count)
        XCTAssertNil(made.sent)
        XCTAssertTrue(made.sentTodos.isEmpty)
        XCTAssertFalse(made.pinned)
        XCTAssertEqual(made.created, now.addingTimeInterval(100))
    }

    func testFreshMapAndArrowsAreRepointed() {
        var shelf = StarterShelf()
        let flow = Starter.flow.board(now: now)
        let id = shelf.saveAs(flow, name: "F", now: now)
        let made = shelf.makeBoard(from: id, now: now)!
        XCTAssertEqual(made.links.count, flow.links.count)
        for l in made.links { XCTAssertNotNil(made.item(l.from)); XCTAssertNotNil(made.item(l.to)) }
        let mind = Starter.mindMap.board(now: now)
        let mid = shelf.saveAs(mind, name: "M", now: now)
        let m = shelf.makeBoard(from: mid, now: now)!
        for i in m.items { if let p = i.parent { XCTAssertNotNil(m.item(p)) } }
        XCTAssertEqual(m.items.filter { $0.parent != nil }.count, mind.items.filter { $0.parent != nil }.count)
    }

    func testTimelineMovesByWholeDays() {
        var shelf = StarterShelf()
        let saved = Starter.timeline.board(now: now)
        let id = shelf.saveAs(saved, name: "T", now: now)
        let later = now.addingTimeInterval(10 * 86_400)
        let made = shelf.makeBoard(from: id, now: later)!
        let a = saved.items.compactMap(\.start).compactMap { Day(iso: $0) }.min()!
        let b = made.items.compactMap(\.start).compactMap { Day(iso: $0) }.min()!
        XCTAssertEqual(b - a, 10)
    }

    func testNewerCopyWins() {
        let old = StarterEntry(id: "x", name: "Old", changed: now)
        let new = StarterEntry(id: "x", name: "New", changed: now.addingTimeInterval(5))
        XCTAssertEqual(StarterEntry.newer(old, new).name, "New")
        XCTAssertEqual(StarterShelf(entries: [new, old]).starter("x")?.name, "New")
    }

    func testEntryCarriesUnknownFieldsAndToleratesMissingOnes() throws {
        let json = #"{"id":"abc","future":{"a":1}}"#.data(using: .utf8)!
        let e = try JSONDecoder().decode(StarterEntry.self, from: json)
        XCTAssertEqual(e.name, "Starter")
        let back = try JSONEncoder().encode(e)
        XCTAssertTrue(String(data: back, encoding: .utf8)!.contains("future"))
        let again = try JSONDecoder().decode(StarterEntry.self, from: back)
        XCTAssertEqual(again, e)
    }

    func testOwnNameTakenBecomesNumbered() {
        var shelf = StarterShelf()
        let id1 = shelf.saveAs(Board(title: "A"), name: "Plan", now: now)
        let id2 = shelf.saveAs(Board(title: "A"), name: "Plan", now: now)
        XCTAssertEqual(shelf.starter(id1)?.name, "Plan")
        XCTAssertEqual(shelf.starter(id2)?.name, "Plan 2")
        XCTAssertEqual(shelf.shown.last?.id, id2)
    }

    func testRemovedOwnStarterGoesAfterThirtyDays() {
        var shelf = StarterShelf()
        let id = shelf.saveAs(Board(title: "A"), name: "Plan", now: now)
        shelf.remove(id, now: now)
        XCTAssertTrue(shelf.purgeable(now: now.addingTimeInterval(29 * 86_400)).isEmpty)
        XCTAssertEqual(shelf.purgeable(now: now.addingTimeInterval(31 * 86_400)), [id])
        XCTAssertFalse(shelf.missingBuiltins)
    }

    func testWorkingBoardKeepsIdsAndMovesATimelineToToday() {
        var shelf = StarterShelf()
        let saved = Starter.timeline.board(now: now)
        let id = shelf.saveAs(saved, name: "T", now: now)
        let later = now.addingTimeInterval(5 * 86_400)
        let work = shelf.workingBoard(for: id, now: later)!
        XCTAssertEqual(Set(work.items.map(\.id)), Set(shelf.starter(id)!.board!.items.map(\.id)))
        let a = saved.items.compactMap(\.start).compactMap { Day(iso: $0) }.min()!
        let b = work.items.compactMap(\.start).compactMap { Day(iso: $0) }.min()!
        XCTAssertEqual(b - a, 5)
    }
}
