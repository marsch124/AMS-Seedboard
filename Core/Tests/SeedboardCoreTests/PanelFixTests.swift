import XCTest
@testable import SeedboardCore

/// One small test per rule that came out of the expert panel before 0.2 (B2, B4–B8).
final class PanelFixTests: XCTestCase {
    private func overlap(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    // MARK: B2 — the view stays where the owner slid it

    func testAFingerSlideCountsAsMovedSoTheViewIsNotFittedAgain() {
        let all = CGRect(x: 0, y: 0, width: 400, height: 300)
        var view = Viewport()
        view.resized(to: CGSize(width: 800, height: 600), showing: all)
        let fitted = view.offset
        // Not moved yet: a new room (the keyboard coming up) shows the whole board again.
        view.resized(to: CGSize(width: 800, height: 400), showing: all)
        XCTAssertNotEqual(view.offset, fitted)
        XCTAssertFalse(view.movedByOwner)

        let start = view.offset
        view.slide(from: start, by: CGSize(width: -120, height: 40))
        XCTAssertTrue(view.movedByOwner)
        XCTAssertEqual(view.offset, CGSize(width: start.width - 120, height: start.height + 40))
        let slid = view.offset
        view.resized(to: CGSize(width: 800, height: 600), showing: all)
        XCTAssertEqual(view.offset, slid)
        XCTAssertEqual(view.size, CGSize(width: 800, height: 600))
    }

    // MARK: B4 — a main branch remembers its side

    func testANewMainBranchGoesToTheEmptierSideAndNobodyJumps() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: true)
        var all: [UUID] = []
        var before: [UUID: Side] = [:]
        for n in 0..<7 {
            let right = all.filter { board.side(of: $0) == .right }.count
            let new = board.addChild(of: c, text: "k\(n)")!
            // Nobody who was there changed sides.
            for id in all { XCTAssertEqual(board.side(of: id), before[id]) }
            // The new one went to the emptier side (right when even).
            XCTAssertEqual(board.side(of: new), right > all.count - right ? .left : .right)
            all.append(new)
            for id in all { before[id] = board.side(of: id) }
        }
        // Taking one away moves nobody either.
        board.remove([all[0]])
        board.layoutMaps()
        for id in all.dropFirst() { XCTAssertEqual(board.side(of: id), before[id]) }
        // The next idea beside a branch stays on that branch's side while the sides are even …
        var even = Board()
        let e = even.addCentre(at: .zero, text: "C", bothSides: true)
        let a = even.addChild(of: e)!, b = even.addChild(of: e)!
        XCTAssertEqual([even.side(of: a), even.side(of: b)], [.right, .left])
        let besideB = even.addSister(of: b)!
        XCTAssertEqual(even.side(of: besideB), .left)
        // … and a one-sided map keeps everything on the right.
        var one = Board()
        let o = one.addCentre(at: .zero, text: "C", bothSides: false)
        let k = (0..<4).map { _ in one.addChild(of: o)! }
        XCTAssertEqual(Set(k.map { one.side(of: $0) }), [.right])
    }

    func testTheSideIsKeptInTheFileAndAnOlderFileStillOpens() throws {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: true)
        let k = (0..<3).map { board.addChild(of: c, text: "k\($0)")! }
        board.layoutMaps()
        let data = try JSONEncoder().encode(board)
        let back = try JSONDecoder().decode(Board.self, from: data)
        XCTAssertEqual(back.items.map(\.side), board.items.map(\.side))
        XCTAssertEqual(k.map { back.side(of: $0) }, [.right, .left, .right])

        // A file from before sides were kept: no "side" anywhere. It opens, and is split as it always was.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var items = try XCTUnwrap(json["items"] as? [[String: Any]])
        for i in items.indices { items[i]["side"] = nil }
        json["items"] = items
        var old = try JSONDecoder().decode(Board.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.items.count, 4)
        XCTAssertTrue(old.items.allSatisfy { $0.side == nil })
        old.layoutMaps()
        XCTAssertEqual(k.map { old.side(of: $0) }, [.right, .right, .left])
        XCTAssertEqual(k.map { old.item($0)!.side }, [.right, .right, .left])
    }

    // MARK: B5 — a middle idea can be hung under an idea of another map, and taken off again

    func testAMapCanBeHungUnderAnIdeaOfAnotherMapAndTakenOffAgain() {
        var board = Board()
        let a = board.addCentre(at: .zero, text: "A", bothSides: true)
        let a1 = board.addChild(of: a, text: "a1")!
        let b = board.addCentre(at: CGPoint(x: 600, y: 0), text: "B", bothSides: true)
        let b1 = board.addChild(of: b, text: "b1")!, b2 = board.addChild(of: b, text: "b2")!
        let b11 = board.addChild(of: b1, text: "b11")!

        XCTAssertTrue(board.reparent(b, under: a1))
        board.layoutMaps()
        XCTAssertEqual(board.mapCentres.map(\.id), [a])
        XCTAssertEqual(board.centre(of: b11), a)
        // Everything that came along follows the colour of the branch it now hangs in.
        for id in [b, b1, b2, b11] {
            XCTAssertEqual(board.item(id)!.colour, "")
            XCTAssertNil(board.item(id)!.side)
            XCTAssertEqual(board.branchColour(of: id), board.item(a1)!.colour)
        }
        XCTAssertFalse(board.item(b)!.bothSides)
        // It cannot be hung under something of its own.
        XCTAssertFalse(board.reparent(a, under: b11))

        // Hung straight under a centre it is a main branch with its own colour and a side.
        var two = Board()
        let x = two.addCentre(at: .zero, text: "X", bothSides: true)
        let x1 = two.addChild(of: x, text: "x1")!
        let y = two.addCentre(at: CGPoint(x: 500, y: 0), text: "Y")
        XCTAssertTrue(two.reparent(y, under: x))
        XCTAssertFalse(two.item(y)!.colour.isEmpty)
        XCTAssertNotEqual(two.item(y)!.colour, two.item(x1)!.colour)
        XCTAssertEqual(two.side(of: y), .left)

        // Taken off again, the ideas right under it become main branches with colours of their own.
        board.detach(b, at: CGPoint(x: 900, y: 0))
        XCTAssertTrue(board.isCentre(b))
        XCTAssertEqual(Set([b1, b2].map { board.item($0)!.colour }).count, 2)
        XCTAssertFalse(board.item(b1)!.colour.isEmpty)

        // Finding the idea under a dragged map leaves the dragged ideas out.
        board.layoutMaps()
        let on = board.item(a1)!.centre
        XCTAssertEqual(board.idea(at: on, notIn: [b, b1, b2, b11]), a1)
        XCTAssertNil(board.idea(at: on, notIn: [a1]))
    }

    // MARK: B6 — Shift+Tab moves an idea out one level; only a new line break ends an idea

    func testMoveOutMakesAnIdeaTheNextSisterOfItsParent() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: true)
        let a = board.addChild(of: c, text: "a")!, b = board.addChild(of: c, text: "b")!
        let a1 = board.addChild(of: a, text: "a1")!, a2 = board.addChild(of: a, text: "a2")!
        let a11 = board.addChild(of: a1, text: "a11")!

        XCTAssertTrue(board.moveOut(a11))
        XCTAssertEqual(board.children(of: a).map(\.id), [a1, a11, a2])
        XCTAssertTrue(board.children(of: a1).isEmpty)

        // Out of a main branch: a main branch of its own, right after it, on the same side, with a colour.
        XCTAssertTrue(board.moveOut(a1))
        XCTAssertEqual(board.children(of: c).map(\.id), [a, a1, b])
        XCTAssertEqual(board.side(of: a1), board.side(of: a))
        XCTAssertFalse(board.item(a1)!.colour.isEmpty)

        // A main branch and a centre have no level further out.
        XCTAssertFalse(board.moveOut(b))
        XCTAssertFalse(board.moveOut(c))
        XCTAssertEqual(board.children(of: c).map(\.id), [a, a1, b])
    }

    func testOnlyOneNewLineBreakEndsAnIdea() {
        // The screen keyboard's Return: one new break, wherever the cursor stood.
        XCTAssertEqual(Typing.withoutNewBreak(old: "Buy wood", new: "Buy wood\n"), "Buy wood")
        XCTAssertEqual(Typing.withoutNewBreak(old: "Buy wood", new: "Buy\n wood"), "Buy wood")
        // A break made earlier with Shift and Return stays.
        XCTAssertEqual(Typing.withoutNewBreak(old: "Buy\nwood", new: "Buy\nwood\n"), "Buy\nwood")
        XCTAssertEqual(Typing.withoutNewBreak(old: "Buy\nwood", new: "Buy\n\nwood"), "Buy\nwood")
        // Plain typing in an idea that has two lines is not a Return.
        XCTAssertNil(Typing.withoutNewBreak(old: "Buy\nwood", new: "Buy\nwoods"))
        XCTAssertNil(Typing.withoutNewBreak(old: "Buy\nwood", new: "Buywood"))
        // Several lines pasted in stay as they are.
        XCTAssertNil(Typing.withoutNewBreak(old: "", new: "a\nb\nc"))
        // An idea with two lines is one line in a copied list.
        var board = Board()
        let c = board.addCentre(at: .zero, text: "Two\nlines")
        board.addChild(of: c, text: "under")
        XCTAssertEqual(board.outlineText, "- Two lines\n  - under")
    }

    // MARK: B7 — a shape's size is the owner's; words make it wider first, then taller

    func testChangingAShapesKindKeepsTheSizeTheOwnerSet() {
        var board = Board()
        let plain = board.add(.box, centre: CGPoint(x: 100, y: 100), text: "Go?", colour: "blue")
        let sized = board.add(.box, centre: CGPoint(x: 400, y: 100))
        board.resize(sized, to: CGRect(x: 300, y: 50, width: 220, height: 90))

        board.setKind(plain, to: .diamond)
        board.setKind(sized, to: .diamond)
        // Never sized by the owner: the new kind's own size, round the same middle.
        XCTAssertEqual(board.item(plain)!.kind, .diamond)
        XCTAssertEqual(board.item(plain)!.frame.size, ItemKind.diamond.defaultSize)
        XCTAssertEqual(board.item(plain)!.centre, CGPoint(x: 100, y: 100))
        XCTAssertEqual(board.item(plain)!.text, "Go?")
        XCTAssertEqual(board.item(plain)!.colour, "blue")
        // Sized by the owner: exactly as it was.
        XCTAssertEqual(board.item(sized)!.kind, .diamond)
        XCTAssertEqual(board.item(sized)!.frame, CGRect(x: 300, y: 50, width: 220, height: 90))
        // Only flow shapes change kind.
        let note = board.add(.note, centre: .zero)
        board.setKind(note, to: .box)
        XCTAssertEqual(board.item(note)!.kind, .note)
    }

    func testAShapeGrowsWiderFirstThenTaller() {
        // Made-up words: every letter 8 wide, every line 18 high, broken wherever the width runs out.
        func words(_ letters: Int) -> (Double) -> Double {
            { width in Double(max(1, Int((Double(letters) * 8 / width).rounded(.up)))) * 18 }
        }
        let own = ItemKind.diamond.defaultSize
        // Short words: nothing changes.
        var size = ShapeFit.size(.diamond, w: 160, h: 104, widen: true, wordsHeight: words(8))
        XCTAssertEqual(size.w, 160)
        XCTAssertEqual(size.h, 104)
        // Longer words: wider, just enough, and no taller.
        size = ShapeFit.size(.diamond, w: 160, h: 104, widen: true, wordsHeight: words(40))
        XCTAssertGreaterThan(size.w, Double(own.width))
        XCTAssertLessThan(size.w, ShapeFit.widest(.diamond))
        XCTAssertEqual(size.h, 104)
        XCTAssertGreaterThan(ShapeFit.height(.diamond, words: words(40)(ShapeFit.wordsWidth(.diamond, w: size.w - 6))), 104)
        // Very long words: as wide as a shape grows by itself, then taller.
        size = ShapeFit.size(.diamond, w: 160, h: 104, widen: true, wordsHeight: words(200))
        XCTAssertEqual(size.w, ShapeFit.widest(.diamond))
        XCTAssertGreaterThan(size.h, 104)
        // Not typing (the owner pulled it narrow): the width is the owner's, only the height grows.
        size = ShapeFit.size(.box, w: 100, h: 56, widen: false, wordsHeight: words(40))
        XCTAssertEqual(size.w, 100)
        XCTAssertGreaterThan(size.h, 56)
        // It never shrinks, and never narrows what the owner made wide.
        size = ShapeFit.size(.box, w: 500, h: 200, widen: true, wordsHeight: words(3))
        XCTAssertEqual(size.w, 500)
        XCTAssertEqual(size.h, 200)
    }

    // MARK: B8 — a growing map pushes aside what it would cover

    func testAGrowingMapPushesAsideJustWhatItWouldCover() {
        var board = Board()
        let c = board.addCentre(at: .zero, text: "C", bothSides: false)
        let k = board.addChild(of: c, text: "k")!
        board.layoutMaps()
        let branch = board.item(k)!.frame
        // A note where the next ideas will land, a note it leans on, a note already on the map on
        // purpose, a note far away, and a second map.
        let inTheWay = board.add(.note, centre: CGPoint(x: branch.maxX + MindMap.gapAcross + 80, y: branch.midY))
        let behind = board.add(.note, centre: CGPoint(x: branch.maxX + MindMap.gapAcross + 80 + 156, y: branch.midY))
        let onPurpose = board.add(.note, centre: board.item(c)!.centre)
        let far = board.add(.box, centre: CGPoint(x: 0, y: 900))
        let other = board.addCentre(at: CGPoint(x: branch.maxX + MindMap.gapAcross + 60, y: branch.midY + 150), text: "Other", bothSides: false)
        let otherKid = board.addChild(of: other, text: "ok")!
        board.layoutMaps()
        let before = board

        for n in 0..<8 { board.addChild(of: k, text: "idea number \(n)") }
        board.layoutMaps()
        let ideas = board.descendants(of: c).map { board.item($0)!.frame } + [board.item(c)!.frame]
        XCTAssertTrue(ideas.contains { overlap($0, board.item(inTheWay)!.frame) }, "the test needs the map to grow over the note")

        board.makeRoom(since: before)
        // Nothing it newly covered is under it any more, and the gap is kept.
        for id in [inTheWay, behind] {
            let frame = board.item(id)!.frame.insetBy(dx: -7.9, dy: -7.9)
            XCTAssertFalse(ideas.contains { overlap($0, frame) })
        }
        // Sideways, the shortest way, and no further than needed: it touches the gap of an idea.
        let moved = board.item(inTheWay)!, was = before.item(inTheWay)!
        XCTAssertEqual(moved.y, was.y)
        XCTAssertGreaterThan(moved.x, was.x)
        XCTAssertTrue(ideas.contains { overlap($0, moved.frame.insetBy(dx: -8.5, dy: -8.5)) })
        // The note behind it was pushed along and does not lie under it.
        XCTAssertFalse(overlap(board.item(behind)!.frame, moved.frame))
        XCTAssertGreaterThan(board.item(behind)!.x, before.item(behind)!.x)
        // What the owner laid on the map, and what is far away, stay.
        XCTAssertEqual(board.item(onPurpose)!.frame, before.item(onPurpose)!.frame)
        XCTAssertEqual(board.item(far)!.frame, before.item(far)!.frame)
        // The other map went as a whole and stands clear.
        let shift = CGSize(width: board.item(other)!.x - before.item(other)!.x, height: board.item(other)!.y - before.item(other)!.y)
        XCTAssertTrue(shift.width != 0 || shift.height != 0)
        XCTAssertEqual(board.item(otherKid)!.x - before.item(otherKid)!.x, Double(shift.width), accuracy: 0.001)
        XCTAssertEqual(board.item(otherKid)!.y - before.item(otherKid)!.y, Double(shift.height), accuracy: 0.001)
        for id in [other, otherKid] {
            XCTAssertFalse(ideas.contains { overlap($0, board.item(id)!.frame) })
        }

        // A map that was dragged (its centre moved) pushes nothing: the owner put it there.
        var dragged = before
        dragged.move(dragged.carried(by: [c]), by: CGSize(width: 150, height: 0))
        let asDropped = dragged
        dragged.makeRoom(since: before)
        XCTAssertEqual(dragged, asDropped)
    }

    // 0.3 — Shift and Return while typing: the new line goes where the cursor stands, and the cursor follows it.
    func testShiftReturnPutsTheNewLineAtTheCursor() {
        XCTAssertEqual(Typing.lineBreak(in: "OneTwo", from: 3, to: 3).words, "One\nTwo")
        XCTAssertEqual(Typing.lineBreak(in: "OneTwo", from: 3, to: 3).cursor, 4)
        // What is chosen is replaced by the break.
        XCTAssertEqual(Typing.lineBreak(in: "One and Two", from: 3, to: 8).words, "One\nTwo")
        // Cursor unknown: the line goes at the end.
        XCTAssertEqual(Typing.lineBreak(in: "One", from: -1, to: -1).words, "One\n")
        XCTAssertEqual(Typing.lineBreak(in: "One", from: -1, to: -1).cursor, 4)
        // Letters that take two units (an emoji) keep whole.
        XCTAssertEqual(Typing.lineBreak(in: "A😀B", from: 3, to: 3).words, "A😀\nB")
        // The idea rule still sees it as one new break, which the session lets through for Shift and Return.
        XCTAssertEqual(Typing.withoutNewBreak(old: "OneTwo", new: "One\nTwo"), "OneTwo")
    }
}
