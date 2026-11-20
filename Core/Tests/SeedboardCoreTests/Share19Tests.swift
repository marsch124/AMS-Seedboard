import XCTest
@testable import SeedboardCore

final class Share19Tests: XCTestCase {
    func testFramePictureHoldsFrameAndWhatLiesInIt() {
        var board = Board(title: "Plan")
        let frame = Item(kind: .frame, text: "Pros", x: 0, y: 0, w: 300, h: 200)
        let inside = Item(kind: .note, text: "In", x: 50, y: 50)
        let outside = Item(kind: .note, text: "Out", x: 600, y: 600)
        board.items = [frame, inside, outside]
        let part = board.framePicture(of: frame.id)
        XCTAssertEqual(part?.title, "Pros")
        XCTAssertEqual(part?.items.map(\.text).sorted(), ["", "In"].sorted().map { $0 == "" ? "Pros" : $0 }.sorted())
        XCTAssertNil(board.framePicture(of: inside.id))
        board.items[0].text = ""
        XCTAssertEqual(board.framePicture(of: frame.id)?.title, "Frame")
    }

    func testPreviewIsTheWrittenText() {
        var board = Board(title: "Trip")
        let centre = board.addCentre(at: .zero, text: "Trip")
        let child = board.addChild(of: centre, text: "Book flights")!
        board.items[board.index(of: child)!].todo = true
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for project in [false, true] {
            let written = ParagonExport.handoverText(project: project, board: board, title: "Trip", picture: "p.png", now: now).text
            let shown = SendPreviewText(written)
            XCTAssertEqual(shown.shown(all: true), written.trimmingCharacters(in: .newlines))
            XCTAssertEqual(shown.shown(all: false).components(separatedBy: "\n").count, min(shown.lines.count, 8))
        }
    }

    func testChecklistForms() {
        let text = "- [ ] a\n- [x] b\n* [X] c\n☐ d\n☑ e\n✓ f\n✔ g\n◦ h\n• i\n[ ] j"
        let lines = Checklist.parse(text)
        XCTAssertEqual(lines?.map(\.words), ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"])
        XCTAssertEqual(lines?.map(\.done), [false, true, true, false, true, true, true, false, false, false])
        XCTAssertNil(Checklist.parse("• one\n• two"))            // bullets alone: no checklist
        XCTAssertNil(Checklist.parse("- [ ] a\njust words"))     // a line without a mark
        XCTAssertNil(Checklist.parse("hello"))
    }

    func testChecklistPasteMarksDoneAndOpen() {
        var board = Board(title: "B")
        let made = board.addChecklist([ChecklistLine("Milk"), ChecklistLine("Eggs", done: true)], at: .zero, doneDay: "2026-11-20")
        XCTAssertEqual(made.count, 1)
        let milk = board.items.first { $0.text == "Milk" }!, eggs = board.items.first { $0.text == "Eggs" }!
        XCTAssertTrue(milk.todo); XCTAssertTrue(eggs.todo)
        XCTAssertEqual(board.todoState(of: milk.id), .waiting)
        XCTAssertEqual(board.todoState(of: eggs.id), .done)
        XCTAssertEqual(eggs.doneDay, "2026-11-20")
        XCTAssertNil(milk.doneDay)
        // A ticked line never goes to the PARAGON Inbox; the open one does.
        XCTAssertEqual(ParagonExport.inboxTasks(board: board).map(\.text), ["Milk"])
    }
}
