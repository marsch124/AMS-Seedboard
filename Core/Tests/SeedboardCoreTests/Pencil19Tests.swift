import XCTest
import CoreGraphics
@testable import SeedboardCore

final class Pencil19Tests: XCTestCase {
    /// A deterministic wobble.
    private func wob(_ i: Int) -> Double { sin(Double(i) * 2.3) * 2.2 }

    private func along(_ corners: [CGPoint], steps: Int = 14) -> [CGPoint] {
        var out: [CGPoint] = []
        var n = 0
        for i in 0..<(corners.count - 1) {
            for s in 0..<steps {
                let t = Double(s) / Double(steps)
                out.append(CGPoint(x: Double(corners[i].x) + Double(corners[i + 1].x - corners[i].x) * t + wob(n),
                                   y: Double(corners[i].y) + Double(corners[i + 1].y - corners[i].y) * t + wob(n + 5)))
                n += 1
            }
        }
        out.append(corners.last!)
        return out
    }

    func testRoughBoxBecomesBox() {
        let rough = along([CGPoint(x: 0, y: 0), CGPoint(x: 160, y: 4), CGPoint(x: 158, y: 100), CGPoint(x: 2, y: 98), CGPoint(x: 3, y: 6)])
        XCTAssertEqual(InkClean.clean(rough)?.kind, .box)
    }

    func testRoughCircleBecomesEllipse() {
        let rough = (0...60).map { i -> CGPoint in
            let a = Double(i) / 60 * 2 * .pi
            return CGPoint(x: 100 + 70 * cos(a) + wob(i), y: 100 + 70 * sin(a) + wob(i + 3))
        }
        XCTAssertEqual(InkClean.clean(rough)?.kind, .ellipse)
    }

    func testRoughTriangleBecomesTriangle() {
        let rough = along([CGPoint(x: 100, y: 0), CGPoint(x: 200, y: 160), CGPoint(x: 0, y: 160), CGPoint(x: 101, y: 3)])
        let found = InkClean.clean(rough)
        XCTAssertEqual(found?.kind, .triangle)
        XCTAssertEqual(found?.points.count, 4)
    }

    func testWobblyLineBecomesStraight() {
        let rough = along([CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 60)])
        let found = InkClean.clean(rough)
        XCTAssertEqual(found?.kind, .line)
        XCTAssertEqual(found?.points.count, 2)
    }

    func testArrowGetsAHead() {
        var line = along([CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 0)])
        line += along([CGPoint(x: 200, y: 0), CGPoint(x: 180, y: -14), CGPoint(x: 200, y: 0), CGPoint(x: 180, y: 14)], steps: 3)
        XCTAssertEqual(InkClean.clean(line)?.kind, .arrow)
    }

    func testScribbleAndTinyStayAsDrawn() {
        XCTAssertNil(InkClean.clean(along([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 3)], steps: 5)))
        let zig = along([CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60), CGPoint(x: 20, y: 90), CGPoint(x: 140, y: 20), CGPoint(x: 60, y: 130)])
        XCTAssertNil(InkClean.clean(zig))
    }
}

final class Pencil19RecentTests: XCTestCase {
    func testLastThreeColoursStandFirstWithoutDoubles() {
        var list: [String] = []
        for name in ["red", "", "red", "blue", "green"] { list = InkRecent.adding(name, to: list) }
        XCTAssertEqual(list, ["green", "blue", "red"])
        let all = [""] + Palette.names
        let row = InkRecent.order(recent: list, all: all)
        XCTAssertEqual(Array(row.prefix(3)), ["green", "blue", "red"])
        XCTAssertEqual(row.count, all.count)
        XCTAssertEqual(Set(row).count, row.count)
    }
}

final class Pictures19Tests: XCTestCase {
    private func board() -> (Board, UUID) {
        var b = Board(title: "t")
        let id = b.addPicture(name: "a.jpg", pixelSize: CGSize(width: 800, height: 400), centre: CGPoint(x: 100, y: 100))!
        return (b, id)
    }

    func testRoundMakesItSquareAndCircle() {
        var (b, id) = board()
        let before = b.item(id)!
        XCTAssertTrue(before.w > before.h)
        XCTAssertTrue(b.setPictureRound(id, true))
        let now = b.item(id)!
        XCTAssertTrue(now.isRound)
        XCTAssertEqual(now.w, now.h, accuracy: 0.01)
        XCTAssertEqual(now.shownPart[2], 0.5, accuracy: 0.001)
        XCTAssertTrue(b.setPictureRound(id, false))
        XCTAssertFalse(b.item(id)!.isRound)
    }

    func testPrintFrameBorder() {
        var (b, id) = board()
        XCTAssertTrue(b.setPrintFrame(id, true))
        XCTAssertTrue(b.item(id)!.isFramed)
        XCTAssertEqual(Item.printBorder(width: 100, height: 50), 6)
        XCTAssertEqual(Item.printBorder(width: 1000, height: 500), 20)
        XCTAssertTrue(b.setPrintFrame(id, false))
        XCTAssertNil(b.item(id)!.printFrame)
    }
}
