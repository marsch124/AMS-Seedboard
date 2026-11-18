import XCTest
@testable import SeedboardCore

final class OutlineTests: XCTestCase {
    func testBulletsAreStripped() {
        let nodes = Outline.parse("- one\n* two\n+ three\n• four\n– five\n◦ six")
        XCTAssertEqual(nodes.map(\.text), ["one", "two", "three", "four", "five", "six"])
    }

    func testNumbersAndLettersAreStripped() {
        let nodes = Outline.parse("1. first\n2) second\n10. tenth\na) letter")
        XCTAssertEqual(nodes.map(\.text), ["first", "second", "tenth", "letter"])
    }

    func testCheckBoxesAreStripped() {
        let nodes = Outline.parse("- [ ] buy milk\n- [x] call Anna\n- [X] done")
        XCTAssertEqual(nodes.map(\.text), ["buy milk", "call Anna", "done"])
    }

    func testTabsMakeDepth() {
        let nodes = Outline.parse("a\n\tb\n\t\tc\n\td\ne")
        XCTAssertEqual(nodes, [
            OutlineNode("a", [OutlineNode("b", [OutlineNode("c")]), OutlineNode("d")]),
            OutlineNode("e"),
        ])
    }

    func testAnySpaceStepMakesDepth() {
        let two = Outline.parse("- a\n  - b\n    - c")
        let three = Outline.parse("- a\n   - b\n      - c")
        XCTAssertEqual(two, [OutlineNode("a", [OutlineNode("b", [OutlineNode("c")])])])
        XCTAssertEqual(three, two)
    }

    func testATabCountsAsFourSpaces() {
        XCTAssertEqual(Outline.parse("a\n    b\n\tc"), [OutlineNode("a", [OutlineNode("b"), OutlineNode("c")])])
    }

    func testHeadingsNestBulletsUnderThem() {
        let nodes = Outline.parse("# Plan\n## Week 1\n- shop\n- cook\n  - soup\n## Week 2\n- rest")
        XCTAssertEqual(nodes, [OutlineNode("Plan", [
            OutlineNode("Week 1", [OutlineNode("shop"), OutlineNode("cook", [OutlineNode("soup")])]),
            OutlineNode("Week 2", [OutlineNode("rest")]),
        ])])
    }

    func testBlankLinesAndSpacesAreIgnored() {
        let nodes = Outline.parse("\n  first   \n\n\t\n second\n")
        XCTAssertEqual(nodes.map(\.text), ["first", "second"])
    }

    func testADeepJumpIsPulledBackToOneStep() {
        XCTAssertEqual(Outline.parse("a\n        b"), [OutlineNode("a", [OutlineNode("b")])])
        XCTAssertEqual(Outline.parse("      a\nb"), [OutlineNode("a"), OutlineNode("b")])
    }

    func testIsListNeedsTwoLines() {
        XCTAssertFalse(Outline.isList(""))
        XCTAssertFalse(Outline.isList("one idea"))
        XCTAssertFalse(Outline.isList("one idea\n\n  \n"))
        XCTAssertTrue(Outline.isList("one\ntwo"))
    }

    func testTextAndParseRoundTrip() {
        let nodes = [OutlineNode("Food", [OutlineNode("Fruit", [OutlineNode("Apple")]), OutlineNode("Bread")]), OutlineNode("Drink")]
        let text = Outline.text(nodes)
        XCTAssertEqual(text, "- Food\n  - Fruit\n    - Apple\n  - Bread\n- Drink")
        XCTAssertEqual(Outline.parse(text), nodes)
    }

