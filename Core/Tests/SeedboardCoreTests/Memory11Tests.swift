import XCTest
@testable import SeedboardCore

final class Memory11Tests: XCTestCase {
    func testUndoLetsGoTheOldestByCountAndBySizeButKeepsTheNewest() {
        XCTAssertEqual(UndoBudget.toLetGo(weights: Array(repeating: 10, count: 130)), 10)
        let mb = 1024 * 1024
        XCTAssertEqual(UndoBudget.toLetGo(weights: Array(repeating: 10 * mb, count: 6)), 2)
        XCTAssertEqual(UndoBudget.toLetGo(weights: [50 * mb]), 0)
        XCTAssertEqual(UndoBudget.toLetGo(weights: []), 0)
    }

    func testAtMostTwelveFullSizePicturesStayOpenTheMostRecentlyAskedFor() {
        let now = Date()
        let asked = (0..<40).map { (name: "p\($0).jpg", wanted: now.addingTimeInterval(Double($0))) }
        let keep = PictureKeeping.sharpToKeep(asked)
        XCTAssertEqual(keep.count, 12)
        XCTAssertTrue(keep.contains("p39.jpg"))
        XCTAssertFalse(keep.contains("p27.jpg"))
    }
}
