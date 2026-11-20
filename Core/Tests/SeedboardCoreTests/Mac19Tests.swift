import XCTest
@testable import SeedboardCore

final class Mac19Tests: XCTestCase {
    func testToolBarSnapsToNearestEdge() {
        XCTAssertEqual(ToolDock.nearest(x: 500, y: 700, width: 1000, height: 800), .bottom)
        XCTAssertEqual(ToolDock.nearest(x: 40, y: 300, width: 1000, height: 800), .left)
        XCTAssertEqual(ToolDock.nearest(x: 960, y: 300, width: 1000, height: 800), .right)
        XCTAssertEqual(ToolDock.nearest(x: 500, y: 10, width: 1000, height: 800), .left)   // never the top
        XCTAssertEqual(ToolDock.stored("nonsense"), .bottom)
        XCTAssertEqual(ToolDock.stored("right"), .right)
    }

    func testQuickLookTakesFirstSixLines() {
        var b = Board(title: "t")
        for n in 0..<10 { _ = b.add(.note, centre: CGPoint(x: Double(n * 200), y: 0), text: "Note \(n)") }
        XCTAssertEqual(b.quickLookLines().count, 6)
        XCTAssertEqual(b.quickLookLines(limit: 2).count, 2)
        XCTAssertTrue(Board(title: "e").quickLookLines().allSatisfy { !$0.isEmpty })
    }
}