    func testAddMapWithOneTopMakesItTheCentre() {
        var board = Board()
        let centre = board.addMap(from: [OutlineNode("Trip", [OutlineNode("Pack"), OutlineNode("Book")])], title: "Ignored", at: CGPoint(x: 100, y: 50))
        XCTAssertEqual(board.item(centre)?.text, "Trip")
        XCTAssertEqual(board.items.count, 3)
        XCTAssertEqual(board.children(of: centre).map(\.text), ["Pack", "Book"])
        XCTAssertEqual(board.item(centre)?.centre.x ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(board.item(centre)?.centre.y ?? 0, 50, accuracy: 0.001)
    }

    func testAddMapWithManyTopsUsesTheTitle() {
        var board = Board()
        let centre = board.addMap(from: [OutlineNode("a"), OutlineNode("b")], title: "My list", at: .zero)
        XCTAssertEqual(board.item(centre)?.text, "My list")
        XCTAssertEqual(board.children(of: centre).map(\.text), ["a", "b"])
        var other = Board()
        let c2 = other.addMap(from: [OutlineNode("a"), OutlineNode("b")], title: nil, at: .zero)
        XCTAssertEqual(other.item(c2)?.text, "Ideas")
    }

    func testMainBranchesGetDifferentColours() {
        var board = Board()
        let centre = board.addMap(from: (1...4).map { OutlineNode("n\($0)") }, title: nil, at: .zero)
        XCTAssertEqual(Set(board.children(of: centre).map(\.colour)).count, 4)
    }

    func testBothSidesOnlyAboveFourBranches() {
        var four = Board()
        let a = four.addMap(from: (1...4).map { OutlineNode("n\($0)") }, title: nil, at: .zero)
        XCTAssertEqual(four.item(a)?.bothSides, false)
        var five = Board()
        let b = five.addMap(from: (1...5).map { OutlineNode("n\($0)") }, title: nil, at: .zero)
        XCTAssertEqual(five.item(b)?.bothSides, true)
        XCTAssertTrue(five.children(of: b).contains { five.side(of: $0.id) == .left })
    }

    func testAddMapGivesRoughSizesAndNoOverlap() {
        var board = Board()
        let long = String(repeating: "x", count: 100)
        let centre = board.addMap(from: [OutlineNode("Hi", [OutlineNode(long, [OutlineNode("deep")]), OutlineNode("b")])], title: nil, at: .zero)
        XCTAssertEqual(board.item(centre)?.w ?? 0, 60 + 24, accuracy: 0.001)
        XCTAssertEqual(board.item(centre)?.h ?? 0, 46, accuracy: 0.001)
        let wide = board.children(of: centre).first { $0.text == long }
        XCTAssertEqual(wide?.w ?? 0, 260, accuracy: 0.001)
        XCTAssertEqual(Board.roughSize(for: "abcdefghij").width, 98, accuracy: 0.001)
        XCTAssertEqual(Board.roughSize(for: "a").width, 60, accuracy: 0.001)
        XCTAssertEqual(Board.roughSize(for: "a").height, 30, accuracy: 0.001)
        let ideas = board.items
        for i in ideas.indices { for j in ideas.indices where j > i {
            XCTAssertFalse(ideas[i].frame.insetBy(dx: 1, dy: 1).intersects(ideas[j].frame.insetBy(dx: 1, dy: 1)))
        } }
    }

    func testAddIdeasHangsUnderAnIdea() {
        var board = Board()
        let centre = board.addCentre(at: .zero, text: "Root")
        let kid = board.addChild(of: centre, text: "Kid")!
        let made = board.addIdeas(from: [OutlineNode("x", [OutlineNode("x1")]), OutlineNode("y")], under: kid)
        XCTAssertEqual(made.count, 2)
        XCTAssertEqual(board.children(of: kid).map(\.text), ["x", "y"])
        XCTAssertEqual(board.descendants(of: kid).count, 3)
        let shape = board.add(.box, centre: .zero)
        XCTAssertEqual(board.addIdeas(from: [OutlineNode("z")], under: shape), [])
    }

    func testOutlineOfKeepsFoldedBranches() {
        var board = Board()
        let centre = board.addMap(from: [OutlineNode("R", [OutlineNode("A", [OutlineNode("A1")])])], title: nil, at: .zero)
        let a = board.children(of: centre)[0].id
        board.items[board.index(of: a)!].folded = true
        XCTAssertEqual(board.outline(of: centre), OutlineNode("R", [OutlineNode("A", [OutlineNode("A1")])]))
    }

    func testOutlineTextHasAllSectionsInOrder() {
        var board = Board()
        board.addMap(from: [OutlineNode("Map", [OutlineNode("Kid")])], title: nil, at: .zero)
        let a = board.add(.box, centre: .zero, text: "Start")
        let b = board.add(.diamond, centre: .zero, text: "")
        let c = board.add(.box, centre: .zero, text: "End")
        board.link(from: a, to: b)
        board.link(from: b, to: c, text: "yes")
        board.add(.note, centre: .zero, text: "line one\nline two")
        board.add(.text, centre: .zero, text: "free")
        board.add(.oval, centre: .zero, text: "Alone")
        let expected = """
        - Map
          - Kid

        Flow:
        Start → (empty)
        (empty) → End (yes)

        Notes:
        - line one line two
        - free

        Shapes:
        - Alone
        """
        XCTAssertEqual(board.outlineText, expected)
    }

    func testOutlineTextLeavesEmptySectionsOut() {
        XCTAssertEqual(Board().outlineText, "")
        var board = Board()
        board.add(.note, centre: .zero, text: "only")
        XCTAssertEqual(board.outlineText, "Notes:\n- only")
    }
}
