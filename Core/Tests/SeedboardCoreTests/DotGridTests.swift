import XCTest
@testable import SeedboardCore

final class DotGridTests: XCTestCase {
    func testDotsStandEvery24AndThinOutSoTheyNeverCrowd() {
        XCTAssertEqual(DotGrid.step(scale: 1), 24)
        XCTAssertEqual(DotGrid.step(scale: 3), 24)
        XCTAssertEqual(DotGrid.step(scale: 0.5), 24)     // 12 screen points apart: just allowed
        XCTAssertEqual(DotGrid.step(scale: 0.4), 48)     // 24 would be 9.6 apart
        XCTAssertEqual(DotGrid.step(scale: 0.2), 96)
        for scale in stride(from: CGFloat(0.2), through: 3, by: 0.05) {
            XCTAssertGreaterThanOrEqual(DotGrid.step(scale: scale) * scale, 12 - 0.0001)
        }
    }

    func testDotsFadeBelowFortyPercent() {
        XCTAssertEqual(DotGrid.strength(scale: 1), 1)
        XCTAssertEqual(DotGrid.strength(scale: 0.4), 1)
        XCTAssertEqual(DotGrid.strength(scale: 0.3), 0.5, accuracy: 0.0001)
        XCTAssertEqual(DotGrid.strength(scale: 0.2), 0)
    }

    func testOnlyTheDotsThatCanBeSeenAreMade() {
        // A view of 100 × 50 board points starting at (-30, 10): dots at x -24, 0, 24, 48 and y 24, 48.
        let dots = DotGrid.dots(in: CGRect(x: -30, y: 10, width: 100, height: 50), scale: 1)
        XCTAssertEqual(dots.count, 8)
        XCTAssertEqual(dots.first, CGPoint(x: -24, y: 24))
        XCTAssertEqual(dots.last, CGPoint(x: 48, y: 48))
        XCTAssertTrue(DotGrid.dots(in: CGRect(x: 0, y: 0, width: 500, height: 500), scale: 0.2).isEmpty)
    }
}
