import XCTest
@testable import SeedboardCore

final class PictureTests: XCTestCase {
    private func board(with name: String = "a.jpg", pixels: CGSize = CGSize(width: 4000, height: 3000)) -> (Board, UUID) {
        var b = Board(title: "Pictures")
        let id = b.addPicture(name: name, pixelSize: pixels, centre: CGPoint(x: 100, y: 50))!
        return (b, id)
    }

    func testAPictureIsLaidAtMost320KeepingItsShapeWithItsMiddleAtThePoint() {
        let (b, id) = board()
        let item = b.item(id)!
        XCTAssertEqual(item.w, 320); XCTAssertEqual(item.h, 240)
        XCTAssertEqual(item.frame.midX, 100); XCTAssertEqual(item.frame.midY, 50)
        XCTAssertEqual(item.picture, "a.jpg")
        let (tall, t) = board(pixels: CGSize(width: 1000, height: 2000))
        XCTAssertEqual(tall.item(t)!.h, 320); XCTAssertEqual(tall.item(t)!.w, 160)
        let (tiny, s) = board(pixels: CGSize(width: 30, height: 20))
        XCTAssertEqual(tiny.item(s)!.w, 120)
    }

    func testResizingByACornerKeepsTheShapeAndTheOppositeCorner() {
        var (b, id) = board()
        let f = b.item(id)!.frame
        b.resize(id, to: CGRect(x: f.minX, y: f.minY, width: 160, height: 400))   // bottom right, pulled oddly
        var item = b.item(id)!
        XCTAssertEqual(item.w / item.h, 320.0 / 240.0, accuracy: 0.001)
        XCTAssertEqual(item.frame.minX, f.minX, accuracy: 0.001)
        XCTAssertEqual(item.frame.minY, f.minY, accuracy: 0.001)
        // Top left corner dragged: the bottom right stays.
        let g = item.frame
        b.resize(id, to: CGRect(x: g.maxX - 100, y: g.maxY - 20, width: 100, height: 20))
        item = b.item(id)!
        XCTAssertEqual(item.frame.maxX, g.maxX, accuracy: 0.001)
        XCTAssertEqual(item.frame.maxY, g.maxY, accuracy: 0.001)
        XCTAssertEqual(item.w / item.h, 320.0 / 240.0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(item.w, 44)
    }

    func testAPictureIsRefusedOnTimelineAndWhoDoesWhatBoards() {
        var timeline = Board.timeline(title: "T")
        XCTAssertNil(timeline.addPicture(name: "a.jpg", pixelSize: CGSize(width: 10, height: 10), centre: .zero))
        var who = Board.sequence(title: "W")
        XCTAssertNil(who.addPicture(name: "a.jpg", pixelSize: CGSize(width: 10, height: 10), centre: .zero))
        var plain = Board()
        XCTAssertNil(plain.addPicture(name: "../x.jpg", pixelSize: CGSize(width: 10, height: 10), centre: .zero))
        XCTAssertTrue(plain.items.isEmpty)
    }

    func testArrowsCopyAndPasteCarryThePictureFileName() {
        var (b, id) = board()
        let note = b.add(.note, centre: CGPoint(x: 600, y: 50), text: "Nice")
        XCTAssertNotNil(b.link(from: id, to: note))
        XCTAssertNotNil(b.link(from: note, to: id))
        XCTAssertNotNil(b.arrow(b.links[0].id))
        let clip = b.clip(of: [id])
        var other = Board()
        let made = other.paste(clip, at: CGPoint(x: 0, y: 0))
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(other.items.first?.picture, "a.jpg")
        XCTAssertNotEqual(other.items.first?.id, id)
        var twin = b
        let copies = twin.duplicate([id])
        XCTAssertEqual(twin.item(copies.first!)?.picture, "a.jpg")
    }

    func testAPictureIsOnePlainLineInTheTextsAndCountsAsAPicture() {
        var (b, id) = board()
        let note = b.add(.note, centre: .zero, text: "Hello")
        b.link(from: id, to: note)
        XCTAssertTrue(b.outlineText.contains("- A picture"))
        XCTAssertTrue(b.outlineText.contains("A picture → Hello"))
        XCTAssertEqual(b.countLine, "1 note · 1 picture")
        XCTAssertEqual(ParagonExport.pictureLine(), "A picture (see the picture)")
        XCTAssertEqual(ParagonExport.label(b.item(id)!), "A picture")
    }

    func testTidyTreatsAPictureAsAFixedShape() {
        var (b, id) = board()
        let box = b.add(.box, centre: CGPoint(x: 500, y: 300))
        let before = b.item(id)!
        b.sameSize([id, box])
        XCTAssertEqual(b.item(id)!.w, before.w)
        XCTAssertEqual(b.item(id)!.h, before.h)
        b.lineUp([id, box])
        XCTAssertEqual(b.item(id)!.frame.midY, b.item(box)!.frame.midY, accuracy: 0.01)
        XCTAssertEqual(Controls.knobCorners(of: .picture).count, 4)
    }

    func testAPictureFileGoesOnlyWhenNoBoardNamesItAndItIsOlderThan30Days() {
        let now = Date()
        let old = now.addingTimeInterval(-31 * 86_400), young = now.addingTimeInterval(-5 * 86_400)
        let files: [(name: String, date: Date?)] = [("used.jpg", old), ("lonely.jpg", old), ("new.jpg", young), ("unknown.jpg", nil), ("../evil", old)]
        XCTAssertEqual(PictureKeeping.deletable(files: files, named: ["used.jpg"], now: now), ["lonely.jpg"])
        XCTAssertEqual(PictureKeeping.deletable(files: files, named: [], now: now, complete: false), [])
    }

    func testTheBoardIsInTheCurrentFormatAndKeepsThePictureThroughASave() throws {
        var (b, _) = board()
        b.touch()
        XCTAssertEqual(b.format, Board.currentFormat)
        let back = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(back.pictureNames, ["a.jpg"])
    }
}
