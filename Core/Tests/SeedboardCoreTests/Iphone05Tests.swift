import XCTest
@testable import SeedboardCore

/// 0.5, the `iphone` lane: one small test per rule — the links that make a new board, the lines a long press on
/// the app's icon shows, the ways of the Picture tile, and the ONE undo path of the device's own Undo.
@MainActor
final class Iphone05Tests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Links that make a new board

    func testANewLinkIsReadAndWrittenTheSameWay() {
        XCTAssertEqual(NewLink.ask(from: URL(string: "seedboard://new/mindMap")!), .starter("mindMap"))
        XCTAssertEqual(NewLink.ask(from: URL(string: "SEEDBOARD://NEW/blank")!), .starter("blank"))
        XCTAssertEqual(NewLink.ask(from: URL(string: "seedboard://new/clipboard")!), .clipboard)
        XCTAssertEqual(NewLink.ask(from: URL(string: "seedboard://new/Clipboard")!), .clipboard)
        // No starter named: a blank board.
        XCTAssertEqual(NewLink.ask(from: URL(string: "seedboard://new")!), .starter("blank"))
        XCTAssertEqual(NewLink.ask(from: URL(string: "seedboard://new/")!), .starter("blank"))
        // A link to a board is not a link that makes one, and the other way round.
        XCTAssertNil(NewLink.ask(from: URL(string: "seedboard://board/5F0B7A0E-6C0E-4C52-9F0B-1D2E3F4A5B6C")!))
        XCTAssertNil(NewLink.ask(from: URL(string: "https://new/blank")!))
        XCTAssertNil(BoardLink.id(from: URL(string: "seedboard://new/blank")!))
        // Written and read back.
        for ask in [NewLink.Ask.starter("blank"), .starter("mindMap"), .starter("5F0B7A0E-6C0E-4C52-9F0B-1D2E3F4A5B6C"), .clipboard] {
            XCTAssertEqual(NewLink.ask(from: URL(string: NewLink.link(ask))!), ask)
        }
    }

    func testANewLinkOpensAFreshBoardFromThatStarter() {
        let shelf = StarterShelf()
        // Blank: an empty board called "New board".
        let blank = NewLink.board(for: .starter("blank"), shelf: shelf, clipboard: nil, now: now)
        XCTAssertEqual(blank.board.title, "New board")
        XCTAssertTrue(blank.board.items.isEmpty)
        XCTAssertNil(blank.line)
        // Mind map: the middle idea and its four thoughts; capitals in the id do not matter.
        let map = NewLink.board(for: .starter("MINDMAP"), shelf: shelf, clipboard: nil, now: now)
        XCTAssertEqual(map.board.title, "Mind map")
        XCTAssertEqual(map.board.items.filter { $0.kind == .idea }.count, 5)
        XCTAssertNil(map.line)
        // Each press makes a board of its own.
        let again = NewLink.board(for: .starter("mindMap"), shelf: shelf, clipboard: nil, now: now)
        XCTAssertNotEqual(again.board.id, map.board.id)
    }

    func testANewLinkTakesTheOwnersOwnVersionAndHisOwnStarters() {
        var shelf = StarterShelf()
        // He renamed the mind map starter: the board carries his name.
        shelf.rename("mindMap", name: "Brainstorm", hint: "Mine", now: now)
        XCTAssertEqual(NewLink.board(for: .starter("mindMap"), shelf: shelf, clipboard: nil, now: now).board.title, "Brainstorm")
        // One of his own starters, by its id.
        var mine = Board(title: "Trip", created: now)
        mine.add(.note, centre: .zero, text: "Passports")
        let id = shelf.saveAs(mine, name: "Trip plan", hint: "Your own starter", now: now)
        let made = NewLink.board(for: .starter(id), shelf: shelf, clipboard: nil, now: now)
        XCTAssertEqual(made.board.title, "Trip plan")
        XCTAssertEqual(made.board.items.map(\.text), ["Passports"])
        XCTAssertNotEqual(made.board.id, mine.id)
        XCTAssertNil(made.line)
    }

    func testAStarterThatIsGoneGivesABlankBoardAndSaysSo() {
        var shelf = StarterShelf()
        _ = shelf.remove("mindMap", now: now)
        for id in ["mindMap", "no-such-starter"] {
            let made = NewLink.board(for: .starter(id), shelf: shelf, clipboard: nil, now: now)
            XCTAssertEqual(made.board.title, "New board")
            XCTAssertTrue(made.board.items.isEmpty)
            XCTAssertEqual(made.line, "That starter is not here any more. This is a blank board.")
        }
    }

    func testTheClipboardLinkFollowsTheRuleOfNewBoardFromText() {
        let shelf = StarterShelf()
        // A list: a mind map, exactly as "New board from text" makes it.
        let words = "Summer cabin\n- Roof\n- Paint\n"
        let list = NewLink.board(for: .clipboard, shelf: shelf, clipboard: words, now: now)
        let same = Outside.board(title: nil, text: words, now: now)
        XCTAssertEqual(list.board.title, same.title)
        XCTAssertEqual(list.board.items.map(\.text), same.items.map(\.text))
        XCTAssertTrue(list.board.items.allSatisfy { $0.kind == .idea })
        XCTAssertGreaterThanOrEqual(list.board.items.count, 3)
        XCTAssertNil(list.line)
        // One thought: one sticky note, the board named after it.
        let one = NewLink.board(for: .clipboard, shelf: shelf, clipboard: "  Call Alex about the boat  ", now: now)
        XCTAssertEqual(one.board.items.map(\.kind), [.note])
        XCTAssertEqual(one.board.items.first?.text, "Call Alex about the boat")
        XCTAssertEqual(one.board.title, "Call Alex about the boat")
        // Nothing there (or only blanks): a blank board, and it is said.
        for nothing in [nil, "", "  \n "] as [String?] {
            let made = NewLink.board(for: .clipboard, shelf: shelf, clipboard: nothing, now: now)
            XCTAssertTrue(made.board.items.isEmpty)
            XCTAssertEqual(made.board.title, "New board")
            XCTAssertEqual(made.line, "There were no words to paste. This is a blank board.")
        }
    }

    // MARK: A long press on the app's icon

    func testTheIconsMenuIsThreeNewLinesAndTheFirstTwoPinnedBoards() {
        // Nothing pinned: the three ways to begin.
        let plain = QuickActions.list(pinned: [])
        XCTAssertEqual(plain.map(\.title), ["New board", "New mind map", "New board from the clipboard"])
        XCTAssertEqual(plain.map(\.link), ["seedboard://new/blank", "seedboard://new/mindMap", "seedboard://new/clipboard"])
        XCTAssertEqual(plain.map(\.mark), [.add, .mindMap, .paste])
        XCTAssertEqual(plain.compactMap(\.subtitle), [])

        // Three pinned boards and one that is not: the first two pinned ones, in the list's order.
        func board(_ title: String, pinned: Bool) -> Board {
            var b = Board(title: title, created: now)
            b.pinned = pinned
            b.add(.note, centre: .zero, text: "One")
            return b
        }
        let boards = [board("Not pinned", pinned: false), board("Summer\ncabin", pinned: true), board("Boat", pinned: true), board("Third", pinned: true)]
        let all = QuickActions.list(pinned: boards)
        // 0.6: the device shows four lines; with two pinned boards New mind map makes way, so both fit.
        XCTAssertEqual(all.count, 4)
        XCTAssertEqual(all.map(\.title), ["New board", "New board from the clipboard", "Summer cabin", "Boat"])
        XCTAssertEqual(all.suffix(2).map(\.mark), [.board, .board])
        XCTAssertEqual(all[2].link, "seedboard://board/\(boards[1].id.uuidString)")
        XCTAssertEqual(all[2].subtitle, boards[1].countLine)
        // Each of those links opens that board.
        XCTAssertEqual(BoardLink.id(from: URL(string: all[3].link)!), boards[2].id)
        // One pinned board: New mind map still fits.
        XCTAssertEqual(QuickActions.list(pinned: [boards[1]]).map(\.title),
                       ["New board", "New mind map", "New board from the clipboard", "Summer cabin"])
        // Every link of the menu is one the app understands.
        for line in all {
            let url = URL(string: line.link)!
            XCTAssertTrue(NewLink.ask(from: url) != nil || BoardLink.id(from: url) != nil, line.link)
        }
    }

    // MARK: The Picture tile's three ways

    func testThePictureTileOffersThreeWaysAndAScanLandsTwelvePagesAtMost() {
        XCTAssertEqual(PictureWay.allCases.map(\.word), ["Photos", "Take a photo", "Scan a page"])
        XCTAssertEqual(PictureWay.pages(scanned: 3).land, 3)
        XCTAssertNil(PictureWay.pages(scanned: 12).line)
        let many = PictureWay.pages(scanned: 15)
        XCTAssertEqual(many.land, 12)
        XCTAssertEqual(many.line, "A scan puts 12 pages on a board at most. The first 12 of 15 are here.")
        XCTAssertEqual(PictureWay.pages(scanned: 0).land, 0)
        XCTAssertEqual(PictureWay.noCamera, "This device has no camera.")
    }

    // MARK: The device's own Undo — ONE path

    func testTheDevicesUndoTakesBackExactlyOneStepThroughTheBoardsOwnUndo() {
        // A board with its own steps, as `BoardSession` keeps them.
        var done = 3, undone = 0
        var undoCalls = 0, redoCalls = 0
        let manager = UndoManager()
        let link = SystemUndo()
        func show() { XCTAssertTrue(link.show(canUndo: done > 0, canRedo: undone > 0, in: manager)) }
        link.undo = { undoCalls += 1; done -= 1; undone += 1 }
        link.redo = { redoCalls += 1; done += 1; undone -= 1 }

        // Three steps taken, nothing to redo. Putting it there calls nothing.
        show()
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(undoCalls + redoCalls, 0)
        // Asked twice in one event, and then the event ends (the manager closes its own groups there): no harm.
        show()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)

        // Three fingers swiped left: ONE step back, by the board's own undo.
        manager.undo()
        XCTAssertEqual(undoCalls, 1)
        XCTAssertEqual(redoCalls, 0)
        show()
        XCTAssertTrue(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
        XCTAssertEqual(undoCalls, 1, "putting the entries back must not undo again")

        // Swiped right: the step comes back, once.
        manager.redo()
        XCTAssertEqual(redoCalls, 1)
        XCTAssertEqual(undoCalls, 1)
        show()
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)

        // The Undo BUTTON goes straight to the board (not through the manager): after it the manager still
        // offers one undo, and using it takes back one more step — never two.
        link.undo()
        XCTAssertEqual(undoCalls, 2)
        show()
        manager.undo()
        XCTAssertEqual(undoCalls, 3)
        show()
        // All three steps are back: nothing left to undo, three to redo.
        manager.undo()
        show()
        XCTAssertEqual(done, 0)
        XCTAssertEqual(undoCalls, 4)
        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
        // A swipe with nothing to take back does nothing.
        manager.undo()
        XCTAssertEqual(undoCalls, 4)

        // Typing in a thing, a board that is only read, or the list of boards: nothing is offered.
        XCTAssertTrue(link.show(canUndo: false, canRedo: false, in: manager))
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        show()
        link.clear()
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(manager.groupsByEvent, "the window's manager is handed back as it was")
    }

    func testInTheMiddleOfTheDevicesUndoNothingIsTouched() {
        let manager = UndoManager()
        let link = SystemUndo()
        var answer: Bool?
        // The board changes inside the device's own undo: the entries are left alone, the caller asks again later.
        link.undo = { answer = link.show(canUndo: true, canRedo: true, in: manager) }
        XCTAssertTrue(link.show(canUndo: true, canRedo: false, in: manager))
        manager.undo()
        XCTAssertEqual(answer, false)
        XCTAssertTrue(link.show(canUndo: true, canRedo: true, in: manager))
        XCTAssertTrue(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
    }

    func testThreeFingersBelongToTheDeviceAndTheBoardRestsMeanwhile() {
        XCTAssertFalse(Fingers.isDevicesGesture(fingersNeeded: 1))
        XCTAssertFalse(Fingers.isDevicesGesture(fingersNeeded: 2))
        XCTAssertTrue(Fingers.isDevicesGesture(fingersNeeded: 3))
        XCTAssertTrue(Fingers.isDevicesGesture(fingersNeeded: 4))

        // Two fingers slide the board, as ever.
        var third = ThirdFinger()
        third.landed(fingersAlreadyDown: 0)
        third.landed(fingersAlreadyDown: 1)
        XCTAssertTrue(third.slides(fingersDown: 2, now: 10))
        // A third finger lands: the board rests while it is down …
        third.landed(fingersAlreadyDown: 2)
        XCTAssertFalse(third.slides(fingersDown: 3, now: 10.1))
        // … and for 0.3 s after it lifted (the end of a three-finger swipe must not shove the board) …
        XCTAssertFalse(third.slides(fingersDown: 2, now: 10.5))
        XCTAssertFalse(third.slides(fingersDown: 2, now: 10.7))
        // … then two fingers slide again.
        XCTAssertTrue(third.slides(fingersDown: 2, now: 10.81))
        XCTAssertTrue(third.slides(fingersDown: 2, now: 10.82))

        // Three fingers that came and went without the board hearing of it: the next touch starts afresh.
        third.landed(fingersAlreadyDown: 2)
        third.landed(fingersAlreadyDown: 0)
        third.landed(fingersAlreadyDown: 1)
        XCTAssertTrue(third.slides(fingersDown: 2, now: 20))
    }
}
