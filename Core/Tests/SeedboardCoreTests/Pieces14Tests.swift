import XCTest
@testable import SeedboardCore

final class Pieces14Tests: XCTestCase {
    func testTimerWords() {
        XCTAssertEqual(BrainstormTimer.leftWords(total: 300, elapsed: 47.5), "4:13 left")
        XCTAssertEqual(BrainstormTimer.leftWords(total: 300, elapsed: 0), "5:00 left")
        XCTAssertEqual(BrainstormTimer.leftWords(total: 300, elapsed: 299.2), "0:01 left")
        XCTAssertEqual(BrainstormTimer.leftWords(total: 600, elapsed: 541), "0:59 left")
        XCTAssertEqual(BrainstormTimer.filled(total: 300, elapsed: 150), 0.5)
        XCTAssertFalse(BrainstormTimer.isOver(total: 300, elapsed: 299.9))
        XCTAssertTrue(BrainstormTimer.showsTimeUp(total: 300, elapsed: 302))
        XCTAssertFalse(BrainstormTimer.showsTimeUp(total: 300, elapsed: 304.5))
        XCTAssertTrue(BrainstormTimer.isFinished(total: 300, elapsed: 304))
    }

    private func map() -> (Board, UUID, UUID, UUID) {
        var b = Board(title: "Trip")
        var top = Item(kind: .idea, x: 0, y: 0)
        top.text = "Packing"
        var a = Item(kind: .idea, x: 200, y: 0)
        a.text = "Socks"
        a.parent = top.id
        var c = Item(kind: .idea, x: 200, y: 80)
        c.text = "Shirts"
        c.parent = top.id
        b.items = [top, a, c]
        return (b, top.id, a.id, c.id)
    }

    func testCutTakesTheBranchAndNewIdsOnDrop() throws {
        var (board, top, _, _) = map()
        var note = Item(kind: .note, x: 500, y: 0)
        note.text = "Side"
        board.items.append(note)
        let clip = try XCTUnwrap(PieceShelf.cut(from: board, chosen: [top]))
        XCTAssertEqual(clip.items.count, 3, "the branch's children come along")
        XCTAssertEqual(PieceEntry.countLine(of: clip), "3 ideas")

        var shelf = PieceShelf()
        let id = try XCTUnwrap(shelf.save(clip, name: " Packing "))
        let piece = try XCTUnwrap(shelf.piece(id))
        XCTAssertEqual(piece.name, "Packing")

        var other = Board(title: "Other")
        let made = PieceShelf.drop(piece, into: &other, at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(other.items.count, 3)
        XCTAssertTrue(Set(other.items.map(\.id)).isDisjoint(with: Set(board.items.map(\.id))), "new ids")
        XCTAssertFalse(made.isEmpty)
        // A second drop makes a second, separate copy.
        PieceShelf.drop(piece, into: &other, at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(other.items.count, 6)
        XCTAssertNil(PieceShelf.cut(from: board, chosen: []))
    }

    func testShelfRenameRemoveKeepAndPurge() throws {
        let (board, top, _, _) = map()
        let clip = try XCTUnwrap(PieceShelf.cut(from: board, chosen: [top]))
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var shelf = PieceShelf()
        let a = try XCTUnwrap(shelf.save(clip, name: "Packing", now: t0))
        let b = try XCTUnwrap(shelf.save(clip, name: "Packing", now: t0))
        XCTAssertEqual(shelf.piece(b)?.name, "Packing 2")
        XCTAssertEqual(shelf.shown.map(\.id), [a, b])
        XCTAssertNil(shelf.save(clip, name: "  "))
        shelf.rename(a, name: "Bags", now: t0.addingTimeInterval(5))
        XCTAssertEqual(shelf.piece(a)?.name, "Bags")
        shelf.remove(a, now: t0.addingTimeInterval(10))
        XCTAssertEqual(shelf.shown.map(\.id), [b])
        XCTAssertNotNil(shelf.piece(a), "a removed piece is kept")
        XCTAssertTrue(shelf.purgeable(now: t0.addingTimeInterval(86_400 * 29)).isEmpty)
        XCTAssertEqual(shelf.purgeable(now: t0.addingTimeInterval(86_400 * 31)), [a])
        // Newer wins between two devices.
        var old = try XCTUnwrap(shelf.piece(b)); old.name = "Old"; old.changed = t0.addingTimeInterval(-1)
        let merged = PieceShelf(entries: [old, try XCTUnwrap(shelf.piece(b))])
        XCTAssertEqual(merged.piece(b)?.name, "Packing 2")
        // Round trip through JSON.
        let data = try JSONEncoder().encode(try XCTUnwrap(shelf.piece(b)))
        XCTAssertEqual(try JSONDecoder().decode(PieceEntry.self, from: data), shelf.piece(b))
        XCTAssertEqual(PieceFileName.id(of: "ABC.seedpiece"), "ABC")
        XCTAssertNil(PieceFileName.id(of: "ABC 2.seedpiece"))
    }
}
