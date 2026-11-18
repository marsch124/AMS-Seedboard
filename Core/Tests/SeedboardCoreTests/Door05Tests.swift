import XCTest
@testable import SeedboardCore

/// 0.5, pick 13: a door from one board to another (Door.swift). One small test per rule.
final class Door05Tests: XCTestCase {
    private let kitchen = Board(title: "Kitchen plan", colour: "orange")

    // MARK: Making a door

    func testADoorCarriesItsBoardsNameAndLiesWhereItWasAsked() throws {
        var b = Board(title: "Summer cabin")
        let id = try XCTUnwrap(b.addDoor(to: kitchen.id, name: "Kitchen\nplan", centre: CGPoint(x: 100, y: 50)))
        let door = try XCTUnwrap(b.item(id))
        XCTAssertEqual(door.kind, .door)
        XCTAssertEqual(door.door, kitchen.id)
        XCTAssertEqual(door.text, "Kitchen plan")
        XCTAssertEqual(door.centre, CGPoint(x: 100, y: 50))
        XCTAssertEqual(door.frame.size, ItemKind.door.defaultSize)
        XCTAssertEqual(b.doors.map(\.id), [id])
    }

    func testNoDoorOnABoardThatPlacesItsThingsItselfNorToItselfNorOnABoardFromANewerApp() {
        var timeline = Board.timeline()
        XCTAssertNil(timeline.addDoor(to: kitchen.id, name: "Kitchen plan", centre: .zero))
        var who = Board(title: "Who")
        who.kind = Board.sequenceKind
        XCTAssertNil(who.addDoor(to: kitchen.id, name: "Kitchen plan", centre: .zero))
        var own = Board(title: "Own")
        XCTAssertNil(own.addDoor(to: own.id, name: "Own", centre: .zero))
        var newer = Board(title: "Newer")
        newer.format = Board.currentFormat + 1
        XCTAssertNil(newer.addDoor(to: kitchen.id, name: "Kitchen plan", centre: .zero))
        XCTAssertTrue(timeline.items.filter { $0.kind == .door }.isEmpty && who.items.isEmpty && own.items.isEmpty && newer.items.isEmpty)
    }

    func testADoorSurvivesTheFileAndIsCountedInTheList() throws {
        var b = Board(title: "Summer cabin")
        b.addDoor(to: kitchen.id, name: "Kitchen plan", centre: .zero)
        XCTAssertEqual(b.countLine, "1 door")
        b.addDoor(to: UUID(), name: "Garden", centre: CGPoint(x: 0, y: 100))
        b.add(.note, centre: CGPoint(x: 300, y: 0), text: "A note")
        XCTAssertEqual(b.countLine, "1 note · 2 doors")
        let back = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(back, b)
        XCTAssertEqual(back.doors.first?.door, kitchen.id)
        XCTAssertTrue(back.canBeChanged)
        // The search finds a board by the name of a board it has a door to.
        XCTAssertTrue(b.holds("kitchen"))
    }

    // MARK: What a door shows

    func testADoorShowsItsBoardOrSaysRemovedOrNotHereYet() {
        var b = Board(title: "Summer cabin")
        let id = b.addDoor(to: kitchen.id, name: "Old name", centre: .zero)!
        let door = b.item(id)!
        // The board is here: the name and the colour it has NOW, whatever the door remembers.
        XCTAssertEqual(Door.face(of: door, board: kitchen, removed: false), .open(title: "Kitchen plan", colour: "orange"))
        XCTAssertEqual(Door.face(of: door, board: nil, removed: true), .removed(name: "Old name"))
        XCTAssertEqual(Door.face(of: door, board: nil, removed: false), .away(name: "Old name"))
        XCTAssertEqual(Door.removedWords, "This board was removed")
        XCTAssertEqual(Door.awayWords, "Not on this device yet")
    }

