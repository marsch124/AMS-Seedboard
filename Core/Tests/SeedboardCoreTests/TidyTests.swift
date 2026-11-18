import XCTest
@testable import SeedboardCore

final class TidyTests: XCTestCase {
    func testLineUpMakesARowWhenSpreadSidewaysAndAColumnOtherwise() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0))
        let b = board.add(.diamond, centre: CGPoint(x: 300, y: 30))
        let c = board.add(.note, centre: CGPoint(x: 600, y: -60))
        board.lineUp([a, b, c])
        // The middles take the average height (0 + 30 − 60) / 3 = −10; sideways nothing moves.
        XCTAssertEqual([a, b, c].map { board.item($0)!.centre }, [CGPoint(x: 0, y: -10), CGPoint(x: 300, y: -10), CGPoint(x: 600, y: -10)])

        var tall = Board()
        let d = tall.add(.box, centre: CGPoint(x: 10, y: 0))
        let e = tall.add(.box, centre: CGPoint(x: 50, y: 400))
        tall.lineUp([d, e])
        XCTAssertEqual([d, e].map { tall.item($0)!.centre }, [CGPoint(x: 30, y: 0), CGPoint(x: 30, y: 400)])
    }

    func testEvenGapsKeepsTheOuterTwoAndSpreadsTheRest() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 75, y: 0))       // 0…150
        let b = board.add(.box, centre: CGPoint(x: 240, y: 10))     // 165…315
        let c = board.add(.diamond, centre: CGPoint(x: 400, y: 0))  // 320…480
        let d = board.add(.box, centre: CGPoint(x: 875, y: -5))     // 800…950
        board.evenGaps([a, b, c, d])
        // Room between the outer two: 800 − 150 = 650, less 150 + 160 = 340, in 3 gaps of 113⅓.
        let gap = 340.0 / 3
        XCTAssertEqual(board.item(a)!.x, 0)
        XCTAssertEqual(board.item(d)!.x, 800)
        XCTAssertEqual(board.item(b)!.x, 150 + gap, accuracy: 0.0001)
        XCTAssertEqual(board.item(c)!.x, 150 + gap + 150 + gap, accuracy: 0.0001)
        // Up and down nothing moves.
        XCTAssertEqual(board.item(b)!.centre.y, 10)
        // Two things have no gap to even out.
        var two = board
        two.evenGaps([a, b])
        XCTAssertEqual(two, board)
    }

    func testSameSizeTakesTheLargestAndKeepsTheMiddles() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0))            // 150 × 56
        let b = board.add(.diamond, centre: CGPoint(x: 300, y: 40))     // 160 × 104: the largest
        let words = board.add(.text, centre: CGPoint(x: 600, y: 0))
        board.sameSize([a, b, words])
        XCTAssertEqual(board.item(a)!.frame.size, CGSize(width: 160, height: 104))
        XCTAssertEqual(board.item(a)!.centre, CGPoint(x: 0, y: 0))
        XCTAssertEqual(board.item(b)!.frame, CGRect(x: 220, y: -12, width: 160, height: 104))
        // Free text is as big as its words: it is left alone.
        XCTAssertEqual(board.item(words)!.frame.size, ItemKind.text.defaultSize)
    }

    func testIdeasHeldByAMapAreLeftOutAndACentreTakesItsIdeasAlong() {
        var board = Board()
        let centre = board.addCentre(at: CGPoint(x: 0, y: 0), text: "Centre")
        let child = board.addChild(of: centre, text: "Child")!
        board.layoutMaps()
        let box = board.add(.box, centre: CGPoint(x: 500, y: 80))
        XCTAssertEqual(board.tidyable([centre, child, box]).map(\.id), [centre, box])

        let before = board.item(child)!.centre
        board.lineUp([centre, child, box])
        // A row: both middles go to the average height 40; the child moves with its centre, not by itself.
        XCTAssertEqual(board.item(centre)!.centre.y, 40)
        XCTAssertEqual(board.item(box)!.centre.y, 40)
        XCTAssertEqual(board.item(child)!.centre, CGPoint(x: before.x, y: before.y + 40))

        // Only ideas of a map chosen: nothing to tidy.
        let same = board
        board.lineUp([child])
        board.sameSize([centre, child])
        XCTAssertEqual(board, same)
    }
}
