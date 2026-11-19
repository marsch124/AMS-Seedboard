import XCTest
@testable import SeedboardCore

final class Pictures14Tests: XCTestCase {
    func testPictureFileNames() {
        XCTAssertTrue(PictureKeeping.isPictureFileName(PictureKeeping.freshName()))
        XCTAssertTrue(PictureKeeping.isPictureFileName(PictureKeeping.freshPNGName()))
        XCTAssertTrue(PictureKeeping.freshPNGName().hasSuffix(".png"))
        XCTAssertFalse(PictureKeeping.isPictureFileName("a.gif"))
        XCTAssertFalse(PictureKeeping.isPictureFileName(".hidden.png"))
        XCTAssertFalse(PictureKeeping.isPictureFileName("../x.png"))
    }

    func testPNGIsTidiedAndAdoptedLikeAJPG() {
        let old = Date(timeIntervalSinceNow: -3 * 86_400)
        let found = PictureKeeping.unusedNow(files: [("a.png", old, 10), ("b.jpg", old, 20), ("c.gif", old, 5)], named: [])
        XCTAssertEqual(found.names, ["a.png", "b.jpg"])
        XCTAssertEqual(found.bytes, 30)
    }

    func testPDFPageCounts() {
        XCTAssertEqual(PDFPages.counted(total: 6, all: false), 1)
        XCTAssertEqual(PDFPages.counted(total: 6, all: true), 6)
        XCTAssertEqual(PDFPages.counted(total: 50, all: true), 20)
        XCTAssertEqual(PDFPages.counted(total: 0, all: true), 0)
        XCTAssertNil(PDFPages.question(pages: 1))
        XCTAssertEqual(PDFPages.question(pages: 6), "This PDF has 6 pages")
        XCTAssertNil(PDFPages.cutLine(total: 20))
        XCTAssertNotNil(PDFPages.cutLine(total: 21))
    }

    func testPDFPixelsAndSniff() {
        let p = PDFPages.pixels(width: 612, height: 792)
        XCTAssertEqual(p.height, 2048)
        XCTAssertEqual(p.width, 1583)
        XCTAssertEqual(PDFPages.pixels(width: 0, height: 5).width, 1)
        XCTAssertTrue(PDFPages.looksLikePDF(Data("%PDF-1.7\n".utf8)))
        XCTAssertFalse(PDFPages.looksLikePDF(Data("hello".utf8)))
    }

    func testLiftedPictureLiesBeside() {
        let c = LiftOut.centre(besideX: 100, y: 50, w: 200, h: 100, newWidth: 80)
        XCTAssertEqual(c.x, 368)
        XCTAssertEqual(c.y, 100)
    }
}
