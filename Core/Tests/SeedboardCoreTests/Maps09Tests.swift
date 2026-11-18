import XCTest
import CoreGraphics
@testable import SeedboardCore

final class Maps09Tests: XCTestCase {
    // 25. Balance a mind map
    func testBalanceSpreadsBranchesBySize() throws {
        var board = Board(title: "Plan")
        let centre = board.addCentre(at: .zero, text: "Alex", bothSides: false)
        let big = try XCTUnwrap(board.addChild(of: centre, text: "Big"))
        for n in 0..<4 { _ = board.addChild(of: big, text: "b\(n)") }   // weight 5
        let twoA = try XCTUnwrap(board.addChild(of: centre, text: "A"))
        _ = board.addChild(of: twoA, text: "a1")                         // weight 2
        let twoB = try XCTUnwrap(board.addChild(of: centre, text: "B"))
        _ = board.addChild(of: twoB, text: "b1")                         // weight 2
        let one = try XCTUnwrap(board.addChild(of: centre, text: "C"))   // weight 1
        XCTAssertTrue(board.balanceMap(centre))
        XCTAssertEqual(board.item(centre)?.bothSides, true)
        let sides = [big, twoA, twoB, one].map { board.item($0)?.side }
        XCTAssertEqual(sides, [.right, .left, .left, .left])   // 5 against 2+2+1: both sides weigh 5
        XCTAssertFalse(board.balanceMap(centre))                 // already balanced: nothing changes
    }

    // 26. A folded idea's badge counts everything below it
    func testFoldedBadgeCountsAllBelowAndOpensAll() throws {
        var board = Board(title: "Plan")
        let centre = board.addCentre(at: .zero, text: "Alex")
        let a = try XCTUnwrap(board.addChild(of: centre, text: "A"))
        let b = try XCTUnwrap(board.addChild(of: a, text: "B"))
        _ = board.addChild(of: b, text: "C")
        _ = board.addChild(of: a, text: "D")
        XCTAssertEqual(board.hiddenCount(of: a), 3)
        board.items[board.index(of: a)!].folded = true
        XCTAssertTrue(board.hasFolded)
        let badge = MindMap.badge(for: CGRect(x: 0, y: 0, width: 90, height: 30), right: true, count: 3)
        XCTAssertEqual(badge.minX, 96)
        XCTAssertEqual(badge.midY, 15)
        XCTAssertTrue(board.unfoldAll())
        XCTAssertFalse(board.hasFolded)
        XCTAssertFalse(board.unfoldAll())
    }

    // 27. Yes and No out of a diamond (the rule was already there; this keeps it)
    func testDiamondArrowsSayYesThenNo() {
        var board = Board(title: "Flow")
        let q = board.add(.diamond, centre: .zero)
        let a = board.add(.box, centre: CGPoint(x: 300, y: -100))
        let b = board.add(.box, centre: CGPoint(x: 300, y: 100))
        let c = board.add(.box, centre: CGPoint(x: 300, y: 300))
        let l1 = board.link(from: q, to: a)!
        let l2 = board.link(from: q, to: b)!
        let l3 = board.link(from: q, to: c)!
        XCTAssertEqual(board.links.first { $0.id == l1 }?.text, "Yes")
        XCTAssertEqual(board.links.first { $0.id == l2 }?.text, "No")
        XCTAssertEqual(board.links.first { $0.id == l3 }?.text, "")
    }

    // 29. An arrow goes round a box in its way; nothing in the way leaves it as it was
    func testElbowGoesRoundABoxAndStaysWhenFree() {
        let a = Route.End(rect: CGRect(x: 0, y: 0, width: 100, height: 50), side: .right)
        let b = Route.End(rect: CGRect(x: 400, y: 0, width: 100, height: 50), side: .left)
        let plain = Route.elbow(from: a, to: b)
        XCTAssertFalse(plain.detour)
        let far = CGRect(x: 200, y: 400, width: 60, height: 60)
        XCTAssertEqual(Route.elbow(from: a, to: b, obstacles: [far]).points, plain.points)
        let box = CGRect(x: 220, y: -10, width: 60, height: 70)
        let round = Route.elbow(from: a, to: b, obstacles: [box])
        XCTAssertTrue(round.detour)
        for i in 1..<round.points.count { XCTAssertFalse(Route.crosses(round.points[i - 1], round.points[i], box)) }
    }

    // 28. The words of an arrow stand in the middle of the line
    func testArrowMiddleIsOnTheLine() {
        let a = Route.End(rect: CGRect(x: 0, y: 0, width: 100, height: 50), side: .right)
        let b = Route.End(rect: CGRect(x: 300, y: 0, width: 100, height: 50), side: .left)
        let arrow = Route.arrow(from: a, to: b, style: .elbow)
        XCTAssertEqual(arrow.middle.x, 200, accuracy: 1)
        XCTAssertEqual(arrow.middle.y, 25, accuracy: 1)
    }

    // 30. Numbered steps
    func testStepNumbersFollowTheArrows() {
        var board = Board(title: "Flow")
        let start = board.add(.round, centre: CGPoint(x: 0, y: 0))
        let ask = board.add(.diamond, centre: CGPoint(x: 0, y: 150))
        let yes = board.add(.box, centre: CGPoint(x: -150, y: 300))
        let no = board.add(.box, centre: CGPoint(x: 150, y: 300))
        let end = board.add(.round, centre: CGPoint(x: 0, y: 450))
        let lone = board.add(.box, centre: CGPoint(x: 600, y: 0))
        let note = board.add(.note, centre: CGPoint(x: 300, y: 150))
        _ = board.link(from: start, to: ask)
        _ = board.link(from: ask, to: yes)
        _ = board.link(from: ask, to: no)
        _ = board.link(from: yes, to: end)
        _ = board.link(from: no, to: end)
        let numbers = board.stepNumbers()
        XCTAssertEqual([start, ask, yes, no, end].map { numbers[$0] }, [1, 2, 3, 4, 5])
        XCTAssertNil(numbers[lone])
        XCTAssertNil(numbers[note])
    }

    // 33. Who does what: colour by place, and "sends N"
    func testWhoColourAndSendCount() throws {
        var board = Board.sequenceStart()
        let names = board.whos
        XCTAssertGreaterThanOrEqual(names.count, 2)
        let first = names[0].id, second = names[1].id
        board.items[board.index(of: first)!].colour = ""
        XCTAssertEqual(board.whoColour(first), Palette.branches[0])
        board.items[board.index(of: second)!].colour = "green"
        XCTAssertEqual(board.whoColour(second), "green")
        let before = board.sendCount(of: first)
        _ = board.addMessage("Hello", from: first, to: second)
        _ = board.addMessage("Yes", from: first, to: second, answer: true)
        _ = board.addMessage("Back", from: second, to: first)
        XCTAssertEqual(board.sendCount(of: first), before + 2)
    }
}
