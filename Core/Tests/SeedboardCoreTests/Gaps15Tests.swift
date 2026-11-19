import XCTest
@testable import SeedboardCore

/// 0.15: one colour, one meaning on a timeline; a tilted thing sizes along its own edges.
final class Gaps15Tests: XCTestCase {
    func testTimelineNeverPicksPurpleOrRedByItself() {
        var b = Board.timeline()
        let day = Day(year: 2026, month: 11, day: 19)
        let m = b.addMilestone("Go", on: day)
        XCTAssertEqual(b.item(m)?.colour, "orange")
        var picked: [String] = []
        for i in 0..<12 { let id = b.addBar("b\(i)", start: day); picked.append(b.item(id)!.colour) }
        for i in 0..<12 { let id = b.addPhase("p\(i)"); picked.append(b.item(id)!.colour) }
        XCTAssertFalse(picked.contains("purple")); XCTAssertFalse(picked.contains("red"))
    }

    func testATiltedThingKeepsItsHeldCornerWhileSized() {
        let base = CGRect(x: 0, y: 0, width: 100, height: 60), turn = 20.0
        // The bottom-right knob, dragged along the thing's own edges: the top-left corner is held.
        let along = Tilt.along(CGSize(width: 40 * cos(turn * .pi / 180), height: 40 * sin(turn * .pi / 180)), turnedBy: turn)
        XCTAssertEqual(along.width, 40, accuracy: 0.001); XCTAssertEqual(along.height, 0, accuracy: 0.001)
        let grown = CGRect(x: 0, y: 0, width: 140, height: 60)
        let slide = Tilt.slide(from: base, to: grown, turnedBy: turn)
        let before = Tilt.onScreen(CGPoint(x: 0, y: 0), of: base, turnedBy: turn)
        let after = Tilt.onScreen(CGPoint(x: slide.width, y: slide.height), of: grown.offsetBy(dx: slide.width, dy: slide.height), turnedBy: turn)
        XCTAssertEqual(before.x, after.x, accuracy: 0.001); XCTAssertEqual(before.y, after.y, accuracy: 0.001)
        XCTAssertEqual(Tilt.slide(from: base, to: grown, turnedBy: 0), .zero)
    }
}
