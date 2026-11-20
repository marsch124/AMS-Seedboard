import XCTest
@testable import SeedboardCore

final class Canvas19Tests: XCTestCase {
    func testPaperColoursReadAndWrite() {
        var board = Board(title: "T")
        XCTAssertNil(board.paperColour)
        board.paperColour = .warmGrey
        XCTAssertEqual(board.paper, "warmGrey")
        board.paper = "somethingNew"
        XCTAssertNil(board.paperColour)
        board.paperColour = nil
        XCTAssertNil(board.paper)
    }

    func testPaperColoursAreTheAgreedOnes() {
        XCTAssertEqual(PaperColour.paper.dayHex, 0xFBF7EE)
        XCTAssertEqual(PaperColour.nightBlue.nightHex, 0x151C2C)
        XCTAssertEqual(PaperColour.allCases.map(\.word), ["Paper", "Warm grey", "Night blue"])
    }
}
