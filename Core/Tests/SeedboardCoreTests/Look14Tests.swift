import XCTest
@testable import SeedboardCore

/// 0.14 lane "look": copy the look, text sizes, zoom to the chosen, today's date.
final class Look14Tests: XCTestCase {
    func testPasteLookGivesEachKindOnlyWhatFits() {
        var board = Board(title: "Look")
        let box = board.add(.box, centre: CGPoint(x: 0, y: 0))
        let oval = board.add(.oval, centre: CGPoint(x: 300, y: 0))
        let note = board.add(.note, centre: CGPoint(x: 0, y: 300))
        let text = board.add(.text, centre: CGPoint(x: 300, y: 300))
        let pic = board.add(.picture, centre: CGPoint(x: 600, y: 0))
        board.items[board.index(of: box)!].colour = "blue"
        let look = board.lookToCopy(box)!
        XCTAssertEqual(look.colour, "blue")
        board.pasteLook(look, on: [oval, note, text, pic])
        // A shape takes colour and shape kind.
        XCTAssertEqual(board.item(oval)?.kind, .box)
        XCTAssertEqual(board.item(oval)?.colour, "blue")
        // A note stays a note and takes the colour (blue is a note colour).
        XCTAssertEqual(board.item(note)?.kind, .note)
        XCTAssertEqual(board.item(note)?.colour, "blue")
        // A free text and a picture take nothing from a shape.
        XCTAssertNil(board.item(text)?.textSize)
        XCTAssertFalse(board.canTakeLook(look, text))
        XCTAssertFalse(board.canTakeLook(look, pic))
    }

    func testTextSizeOnlyFromFreeTextToFreeText() {
        var board = Board(title: "Look")
        let a = board.add(.text, centre: .zero)
        let b = board.add(.text, centre: CGPoint(x: 0, y: 200))
        let note = board.add(.note, centre: CGPoint(x: 300, y: 0))
        board.items[board.index(of: a)!].textSize = TextSize.title
        let look = board.lookToCopy(a)!
        board.pasteLook(look, on: [b, note])
        XCTAssertEqual(board.item(b)?.textSize, "title")
        XCTAssertNil(board.item(note)?.textSize)
        XCTAssertEqual(TextSize.look(nil).size, 17)
        XCTAssertEqual(TextSize.look("title").size, 28)
        XCTAssertEqual(TextSize.look("small").size, 13)
    }

    func testFitChosenFillsTheRoomWithAMargin() {
        var view = Viewport()
        view.size = CGSize(width: 800, height: 600)
        view.fitChosen(CGRect(x: 1000, y: 1000, width: 100, height: 50))
        XCTAssertEqual(view.scale, 2)
        // The middle of the chosen box is the middle of the screen.
        XCTAssertEqual(view.offset.width + 1050 * 2, 400, accuracy: 0.01)
        view.fitChosen(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        XCTAssertEqual(view.scale, 0.2, accuracy: 0.0001)
        let before = view.scale
        view.fitChosen(nil)
        XCTAssertEqual(view.scale, before)
    }

    func testTodayInWordsAndInsertAtTheCursor() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let day = cal.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 12))!
        XCTAssertEqual(DateWords.short(day, calendar: cal), "19 Nov 2026")
        let made = Typing.insert("19 Nov 2026", in: "Decided on : ok", from: 11, to: 11)
        XCTAssertEqual(made.words, "Decided on 19 Nov 2026: ok")
        XCTAssertEqual(made.cursor, 22)
        XCTAssertEqual(Typing.insert("X", in: "ab", from: -1, to: -1).words, "abX")
        XCTAssertEqual(Typing.insert("X", in: "abcd", from: 1, to: 3).words, "aXd")
    }
}
