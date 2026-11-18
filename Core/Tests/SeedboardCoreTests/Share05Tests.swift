import XCTest
@testable import SeedboardCore

/// 0.5, pick 22: Share… — what can be shared, the pages, the words, how a page lies on the paper.
final class Share05Tests: XCTestCase {
    /// Two named frames side by side (the right one a little higher), one named frame below, one frame
    /// without a name, a note in the first frame, a small mind map in the second, a note outside.
    private func board() -> (board: Board, left: UUID, right: UUID, below: UUID, inLeft: UUID, centre: UUID, outside: UUID) {
        var b = Board(title: "Summer cabin")
        let below = b.add(.frame, centre: .zero, text: "Later")
        b.resize(below, to: CGRect(x: 0, y: 400, width: 300, height: 200))
        let right = b.add(.frame, centre: .zero, text: "Kitchen")
        b.resize(right, to: CGRect(x: 400, y: -20, width: 400, height: 300))
        let left = b.add(.frame, centre: .zero, text: "Plan")
        b.resize(left, to: CGRect(x: 0, y: 0, width: 300, height: 300))
        let bare = b.add(.frame, centre: .zero)
        b.resize(bare, to: CGRect(x: 900, y: 0, width: 200, height: 200))
        let inLeft = b.add(.note, centre: CGPoint(x: 150, y: 150), text: "Ask Alex")
        let centre = b.addCentre(at: CGPoint(x: 520, y: 130), text: "Tiles")
        _ = b.addChild(of: centre, text: "White")
        let outside = b.add(.note, centre: CGPoint(x: 1500, y: 900), text: "Far away")
        return (b, left, right, below, inLeft, centre, outside)
    }

    func testWhatCanBeSharedFollowsWhatIsChosenAndTheNamedFrames() {
        let (b, _, _, _, inLeft, _, _) = board()
        XCTAssertEqual(b.shareChoices(chosen: []), [.whole, .frames])
        XCTAssertEqual(b.shareChoices(chosen: [inLeft]), [.whole, .chosen, .frames])
        // An identity that is not on the board is nothing chosen.
        XCTAssertEqual(b.shareChoices(chosen: [UUID()]), [.whole, .frames])

        // A frame without a name is no page.
        var plain = Board(title: "Plain")
        _ = plain.add(.frame, centre: .zero)
        let note = plain.add(.note, centre: CGPoint(x: 500, y: 0), text: "One")
        XCTAssertEqual(plain.shareChoices(chosen: []), [.whole])
        XCTAssertEqual(plain.shareChoices(chosen: [note]), [.whole, .chosen])

        // A timeline places its things itself: only the whole board.
        var line = Board.timeline(title: "Move")
        let bar = line.addBar("Pack", start: Day(year: 2026, month: 12, day: 1))
        XCTAssertEqual(line.shareChoices(chosen: [bar]), [.whole])
        XCTAssertTrue(line.shareFrames.isEmpty)
    }

    func testNamedFramesComeInReadingOrder() {
        let (b, left, right, below, _, _, _) = board()
        // The right frame starts 20 higher than the left one and is still second: they are one row.
        XCTAssertEqual(b.shareFrames.map(\.id), [left, right, below])
        XCTAssertEqual(b.shareFrames.map(\.text), ["Plan", "Kitchen", "Later"])
    }

    func testAChosenFrameBringsWhatLiesInItAndAnIdeaBringsItsBranch() {
        let (b, left, _, _, inLeft, centre, _) = board()
        let frame = b.sharePart(of: [left])
        XCTAssertEqual(frame.title, "Summer cabin")
        XCTAssertEqual(frame.items.map(\.kind).sorted { $0.rawValue < $1.rawValue }, [.frame, .note])
        XCTAssertEqual(frame.items.first { $0.kind == .note }?.text, "Ask Alex")
        // It lies where it lay on the board.
        XCTAssertEqual(frame.items.first { $0.kind == .frame }?.frame, b.item(left)?.frame)

        let map = b.sharePart(of: [centre])
        XCTAssertEqual(Set(map.items.map(\.text)), ["Tiles", "White"])
        let note = b.sharePart(of: [inLeft])
        XCTAssertEqual(note.items.count, 1)
        // The board itself is not touched.
        XCTAssertEqual(b.items.count, 8)
    }

    func testEachNamedFrameIsAPageAndWhatLiesOutsideIsCounted() {
        let (b, _, _, _, _, _, _) = board()
        let pages = b.sharePages(.frames)
        XCTAssertEqual(pages.map(\.heading), ["Plan", "Kitchen", "Later"])
        XCTAssertEqual(Set(pages[1].board.items.map(\.text)), ["Kitchen", "Tiles", "White"])
        XCTAssertEqual(pages[2].board.items.count, 1)
        // The whole board and what is chosen are one page without a heading; nothing chosen is no page.
        XCTAssertEqual(b.sharePages(.whole).map(\.heading), [""])
        XCTAssertEqual(b.sharePages(.whole).first?.board, b)
        XCTAssertTrue(b.sharePages(.chosen, chosen: []).isEmpty)
        XCTAssertTrue(Board(title: "Empty").sharePages(.whole).isEmpty)
        // Only the note far away lies outside every named frame (the frame without a name is no thing).
        XCTAssertEqual(b.shareLeftOut, 1)
        XCTAssertEqual(SharePlan.leftOutLine(1), "1 thing lies outside the named frames and stays out.")
        XCTAssertEqual(SharePlan.leftOutLine(3), "3 things lie outside the named frames and stay out.")
        XCTAssertNil(SharePlan.leftOutLine(0))
    }

