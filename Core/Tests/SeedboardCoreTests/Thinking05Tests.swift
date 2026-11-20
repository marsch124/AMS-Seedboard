import XCTest
@testable import SeedboardCore

/// One small test per rule of the flow of thinking in 0.5: the next note (pick 10), turn into / a note becomes
/// an idea / make a mind map / break into notes (pick 11), sorting a pile (pick 12), and pasted paragraphs (the bug).
final class Thinking05Tests: XCTestCase {
    private func note(_ board: inout Board, _ words: String, x: Double, y: Double, colour: String = "") -> UUID {
        let id = board.add(.note, centre: .zero, text: words, colour: colour)
        let i = board.index(of: id)!
        board.items[i].x = x
        board.items[i].y = y
        return id
    }

    // MARK: Pick 10 — the next note

    func testTheNextNoteStandsToTheRightElseUnderTheFirstOfTheRow() {
        var board = Board()
        let first = note(&board, "One", x: 0, y: 0, colour: "pink")
        board.items[0].h = 140
        // To the right: same colour, same size, 16 apart.
        let second = board.addNextNote(after: first)!
        let two = board.item(second)!
        XCTAssertEqual([two.x, two.y, two.w, two.h], [166, 0, 150, 140])
        XCTAssertEqual(two.colour, "pink")
        XCTAssertEqual(two.text, "")
        // Something lies where the third would go: it goes under the first note of the row.
        board.add(.box, centre: CGPoint(x: 166 + 166 + 75, y: 70))
        let thirdID = board.addNextNote(after: second)!
        let third = board.item(thirdID)!
        XCTAssertEqual([third.x, third.y], [0, 156])
        // And from there to the right again.
        let fourthID = board.addNextNote(after: third.id)!
        let fourth = board.item(fourthID)!
        XCTAssertEqual([fourth.x, fourth.y], [166, 156])
        // Only a sticky note chains; nothing on a board that places itself.
        XCTAssertNil(board.addNextNote(after: board.items.first { $0.kind == .box }!.id))
        var timeline = board
        timeline.kind = "timeline"
        XCTAssertNil(timeline.addNextNote(after: first))
    }

    // MARK: Pick 11 — turn into, a note becomes an idea, make a mind map, break into notes

    func testTurnIntoKeepsWordsColourTickPlaceAndArrows() {
        var board = Board()
        let pink = note(&board, "Risk", x: 100, y: 100, colour: "pink")
        let box = board.add(.box, centre: CGPoint(x: 500, y: 155), text: "Next")
        board.items[board.index(of: pink)!].todo = true
        board.link(from: pink, to: box)
        XCTAssertEqual(board.turnChoices(for: [pink]), [.box, .text, .idea])
        XCTAssertEqual(board.turnChoices(for: [pink, box]), [.note, .box, .text, .idea])

        XCTAssertEqual(board.turn([pink], into: .box), [pink])
        let turned = board.item(pink)!
        XCTAssertEqual(turned.kind, .box)
        XCTAssertEqual(turned.text, "Risk")
        XCTAssertEqual(turned.colour, "pink")
        XCTAssertTrue(turned.todo)
        XCTAssertEqual(turned.centre, CGPoint(x: 175, y: 155))
        XCTAssertEqual(board.links.count, 1)

        // A box without a colour becomes a yellow note; a note becomes a lone idea (the middle of its own map).
        board.turn([box], into: .note)
        XCTAssertEqual(board.item(box)!.colour, "yellow")
        board.turn([pink], into: .idea)
        XCTAssertTrue(board.isCentre(pink))
        XCTAssertTrue(board.item(pink)!.todo)
        // A frame and a picture cannot be turned.
        let frame = board.add(.frame, centre: .zero)
        XCTAssertTrue(board.turnChoices(for: [frame]).isEmpty)
        XCTAssertTrue(board.turn([frame], into: .note).isEmpty)
    }