    func testDoorNamesFollowTheirBoards() {
        var b = Board(title: "Summer cabin")
        let first = b.addDoor(to: kitchen.id, name: "Kitchen plan", centre: .zero)!
        let gone = UUID()
        let second = b.addDoor(to: gone, name: "Garden", centre: CGPoint(x: 0, y: 100))!
        XCTAssertFalse(b.nameDoors([kitchen.id: "Kitchen plan"]), "nothing to change is no change")
        XCTAssertTrue(b.nameDoors([kitchen.id: "Kitchen 2027"]))
        XCTAssertEqual(b.item(first)?.text, "Kitchen 2027")
        // A door whose board is not in the list keeps the name it remembers.
        XCTAssertEqual(b.item(second)?.text, "Garden")
    }

    // MARK: Move to a new board

    func testMovingThingsToANewBoardLeavesADoorInTheirPlace() throws {
        var b = Board(title: "Summer cabin")
        let frame = b.add(.frame, centre: CGPoint(x: 200, y: 200), text: "Kitchen")           // 440 x 300 round (200, 200)
        let inside = b.add(.note, centre: CGPoint(x: 150, y: 180), text: "Tiles")
        let also = b.add(.box, centre: CGPoint(x: 280, y: 240), text: "Order the sink")
        let outside = b.add(.box, centre: CGPoint(x: 900, y: 200), text: "Pay the plumber")
        let other = b.add(.note, centre: CGPoint(x: 900, y: 500), text: "Stays")
        let amongThem = try XCTUnwrap(b.link(from: inside, to: also))
        let crossing = try XCTUnwrap(b.link(from: also, to: outside))
        let incoming = try XCTUnwrap(b.link(from: other, to: inside))
        let untouched = try XCTUnwrap(b.link(from: other, to: outside))
        b.items[b.index(of: also)!].todo = true
        b.sentTodos = [also, outside]
        b.noteSent(also, words: "Order the sink", place: SentTask.inbox)
        b.noteSent(outside, words: "Pay the plumber", place: SentTask.inbox)
        let room = b.item(frame)!.frame

        let newID = UUID()
        let moved = try XCTUnwrap(b.moveToNewBoard([frame], title: "Kitchen", newID: newID, colour: "blue"))

        // The new board: the frame with what lay in it, the arrow among them, what is known about their tasks.
        XCTAssertEqual(moved.board.id, newID)
        XCTAssertEqual(moved.board.title, "Kitchen")
        XCTAssertEqual(moved.board.colour, "blue")
        XCTAssertEqual(Set(moved.board.items.map(\.id)), [frame, inside, also])
        XCTAssertEqual(moved.board.item(inside)?.frame.origin, CGPoint(x: 150 - 75, y: 180 - 55), "things keep their places")
        XCTAssertEqual(moved.board.links.map(\.id), [amongThem])
        XCTAssertEqual(moved.board.sentTodos, [also])
        XCTAssertEqual(moved.board.sentTasks.map(\.id), [also])
        XCTAssertTrue(moved.board.item(also)!.todo)

        // This board: the things are gone, one door stands in the middle of the room they took.
        XCTAssertEqual(Set(b.items.map(\.id)), [outside, other, moved.door])
        let door = try XCTUnwrap(b.item(moved.door))
        XCTAssertEqual(door.kind, .door)
        XCTAssertEqual(door.door, newID)
        XCTAssertEqual(door.text, "Kitchen")
        XCTAssertEqual(door.centre.x, room.midX, accuracy: 0.001)
        XCTAssertEqual(door.centre.y, room.midY, accuracy: 0.001)
        XCTAssertEqual(b.sentTodos, [outside])
        XCTAssertEqual(b.sentTasks.map(\.id), [outside])
        // An arrow that ran over the edge of what moved now starts or ends at the door.
        XCTAssertNil(b.links.first { $0.id == amongThem })
        XCTAssertEqual(b.links.first { $0.id == crossing }.map { [$0.from, $0.to] }, [moved.door, outside])
        XCTAssertEqual(b.links.first { $0.id == incoming }.map { [$0.from, $0.to] }, [other, moved.door])
        XCTAssertEqual(b.links.first { $0.id == untouched }.map { [$0.from, $0.to] }, [other, outside])
        XCTAssertNotNil(b.arrows()[crossing], "an arrow can start at a door")
    }

