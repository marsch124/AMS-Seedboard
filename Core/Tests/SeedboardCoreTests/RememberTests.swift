import XCTest
@testable import SeedboardCore

/// Pick 26: the app opens where the owner left, and can be reached from outside.
final class RememberTests: XCTestCase {
    private let a = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let b = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    func testTheLastBoardComesBackUnlessItIsGoneOrLaunchWordsSetTheScene() {
        var left = Remembered(open: a)
        left.note(LeftView(scale: 1.5, x: 40, y: -20), of: a)
        XCTAssertEqual(Reopen.board(left, onDevice: [a, b], arguments: ["app"]), a)
        XCTAssertEqual(Reopen.view(left, of: a, arguments: ["app"]), LeftView(scale: 1.5, x: 40, y: -20))
        // A board that is gone: the home page.
        XCTAssertNil(Reopen.board(left, onDevice: [b], arguments: ["app"]))
        // Left on the home page: the home page.
        XCTAssertNil(Reopen.board(Remembered(), onDevice: [a, b], arguments: ["app"]))
        // Launch words for pictures and tests always win, for the board and for its view.
        for words in [["app", "-sampleData"], ["app", "-board", "Summer"], ["app", "-settings"]] {
            XCTAssertNil(Reopen.board(left, onDevice: [a, b], arguments: words), "\(words)")
            XCTAssertNil(Reopen.view(left, of: a, arguments: words), "\(words)")
        }
        // With sample boards nothing is written down either; with `-board` alone it still is.
        XCTAssertFalse(Reopen.remembers(arguments: ["app", "-sampleData"]))
        XCTAssertTrue(Reopen.remembers(arguments: ["app", "-board", "Summer"]))
        // A board never moved has no view: it opens whole.
        XCTAssertNil(Reopen.view(left, of: b, arguments: ["app"]))
    }

    func testWhatIsRememberedSurvivesBeingStoredAndForgetsBoardsThatAreGone() throws {
        var left = Remembered(open: a)
        left.note(LeftView(scale: 0.8, x: 1, y: 2), of: a)
        left.note(LeftView(scale: 2, x: 3, y: 4), of: b)
        let back = try JSONDecoder().decode(Remembered.self, from: JSONEncoder().encode(left))
        XCTAssertEqual(back, left)
        XCTAssertEqual(back.keeping([a]).views.count, 1)
        XCTAssertNotNil(back.keeping([a]).view(of: a))
        // Settings that cannot be read are simply empty, never a crash.
        let odd = try JSONDecoder().decode(Remembered.self, from: Data(#"{"open":7,"views":"x","more":true}"#.utf8))
        XCTAssertEqual(odd, Remembered())
    }

    func testAReopenedBoardHoldsItsSpotWhileTheRoomSettlesUntilTheOwnerMovesIt() throws {
        var view = Viewport()
        // Never moved: nothing to write down.
        view.resized(to: CGSize(width: 800, height: 600), showing: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(view.leftView)
        view.zoom(to: 2)
        view.pan(by: CGSize(width: 30, height: -10))
        let left = try XCTUnwrap(view.leftView)
        XCTAssertEqual(left.scale, 2)

        // The next start: the room is not known when the board opens, then settles in two steps.
        var again = Viewport()
        again.comeBack(to: left)
        again.resized(to: CGSize(width: 500, height: 400), showing: CGRect(x: 0, y: 0, width: 100, height: 100))
        again.resized(to: CGSize(width: 800, height: 600), showing: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(again.scale, 2)
        XCTAssertEqual(again.offset, view.offset)
        XCTAssertEqual(again.leftView, left)
        // In a window of another size the same spot is in the middle.
        again.resized(to: CGSize(width: 400, height: 300), showing: nil)
        let middle = again.toBoard(CGPoint(x: 200, y: 150))
        XCTAssertEqual(Double(middle.x), left.x, accuracy: 0.06)
        XCTAssertEqual(Double(middle.y), left.y, accuracy: 0.06)
        // Once the owner slides the board it stays where he put it.
        again.pan(by: CGSize(width: 50, height: 0))
        let put = again.offset
        again.resized(to: CGSize(width: 900, height: 700), showing: nil)
        XCTAssertEqual(again.offset, put)
        XCTAssertNil(again.pin)
    }

    func testWordsFromOutsideBecomeAMindMapOrOneNote() {
        let list = Outside.board(title: "Trip", text: "- Food\n- Tent\n  - Pegs")
        XCTAssertEqual(list.title, "Trip")
        XCTAssertEqual(list.items.map(\.kind), [.idea, .idea, .idea, .idea])
        XCTAssertEqual(list.mapCentres.first?.text, "Trip")

        let single = Outside.board(title: nil, text: "Trip\n  Food\n  Tent")
        XCTAssertEqual(single.title, "Trip")
        XCTAssertEqual(single.items.count, 3)

        let note = Outside.board(title: "  ", text: "Call the builder about the permit before Friday at noon")
        XCTAssertEqual(note.items.map(\.kind), [.note])
        XCTAssertEqual(note.items[0].text, "Call the builder about the permit before Friday at noon")
        XCTAssertEqual(note.title, "Call the builder about the permit before")

        let empty = Outside.board(title: nil, text: " \n ")
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.title, "New board")
    }

    func testTheDevicesSearchGetsTheFirstWordsAndOnlyWhatChanged() {
        var board = Board(title: "Cabin")
        board.add(.note, centre: .zero, text: "Ask Alex\nabout the lake")
        board.add(.box, centre: CGPoint(x: 300, y: 0), text: "")
        board.add(.box, centre: CGPoint(x: 600, y: 0), text: "Make a plan")
        XCTAssertEqual(Outside.searchWords(of: board), "Ask Alex about the lake · Make a plan")
        XCTAssertEqual(Outside.searchWords(of: board, limit: 30), "Ask Alex about the lake · Make…")
        XCTAssertEqual(Outside.searchWords(of: Board(title: "Empty")), "")

        let old = Date(timeIntervalSince1970: 100), new = Date(timeIntervalSince1970: 200)
        let gone = UUID()
        let plan = Outside.searchPlan(known: [a: old, b: old, gone: old], boards: [a: old, b: new])
        XCTAssertEqual(plan.learn, [b])
        XCTAssertEqual(plan.forget, [gone])
    }

    func testABoardIsFoundByItsNameExactFirst() {
        let boards = ["Summer cabin", "Cabin", "The cabin list", "Trip"].map { Board(title: $0) }
        // The exact name, then names that begin with it, then names that hold it (in the order given).
        XCTAssertEqual(Outside.boards(named: " cabin ", in: boards).map(\.title), ["Cabin", "Summer cabin", "The cabin list"])
        XCTAssertEqual(Outside.boards(named: "the", in: boards).map(\.title), ["The cabin list"])
        XCTAssertEqual(Outside.boards(named: "", in: boards).count, 4)
        XCTAssertTrue(Outside.boards(named: "boat", in: boards).isEmpty)
    }
}
