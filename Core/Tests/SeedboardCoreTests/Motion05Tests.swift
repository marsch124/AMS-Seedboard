import XCTest
@testable import SeedboardCore

/// 0.5, picks 1 and 3: the board glides, and things land, lift, leave, make room and fold softly.
final class Motion05Tests: XCTestCase {
    private func view(scale: Double = 1, offset: CGSize = CGSize(width: 120, height: -40)) -> Viewport {
        var v = Viewport()
        v.size = CGSize(width: 800, height: 600)
        v.offset = offset
        v.scale = scale
        return v
    }

    // MARK: Pick 1 — the glide

    func testHalfWayThroughAZoomGlideThePointUnderTheMiddleIsStillUnderTheMiddle() {
        let from = view()
        var to = from
        to.zoom(to: 1.25)
        let glide = Glide(from: from, to: to, seconds: Glide.zoomStep)
        let middle = CGPoint(x: 400, y: 300)
        let held = from.toBoard(middle)
        for part in [0.1, 0.25, 0.5, 0.75, 0.9] {
            var now = from
            let step = glide.view(at: part)
            now.offset = step.offset
            now.scale = step.scale
            let under = now.toBoard(middle)
            XCTAssertEqual(Double(under.x), Double(held.x), accuracy: 1e-6, "part \(part)")
            XCTAssertEqual(Double(under.y), Double(held.y), accuracy: 1e-6, "part \(part)")
            // The read-out counts along: the zoom is on its way, never past either end.
            XCTAssertGreaterThan(step.scale, 1)
            XCTAssertLessThan(step.scale, 1.25)
        }
        // The same holds for a zoom round another point (the pointer, a finger).
        let corner = CGPoint(x: 90, y: 510)
        var out = from
        out.zoom(to: 0.5, around: corner)
        let half = Glide(from: from, to: out, seconds: Glide.zoomStep).view(at: 0.5)
        var now = from
        now.offset = half.offset
        now.scale = half.scale
        XCTAssertEqual(Double(now.toBoard(corner).x), Double(from.toBoard(corner).x), accuracy: 1e-6)
        XCTAssertEqual(Double(now.toBoard(corner).y), Double(from.toBoard(corner).y), accuracy: 1e-6)
    }

    func testAGlideStartsWhereTheViewStandsIsQuickAtFirstAndEndsExactlyWhereItShall() {
        XCTAssertEqual(Glide.zoomStep, 0.22)
        XCTAssertEqual(Glide.wholeBoard, 0.30)
        XCTAssertEqual(Glide.intoSight, 0.18)
        XCTAssertEqual(Glide.ease(0), 0)
        XCTAssertEqual(Glide.ease(1), 1)
        XCTAssertEqual(Glide.ease(0.5), 0.875, accuracy: 1e-9)   // ease-out: most of the way in half the time

        // A slide without a zoom (bringing a new idea into sight).
        let from = view(scale: 0.8)
        var to = from
        to.pan(by: CGSize(width: -200, height: 60))
        let slide = Glide(from: from, to: to, seconds: Glide.intoSight)
        XCTAssertEqual(slide.view(at: 0).offset, from.offset)
        XCTAssertEqual(slide.view(at: 0).scale, 0.8)
        XCTAssertEqual(Double(slide.view(at: 0.5).offset.width), 120 - 200 * 0.875, accuracy: 1e-9)
        XCTAssertEqual(slide.view(at: 0.5).scale, 0.8)
        // The end is the end itself, not a sum that is nearly it — also after the time is over.
        XCTAssertEqual(slide.view(at: 1).offset, to.offset)
        XCTAssertEqual(slide.view(after: 0.18).offset, to.offset)
        XCTAssertEqual(slide.view(after: 5).offset, to.offset)
        XCTAssertFalse(slide.isStill)
        // A move too small to see is no glide.
        XCTAssertTrue(Glide(from: from, to: from, seconds: 0.3).isStill)
        var hair = from
        hair.pan(by: CGSize(width: 0.2, height: 0))
        XCTAssertTrue(Glide(from: from, to: hair, seconds: 0.3).isStill)
    }

