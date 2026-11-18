import XCTest
@testable import SeedboardCore

/// 0.5, pick 29: the Mac's own habits.
final class Mac05Tests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func board(_ title: String, changed minutes: Double, pinned: Bool = false, sent: Bool = false) -> Board {
        var b = Board(title: title, created: start)
        b.changed = start.addingTimeInterval(minutes * 60)
        b.pinned = pinned
        if sent { b.sent = SentInfo(when: start, kind: "note", title: title, path: "Notes/\(title).md") }
        return b
    }

    func testSpaceShowsAPictureOnlyWhenExactlyOneIsChosenAndNothingWasDragged() {
        XCTAssertTrue(MenuRules.spaceShowsPicture(slid: false, held: 0.12, chosen: 1, pictureChosen: true, typing: false))
        // Slid the board, held long, something else chosen, more than one chosen, nothing chosen, words being typed.
        XCTAssertFalse(MenuRules.spaceShowsPicture(slid: true, held: 0.12, chosen: 1, pictureChosen: true, typing: false))
        XCTAssertFalse(MenuRules.spaceShowsPicture(slid: false, held: 0.8, chosen: 1, pictureChosen: true, typing: false))
        XCTAssertFalse(MenuRules.spaceShowsPicture(slid: false, held: 0.12, chosen: 1, pictureChosen: false, typing: false))
        XCTAssertFalse(MenuRules.spaceShowsPicture(slid: false, held: 0.12, chosen: 2, pictureChosen: true, typing: false))
        XCTAssertFalse(MenuRules.spaceShowsPicture(slid: false, held: 0.12, chosen: 0, pictureChosen: false, typing: false))
        XCTAssertFalse(MenuRules.spaceShowsPicture(slid: false, held: 0.12, chosen: 1, pictureChosen: true, typing: true))
        // For everything that is not a picture, Space still starts typing as before.
        XCTAssertTrue(MenuRules.spaceStartsTyping(slid: false, held: 0.12, chosen: 1, typing: false))
    }

    func testTheDockMenuListsThePinnedBoardsThenTheFiveChangedLast() {
        var all = [board("Old pin", changed: 1, pinned: true), board("New pin", changed: 90, pinned: true)]
        for n in 1...7 { all.append(board("Board \(n)", changed: Double(n * 10), sent: n == 7)) }
        let menu = MacHabits.dockBoards(all)
        XCTAssertEqual(menu.pinned.map(\.title), ["New pin", "Old pin"])
        // Five, newest change first; a board sent to PARAGON counts like any other; a pinned one is not listed twice.
        XCTAssertEqual(menu.recent.map(\.title), ["Board 7", "Board 6", "Board 5", "Board 4", "Board 3"])
        // Never more than ten pinned boards.
        let many = (1...14).map { board("Pin \($0)", changed: Double($0), pinned: true) }
        XCTAssertEqual(MacHabits.dockBoards(many).pinned.count, 10)
        XCTAssertEqual(MacHabits.dockBoards(many).pinned.first?.title, "Pin 14")
        XCTAssertTrue(MacHabits.dockBoards([]).pinned.isEmpty && MacHabits.dockBoards([]).recent.isEmpty)
    }

    func testTheBoardsPicturesAreLookedAtInReadingOrderEachUnderAPlainName() {
        var b = Board(title: "Trip")
        let pixels = CGSize(width: 400, height: 300)
        // Made in a jumbled order: bottom left, top right, top left (a little lower than top right), and one in the middle row.
        let low = b.addPicture(name: "low.jpg", pixelSize: pixels, centre: CGPoint(x: 0, y: 900))!
        let right = b.addPicture(name: "right.jpg", pixelSize: pixels, centre: CGPoint(x: 600, y: 0))!
        let left = b.addPicture(name: "left.jpg", pixelSize: pixels, centre: CGPoint(x: 0, y: 40))!
        let middle = b.addPicture(name: "middle.jpg", pixelSize: pixels, centre: CGPoint(x: 300, y: 450))!
        b.add(.note, centre: CGPoint(x: 900, y: 0), text: "Not a picture")
        b.items[b.items.firstIndex { $0.id == left }!].text = "Cabin: the/porch\nsecond line"
        b.items[b.items.firstIndex { $0.id == middle }!].text = "Cabin- the-porch"
        let look = MacHabits.lookPictures(of: b)
        XCTAssertEqual(look.map(\.id), [left, right, middle, low])
        XCTAssertEqual(look.map(\.stored), ["left.jpg", "right.jpg", "middle.jpg", "low.jpg"])
        // The caption's first line is the name (nothing a file's name may not hold); without one "Picture" and its place;
        // two pictures never share a name.
        XCTAssertEqual(look.map(\.name), ["Cabin- the-porch", "Picture 2", "Cabin- the-porch 2", "Picture 4"])
        XCTAssertTrue(MacHabits.lookPictures(of: Board(title: "Empty")).isEmpty)
    }

    func testAPhotoFromTheIPhoneLandsAtTheRightClickSpotForTwoMinutesOnTheSameBoard() {
        let here = UUID(), other = UUID()
        let spot = CGPoint(x: 120, y: -40)
        XCTAssertEqual(MacHabits.cameraSpot(asked: spot, on: here, at: start, open: here, now: start.addingTimeInterval(45)), spot)
        XCTAssertEqual(MacHabits.cameraSpot(asked: spot, on: here, at: start, open: here, now: start.addingTimeInterval(120)), spot)
        // Too late, another board, or never asked at a spot (the File menu): a free place near the middle.
        XCTAssertNil(MacHabits.cameraSpot(asked: spot, on: here, at: start, open: here, now: start.addingTimeInterval(121)))
        XCTAssertNil(MacHabits.cameraSpot(asked: spot, on: here, at: start, open: other, now: start.addingTimeInterval(5)))
        XCTAssertNil(MacHabits.cameraSpot(asked: nil, on: here, at: start, open: here, now: start.addingTimeInterval(5)))
    }

    func testTheServiceMakesABoardFromMarkedWordsAndNoneFromNoWords() {
        let list = MacHabits.serviceBoard(from: "Summer cabin\n  Roof\n  Paint\n  Jetty", now: start)
        XCTAssertEqual(list?.items.filter { $0.kind == .idea }.count, 4)
        XCTAssertEqual(list?.title, "Summer cabin")
        let plain = MacHabits.serviceBoard(from: "Call Alex about the timber", now: start)
        XCTAssertEqual(plain?.items.map(\.kind), [.note])
        XCTAssertEqual(plain?.title, "Call Alex about the timber")
        XCTAssertNil(MacHabits.serviceBoard(from: nil))
        XCTAssertNil(MacHabits.serviceBoard(from: "  \n "))
    }
}
