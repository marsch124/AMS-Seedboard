import XCTest
@testable import SeedboardCore

final class Safe11Tests: XCTestCase {
    private let good = "11111111-1111-1111-1111-111111111111"
    private let item = #"{"id":"22222222-2222-2222-2222-222222222222","kind":"note","text":"Alex","x":10,"y":20}"#

    private func read(_ json: String, fileDate: Date? = nil) -> Board? {
        let decoder = JSONDecoder()
        if let fileDate { decoder.userInfo[Board.fileDateKey] = fileDate }
        return try? decoder.decode(Board.self, from: Data(json.utf8))
    }

    /// Ten odd files: none may crash, and a readable thing is never lost.
    func testOddFilesNeverCrashAndKeepReadableThings() {
        let files = [
            #"{"id":"\#(good)","items":[\#(item),"#,                                   // cut off
            #"{"id":"\#(good)","items":"not a list","links":5}"#,                       // wrong types
            #"{"id":"\#(good)","items":[\#(item),42,null,{"kind":7}]}"#,                  // junk among items
            #"{"id":"\#(good)","items":[{"kind":"note","x":1e308,"y":-1e308,"w":1e308,"h":-5}]}"#, // huge numbers
            #"{"id":"\#(good)","title":null,"created":null,"changed":null,"items":null,"links":null}"#, // nulls
            #"{"id":"\#(good)","items":[\#(item)],"links":[{"from":null,"to":null},{"id":"x"}]}"#,    // broken arrows
            #"{"id":"\#(good)","created":12345,"changed":"nonsense","format":"seven"}"#,
            #"[]"#, #"{}"#, ""
        ]
        var crashed = 0
        for text in files {
            let data = Data(text.utf8)
            _ = Board.unreadableCount(in: data)
            if let board = read(text) {
                for it in board.items {
                    XCTAssertTrue(it.x.isFinite && abs(it.x) <= SafeNumber.farthest)
                    XCTAssertTrue(it.w.isFinite && it.w >= 0 && it.w <= SafeNumber.biggest)
                }
                _ = DotGrid.dots(in: CGRect(x: -1e300, y: -1e300, width: 2e300, height: 2e300), scale: 1)
                crashed += 0
            }
        }
        XCTAssertEqual(crashed, 0)
        // The readable thing among junk survives; the junk is counted.
        let mixed = #"{"id":"\#(good)","items":[\#(item),42,null],"links":[{"from":null}]}"#
        XCTAssertEqual(read(mixed)?.items.count, 1)
        XCTAssertEqual(Board.unreadableCount(in: Data(mixed.utf8)), 3)
        XCTAssertEqual(Board.unreadableCount(in: Data(#"{"id":"\#(good)","items":[\#(item)]}"#.utf8)), 0)
    }

    func testUnreadableDateUsesFileDateNotNineteenSeventy() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let board = read(#"{"id":"\#(good)","created":"garbled","changed":"garbled"}"#, fileDate: day)
        XCTAssertEqual(board?.created, day)
        XCTAssertEqual(board?.changed, day)
        XCTAssertEqual(read(#"{"id":"\#(good)","created":"garbled"}"#)?.created, Date(timeIntervalSince1970: 0))
    }

    func testPlainLines() {
        XCTAssertEqual(SafetyWords.importSkipped(notBoards: 0, newer: 1), "1 board was made by a newer Seedboard — update Seedboard first.")
        XCTAssertNil(SafetyWords.importSkipped(notBoards: 0, newer: 0))
        XCTAssertTrue(SafetyWords.damaged(count: 1, title: "Plan").contains("Earlier versions"))
        XCTAssertEqual(SafeNumber.int(.infinity), 0)
        XCTAssertEqual(SafeNumber.int(1e300), 1_000_000_000)
    }
}