    // MARK: Pick 3 — things land, lift, leave, make room and fold

    func testANewThingGrowsFrom92PerCentAndFadesInAndARemovedOneShrinksTo94AndFadesOut() {
        XCTAssertEqual(Motion.lands, 0.16)
        XCTAssertEqual(Motion.leaves, 0.12)
        XCTAssertEqual(Motion.landing(at: 0), Motion.Look(size: 0.92, strength: 0))
        XCTAssertEqual(Motion.landing(at: 1), Motion.Look(size: 1, strength: 1))
        XCTAssertEqual(Motion.landing(at: 0.5).size, 0.92 + 0.08 * 0.875, accuracy: 1e-9)
        XCTAssertEqual(Motion.leaving(at: 0), Motion.Look(size: 1, strength: 1))
        XCTAssertEqual(Motion.leaving(at: 1).size, 0.94, accuracy: 1e-9)
        XCTAssertEqual(Motion.leaving(at: 1).strength, 0, accuracy: 1e-9)
    }

    func testADraggedThingsShadowDeepensFrom6PerCentTo16AndGoesBack() {
        XCTAssertEqual(Motion.lifts, 0.10)
        XCTAssertEqual(Motion.nightLift, 0.15)
        XCTAssertEqual(Motion.shadow(rest: Motion.rest, lift: 0), Motion.Shadow(dark: 0.06, radius: 2, down: 1))
        XCTAssertEqual(Motion.shadow(rest: Motion.rest, lift: 1), Motion.Shadow(dark: 0.16, radius: 8, down: 4))
        let half = Motion.shadow(rest: Motion.rest, lift: 0.5)
        XCTAssertEqual(half.dark, 0.11, accuracy: 1e-9)
        XCTAssertEqual(half.radius, 5, accuracy: 1e-9)
        XCTAssertEqual(half.down, 2.5, accuracy: 1e-9)
        // A thing without a shadow of its own (a picture, the middle of a mind map) gets one only in the hand.
        XCTAssertEqual(Motion.shadow(rest: nil, lift: 0).dark, 0)
        XCTAssertEqual(Motion.shadow(rest: nil, lift: 1), Motion.Shadow(dark: 0.16, radius: 8, down: 4))
        // A sticky note's own shadow is never made lighter by lifting it.
        let note = Motion.Shadow(dark: 0.35, radius: 3, down: 1.5)
        XCTAssertEqual(Motion.shadow(rest: note, lift: 1), Motion.Shadow(dark: 0.35, radius: 8, down: 4))
    }

    func testAChangeSetsInMotionWhatLandsWhatLeavesAndWhatMakesRoom() {
        var old = Board()
        let box = old.add(.box, centre: CGPoint(x: 0, y: 0))
        let note = old.add(.note, centre: CGPoint(x: 400, y: 0))
        let stays = old.add(.oval, centre: CGPoint(x: 0, y: 400))
        let typed = old.add(.box, centre: CGPoint(x: 400, y: 400))
        var new = old
        new.move([box], by: CGSize(width: 120, height: 30))
        new.move([typed], by: CGSize(width: 50, height: 0))
        new.remove([note])
        let fresh = new.add(.diamond, centre: CGPoint(x: 800, y: 0))

        let plan = Motion.plan(from: old, to: new, still: [typed])
        XCTAssertEqual(plan.lands, [fresh])
        XCTAssertEqual(plan.leaves.map(\.id), [note])
        XCTAssertEqual(plan.leaves.first?.frame, old.item(note)?.frame)   // drawn as it was
        // Only what really stands somewhere else glides, from where it stood; the thing being typed in jumps.
        XCTAssertEqual(plan.moves, [box: old.item(box)!.frame])
        XCTAssertNil(plan.moves[stays])
        XCTAssertTrue(plan.closes.isEmpty && plan.opens.isEmpty)
        // Nothing changed: nothing moves.
        XCTAssertTrue(Motion.plan(from: new, to: new).isEmpty)

        // On the way: ease-out between the two places, and exactly the new place at the end.
        let from = old.item(box)!.frame, to = new.item(box)!.frame
        XCTAssertEqual(Motion.makesRoom, 0.20)
        XCTAssertEqual(Motion.between(from, to, at: 0), from)
        XCTAssertEqual(Double(Motion.between(from, to, at: 0.5).minX), Double(from.minX) + 120 * 0.875, accuracy: 1e-9)
        XCTAssertEqual(Motion.between(from, to, at: 1), to)
    }