    func testAnIdeaTurnedIntoANoteLeavesItsMapAndItsIdeasMoveUp() {
        var board = Board()
        let centre = board.addCentre(at: .zero, text: "Cabin")
        let a = board.addChild(of: centre, text: "A")!
        let b = board.addChild(of: centre, text: "B")!
        let c = board.addChild(of: centre, text: "C")!
        let b1 = board.addChild(of: b, text: "B1")!
        let b2 = board.addChild(of: b, text: "B2")!
        // The middle of a map that has branches stays an idea.
        XCTAssertFalse(board.canTurn(centre, into: .note))
        XCTAssertEqual(board.turn([b], into: .note), [b])
        XCTAssertEqual(board.item(b)!.kind, .note)
        XCTAssertNil(board.item(b)!.parent)
        // B's ideas took its place among the main branches.
        XCTAssertEqual(board.children(of: centre).map(\.id), [a, b1, b2, c])
        // A branch's colour becomes the note's paper (orange is a paper; teal would be green).
        XCTAssertEqual(board.item(b)!.colour, "orange")
        XCTAssertEqual(Thinking.notePaper(for: "teal"), "green")
        XCTAssertEqual(Thinking.notePaper(for: ""), "yellow")
    }

    func testANoteDroppedOnAnIdeaBecomesAnIdeaUnderIt() {
        var board = Board()
        let centre = board.addCentre(at: .zero, text: "Cabin")
        let a = board.addChild(of: centre, text: "A")!
        let blue = note(&board, "Windows", x: 400, y: 0, colour: "blue")
        let plain = note(&board, "Roof", x: 400, y: 200)
        board.items[board.index(of: plain)!].todo = true
        XCTAssertTrue(board.canBecomeIdea(blue))
        XCTAssertFalse(board.canBecomeIdea(a))
        // Under the middle: a main branch that keeps the note's colour. Since 0.17 yellow is a branch colour too,
        // so a plain yellow note stays yellow.
        XCTAssertTrue(board.makeIdea(blue, under: centre))
        XCTAssertTrue(board.makeIdea(plain, under: centre))
        XCTAssertEqual(board.children(of: centre).map(\.id), [a, blue, plain])
        XCTAssertEqual(board.item(blue)!.colour, "blue")
        XCTAssertEqual(board.item(plain)!.colour, "yellow")
        XCTAssertTrue(board.item(plain)!.todo)
        // Under a branch: it follows the branch's colour.
        let text = board.add(.text, centre: CGPoint(x: 0, y: 400), text: "Later")
        XCTAssertTrue(board.makeIdea(text, under: a))
        XCTAssertEqual(board.item(text)!.parent, a)
        XCTAssertEqual(board.branchColour(of: text), "pink")
        // An idea is not "made an idea", and a diamond stays a diamond.
        XCTAssertFalse(board.makeIdea(a, under: centre))
        let diamond = board.add(.diamond, centre: CGPoint(x: 0, y: 600))
        XCTAssertFalse(board.makeIdea(diamond, under: centre))
    }

    func testMakeAMindMapOfNotesInReadingOrderWithFramesAsBranches() {
        var board = Board(title: "Summer cabin")
        // Two loose notes in one row, then a frame "Risks" with two notes, the frame chosen as well.
        let right = note(&board, "Second", x: 300, y: 0)
        let left = note(&board, "First", x: 0, y: 10, colour: "pink")
        let frame = board.add(.frame, centre: CGPoint(x: 220, y: 400), text: "Risks")
        let low = note(&board, "Rain", x: 240, y: 330)
        let high = note(&board, "Cost", x: 40, y: 300)
        let stays = board.add(.box, centre: CGPoint(x: 900, y: 0), text: "Stays")
        board.items[board.index(of: low)!].todo = true
        XCTAssertEqual(board.mapMakers([right, left, frame, low, high, stays]).count, 4)

        let centre = board.makeMap(of: [right, left, frame, low, high, stays], middle: " Summer cabin ")!
        XCTAssertEqual(board.item(centre)!.text, "Summer cabin")
        let branches = board.children(of: centre)
        XCTAssertEqual(branches.map(\.text), ["First", "Second", "Risks"])
        XCTAssertEqual(branches.map(\.id).prefix(2), [left, right])
        XCTAssertEqual(branches[0].colour, "pink")
        XCTAssertEqual(board.children(of: branches[2].id).map(\.id), [high, low])
        XCTAssertTrue(board.item(low)!.todo)
        // The chosen frame held only these notes: it is gone. The box was not touched.
        XCTAssertNil(board.item(frame))
        XCTAssertEqual(board.item(stays)!.kind, .box)
        // One note is not enough; an empty middle idea says "Ideas".
        XCTAssertNil(board.makeMap(of: [stays, centre], middle: "x"))
        var other = Board()
        let one = note(&other, "One", x: 0, y: 0), two = note(&other, "Two", x: 0, y: 200)
        let middle = other.makeMap(of: [one, two], middle: "  ")!
        XCTAssertEqual(other.item(middle)!.text, "Ideas")
    }

