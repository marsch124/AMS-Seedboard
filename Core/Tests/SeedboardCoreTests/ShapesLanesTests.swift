import XCTest
@testable import SeedboardCore

/// 0.2 picks 15 and 16: the four new flow shapes, and lanes in frames.
final class ShapesLanesTests: XCTestCase {
    private let new: [ItemKind] = [.person, .document, .slanted, .store]

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }

    // MARK: Pick 15 — more shapes

    func testTheNewKindsHaveStableStoredNamesAndSurviveTheFile() throws {
        XCTAssertEqual(new.map(\.rawValue), ["person", "document", "slanted", "store"])
        XCTAssertEqual(ItemKind.flowShapes.count, 8)
        XCTAssertTrue(ItemKind.flowShapes.allSatisfy(\.isShape))
        XCTAssertFalse(ItemKind.note.isShape)

        var board = Board()
        for kind in new { board.add(kind, centre: .zero, text: kind.word) }
        let file = try JSONEncoder().encode(board)
        let back = try JSONDecoder().decode(Board.self, from: file)
        XCTAssertEqual(back.items.map(\.kind), new)
        XCTAssertEqual(back.items, board.items)
    }

    func testWordsFitInsideTheUsablePartOfEveryOutline() {
        for kind in ItemKind.flowShapes {
            for words in [19.0, 37.0, 73.0] {
                let w = Double(kind.defaultSize.width)
                let f = rect(40, 60, w, ShapeFit.height(kind, words: words))
                let box = ShapeOutline.textBox(kind, f)
                XCTAssertGreaterThanOrEqual(Double(box.height), words - 0.5, "\(kind) is too low for words \(words) high")
                XCTAssertEqual(Double(box.width), ShapeFit.wordsWidth(kind, w: w), accuracy: 0.01, "\(kind)")
                XCTAssertTrue(f.contains(box), "\(kind)")
                guard new.contains(kind) else { continue }
                for corner in [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                               CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.maxY)] {
                    XCTAssertTrue(ShapeOutline.holds(kind, f, corner), "\(kind): the words would cross the outline at \(corner)")
                }
            }
        }
        // A Person's words stand under the figure.
        let person = rect(0, 0, 110, 96)
        XCTAssertGreaterThanOrEqual(ShapeOutline.textBox(.person, person).minY, ShapeOutline.figure(in: person).base)
    }

    func testAnArrowMeetsTheRealEdgeNotTheBoxRoundIt() {
        // Slanted box 160 × 56: the slant is 18, so half way up each side lies 9 inside the box round it.
        let slanted = rect(0, 0, 160, 56)
        XCTAssertEqual(ShapeOutline.inset(.slanted, slanted, side: .right), 9)
        XCTAssertEqual(ShapeOutline.inset(.slanted, slanted, side: .up), 0)
        XCTAssertTrue(ShapeOutline.holds(.slanted, slanted, CGPoint(x: 9.5, y: 28)))
        XCTAssertFalse(ShapeOutline.holds(.slanted, slanted, CGPoint(x: 8, y: 28)))

        // Document 150 × 68: the wave swings 9; under the middle the edge lies 9 above the bottom.
        let document = rect(0, 0, 150, 68)
        XCTAssertEqual(ShapeOutline.inset(.document, document, side: .down), 9)
        XCTAssertEqual(ShapeOutline.inset(.document, document, side: .left), 0)
        XCTAssertEqual(ShapeOutline.waveLine(document, x: 75), 59, accuracy: 0.01)

        // Person: met at the shoulders, well inside the box round the figure and its words; top and bottom stay.
        let person = rect(0, 0, 110, 96)
        let side = ShapeOutline.inset(.person, person, side: .left)
        XCTAssertGreaterThan(side, 15)
        XCTAssertEqual(ShapeOutline.inset(.person, person, side: .up), 0)
        XCTAssertEqual(ShapeOutline.inset(.person, person, side: .down), 0)
        XCTAssertTrue(ShapeOutline.holds(.person, person, CGPoint(x: side + 0.5, y: 48)))
        XCTAssertFalse(ShapeOutline.holds(.person, person, CGPoint(x: side - 1.5, y: 48)))

        // A Store's sides are straight, a Box has no other edge: the box round them is the edge.
        for way in Direction.allCases {
            XCTAssertEqual(ShapeOutline.inset(.store, rect(0, 0, 130, 80), side: way), 0)
            XCTAssertEqual(ShapeOutline.inset(.box, rect(0, 0, 150, 56), side: way), 0)
        }

        // An arrow from a Slanted box to a Document in line with it: its start is pulled onto the slanted
        // side, the line stays one straight piece, and the words sit in the middle of the shorter line.
        let from = Item(kind: .slanted, x: 0, y: 0), to = Item(kind: .document, x: 300, y: -6)
        let plain = Route.path(from: from.frame, to: to.frame, style: .elbow)
        let met = plain.meeting(from, to)
        XCTAssertEqual(plain.points, [CGPoint(x: 160, y: 28), CGPoint(x: 300, y: 28)])
        XCTAssertEqual(met.points, [CGPoint(x: 151, y: 28), CGPoint(x: 300, y: 28)])
        XCTAssertEqual(met.label, CGPoint(x: 225.5, y: 28))
        // Down onto a Document from above nothing changes; up into its wave from below the end moves 9.
        let below = Item(kind: .box, x: 300, y: 200)
        XCTAssertEqual(Route.path(from: below.frame, to: to.frame, style: .elbow).meeting(below, to).points.last, CGPoint(x: 375, y: 53))
        XCTAssertEqual(Route.path(from: to.frame, to: below.frame, style: .elbow).meeting(to, below).points.first, CGPoint(x: 375, y: 53))
        // Between two plain boxes the line is left as it is.
        let box = Item(kind: .box, x: 0, y: 200)
        XCTAssertEqual(Route.path(from: box.frame, to: below.frame, style: .elbow).meeting(box, below), Route.path(from: box.frame, to: below.frame, style: .elbow))

        // The to-do tick: the top right corner; for a Person beside the head, not out in the empty corner.
        XCTAssertEqual(ShapeOutline.tickSpot(.box, rect(0, 0, 150, 56)), CGPoint(x: 147, y: 3))
        XCTAssertLessThan(ShapeOutline.tickSpot(.person, person).x, 95)
    }

    func testANewKindBehavesLikeABox() {
        var board = Board()
        let box = board.add(.box, centre: CGPoint(x: 0, y: 0), text: "Customer")
        board.setKind(box, to: .person)
        // Still at its kind's own size, it takes the new kind's own size round the same middle.
        XCTAssertEqual(board.item(box)?.frame, rect(-55, -48, 110, 96))
        let next = board.addNext(from: box, direction: .right)!
        XCTAssertEqual(board.item(next)?.kind, .person)
        XCTAssertEqual(board.links.count, 1)
        let copy = board.duplicate([box]).first!
        XCTAssertEqual(board.item(copy)?.kind, .person)
        XCTAssertEqual(board.countLine, "3 shapes")

        // Typing long words: a Person grows wider first (up to 220), then taller.
        let size = ShapeFit.size(.person, w: 110, h: 96, widen: true) { width in width < 200 ? 80 : 19 }
        XCTAssertEqual(size.h, 96)
        XCTAssertGreaterThan(size.w, 110)
        XCTAssertLessThanOrEqual(size.w, 220)
    }

    func testTheBoxTileRemembersTheLastShapeButNeverADiamond() {
        XCTAssertEqual(ItemKind.boxTile(stored: nil), .box)
        XCTAssertEqual(ItemKind.boxTile(stored: "store"), .store)
        XCTAssertEqual(ItemKind.boxTile(stored: "oval"), .oval)
        XCTAssertEqual(ItemKind.boxTile(stored: "diamond"), .box)   // Diamond has its own tile
        XCTAssertEqual(ItemKind.boxTile(stored: "note"), .box)
        XCTAssertEqual(ItemKind.boxTile(stored: "something newer"), .box)
    }

    func testTheNewKindsReadLikeBoxesInParagon() {
        var board = Board(title: "Order")
        let a = board.add(.person, centre: CGPoint(x: 0, y: 0), text: "Customer")
        let b = board.add(.document, centre: CGPoint(x: 200, y: 0), text: "Order form")
        let c = board.add(.store, centre: CGPoint(x: 400, y: 0), text: "Orders")
        board.add(.slanted, centre: CGPoint(x: 0, y: 300), text: "Parcel")
        board.link(from: a, to: b)
        board.link(from: b, to: c, text: "saved")
        let now = Date(timeIntervalSince1970: 0)
        let note = ParagonExport.note(board: board, title: "Order", picture: nil, now: now)
        XCTAssertTrue(note.contains("## Flow\n\n- Customer → Order form\n- Order form → Orders (saved)\n"))
        let project = ParagonExport.project(board: board, title: "Order", picture: nil, now: now)
        XCTAssertTrue(project.contains("### Steps\n- [ ] Customer\n- [ ] Order form\n- [ ] Orders\n- [ ] Parcel\n"))
        XCTAssertTrue(board.outlineText.contains("Shapes:\n- Parcel"))
    }

    // MARK: Pick 16 — lanes in frames

    func testLanesShareTheFrameEvenlyAndStretchWithIt() {
        let lanes = Lanes(way: .rows, count: 3)
        // Frame 440 × 300: its name band takes 30, the three rows share the other 270.
        XCTAssertEqual(lanes.rects(in: rect(0, 0, 440, 300)), [rect(0, 30, 440, 90), rect(0, 120, 440, 90), rect(0, 210, 440, 90)])
        XCTAssertEqual(lanes.headers(in: rect(0, 0, 440, 300)).first, rect(0, 30, 24, 90))
        // Twice as high: every row grows with it.
        XCTAssertEqual(lanes.rects(in: rect(0, 0, 440, 570)).map { Double($0.height).rounded() }, [180, 180, 180])

        let columns = Lanes(way: .columns, count: 2)
        XCTAssertEqual(columns.rects(in: rect(100, 0, 400, 300)), [rect(100, 30, 200, 270), rect(300, 30, 200, 270)])
        XCTAssertEqual(columns.headers(in: rect(100, 0, 400, 300)).last, rect(300, 30, 200, 24))

        XCTAssertEqual(Lanes(way: .rows, count: 1).count, 2)   // 2 to 5
        XCTAssertEqual(Lanes(way: .rows, count: 9).count, 5)
        XCTAssertEqual(lanes.name(1), "Lane 2")
    }

    func testWhichLaneHoldsAPoint() {
        let f = rect(0, 0, 440, 300)
        let rows = Lanes(way: .rows, count: 3)
        XCTAssertEqual(rows.index(at: CGPoint(x: 200, y: 60), in: f), 0)
        XCTAssertEqual(rows.index(at: CGPoint(x: 200, y: 120), in: f), 1)   // on the line: the lane below
        XCTAssertEqual(rows.index(at: CGPoint(x: 200, y: 299), in: f), 2)
        XCTAssertEqual(rows.index(at: CGPoint(x: 200, y: 10), in: f), 0)    // in the frame's name band: the first row
        XCTAssertNil(rows.index(at: CGPoint(x: 500, y: 60), in: f))
        let columns = Lanes(way: .columns, count: 4)
        XCTAssertEqual(columns.index(at: CGPoint(x: 115, y: 10), in: f), 1)
        XCTAssertEqual(columns.index(at: CGPoint(x: 439, y: 200), in: f), 3)
    }

    func testDraggingTheLineBetweenTwoLanesKeepsBothAtLeast60() {
        let f = rect(0, 0, 440, 300)   // rows 30…120…210…300
        var lanes = Lanes(way: .rows, count: 3)
        lanes.moveLine(0, to: 150, in: f)
        XCTAssertEqual(lanes.rects(in: f).map { Double($0.height).rounded() }, [120, 60, 90])
        XCTAssertEqual(lanes.rects(in: f)[0].maxY, 150, accuracy: 0.001)
        // Further down would squeeze the middle lane under 60: the line stops at 150.
        lanes.moveLine(0, to: 190, in: f)
        XCTAssertEqual(lanes.rects(in: f)[0].maxY, 150, accuracy: 0.001)
        // Up: the first lane keeps 60 too.
        lanes.moveLine(0, to: 0, in: f)
        XCTAssertEqual(lanes.rects(in: f)[0].height, 60, accuracy: 0.001)
        // The lines are parts of the room, so the lanes stretch with the frame: 60 of 270 is now 120 of 540.
        XCTAssertEqual(lanes.rects(in: rect(0, 0, 440, 570))[0].height, 120, accuracy: 0.001)

        // A frame is never sized so small that a lane falls under 60.
        var board = Board()
        let frame = board.add(.frame, centre: CGPoint(x: 220, y: 150))
        board.setLanes(frame, way: .rows, count: 5)
        XCTAssertEqual(board.item(frame)?.h, 330)   // 30 + 5 × 60: the frame grew to hold five rows
        board.resize(frame, to: rect(0, 0, 50, 50))
        XCTAssertEqual(board.item(frame)?.frame.size, CGSize(width: 120, height: 330))
        board.setLanes(frame, way: nil)
        board.resize(frame, to: rect(0, 0, 50, 50))
        XCTAssertEqual(board.item(frame)?.frame.size, CGSize(width: 120, height: 80))
    }

    func testAThingBelongsWhereItsMiddleIs() {
        var board = Board()
        let frame = board.add(.frame, centre: CGPoint(x: 220, y: 150), text: "F")   // 0…440, 0…300
        board.setLanes(frame, way: .rows, count: 3)                                   // rows 30…120…210…300
        let small = board.add(.frame, centre: CGPoint(x: 100, y: 255))
        board.resize(small, to: rect(20, 220, 160, 70))
        let top = board.add(.box, centre: CGPoint(x: 100, y: 70), text: "top")
        let halfOut = board.add(.box, centre: CGPoint(x: 420, y: 160), text: "half out")   // 345…495: its middle is inside
        let mostlyOut = board.add(.box, centre: CGPoint(x: 460, y: 160), text: "mostly out")
        let nested = board.add(.note, centre: CGPoint(x: 100, y: 255), text: "nested")

        XCTAssertEqual(board.spot(of: top), FrameSpot(frame: frame, lane: 0))
        XCTAssertEqual(board.spot(of: halfOut), FrameSpot(frame: frame, lane: 1))
        XCTAssertNil(board.spot(of: mostlyOut))
        XCTAssertEqual(board.spot(of: nested), FrameSpot(frame: small, lane: nil))   // the smallest frame round its middle
        XCTAssertNil(board.spot(of: frame))

        // Moving the frame carries what belongs to it — also the thing that sticks out, and the frame inside with its note.
        XCTAssertEqual(board.carried(by: [frame]), [frame, small, top, halfOut, nested])
        XCTAssertEqual(board.thingsByLane(in: frame).map { $0.map(\.text) }, [["top"], ["half out"], ["nested"]])
        // While dragged, a thing lights up the lane under its middle; a frame dragged along lights nothing.
        XCTAssertEqual(board.spots(ofDragged: [top, halfOut]), [FrameSpot(frame: frame, lane: 0), FrameSpot(frame: frame, lane: 1)])
        XCTAssertEqual(board.spots(ofDragged: [frame, top]), [])

        // Sizing the frame moves nothing else — but the thing that was outside now belongs, in reading order.
        let before = board.item(top)?.frame
        board.resize(frame, to: rect(0, 0, 600, 300))
        XCTAssertEqual(board.item(top)?.frame, before)
        XCTAssertEqual(board.thingsByLane(in: frame).map { $0.map(\.text) }, [["top"], ["half out", "mostly out"], ["nested"]])
    }

    func testALanesNameBandCatchesTheFrame() {
        var board = Board()
        let frame = board.add(.frame, centre: CGPoint(x: 220, y: 150))
        XCTAssertNil(board.hit(CGPoint(x: 12, y: 160)))           // a plain frame: only its name band and its edge
        board.setLanes(frame, way: .rows, count: 3)
        XCTAssertEqual(board.hit(CGPoint(x: 12, y: 160)), frame)   // the second row's name band
        XCTAssertEqual(board.item(frame)?.laneName(at: CGPoint(x: 12, y: 160)), 1)
        XCTAssertNil(board.hit(CGPoint(x: 200, y: 160)))           // the lane itself stays free for what lies in it
        board.setLaneName(frame, lane: 1, to: "  Shop ")
        XCTAssertEqual(board.item(frame)?.lanes?.names, ["", "Shop", ""])
        // Another number of lanes keeps the names that fit; another direction keeps them all.
        board.setLanes(frame, way: .columns, count: 2)
        XCTAssertEqual(board.item(frame)?.lanes?.names, ["", "Shop"])
        XCTAssertEqual(board.item(frame)?.lanes?.way, .columns)
    }

    func testLanesAreStoredAsAnOptionalFieldAndOldFilesStillOpen() throws {
        // A frame written by 0.1 has no lanes.
        let old = #"{"id":"11111111-1111-1111-1111-111111111111","kind":"frame","text":"F","x":0,"y":0,"w":440,"h":300}"#
        XCTAssertNil(try JSONDecoder().decode(Item.self, from: Data(old.utf8)).lanes)

        var item = Item(kind: .frame, text: "F")
        item.lanes = Lanes(way: .columns, count: 3)
        item.lanes?.names = ["A", "B", "C"]
        item.lanes?.cuts = [0.25, 0.5]
        let back = try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(back.lanes, item.lanes)

        // Lines that make no sense (too few, or not rising) are read as even lanes; one name is filled up to two.
        let broken = #"{"way":"columns","names":["A","B","C"],"cuts":[0.8,0.2]}"#
        XCTAssertEqual(try JSONDecoder().decode(Lanes.self, from: Data(broken.utf8)).cuts, Lanes.even(3))
        let thin = #"{"names":["Only"]}"#
        let read = try JSONDecoder().decode(Lanes.self, from: Data(thin.utf8))
        XCTAssertEqual(read.names, ["Only", ""])
        XCTAssertEqual(read.way, .rows)
        XCTAssertEqual(read.cuts, [0.5])
    }

    func testAFrameWithLanesGoesToParagonLaneByLane() {
        var board = Board(title: "Order")
        let frame = board.add(.frame, centre: CGPoint(x: 220, y: 150), text: "Web shop order")
        board.setLanes(frame, way: .rows, count: 3)
        board.setLaneName(frame, lane: 0, to: "Customer")
        board.setLaneName(frame, lane: 1, to: "Shop")
        let pack = board.add(.box, centre: CGPoint(x: 300, y: 165), text: "Pack")
        let check = board.add(.document, centre: CGPoint(x: 120, y: 165), text: "Check\nthe order")
        let order = board.add(.person, centre: CGPoint(x: 120, y: 75), text: "Orders")
        board.add(.note, centre: CGPoint(x: 330, y: 75), text: "Pays by card")
        board.add(.box, centre: CGPoint(x: 900, y: 0), text: "Outside")
        board.link(from: order, to: check)
        board.link(from: check, to: pack)
        let now = Date(timeIntervalSince1970: 0)

        let note = ParagonExport.note(board: board, title: "Order", picture: nil, now: now)
        // Lane by lane, left to right inside a row; the third lane holds nothing and is left out.
        XCTAssertTrue(note.contains("## Web shop order\n\n### Customer\n\n- Orders\n- Pays by card\n\n### Shop\n\n- Check the order\n- Pack\n\n## Notes"), note)

        let project = ParagonExport.project(board: board, title: "Order", picture: nil, now: now)
        XCTAssertTrue(project.contains("### Web shop order: Customer\n- [ ] Orders\n\n### Web shop order: Shop\n- [ ] Check the order\n- [ ] Pack\n\n### Steps\n- [ ] Outside\n"), project)

        // Once an idea is ticked, only ticked shapes in a lane become tasks — the same rule as for the steps.
        var ticked = board
        let idea = ticked.add(.idea, centre: CGPoint(x: 900, y: 300), text: "Plan")
        if let i = ticked.index(of: idea) { ticked.items[i].todo = true }
        if let i = ticked.index(of: pack) { ticked.items[i].todo = true }
        let mixed = ParagonExport.project(board: ticked, title: "Order", picture: nil, now: now)
        XCTAssertTrue(mixed.contains("### Web shop order: Shop\n- Check the order\n- [ ] Pack\n"), mixed)

        // A frame without lanes, with a name, is a heading for the notes in it (0.5; see Send05Tests).
        board.setLanes(frame, way: nil)
        XCTAssertTrue(ParagonExport.note(board: board, title: "Order", picture: nil, now: now).contains("## Notes\n\n### Web shop order\n\n- Pays by card\n"))
    }
}