    func testABranchMovedOutBecomesAMapOfItsOwnAndTheOldMapClosesUp() throws {
        var b = Board(title: "Summer cabin")
        let centre = b.addCentre(at: .zero, text: "Cabin")
        let build = b.addChild(of: centre, text: "Build")!
        let walls = b.addChild(of: build, text: "Walls")!
        let roof = b.addChild(of: build, text: "Roof")!
        let money = b.addChild(of: centre, text: "Money")!
        b.items[b.index(of: build)!].colour = "teal"
        b.items[b.index(of: build)!].folded = true
        b.layoutMaps()

        let moved = try XCTUnwrap(b.moveToNewBoard([build], title: b.nameForMovedOut([build])))
        XCTAssertEqual(moved.board.title, "Build")
        XCTAssertEqual(Set(moved.board.items.map(\.id)), [build, walls, roof], "a folded branch goes whole")
        let top = try XCTUnwrap(moved.board.item(build))
        XCTAssertNil(top.parent)
        XCTAssertEqual(top.colour, "")
        XCTAssertEqual(moved.board.mapCentres.map(\.id), [build])
        XCTAssertEqual(moved.board.item(walls)?.colour, "teal", "the ideas under it keep the branch's colour")
        XCTAssertEqual(Set(b.items.map(\.id)), [centre, money, moved.door])
        XCTAssertEqual(b.children(of: centre).map(\.id), [money])
        // The map closed up: the door covers none of it.
        let door = try XCTUnwrap(b.item(moved.door)).frame
        XCTAssertFalse(b.items.contains { $0.id != moved.door && $0.frame.intersects(door) })

        // Nothing to move, or a board that places its things itself: nothing happens.
        XCTAssertNil(b.moveToNewBoard([UUID()], title: "X"))
        var timeline = Board.timelineStart()
        let before = timeline
        XCTAssertNil(timeline.moveToNewBoard(Set(timeline.items.map(\.id)), title: "X"))
        XCTAssertEqual(timeline, before)
    }

    func testTheNameOfferedAndANameNoOtherBoardHas() {
        var b = Board(title: "Summer cabin")
        let frame = b.add(.frame, centre: CGPoint(x: 200, y: 200), text: "Kitchen")
        let inside = b.add(.note, centre: CGPoint(x: 150, y: 180), text: "Tiles")
        let far = b.add(.note, centre: CGPoint(x: 900, y: 180), text: "Permit\nfrom the council")
        XCTAssertEqual(b.nameForMovedOut([frame]), "Kitchen")
        XCTAssertEqual(b.nameForMovedOut([frame, inside]), "Kitchen", "what the frame carries is not a second thing")
        XCTAssertEqual(b.nameForMovedOut([far]), "Permit from the council")
        XCTAssertEqual(b.nameForMovedOut([inside, far]), "Part of Summer cabin")

        XCTAssertEqual(Door.freeName("Kitchen", taken: ["Summer cabin"]), "Kitchen")
        XCTAssertEqual(Door.freeName("kitchen", taken: ["Kitchen", "Kitchen 2"]), "kitchen 3")
        XCTAssertEqual(Door.freeName("  ", taken: ["New board"]), "New board")
        XCTAssertEqual(Door.cleanName(String(repeating: "a", count: 80)).count, 60)
    }

    // MARK: The way back

    func testTheWayBackLeadsThroughTheDoorsHeCameThrough() {
        let a = UUID(), b = UUID(), c = UUID(), other = UUID()
        var trail = DoorTrail()
        trail.opened(a)
        XCTAssertNil(trail.back, "a board opened from the list has no way back")
        trail.through(from: a, to: b)
        trail.opened(b)
        XCTAssertEqual(trail.back, a)
        trail.through(from: b, to: c)
        trail.opened(c)
        XCTAssertEqual(trail.came, [a, b])
        // One step back, and one more.
        XCTAssertEqual(trail.stepBack(), b)
        trail.opened(b)
        XCTAssertEqual(trail.back, a)
        XCTAssertEqual(trail.stepBack(), a)
        trail.opened(a)
        XCTAssertNil(trail.back)
        XCTAssertNil(trail.stepBack())

        // Any other way of opening a board ends the walk.
        trail.through(from: a, to: b)
        trail.opened(b)
        trail.opened(other)
        XCTAssertNil(trail.back)
        // A door whose board is still on its way: the home page in between does not lose the way back.
        trail.through(from: other, to: c)
        trail.opened(nil)
        trail.opened(c)
        XCTAssertEqual(trail.back, other)
        // A board that was removed is no place to go back to; a door to the board itself is no step.
        trail.forget(other)
        XCTAssertNil(trail.back)
        trail.through(from: c, to: c)
        trail.opened(c)
        XCTAssertNil(trail.back)
    }

