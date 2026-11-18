import XCTest
@testable import SeedboardCore

final class StartersTests: XCTestCase {
    func testBlankIsEmptyAndTitled() {
        let board = Starter.blank.board()
        XCTAssertTrue(board.isEmpty)
        XCTAssertEqual(board.title, "New board")
        XCTAssertEqual(Starter.blank.board(title: "Mine").title, "Mine")
    }

    func testEveryOtherStarterHasItemsAndItsNameAsTitle() {
        for starter in Starter.allCases where starter != .blank {
            let board = starter.board()
            XCTAssertFalse(board.items.isEmpty, starter.name)
            XCTAssertEqual(board.title, starter.name)
            XCTAssertFalse(starter.hint.isEmpty)
        }
        XCTAssertEqual(Starter.allCases.map(\.name), ["Blank board", "Mind map", "Flow", "Pros and cons", "Plan in steps", "Timeline"])
    }

    func testNoStarterOverlapsItsShapes() {
        // A timeline's bars are placed by their days and rows, not by a frame (see TimelineTests).
        for starter in Starter.allCases where starter != .timeline {
            let items = starter.board().items.filter { $0.kind != .frame }
            for i in items.indices { for j in items.indices where j > i {
                XCTAssertFalse(items[i].frame.intersects(items[j].frame), "\(starter.name): \(items[i].text) / \(items[j].text)")
            } }
        }
    }

    func testEveryArrowHasBothEnds() {
        for starter in Starter.allCases {
            let board = starter.board()
            for link in board.links {
                XCTAssertNotNil(board.item(link.from), starter.name)
                XCTAssertNotNil(board.item(link.to), starter.name)
                XCTAssertNotEqual(link.from, link.to)
            }
        }
    }

    func testMindMapStarterHasFourBranchesOnBothSides() {
        let board = Starter.mindMap.board()
        let centre = board.mapCentres[0]
        XCTAssertEqual(centre.text, "Main idea")
        XCTAssertTrue(centre.bothSides)
        XCTAssertEqual(board.children(of: centre.id).map(\.text), ["First thought", "Second thought", "Third thought", "Fourth thought"])
        XCTAssertEqual(board.children(of: centre.id).filter { board.side(of: $0.id) == .left }.count, 2)
    }

    func testFlowStarterHasTheDecision() {
        let board = Starter.flow.board()
        XCTAssertEqual(board.links.count, 4)
        XCTAssertEqual(board.links.filter { !$0.text.isEmpty }.map(\.text).sorted(), ["No", "Yes"])
        let diamond = board.items.first { $0.kind == .diamond }!
        let think = board.items.first { $0.text == "Think again" }!
        XCTAssertGreaterThan(think.y, diamond.y + diamond.h)
        let start = board.items.first { $0.text == "Start" }!
        let doIt = board.items.first { $0.text == "Do it" }!
        XCTAssertLessThan(start.x, doIt.x)
        XCTAssertEqual(start.kind, .round)
    }

    func testProsConsStarterHasTwoFramesWithNotesInside() {
        let board = Starter.prosCons.board()
        let frames = board.items.filter { $0.kind == .frame }
        XCTAssertEqual(frames.map(\.text).sorted(), ["Cons", "Pros"])
        XCTAssertEqual(frames.first { $0.text == "Pros" }?.colour, "green")
        XCTAssertEqual(frames.first { $0.text == "Cons" }?.colour, "red")
        for frame in frames {
            XCTAssertEqual(frame.w, 360); XCTAssertEqual(frame.h, 420)
            XCTAssertEqual(board.items.filter { $0.kind == .note && frame.frame.contains($0.frame) }.count, 2)
        }
        XCTAssertEqual(board.items.filter { $0.kind == .note }.count, 4)
        let question = board.items.first { $0.kind == .text }!
        XCTAssertEqual(question.text, "What are we deciding?")
        XCTAssertLessThan(question.y + question.h, frames[0].y)
    }

    func testStepsStarterHasFiveJoinedBoxesWithNotes() {
        let board = Starter.steps.board()
        XCTAssertEqual(board.items.filter { $0.kind == .box }.map(\.text), (1...5).map { "Step \($0)" })
        XCTAssertEqual(board.links.count, 4)
        XCTAssertEqual(board.items.filter { $0.kind == .note && $0.text == "What it needs" }.count, 5)
    }
}
