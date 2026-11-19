import XCTest
import CoreGraphics
@testable import SeedboardCore

final class Pictures11Tests: XCTestCase {
    private func picture(_ b: inout Board, x: Double, caption: String = "") -> UUID {
        let id = b.add(.picture, centre: CGPoint(x: x + 100, y: 100))
        b.items[b.index(of: id)!].w = 200; b.items[b.index(of: id)!].h = 100
        b.items[b.index(of: id)!].x = x
        b.items[b.index(of: id)!].text = caption
        return id
    }

    func testCaptionRoomFollowsTheMeasuringTheScreenUses() {
        let saved = Item.captionMeasure
        defer { Item.captionMeasure = saved }
        let words = "one two three four five six"
        let narrow = Item.captionLines(words, width: 120)
        Item.captionMeasure = { Double($0.count) * 12 }   // a wider lettering
        XCTAssertGreaterThan(Item.captionLines(words, width: 120), narrow)
        XCTAssertEqual(Item.captionLines(words, width: 120), Item.captionWrapped(words, width: 120).count)
    }

    func testEvenGapsAndLineUpCountTheCaption() {
        var b = Board()
        let a = picture(&b, x: 0), c = picture(&b, x: 300, caption: "A caption that is long enough to take two lines at least")
        let d = picture(&b, x: 900)
        b.evenGaps([a, c, d])
        let gap1 = b.item(c)!.reach.minX - b.item(a)!.reach.maxX
        let gap2 = b.item(d)!.reach.minX - b.item(c)!.reach.maxX
        XCTAssertEqual(gap1, gap2, accuracy: 0.001)
        // Lined up in a column: the middles of picture + caption share one line.
        var col = Board()
        let p = picture(&col, x: 0, caption: "A caption that is long enough to take two lines at least")
        let q = picture(&col, x: 0)
        col.items[col.index(of: q)!].y = 600
        col.lineUp([p, q])
        XCTAssertEqual(col.item(p)!.reach.midX, col.item(q)!.reach.midX, accuracy: 0.001)
        var row = Board()
        let r = picture(&row, x: 0, caption: "A caption that is long enough to take two lines at least")
        let s = picture(&row, x: 500)
        row.lineUp([r, s])
        XCTAssertEqual(row.item(r)!.reach.midY, row.item(s)!.reach.midY, accuracy: 0.001)
    }

    func testPictureAndSketchLinesShareOneWording() {
        var b = Board()
        let id = picture(&b, x: 0)
        XCTAssertEqual(ParagonExport.pictureLine(for: b.item(id)!, picture: false), "A picture (on the board)")
        XCTAssertEqual(ParagonExport.pictureLine(), "A picture (see the picture)")
        b.items[b.index(of: id)!].text = "After the makeover"
        XCTAssertEqual(ParagonExport.pictureLine(for: b.item(id)!, picture: true), "A picture: After the makeover (see the picture)")
        XCTAssertEqual(ParagonExport.sketchLine(picture: false), "A sketch (on the board)")
    }

    func testWordsToANoteMakesANoteBesideThePictureOnlyWhenThereAreWords() {
        var b = Board()
        let id = picture(&b, x: 0)
        XCTAssertNil(b.noteWithPictureWords(id))
        b.items[b.index(of: id)!].pictureWords = "Platform 9 Departures"
        XCTAssertEqual(b.item(id)!.foundWords, "Platform 9 Departures")
        let note = b.noteWithPictureWords(id)!
        XCTAssertEqual(b.item(note)?.kind, .note)
        XCTAssertEqual(b.item(note)?.text, "Platform 9 Departures")
        XCTAssertGreaterThanOrEqual(b.item(note)!.x, b.item(id)!.reach.maxX)
    }
}
