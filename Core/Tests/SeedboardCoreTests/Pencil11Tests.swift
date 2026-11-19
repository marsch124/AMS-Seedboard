import XCTest
@testable import SeedboardCore

final class Pencil11Tests: XCTestCase {
    func testRulerSnapsANearLineStraightAndLeavesAFarOneAlone() {
        let ruler = Ruler(centre: CGPoint(x: 100, y: 100), angle: 0)
        let near = [CGPoint(x: 20, y: 104), CGPoint(x: 60, y: 97), CGPoint(x: 150, y: 103)]
        let snapped = ruler.snapped(near, reach: 12)
        XCTAssertEqual(snapped?.count, 2)
        XCTAssertEqual(Double(snapped![0].y), 100, accuracy: 0.001)
        XCTAssertEqual(Double(snapped![1].x), 150, accuracy: 0.001)
        XCTAssertNil(ruler.snapped([CGPoint(x: 20, y: 140), CGPoint(x: 150, y: 140)], reach: 12))
        XCTAssertNil(ruler.snapped([CGPoint(x: 20, y: 100)], reach: 12))
    }

    func testRulerTurnedSnapsAlongItsAngle() {
        let ruler = Ruler(centre: .zero, angle: .pi / 2)
        let out = ruler.snapped([CGPoint(x: 3, y: 10), CGPoint(x: -2, y: 90)], reach: 10)
        XCTAssertEqual(Double(out![1].x), 0, accuracy: 0.001)
        XCTAssertEqual(Double(out![1].y), 90, accuracy: 0.001)
    }

    func testReadNoteSitsBesideTheDrawingAndKeepsIt() {
        var board = Board()
        let id = board.add(.drawing, centre: CGPoint(x: 100, y: 100))
        let before = board.item(id)!
        let note = board.addReadNote(besideDrawing: id, words: " Call Alex ")
        XCTAssertNotNil(note)
        XCTAssertEqual(board.item(note!)?.text, "Call Alex")
        XCTAssertGreaterThan(board.item(note!)!.x, before.x + before.w)
        XCTAssertEqual(board.item(id), before)
        XCTAssertNil(board.addReadNote(besideDrawing: id, words: "  "))
    }
}
