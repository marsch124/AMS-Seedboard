import XCTest
@testable import SeedboardCore

/// 0.14, the safety lane: ideas 7 to 12.
final class Safety14Tests: XCTestCase {
    func testHugePictureIsCutToAbout100MillionPixels() {
        let huge = PictureLimit.boardScale(width: 20_000, height: 20_000)
        XCTAssertTrue(huge.smaller)
        XCTAssertLessThanOrEqual(20_000 * 20_000 * huge.scale * huge.scale, PictureLimit.mostPixels * 1.0001)
        let normal = PictureLimit.boardScale(width: 2_000, height: 1_500)
        XCTAssertEqual(normal.scale, 2); XCTAssertFalse(normal.smaller)
        XCTAssertEqual(PictureLimit.boardScale(width: 5_000, height: 4_000).scale, 1)
    }

    func testBigPageIsStripsAndOrdinaryPageIsOne() {
        XCTAssertEqual(PageStrips.strips(paperHeight: 842, scale: 0.9, items: 40).count, 1)
        let strips = PageStrips.strips(paperHeight: 842, scale: 0.1, items: 40)
        XCTAssertEqual(strips.count, 4)
        XCTAssertEqual(strips.map(\.height).reduce(0, +), 842)
        XCTAssertEqual(strips[1].y, strips[0].height)
        XCTAssertEqual(PageStrips.strips(paperHeight: 842, scale: 0.9, items: 900).count, 4)
    }

    func testLongSharedWordsAreSaidToBeCut() {
        XCTAssertFalse(Arrivals.wasCut(String(repeating: "a", count: 20_000)))
        XCTAssertTrue(Arrivals.wasCut(String(repeating: "a", count: 20_001) + "  "))
    }

    func testACopyOfAPutAwayBoardIsListed() {
        var board = Board.timeline(title: "Old")
        PutAway.putAway(&board)
        let id = board.id
        board.becomeCopy(takenTitles: ["Old", "Old copy"])
        XCTAssertNil(board.putAway)
        XCTAssertNotEqual(board.id, id)
        XCTAssertEqual(board.title, "Old copy 2")
    }

    func testTicksNotToldAreKeptOnceAndSurviveARestart() {
        let board = UUID()
        let line = ParagonExport.DoneLine(words: "Permit", board: "Build", place: SentTask.inbox, when: Date())
        var queue = DoneQueue()
        queue.add([line], board: board)
        queue.add([line], board: board)
        XCTAssertEqual(queue.entries.count, 1)
        let back = DoneQueue.decoded(queue.encoded())
        XCTAssertEqual(back.boards, [board])
        var old = back
        old.dropOld(now: Date().addingTimeInterval(Double(DoneQueue.keptDays + 1) * 86_400))
        XCTAssertTrue(old.entries.isEmpty)
    }
}
