import XCTest
@testable import SeedboardCore

/// One small test per rule of the bar beside the chosen thing (pick 7), the press-and-hold menu
/// (pick 18) and copy, cut and paste (pick 17).
final class BarClipTests: XCTestCase {
    // MARK: Pick 7 — the bar's place, the controls, sizing from a corner

    func testTheBarStandsAboveTheBoxElseBelowAndAlwaysInside() {
        let room = CGRect(x: 0, y: 0, width: 900, height: 600)
        let bar = CGSize(width: 300, height: 40)
        // Room above: 12 over the box, in the middle over it.
        let above = BarPlace.spot(box: CGRect(x: 400, y: 200, width: 100, height: 60), bar: bar, room: room)
        XCTAssertEqual(above, BarPlace.Spot(origin: CGPoint(x: 300, y: 148), above: true))
        // No room above: 12 under the box.
        let below = BarPlace.spot(box: CGRect(x: 400, y: 30, width: 100, height: 60), bar: bar, room: room)
        XCTAssertEqual(below, BarPlace.Spot(origin: CGPoint(x: 300, y: 102), above: false))
        // Near the left edge: pushed back inside, 8 from the edge.
        let left = BarPlace.spot(box: CGRect(x: 10, y: 200, width: 100, height: 60), bar: bar, room: room)
        XCTAssertEqual(left.origin.x, 8)
        // Near the right edge.
        let right = BarPlace.spot(box: CGRect(x: 850, y: 200, width: 100, height: 60), bar: bar, room: room)
        XCTAssertEqual(right.origin.x, 900 - 8 - 300)
        // The thing fills the view: the bar stays at the top edge, inside.
        let filled = BarPlace.spot(box: CGRect(x: -50, y: -50, width: 1000, height: 700), bar: bar, room: room)
        XCTAssertEqual(filled.origin, CGPoint(x: 300, y: 8))
        // The thing has slid out of sight below: the bar waits at the bottom edge, inside.
        let gone = BarPlace.spot(box: CGRect(x: 400, y: 900, width: 100, height: 60), bar: bar, room: room)
        XCTAssertEqual(gone.origin.y, 600 - 8 - 40)
    }

    func testSizingFromACornerKeepsTheOppositeCorner() {
        let base = CGRect(x: 100, y: 100, width: 150, height: 56)
        let least = CGSize(width: 44, height: 28)
        // The top left corner dragged up and left: the bottom right corner stays.
        let grown = Corner.topLeft.rect(from: base, by: CGSize(width: -30, height: -20), least: least)
        XCTAssertEqual(grown, CGRect(x: 70, y: 80, width: 180, height: 76))
        // Dragged far past the opposite corner: it stops at the smallest size, the corner still stays.
        let tiny = Corner.topLeft.rect(from: base, by: CGSize(width: 500, height: 500), least: least)
        XCTAssertEqual(tiny, CGRect(x: 206, y: 128, width: 44, height: 28))
        // The bottom right corner: the top left stays, as in 0.1.
        let old = Corner.bottomRight.rect(from: base, by: CGSize(width: 10, height: 4), least: least)
        XCTAssertEqual(old, CGRect(x: 100, y: 100, width: 160, height: 60))

        // On a board: sized from the top right, the bottom left corner does not move.
        var board = Board()
        let id = board.add(.box, centre: CGPoint(x: 175, y: 128))
        let before = board.item(id)!.frame
        board.size(id, corner: .topRight, from: before, by: CGSize(width: 40, height: -30), reach: 0)
        let after = board.item(id)!.frame
        XCTAssertEqual(after.minX, before.minX)
        XCTAssertEqual(after.maxY, before.maxY)
        XCTAssertEqual(after.width, before.width + 40)
        XCTAssertEqual(after.height, before.height + 30)
    }