    func testBreakIntoNotesMakesAColumnInTheBranchColour() {
        var board = Board()
        let centre = board.addCentre(at: .zero, text: "Cabin")
        let a = board.addChild(of: centre, text: "A")!
        let b = board.addChild(of: centre, text: "B")!
        let a1 = board.addChild(of: a, text: "A1")!
        let a2 = board.addChild(of: a, text: "A2")!
        board.items[board.index(of: a1)!].todo = true
        board.layoutMaps()
        let spot = board.item(a)!
        XCTAssertEqual(board.breakIntoNotes(a), [a, a1, a2])
        let notes = [a, a1, a2].map { board.item($0)! }
        XCTAssertTrue(notes.allSatisfy { $0.kind == .note && $0.parent == nil && $0.colour == "pink" })
        XCTAssertEqual(notes.map(\.x), [spot.x, spot.x, spot.x])
        XCTAssertEqual(notes.map(\.y), [spot.y, spot.y + 126, spot.y + 252])
        XCTAssertTrue(notes[1].todo)
        // The rest of the map stays a map.
        XCTAssertEqual(board.children(of: centre).map(\.id), [b])
        XCTAssertTrue(board.breakIntoNotes(notes[0].id).isEmpty)
    }

    // MARK: Pick 12 — sort a pile

    func testOneColourForSeveralAndTheRingOnlyWhenAllAgree() {
        var board = Board()
        let a = note(&board, "A", x: 0, y: 0)
        let b = note(&board, "B", x: 200, y: 0, colour: "pink")
        let box = board.add(.box, centre: CGPoint(x: 0, y: 300))
        let text = board.add(.text, centre: CGPoint(x: 0, y: 500), text: "Words")
        // A note among them: the six papers. Only shapes: "no colour" first, then all nine.
        XCTAssertEqual(board.coloursOffered(for: [a, box]), Palette.notes)
        XCTAssertEqual(board.coloursOffered(for: [box]), [""] + Palette.names)
        XCTAssertTrue(board.coloursOffered(for: [text]).isEmpty)
        XCTAssertNil(board.sharedColour(of: [a, b]))
        board.setColour("blue", of: [a, b, box, text])
        XCTAssertEqual(board.sharedColour(of: [a, b, box, text]), "blue")
        XCTAssertEqual([a, b, box].map { board.item($0)!.colour }, ["blue", "blue", "blue"])
        XCTAssertEqual(board.item(text)!.colour, "")
    }

    func testTidyMakesAGridWhereThePileLies() {
        XCTAssertEqual([1, 3, 5, 6, 7, 10, 11].map(Thinking.across), [1, 3, 5, 3, 4, 5, 4])
        var board = Board()
        // A pile of six, made out of order; reading order is A B C / D E F.
        let d = note(&board, "D", x: 20, y: 150)
        let b = note(&board, "B", x: 130, y: 12)
        let f = note(&board, "F", x: 300, y: 170)
        let a = note(&board, "A", x: 10, y: 0)
        let e = note(&board, "E", x: 140, y: 160)
        let c = note(&board, "C", x: 290, y: 30)
        board.items[board.index(of: b)!].h = 150
        let ids: Set<UUID> = [a, b, c, d, e, f]
        XCTAssertEqual(Thinking.readingOrder(board.gridable(ids)).map(\.text), ["A", "B", "C", "D", "E", "F"])
        board.tidyGrid(ids)
        func at(_ id: UUID) -> [Double] { [board.item(id)!.x, board.item(id)!.y] }
        // Top left corner stays (10, 0); 16 apart; the second row starts under the tallest of the first (150).
        XCTAssertEqual([a, b, c].map(at), [[10, 0], [176, 0], [342, 0]])
        XCTAssertEqual([d, e, f].map(at), [[10, 166], [176, 166], [342, 166]])
        // Two things are no pile.
        var two = Board()
        let x = note(&two, "X", x: 5, y: 5), y = note(&two, "Y", x: 9, y: 90)
        two.tidyGrid([x, y])
        XCTAssertEqual(two.item(y)!.x, 9)
    }

