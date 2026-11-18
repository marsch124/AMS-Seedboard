import XCTest
@testable import SeedboardCore

final class CaptionCropTests: XCTestCase {
    private func board() -> (Board, UUID) {
        var b = Board(title: "Balcony")
        let id = b.addPicture(name: "a.jpg", pixelSize: CGSize(width: 4000, height: 3000), centre: CGPoint(x: 100, y: 50))!   // 320 x 240
        return (b, id)
    }

    func testACaptionIsInTheTextsTheSearchAndTheNote() {
        var (b, id) = board()
        XCTAssertTrue(b.outlineText.contains("- A picture"))
        XCTAssertFalse(b.outlineText.contains("A picture:"))
        b.items[b.index(of: id)!].text = "After the makeover"
        XCTAssertTrue(b.outlineText.contains("- A picture: After the makeover"))
        XCTAssertTrue(b.readableText.contains("After the makeover"))
        let note = ParagonExport.note(board: b, title: "T", picture: nil, now: Date())
        XCTAssertTrue(note.contains("- A picture: After the makeover"))
        XCTAssertFalse(b.item(id)!.todo)
    }

    func testTheBoardsBoundsGiveTheCaptionItsRoomAndItMovesWithThePicture() {
        var (b, id) = board()
        let bare = b.bounds!
        b.items[b.index(of: id)!].text = "One line"
        let with = b.bounds!
        XCTAssertEqual(with.minY, bare.minY)
        XCTAssertGreaterThanOrEqual(with.maxY, bare.maxY + 6 + 15)
        b.items[b.index(of: id)!].text = String(repeating: "word ", count: 80)
        XCTAssertGreaterThan(b.bounds!.maxY, with.maxY + 30)
        let cap = b.item(id)!.captionFrame!
        XCTAssertEqual(cap.minY, b.item(id)!.frame.maxY + 6, accuracy: 0.001)
        XCTAssertEqual(cap.width, b.item(id)!.w, accuracy: 0.001)
        XCTAssertEqual(b.hit(CGPoint(x: cap.midX, y: cap.midY)), id)
    }

    func testCroppingKeepsTheScaleAndTheKeptPartWhereItWas() {
        var (b, id) = board()
        let f = b.item(id)!.frame          // 320 x 240
        XCTAssertTrue(b.cropPicture(id, to: [0.25, 0.5, 0.5, 0.25]))
        var item = b.item(id)!
        XCTAssertEqual(item.crop!, [0.25, 0.5, 0.5, 0.25])
        XCTAssertEqual(item.w, 160, accuracy: 0.001); XCTAssertEqual(item.h, 60, accuracy: 0.001)
        XCTAssertEqual(item.x, f.minX + 80, accuracy: 0.001); XCTAssertEqual(item.y, f.minY + 120, accuracy: 0.001)
        // A smaller part of the part: the scale still stays (the whole picture is still 320 wide).
        XCTAssertTrue(b.cropPicture(id, to: [0.5, 0.5, 0.25, 0.25]))
        item = b.item(id)!
        XCTAssertEqual(item.w, 80, accuracy: 0.001); XCTAssertEqual(item.h, 60, accuracy: 0.001)
        XCTAssertEqual(item.x, f.minX + 160, accuracy: 0.001); XCTAssertEqual(item.y, f.minY + 120, accuracy: 0.001)
        // Everything back: the first box again, and no crop stored.
        XCTAssertTrue(b.cropPicture(id, to: nil))
        item = b.item(id)!
        XCTAssertNil(item.crop)
        XCTAssertEqual(item.frame, f)
        XCTAssertTrue(b.cropPicture(id, to: [0.1, 0.1, 0.5, 0.5]))
        XCTAssertTrue(b.cropPicture(id, to: [0, 0, 1, 1]))
        XCTAssertNil(b.item(id)!.crop)
        XCTAssertEqual(b.item(id)!.frame.width, 320, accuracy: 0.001)
    }

    func testABadPartIsRefusedAndTheOtherThingsAreLeftAlone() {
        var (b, id) = board()
        let before = b
        XCTAssertFalse(b.cropPicture(id, to: [0, 0, 0.04, 1]))
        XCTAssertFalse(b.cropPicture(id, to: [0.6, 0, 0.6, 1]))
        XCTAssertFalse(b.cropPicture(id, to: [0, 0, .nan, 1]))
        XCTAssertFalse(b.cropPicture(id, to: [0, 0, 1]))
        XCTAssertEqual(b, before)
        let note = b.add(.note, centre: .zero, text: "x")
        XCTAssertFalse(b.cropPicture(note, to: [0, 0, 0.5, 0.5]))
    }