    func testFoldingSlidesTheIdeasBelowIntoTheFoldedIdeaAndUnfoldingBringsThemOut() {
        var open = Board()
        let centre = open.add(.idea, centre: .zero, text: "Trip")
        let branch = open.addChild(of: centre, text: "Pack")!
        let leaf = open.addChild(of: branch, text: "Shoes")!
        let other = open.addChild(of: centre, text: "Book")!
        open.layoutMaps()
        var folded = open
        folded.items[folded.index(of: branch)!].folded = true
        folded.layoutMaps()

        let closing = Motion.plan(from: open, to: folded)
        XCTAssertEqual(Motion.folds, 0.18)
        XCTAssertEqual(closing.closes, [leaf: Motion.Into(idea: branch, stood: open.item(leaf)!.frame)])
        XCTAssertTrue(closing.lands.isEmpty && closing.leaves.isEmpty && closing.opens.isEmpty)
        XCTAssertNil(closing.closes[other])

        let opening = Motion.plan(from: folded, to: open)
        XCTAssertEqual(opening.opens, [leaf: branch])
        XCTAssertTrue(opening.closes.isEmpty && opening.lands.isEmpty && opening.leaves.isEmpty)

        // Folding the middle hides everything below it: all of it slides into the middle, also what was two levels down.
        var all = open
        all.items[all.index(of: centre)!].folded = true
        all.layoutMaps()
        XCTAssertEqual(Motion.plan(from: open, to: all).closes.mapValues(\.idea), [branch: centre, leaf: centre, other: centre])
        // What was hidden before and still is stays out of it; a new idea under a folded one does not land.
        var more = folded
        let unseen = Item(kind: .idea, text: "Socks", parent: branch, order: 9)
        more.items.append(unseen)
        more.layoutMaps()
        let quiet = Motion.plan(from: folded, to: more)
        XCTAssertFalse(quiet.lands.contains(unseen.id))
        XCTAssertTrue(quiet.closes.isEmpty && quiet.opens.isEmpty)
    }

    func testBoardsOver150ThingsAndBoardsThatPlaceThemselvesStandStill() {
        var board = Board()
        for n in 0..<150 { board.add(.box, centre: CGPoint(x: Double(n % 15) * 200, y: Double(n / 15) * 120)) }
        XCTAssertEqual(Motion.most, 150)
        XCTAssertTrue(Motion.runs(on: board))
        var moved = board
        moved.move([board.items[0].id], by: CGSize(width: 40, height: 0))
        XCTAssertEqual(Motion.plan(from: board, to: moved).moves.count, 1)

        var big = moved
        let extra = big.add(.box, centre: CGPoint(x: -400, y: -400))
        XCTAssertFalse(Motion.runs(on: big))
        // The 151st thing does not land, and taking it away again does not make it leave.
        XCTAssertTrue(Motion.plan(from: moved, to: big).isEmpty)
        var back = big
        back.remove([extra])
        XCTAssertTrue(Motion.plan(from: big, to: back).isEmpty)

        // A timeline and a "Who does what" board place and draw their things themselves.
        XCTAssertFalse(Motion.runs(on: Board.timeline()))
        var line = Board.timeline()
        let before = line
        line.title = "Other"
        XCTAssertTrue(Motion.plan(from: before, to: line).isEmpty)
    }
}
