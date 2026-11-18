import XCTest
import CoreGraphics
@testable import SeedboardCore

final class Views09Tests: XCTestCase {
    private func frames(_ b: inout Board, _ spots: [(String, Double, Double)]) {
        for (name, x, y) in spots {
            let f = b.add(.frame, centre: .zero, text: name)
            b.resize(f, to: CGRect(x: x, y: y, width: 200, height: 100))
        }
    }

    func testShowOrderIsTopRowsThenLeftToRight() {
        var b = Board(title: "t")
        frames(&b, [("D", 300, 130), ("B", 300, 0), ("C", 0, 140), ("A", 0, 5)])
        XCTAssertEqual(b.showOrder().compactMap { b.item($0)?.text }, ["A", "B", "C", "D"])
    }

    func testTidyIntoGridMakesSquareishGridWithGap16() {
        var b = Board(title: "t")
        var ids = Set<UUID>()
        for n in 0..<5 { ids.insert(b.add(.note, centre: CGPoint(x: Double(n * 400), y: Double((n % 2) * 37)))) }
        XCTAssertTrue(b.tidyIntoGrid(ids))
        let notes = Thinking.readingOrder(b.items.filter { ids.contains($0.id) })
        XCTAssertEqual(Set(notes.map(\.x)).count, 3)   // 5 things: 3 columns
        XCTAssertEqual(Set(notes.map(\.y)).count, 2)
        let xs = Array(Set(notes.map(\.x))).sorted()
        XCTAssertEqual(xs[1] - xs[0] - 150, 16, accuracy: 0.001)
        XCTAssertEqual(notes.map(\.x).min() ?? 0, -75, accuracy: 0.001)   // starts at the group's top left
    }

    func testTidyIntoGridLeavesPinnedAndWorksOnLooseNotes() {
        var b = Board(title: "t")
        let pinned = b.add(.note, centre: CGPoint(x: 900, y: 900))
        b.items[b.index(of: pinned)!].locked = true
        for n in 0..<4 { b.add(.note, centre: CGPoint(x: Double(n * 500), y: Double(n * 300))) }
        let before = b.item(pinned)!.frame
        XCTAssertTrue(b.tidyIntoGrid([]))
        XCTAssertEqual(b.item(pinned)!.frame, before)
        XCTAssertEqual(Set(b.items.filter { $0.id != pinned }.map(\.x)).count, 2)
        var one = Board(title: "t"); one.add(.note, centre: .zero)
        XCTAssertFalse(one.tidyIntoGrid([]))
    }

    func testMapMaths() {
        let visible = CGRect(x: 0, y: 0, width: 400, height: 300)
        XCTAssertFalse(BoardMap.isNeeded(content: CGRect(x: 0, y: 0, width: 700, height: 500), visible: visible))
        let content = CGRect(x: -1000, y: -500, width: 2400, height: 1000)
        XCTAssertTrue(BoardMap.isNeeded(content: content, visible: visible))
        let map = BoardMap(content: content, visible: visible, size: CGSize(width: 120, height: 80))
        let r = map.toMap(content)
        XCTAssertLessThanOrEqual(r.width, 120.001); XCTAssertLessThanOrEqual(r.height, 80.001)
        let p = CGPoint(x: 100, y: 200)
        let back = map.toBoard(map.toMap(p))
        XCTAssertEqual(Double(back.x), 100, accuracy: 0.001); XCTAssertEqual(Double(back.y), 200, accuracy: 0.001)
    }

    func testShowZoomsToFitFrame() {
        var v = Viewport()
        v.size = CGSize(width: 800, height: 600)
        v.show(CGRect(x: 100, y: 100, width: 400, height: 200), air: 40)
        XCTAssertEqual(v.scale, 1.8, accuracy: 0.001)
        let mid = v.toBoard(CGPoint(x: 400, y: 300))
        XCTAssertEqual(Double(mid.x), 300, accuracy: 0.001); XCTAssertEqual(Double(mid.y), 200, accuracy: 0.001)
    }

    func testNewStartersExistAndDoNotOverlap() {
        XCTAssertEqual(Starter.decisionGrid.name, "Decision grid")
        for starter in [Starter.decisionGrid, .weeklyReview, .swot] {
            let b = starter.board()
            XCTAssertTrue(Starter.allCases.contains(starter))
            let frames = b.items.filter { $0.kind == .frame }
            XCTAssertFalse(frames.isEmpty)
            for (i, a) in frames.enumerated() { for c in frames[(i + 1)...] { XCTAssertFalse(a.frame.intersects(c.frame), starter.name) } }
            let others = b.items.filter { $0.kind != .frame }
            for (i, a) in others.enumerated() { for c in others[(i + 1)...] { XCTAssertFalse(a.frame.intersects(c.frame), starter.name) } }
            for o in others where o.kind == .text { for f in frames { XCTAssertFalse(f.frame.intersects(o.frame)) } }
            for o in others where o.kind == .note { XCTAssertEqual(frames.filter { $0.frame.contains(o.frame) }.count, 1, starter.name) }
        }
        XCTAssertEqual(Starter.swot.board().items.filter { $0.kind == .frame }.map(\.text).sorted(), ["Opportunities", "Strengths", "Threats", "Weaknesses"])
        XCTAssertEqual(Starter.weeklyReview.board().items.filter { $0.kind == .frame }.map(\.text).sorted(), ["Done", "Ideas", "Next week", "Stuck"])
        XCTAssertEqual(Starter.decisionGrid.board().items.first { $0.kind == .frame }?.lanes?.count, 3)
    }
}
