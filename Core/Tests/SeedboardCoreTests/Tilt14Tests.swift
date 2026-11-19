import XCTest
@testable import SeedboardCore

/// 0.14: tilt a note, a picture, a free text or a flowchart shape.
final class Tilt14Tests: XCTestCase {
    func testTheButtonStepsStraightLeftRightStraightAndStraightIsNil() {
        var b = Board(title: "t")
        let n = b.add(.note, centre: CGPoint(x: 100, y: 100))
        XCTAssertEqual(b.item(n)?.tilt, nil)
        b.stepTilt([n]); XCTAssertEqual(b.item(n)?.tilt, -4)
        b.stepTilt([n]); XCTAssertEqual(b.item(n)?.tilt, 4)
        b.stepTilt([n]); XCTAssertNil(b.item(n)?.tilt)
        b.setTilt([n], to: 0); XCTAssertNil(b.item(n)?.tilt)
        b.setTilt([n], to: 90); XCTAssertEqual(b.item(n)?.tilt, 45)
        XCTAssertNil(Tilt.snapped(2.9)); XCTAssertEqual(Tilt.snapped(-10), -10)
    }

    func testOnlyNotesPicturesTextAndShapesTilt() {
        XCTAssertTrue(Tilt.canTilt(.note)); XCTAssertTrue(Tilt.canTilt(.text)); XCTAssertTrue(Tilt.canTilt(.box))
        XCTAssertTrue(Tilt.canTilt(.picture)); XCTAssertTrue(Tilt.canTilt(.diamond))
        for kind in [ItemKind.idea, .frame, .door, .drawing, .table, .bar, .milestone, .phase, .who, .message, .band, .section, .block] {
            XCTAssertFalse(Tilt.canTilt(kind), "\(kind)")
        }
        var item = Item(kind: .idea); item.tilt = 4
        XCTAssertEqual(item.turn, 0)
    }

    func testAPressUsesTheTurnedShape() {
        var b = Board(title: "t")
        let n = b.add(.note, centre: CGPoint(x: 100, y: 100))
        let f = b.item(n)!.frame
        // A corner of the straight box lies outside once the note is turned a lot.
        let corner = CGPoint(x: f.minX + 1, y: f.minY + 1)
        XCTAssertEqual(b.hit(corner), n)
        b.setTilt([n], to: 40)
        XCTAssertNil(b.hit(corner))
        // The middle stays, and a point just beyond the turned top corner is caught.
        XCTAssertEqual(b.hit(CGPoint(x: f.midX, y: f.midY)), n)
        let turned = Tilt.rotate(CGPoint(x: f.maxX - 1, y: f.minY + 1), about: CGPoint(x: f.midX, y: f.midY), degrees: 40)
        XCTAssertEqual(b.hit(turned), n)
        XCTAssertEqual(Tilt.bounds(of: f, turnedBy: 0), f)
    }
}