    func testNoPlusOnASideWithAnArrowAndAKnobOnEveryCorner() {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0))
        let b = board.add(.box, centre: CGPoint(x: 300, y: 0))
        board.link(from: a, to: b)
        XCTAssertEqual(board.sidesWithArrows(of: a), [.right])
        XCTAssertEqual(board.sidesWithArrows(of: b), [.left])

        let item = board.item(a)!
        let all = Controls.round(item, side: .right, scale: 1, taken: board.sidesWithArrows(of: a))
        let plus = all.compactMap { c -> Direction? in if case .plus(let d) = c.kind { return d } else { return nil } }
        XCTAssertEqual(Set(plus), [.down, .left, .up])
        let knobs = all.compactMap { c -> Corner? in if case .size(let k) = c.kind { return k } else { return nil } }
        XCTAssertEqual(Set(knobs), Set(Corner.allCases))
        // A dot is 10 at rest and 18 with its plus; a knob is 9.
        let down = all.first { $0.kind == .plus(.down) }!
        XCTAssertEqual(down.rest.width, 10)
        XCTAssertEqual(down.grown.width, 18)
        XCTAssertEqual(down.grown.midY, item.frame.maxY + 17)
        XCTAssertEqual(all.first { $0.kind == .size(.topLeft) }!.rest.width, 9)
        // A handle never sits on an arrow's words.
        let words = [CGRect(x: item.frame.midX - 20, y: item.frame.maxY + 10, width: 40, height: 16)]
        let clear = Controls.round(item, side: .right, scale: 1, words: words)
        XCTAssertFalse(clear.contains { $0.kind == .plus(.down) })
        // An idea has its one handle and no knob; free text has no knob; a frame has only knobs.
        let idea = Item(kind: .idea, parent: UUID())
        XCTAssertEqual(Controls.round(idea, side: .left, scale: 1).map(\.kind), [.plus(.left)])
        XCTAssertTrue(Controls.knobCorners(of: .text).isEmpty)
        XCTAssertEqual(Controls.round(Item(kind: .frame), side: .right, scale: 1).count, 4)
    }

    // MARK: Pick 18 — press and hold

    func testAStillPressOfHalfASecondOpensTheMenu() {
        XCTAssertTrue(Fingers.opensMenu(moved: 2, after: 0.5))
        // Too short: a press.
        XCTAssertFalse(Fingers.opensMenu(moved: 0, after: 0.3))
        // It moved: a drag, however long it lasts.
        XCTAssertFalse(Fingers.opensMenu(moved: 9, after: 2))
        // With the menu open, a small tremble keeps it; a real move takes the press back as a drag.
        XCTAssertFalse(Fingers.leavesMenu(moved: 8))
        XCTAssertTrue(Fingers.leavesMenu(moved: 14))
    }

    // MARK: Pick 17 — copy and paste

    private func flow() -> (board: Board, a: UUID, b: UUID, c: UUID) {
        var board = Board()
        let a = board.add(.box, centre: CGPoint(x: 0, y: 0), text: "A")
        let b = board.add(.diamond, centre: CGPoint(x: 300, y: 0), text: "B", colour: "blue")
        let c = board.add(.box, centre: CGPoint(x: 600, y: 0), text: "C")
        board.link(from: a, to: b, text: "first")
        board.link(from: b, to: c, text: "then")
        return (board, a, b, c)
    }

    func testCopyTakesTheChosenThingsWithTheArrowsBetweenThem() {
        let made = flow()
        let clip = made.board.clip(of: [made.a, made.b])
        XCTAssertEqual(Set(clip.items.map(\.id)), [made.a, made.b])
        // Only the arrow whose two ends are both copied comes along.
        XCTAssertEqual(clip.links.map(\.text), ["first"])
        XCTAssertTrue(clip.canBePasted)
        // The clip survives the clipboard.
        XCTAssertEqual(Clip.decoded(clip.encoded()!), clip)
        // Its words for other apps: several things give the outline, one thing just its words.
        XCTAssertEqual(clip.text, "Flow:\nA → B (first)")
        XCTAssertEqual(made.board.clip(of: [made.c]).text, "C")
        // A clip from a newer Seedboard is not pasted.
        var newer = clip
        newer.format = Board.currentFormat + 1
        XCTAssertFalse(newer.canBePasted)
    }

    func testPasteMakesNewThingsWithNewIdentitiesAtTheSpot() {
        let made = flow()
        let clip = made.board.clip(of: [made.a, made.b])
        // Into ANOTHER board, with the middle of the two at (1000, 500).
        var other = Board()
        let pasted = other.paste(clip, at: CGPoint(x: 1000, y: 500))
        XCTAssertEqual(pasted.count, 2)
        XCTAssertTrue(pasted.isDisjoint(with: [made.a, made.b]))
        XCTAssertEqual(other.items.map(\.text), ["A", "B"])
        XCTAssertEqual(other.items.first { $0.text == "B" }?.colour, "blue")
        let box = other.bounds!
        XCTAssertEqual(Double(box.midX), 1000, accuracy: 0.001)
        XCTAssertEqual(Double(box.midY), 500, accuracy: 0.001)
        // The arrow is kept, between the new things, with a new identity.
        XCTAssertEqual(other.links.count, 1)
        XCTAssertEqual(other.links[0].text, "first")
        XCTAssertTrue(pasted.contains(other.links[0].from) && pasted.contains(other.links[0].to))
        XCTAssertNotEqual(other.links[0].id, made.board.links[0].id)
        // Pasted again: new identities again; the app sets each further paste 28 off.
        let again = other.paste(clip, at: CGPoint(x: 1000, y: 500))
        XCTAssertTrue(again.isDisjoint(with: pasted))
        XCTAssertEqual(other.items.count, 4)
        XCTAssertEqual(Clip.step(again: 0), .zero)
        XCTAssertEqual(Clip.step(again: 2), CGSize(width: 56, height: 56))
        // A frame goes underneath everything.
        var framed = Board()
        let frame = framed.add(.frame, centre: .zero, text: "F")
        let note = framed.add(.note, centre: .zero, text: "N")
        other.paste(framed.clip(of: [frame, note]), at: .zero)
        XCTAssertEqual(other.items.first?.text, "F")
    }

    func testABranchCopiesWithEverythingUnderIt() {
        var board = Board()
        let centre = board.addCentre(at: .zero, text: "Cabin")
        let budget = board.addChild(of: centre, text: "Budget")!
        let loan = board.addChild(of: budget, text: "Loan")!
        board.addChild(of: loan, text: "Bank")
        board.addChild(of: centre, text: "Place")
        if let i = board.index(of: budget) { board.items[i].colour = "teal"; board.items[i].folded = true }

        // Only the branch is chosen: its ideas come along, folded or not.
        let clip = board.clip(of: [budget])
        XCTAssertEqual(Set(clip.items.map(\.text)), ["Budget", "Loan", "Bank"])
        XCTAssertEqual(clip.topIdeas.map(\.text), ["Budget"])
        XCTAssertEqual(clip.text, "- Budget\n  - Loan\n    - Bank")

        // Pasted on empty board it is a small map of its own; the ideas under it keep the branch's colour.
        var other = Board()
        let tops = other.paste(clip, at: CGPoint(x: 50, y: 50))
        XCTAssertEqual(tops.count, 1)
        let top = other.item(tops.first!)!
        XCTAssertEqual(top.text, "Budget")
        XCTAssertNil(top.parent)
        XCTAssertEqual(other.children(of: top.id).map(\.text), ["Loan"])
        XCTAssertEqual(other.children(of: top.id).first?.colour, "teal")
        XCTAssertEqual(other.descendants(of: top.id).count, 2)

        // Pasted with an idea chosen it hangs under that idea.
        let place = board.items.first { $0.text == "Place" }!.id
        let hung = board.paste(clip, under: place)
        XCTAssertEqual(hung.count, 1)
        XCTAssertEqual(board.item(hung.first!)?.parent, place)
        XCTAssertEqual(board.descendants(of: place).count, 3)
        XCTAssertEqual(board.items.filter { $0.kind == .idea }.count, 8)
    }

    func testWordsFromElsewhereBecomeANoteAndAListAMindMap() {
        var board = Board()
        let note = board.addWords("  Call the builder  ", at: CGPoint(x: 100, y: 100))!
        XCTAssertEqual(board.item(note)?.kind, .note)
        XCTAssertEqual(board.item(note)?.text, "Call the builder")
        XCTAssertEqual(board.item(note)?.centre, CGPoint(x: 100, y: 100))
        let map = board.addWords("Trip\n  - Food\n  - Bed", at: CGPoint(x: 400, y: 100))!
        XCTAssertEqual(board.item(map)?.kind, .idea)
        XCTAssertEqual(board.item(map)?.text, "Trip")
        XCTAssertEqual(board.children(of: map).map(\.text), ["Food", "Bed"])
        XCTAssertNil(board.addWords("  \n ", at: .zero))
    }
}
