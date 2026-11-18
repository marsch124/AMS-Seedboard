import XCTest
@testable import SeedboardCore

final class ParagonTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = format
        return f.string(from: now)
    }

    /// Centre "Cabin" with branches "Food" (Buy fish, Bake -> Flour) and "Book trip" (no ideas).
    private func mapBoard() -> Board {
        let centre = Item(kind: .idea, text: "Cabin")
        let food = Item(kind: .idea, text: "Food", parent: centre.id, order: 1)
        let trip = Item(kind: .idea, text: "Book trip", parent: centre.id, order: 2)
        let fish = Item(kind: .idea, text: "Buy fish", parent: food.id, order: 1)
        let bake = Item(kind: .idea, text: "Bake", parent: food.id, order: 2)
        let flour = Item(kind: .idea, text: "Flour", parent: bake.id, order: 1)
        return Board(title: "Summer cabin", items: [centre, food, trip, fish, bake, flour])
    }

    func testNoteTitleReplacesForbiddenCharacters() {
        XCTAssertEqual(ParagonExport.noteTitle(for: "Plan: a/b?\n  c."), "Plan a b c")
        XCTAssertEqual(ParagonExport.noteTitle(for: "  ?:/  "), "Board")
        XCTAssertEqual(ParagonExport.noteTitle(for: "Capture"), "Capture (board)")
    }

    func testFreeTitleNeverMakesABareNumberedCopy() {
        XCTAssertEqual(ParagonExport.freeTitle("Trip", taken: ["Other"]), "Trip")
        XCTAssertEqual(ParagonExport.freeTitle("Trip", taken: ["trip"]), "Trip (board 2)")
        XCTAssertEqual(ParagonExport.freeTitle("Trip", taken: ["Trip", "Trip (board 2)"]), "Trip (board 3)")
        // "Trip 2" beside "Trip" would be read by PARAGON as a stray copy.
        XCTAssertEqual(ParagonExport.freeTitle("Trip 2", taken: ["Trip"]), "Trip 2 (board 2)")
    }

    func testPictureNameAndLinkAreSafe() {
        let name = ParagonExport.pictureName(for: "Summer: cabin/åäö?", now: now)
        XCTAssertEqual(name, "Seedboard Summer cabin åäö \(day("yyyy-MM-dd HHmm")).png")
        XCTAssertFalse(name.contains(":"))
        let text = ParagonExport.note(board: mapBoard(), title: "Summer cabin", picture: "Seedboard Summer cabin 2026-11-18 0812.png", now: now)
        XCTAssertTrue(text.contains("![Picture](../Pictures/Seedboard%20Summer%20cabin%202026-11-18%200812.png)\n"))
    }

    func testBoardLinkAndBackLine() {
        let board = mapBoard()
        XCTAssertEqual(ParagonExport.boardLink(board.id), "seedboard://board/\(board.id.uuidString)")
        let text = ParagonExport.note(board: board, title: "Summer cabin", picture: nil, now: now)
        XCTAssertTrue(text.contains("[Open the board in Seedboard](seedboard://board/\(board.id.uuidString))"))
        XCTAssertFalse(text.contains("!["))
    }

    func testNoteHasFrontMatterAndOnlySectionsWithContent() {
        let board = mapBoard()
        let text = ParagonExport.note(board: board, title: "Summer cabin", picture: nil, now: now)
        XCTAssertTrue(text.hasPrefix("---\ntitle: Summer cabin\ntype: resource\ncreated: \(day("yyyy-MM-dd"))\n---\n# Summer cabin\n"))
        XCTAssertTrue(text.contains("## Outline\n\n- Cabin\n  - Food\n    - Buy fish\n    - Bake\n      - Flour\n  - Book trip\n"))
        XCTAssertFalse(text.contains("## Flow"))
        XCTAssertFalse(text.contains("## Notes"))
        XCTAssertFalse(text.contains("## Tasks"))
    }

    func testNoteFlowNotesAndTasks() {
        let a = Item(kind: .box, text: "Start")
        let b = Item(kind: .diamond, text: "")
        let sticky = Item(kind: .note, text: "Line one\nLine two", todo: true)
        var board = Board(title: "Flow", items: [a, b, sticky])
        board.links = [Link(from: a.id, to: b.id, text: "yes"), Link(from: b.id, to: a.id)]
        let text = ParagonExport.note(board: board, title: "Flow", picture: nil, now: now)
        XCTAssertTrue(text.contains("## Flow\n\n- Start → (empty) (yes)\n- (empty) → Start\n"))
        XCTAssertTrue(text.contains("## Notes\n\n- Line one Line two\n"))
        XCTAssertTrue(text.contains("## Tasks\n\n- [ ] Line one Line two\n"))
    }

    func testProjectTasksFromBranches() {
        let text = ParagonExport.project(board: mapBoard(), title: "Summer cabin", picture: nil, now: now)
        XCTAssertTrue(text.hasPrefix("---\ntitle: Summer cabin\ntype: project\nstatus: active\ncreated: \(day("yyyy-MM-dd"))\n---\n"))
        XCTAssertTrue(text.contains("## Outcome\n\nCabin\n"))
        XCTAssertTrue(text.contains("## Tasks\n\n- [ ] Book trip\n\n### Food\n- [ ] Buy fish\n- [ ] Bake\n  - [ ] Flour\n"))
        XCTAssertTrue(text.contains("## Notes\n"))
        XCTAssertTrue(text.contains("## Log\n\n- \(day("yyyy-MM-dd")): Project created"))
    }

    func testProjectStepsAndTodoGroups() {
        let a = Item(kind: .box, text: "Draft")
        let b = Item(kind: .box, text: "Send")
        let note = Item(kind: .note, text: "Call Anna", todo: true)
        var board = Board(title: "Mail", items: [b, a, note])
        board.links = [Link(from: a.id, to: b.id)]
        let text = ParagonExport.project(board: board, title: "Mail", picture: nil, now: now)
        XCTAssertTrue(text.contains("### Steps\n- [ ] Draft\n- [ ] Send\n"))
        XCTAssertTrue(text.contains("### To do\n- [ ] Call Anna\n"))
        XCTAssertTrue(text.contains("## Outcome\n\nMail\n"))
        XCTAssertTrue(text.contains("## Notes\n\n- Call Anna\n"))
    }

    func testInboxTasksSkipSentOnes() {
        let one = Item(kind: .box, text: "One", todo: true)
        let two = Item(kind: .note, text: "Two\nlines", todo: true)
        let empty = Item(kind: .box, text: "  ", todo: true)
        let plain = Item(kind: .box, text: "Plain")
        var board = Board(items: [one, plain, two, empty])
        XCTAssertEqual(ParagonExport.inboxTasks(board: board).map(\.text), ["One", "Two lines"])
        board.sentTodos = [one.id]
        let left = ParagonExport.inboxTasks(board: board)
        XCTAssertEqual(left.map(\.id), [two.id])
    }

    func testCaptureURLEncoding() throws {
        let url = try XCTUnwrap(ParagonExport.captureURL(text: "Buy fish & chips? #1 på ä ö", asNote: false))
        XCTAssertEqual(url.absoluteString, "amspara://capture?text=Buy%20fish%20%26%20chips%3F%20%231%20p%C3%A5%20%C3%A4%20%C3%B6&target=inbox")
        let comps = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(comps.queryItems?.first { $0.name == "text" }?.value, "Buy fish & chips? #1 på ä ö")
        let note = try XCTUnwrap(ParagonExport.captureURL(text: "Idea", asNote: true))
        XCTAssertTrue(note.absoluteString.hasSuffix("&note=1"))
        XCTAssertNil(ParagonExport.captureURL(text: " \n ", asNote: false))
    }

    func testOpenURLUsesEncodedTitle() throws {
        let url = try XCTUnwrap(ParagonExport.openURL(noteTitle: "Sommarstuga åäö (board 2)"))
        XCTAssertEqual(url.absoluteString, "amspara://Sommarstuga%20%C3%A5%C3%A4%C3%B6%20%28board%202%29")
        XCTAssertNil(ParagonExport.openURL(noteTitle: "  "))
    }
}
