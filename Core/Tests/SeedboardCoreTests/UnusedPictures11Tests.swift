import XCTest
@testable import SeedboardCore

final class UnusedPictures11Tests: XCTestCase {
    func testOnlyUnnamedOldPlainPicturesAreCounted() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-86_400)
        let files: [(name: String, date: Date?, bytes: Int)] = [
            ("a.jpg", old, 3_000_000), ("named.jpg", old, 5_000_000), ("fresh.jpg", now.addingTimeInterval(-60), 1_000_000),
            ("nodate.jpg", nil, 1_000_000), ("../x.jpg", old, 1_000_000), ("note.txt", old, 10),
        ]
        let found = PictureKeeping.unusedNow(files: files, named: ["named.jpg"], now: now)
        XCTAssertEqual(found.names, ["a.jpg"])
        XCTAssertEqual(found.bytes, 3_000_000)
        // Any doubt (something unreadable or still in iCloud): nothing is counted.
        XCTAssertTrue(PictureKeeping.unusedNow(files: files, named: [], now: now, complete: false).names.isEmpty)
        XCTAssertEqual(PictureKeeping.unusedLine(count: 3, bytes: 12 * 1_048_576), "Pictures nobody uses: 3 (12 MB)")
        XCTAssertEqual(PictureKeeping.unusedLine(count: 0, bytes: 0), "Pictures nobody uses: none")
        XCTAssertEqual(PictureKeeping.removeQuestion(count: 1), "Remove 1 picture nobody uses? This cannot be undone.")
    }
}