    func testTheWordsOfTheWholeBoardOfWhatIsChosenAndFrameByFrame() {
        let (b, _, _, _, inLeft, centre, outside) = board()
        XCTAssertEqual(b.shareWords(.whole), b.outlineText)
        // One chosen thing gives just its words; several give the list.
        XCTAssertEqual(b.shareWords(.chosen, chosen: [inLeft]), "Ask Alex")
        let two = b.shareWords(.chosen, chosen: [centre, outside])
        XCTAssertTrue(two.contains("Tiles") && two.contains("White") && two.contains("- Far away"), two)
        XCTAssertFalse(two.contains("Ask Alex"))
        let frames = b.shareWords(.frames)
        XCTAssertTrue(frames.hasPrefix("Plan\n----\nNotes:\n- Ask Alex\n\n\nKitchen\n-------\n"), frames)
        XCTAssertTrue(frames.hasSuffix("\n\n\nLater\n-----"), frames)
        XCTAssertFalse(frames.contains("Far away"))
    }

    func testAPageLiesOnItsSideWhenTheBoardIsWiderAndIsNeverLargerThanLife() {
        let a4 = SharePlan.paper(region: "SE")
        XCTAssertEqual(a4, CGSize(width: 595, height: 842))
        XCTAssertEqual(SharePlan.paper(region: "US"), CGSize(width: 612, height: 792))
        XCTAssertEqual(SharePlan.paper(region: nil), a4)

        // Wider than tall: on its side, made smaller until it fits between the edges, under the top line.
        let wide = SharePlan.fit(content: CGSize(width: 1572, height: 400), paper: a4)
        XCTAssertTrue(wide.landscape)
        XCTAssertEqual(wide.paper, CGSize(width: 842, height: 595))
        XCTAssertEqual(wide.scale, 0.5, accuracy: 0.0001)             // (842 − 2 × 28) ÷ 1572
        XCTAssertEqual(wide.origin, CGPoint(x: 28, y: 48))

        // Taller than wide: upright; the height decides; in the middle sideways.
        let tall = SharePlan.fit(content: CGSize(width: 300, height: 1532), paper: a4)
        XCTAssertFalse(tall.landscape)
        XCTAssertEqual(tall.scale, 0.5, accuracy: 0.0001)             // (842 − 48 − 28) ÷ 1532
        XCTAssertEqual(tall.origin.x, 28 + (539 - 150) / 2, accuracy: 0.0001)

        // A small board stays life size; a frame's page keeps room for its heading; a timeline is always on its side.
        let small = SharePlan.fit(content: CGSize(width: 200, height: 300), paper: a4, hasHeading: true)
        XCTAssertEqual(small.scale, 1)
        XCTAssertEqual(small.origin, CGPoint(x: 197.5, y: 72))                 // 28 + (539 − 200) ÷ 2; 28 + 20 + 24
        XCTAssertTrue(SharePlan.fit(content: CGSize(width: 200, height: 300), paper: a4, alwaysLandscape: true).landscape)
        // Nothing to fit never divides by nothing.
        XCTAssertEqual(SharePlan.fit(content: .zero, paper: a4).scale, 1)
    }

    func testTheNamesOfTheSharedFilesAndTheLinesOnThePage() {
        XCTAssertEqual(SharePlan.fileName("Summer cabin", form: .pdf), "Summer cabin.pdf")
        XCTAssertEqual(SharePlan.fileName("Plan 1/2: now", part: "Kitchen", form: .picture), "Plan 1-2- now - Kitchen.png")
        XCTAssertEqual(SharePlan.fileName("  ", part: "part", form: .words), "Board - part.txt")
        XCTAssertEqual(SharePlan.fileName("Two\nlines", form: .words), "Two lines.txt")
        XCTAssertEqual(SharePlan.fileName(String(repeating: "a", count: 200), form: .pdf).count, 84)

        let noon = Date(timeIntervalSince1970: 1_795_348_800)   // 22 Nov 2026, 12:00 in Greenwich
        let zone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(SharePlan.dateLine(noon, timeZone: zone), "22 Nov 2026")
        XCTAssertEqual(SharePlan.dateLine(noon, page: 2, of: 4, timeZone: zone), "22 Nov 2026 · 2 of 4")
        XCTAssertEqual(SharePlan.nameLine(" "), "Board")
        XCTAssertEqual(SharePlan.nameLine(String(repeating: "b", count: 90)).count, 70)
    }

    func testThePlateSaysWhatHeGets() {
        XCTAssertEqual(SharePlan.line(.whole, .picture), "One picture of the whole board.")
        XCTAssertEqual(SharePlan.line(.whole, .pdf), "The whole board on one page, sharp at any size.")
        XCTAssertEqual(SharePlan.line(.whole, .words), "The board's words as a small text file.")
        XCTAssertEqual(SharePlan.line(.chosen, .picture, chosen: 1), "One picture of the chosen thing.")
        XCTAssertEqual(SharePlan.line(.chosen, .pdf, chosen: 3), "The 3 chosen things on one page, sharp at any size.")
        XCTAssertEqual(SharePlan.line(.chosen, .words, chosen: 3), "The words of the 3 chosen things as a small text file.")
        XCTAssertEqual(SharePlan.line(.frames, .picture, pages: 4), "4 pictures, one of each named frame.")
        XCTAssertEqual(SharePlan.line(.frames, .pdf, pages: 4), "4 pages, one for each named frame, its name on top.")
        XCTAssertEqual(SharePlan.line(.frames, .pdf, pages: 1), "One page with the named frame, its name on top.")
        XCTAssertEqual(ShareWhat.allCases.map(\.word), ["Whole board", "What is chosen", "Each frame a page"])
        XCTAssertEqual(ShareForm.allCases.map(\.word), ["Picture", "PDF", "Words"])
    }
}