    func testResizingACroppedPictureKeepsTheCroppedShapeDuplicateAndPasteCarryTheCrop() {
        var (b, id) = board()
        b.cropPicture(id, to: [0, 0, 0.5, 0.25])           // 160 x 60
        let f = b.item(id)!.frame
        b.resize(id, to: CGRect(x: f.minX, y: f.minY, width: 320, height: 500))
        let item = b.item(id)!
        XCTAssertEqual(item.w / item.h, 160.0 / 60.0, accuracy: 0.001)
        XCTAssertEqual(item.crop!, [0, 0, 0.5, 0.25])
        let twin = b.duplicate([id]).first!
        XCTAssertEqual(b.item(twin)!.crop!, [0, 0, 0.5, 0.25])
        let clip = b.clip(of: [id])
        var other = Board(title: "Other")
        let pasted = other.paste(clip, at: .zero).first!
        XCTAssertEqual(other.item(pasted)!.crop!, [0, 0, 0.5, 0.25])
    }

    func testACropIsSavedAndReadBackAndBadStoredCropsAreCleanedUp() throws {
        var (b, id) = board()
        b.cropPicture(id, to: [0.2, 0.3, 0.4, 0.5])
        b.touch()
        XCTAssertEqual(b.format, Board.currentFormat)
        let back = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(back.item(id)!.crop!, [0.2, 0.3, 0.4, 0.5])
        func read(_ crop: String) throws -> [Double]? {
            let json = #"{"id":"11111111-1111-1111-1111-111111111111","items":[{"id":"22222222-2222-2222-2222-222222222222","kind":"picture","picture":"a.jpg","crop":\#(crop)}]}"#
            return try JSONDecoder().decode(Board.self, from: Data(json.utf8)).items[0].crop
        }
        XCTAssertNil(try read("[0,0,0.01,1]"))
        XCTAssertNil(try read("[0,0,1]"))
        XCTAssertNil(try read(#""wide""#))
        XCTAssertNil(try read("[0,0,1,1]"))
        XCTAssertEqual(try read("[0.5,0.5,2,2]"), [0.5, 0.5, 0.5, 0.5])
        XCTAssertEqual(try read("[-1,0,0.5,0.5]"), [0, 0, 0.5, 0.5])
    }

    func testAMapThatGrowsMakesRoomForACaptionToo() {
        var grown = Board(title: "Room")
        let c = grown.addCentre(at: .zero, text: "Centre", bothSides: false)
        let k = grown.addChild(of: c, text: "first")!
        grown.layoutMaps()
        let before = grown
        for n in 0..<8 { grown.addChild(of: k, text: "idea number \(n)") }
        grown.layoutMaps()
        let oldFrames = before.items.filter { $0.kind == .idea }.map(\.frame)
        let fresh = grown.items.filter { $0.kind == .idea && !oldFrames.contains($0.frame) }.map(\.frame)
        // A picture whose own box stands clear of the map, but whose caption lies under a new idea.
        let target = fresh.max { $0.maxY < $1.maxY }!
        var b = before
        let pic = b.addPicture(name: "a.jpg", pixelSize: CGSize(width: 120, height: 80), centre: .zero)!
        let i = b.index(of: pic)!
        b.items[i].text = "A caption"
        b.items[i].x = Double(target.minX)
        b.items[i].y = Double(target.midY) - b.items[i].h - Item.captionGap - 4
        func overlaps(_ a: CGRect, _ r: [CGRect]) -> Bool { r.contains { $0.intersects(a) } }
        XCTAssertFalse(overlaps(b.item(pic)!.frame, oldFrames), "the set-up needs the picture clear of the map")
        XCTAssertTrue(overlaps(b.item(pic)!.reach, fresh), "the set-up needs the caption under a new idea")
        let start = b.item(pic)!
        for n in 0..<8 { b.addChild(of: k, text: "idea number \(n)") }
        b.layoutMaps()
        b.makeRoom(since: before.withPicture(start))
        let ideas = b.items.filter { $0.kind == .idea }.map(\.frame)
        XCTAssertFalse(overlaps(b.item(pic)!.reach, ideas), "the caption was left under the map")
    }
}

private extension Board {
    func withPicture(_ picture: Item) -> Board { var b = self; b.items.append(picture); return b }
}