    // MARK: PARAGON, the board's words, arrows, a dropped board

    func testADoorIsALineWithALinkInParagonsNoteAndProjectAndANameInTheBoardsWords() {
        var b = Board(title: "Summer cabin")
        let note = b.add(.note, centre: .zero, text: "Ask Alex")
        let door = b.addDoor(to: kitchen.id, name: "Kitchen [plan]", centre: CGPoint(x: 300, y: 0))!
        b.link(from: note, to: door)
        let link = "[Kitchen (plan)](seedboard://board/\(kitchen.id.uuidString))"
        XCTAssertEqual(Door.link(for: b.item(door)!), link)
        XCTAssertNil(Door.link(for: b.item(note)!))

        let text = ParagonExport.note(board: b, title: "Summer cabin", picture: nil, now: Date())
        XCTAssertTrue(text.contains("## Doors\n\n- \(link)\n"))
        XCTAssertTrue(text.contains("- Ask Alex → Kitchen [plan]"), "an arrow to a door names the board")
        XCTAssertFalse(text.contains("- [ ] Kitchen"), "a door is never a task")
        let project = ParagonExport.project(board: b, title: "Summer cabin", picture: nil, now: Date())
        XCTAssertTrue(project.contains("## Doors\n\n- \(link)\n"))
        XCTAssertLessThan(project.range(of: "## Doors")!.lowerBound, project.range(of: "## Log")!.lowerBound)
        XCTAssertFalse(project.contains("- [ ] Kitchen"))
        XCTAssertTrue(ParagonExport.inboxTasks(board: b).isEmpty)

        XCTAssertTrue(b.outlineText.contains("Doors:\n- Kitchen [plan]"))
        // A board without doors says nothing about doors.
        var plain = Board(title: "Plain")
        plain.add(.note, centre: .zero, text: "A note")
        XCTAssertFalse(ParagonExport.note(board: plain, title: "Plain", picture: nil, now: Date()).contains("Doors"))
        XCTAssertFalse(plain.outlineText.contains("Doors"))
    }

    func testAnArrowCanStartOrEndAtADoorAndOtherArrowsGoRoundIt() throws {
        var b = Board(title: "Summer cabin")
        let left = b.add(.box, centre: CGPoint(x: 0, y: 0), text: "Plan")
        let door = b.addDoor(to: kitchen.id, name: "Kitchen plan", centre: CGPoint(x: 300, y: 0))!
        let right = b.add(.box, centre: CGPoint(x: 600, y: 0), text: "Build")
        let into = try XCTUnwrap(b.link(from: left, to: door))
        let out = try XCTUnwrap(b.link(from: door, to: right))
        let past = try XCTUnwrap(b.link(from: left, to: right))
        let arrows = b.arrows()
        XCTAssertNotNil(arrows[into])
        XCTAssertNotNil(arrows[out])
        // The arrow from Plan to Build does not run through the door that lies between them.
        let line = try XCTUnwrap(arrows[past]).outline
        let card = b.item(door)!.frame.insetBy(dx: 2, dy: 2)
        XCTAssertFalse(line.contains { card.contains($0) })
        // Removing the door takes its arrows along.
        b.remove([door])
        XCTAssertEqual(b.links.map(\.id), [past])
    }

    func testABoardDraggedFromTheListIsKnownByItsLink() {
        let id = UUID()
        XCTAssertEqual(Door.target(ofLink: "seedboard://board/\(id.uuidString)"), id)
        XCTAssertEqual(Door.target(ofLink: "  seedboard://board/\(id.uuidString)\n"), id)
        XCTAssertNil(Door.target(ofLink: "See seedboard://board/\(id.uuidString)"))
        XCTAssertNil(Door.target(ofLink: "https://example.com/board/\(id.uuidString)"))
        XCTAssertNil(Door.target(ofLink: "Buy milk"))
    }
}