    func testByColourMakesOneColumnPerColourInTheOrderOfTheDots() {
        var board = Board()
        let blue1 = note(&board, "b1", x: 0, y: 0, colour: "blue")
        let pink = note(&board, "p", x: 200, y: 10, colour: "pink")
        let plain = note(&board, "y", x: 50, y: 200)
        let blue2 = note(&board, "b2", x: 220, y: 210, colour: "blue")
        board.tidyByColour([blue1, pink, plain, blue2])
        func at(_ id: UUID) -> [Double] { [board.item(id)!.x, board.item(id)!.y] }
        // The dots of a note: yellow, pink, blue, … Columns 16 apart, things 16 apart, the top left corner stays.
        XCTAssertEqual(at(plain), [0, 0])
        XCTAssertEqual(at(pink), [166, 0])
        XCTAssertEqual(at(blue1), [332, 0])
        XCTAssertEqual(at(blue2), [332, 126])
    }

    func testChooseAllOfThisColourFindsTheNotesWithTheSamePaper() {
        var board = Board()
        let a = note(&board, "A", x: 0, y: 0)
        let b = note(&board, "B", x: 200, y: 0, colour: "yellow")
        let c = note(&board, "C", x: 400, y: 0, colour: "pink")
        let box = board.add(.box, centre: CGPoint(x: 0, y: 300), colour: "yellow")
        XCTAssertEqual(board.notes(colouredLike: a), [a, b])
        XCTAssertEqual(board.notes(colouredLike: c), [c])
        XCTAssertTrue(board.notes(colouredLike: box).isEmpty)
    }

    // MARK: The bug — pasted paragraphs stay one text

    func testParagraphsStayOneTextAndOnlyRealListsBecomeAMap() {
        let long = String(repeating: "A long sentence from an e-mail. ", count: 4)
        let paragraphs = long + "\n\n" + long
        XCTAssertFalse(Outline.isList(paragraphs))
        XCTAssertTrue(Outline.hasSeveralLines(paragraphs))
        XCTAssertTrue(Outline.isList("Food\nTent\nMap"))
        XCTAssertTrue(Outline.isList("- Food\n- " + long + "\n- Map"))
        XCTAssertTrue(Outline.isList("1. " + long + "\n2. " + long))
        XCTAssertTrue(Outline.isList(long + "\n\tunder it"))
        XCTAssertTrue(Outline.isList("# Plan\n" + long))
        XCTAssertTrue(Outline.isList("[ ] " + long + "\n[x] " + long))

        var board = Board()
        // Two paragraphs: ONE text with its lines kept.
        let textID = board.addWords(paragraphs, at: .zero)!
        let text = board.item(textID)!
        XCTAssertEqual(text.kind, .text)
        XCTAssertEqual(text.text, paragraphs.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(board.items.count, 1)
        // Three short lines: a map. A marked list with one long line: a map. One line: a sticky note, as before.
        let short = board.addWords("Food\nTent\nMap", at: .zero)!
        let marked = board.addWords("- Food\n- " + long + "\n- Map", at: .zero)!
        let line = board.addWords(long, at: .zero)!
        XCTAssertEqual([short, marked, line].map { board.item($0)!.kind }, [.idea, .idea, .note])
        // A board from a Shortcuts action follows the same rule.
        XCTAssertEqual(Outside.board(title: "Mail", text: paragraphs).items.map(\.kind), [.text])
    }
}
