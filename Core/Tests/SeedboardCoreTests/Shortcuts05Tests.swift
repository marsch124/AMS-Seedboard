import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.5, picks 23 and 28: a thought added from outside, finding boards, starters by name, every word for
/// the device's search, and Handoff.
final class Shortcuts05Tests: XCTestCase {
    private let a = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let b = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    /// One line becomes a sticky note in a free column to the right of everything; a list becomes a mind map
    /// carried there as one block; a picture goes under the words. Nothing on the board is covered or moved.
    func testAThoughtFromOutsideLandsInAFreeColumnAndCoversNothing() {
        var board = Board(title: "Summer cabin")
        board.add(.box, centre: CGPoint(x: 0, y: 0), text: "Roof")
        board.add(.note, centre: CGPoint(x: 300, y: 200), text: "Ask Alex")
        let before = board
        let old = before.items.dropFirst().reduce(before.items[0].frame) { $0.union($1.frame) }

        let made = Outside.add(text: "  Call the builder  ", to: &board)
        XCTAssertEqual(made.count, 1)
        let note = board.item(made[0])!
        XCTAssertEqual(note.kind, .note)
        XCTAssertEqual(note.text, "Call the builder")
        XCTAssertEqual(note.frame.minX, old.maxX + 40, accuracy: 0.01)     // 40 to the right of everything
        XCTAssertEqual(note.frame.minY, old.minY, accuracy: 0.01)          // its top at the top of what is there
        XCTAssertEqual(Array(board.items.prefix(2)), before.items)         // what was there is untouched

        // A list: a mind map, as one block, again to the right of everything (the note included).
        var listed = board
        let map = Outside.add(text: "Trip\n  Food\n  Tent", to: &listed)
        XCTAssertEqual(map.count, 3)
        XCTAssertTrue(map.allSatisfy { listed.item($0)?.kind == .idea })
        let block = map.compactMap { listed.item($0)?.frame }.reduce(CGRect.null) { $0.union($1) }
        XCTAssertEqual(block.minX, note.frame.maxX + 40, accuracy: 0.01)
        XCTAssertFalse(listed.items.filter { !map.contains($0.id) }.contains { $0.frame.intersects(block) })

        // Words and a picture in one go: the picture lies under the words, 16 apart, in the same column.
        var both = before
        let two = Outside.add(text: "Look at this", picture: .init(name: "ABC.jpg", pixels: CGSize(width: 800, height: 400)), to: &both)
        XCTAssertEqual(two.count, 2)
        let words = both.item(two[0])!, picture = both.item(two[1])!
        XCTAssertEqual(picture.kind, .picture)
        XCTAssertEqual(picture.picture, "ABC.jpg")
        XCTAssertEqual(picture.frame.minX, words.frame.minX, accuracy: 0.01)
        XCTAssertEqual(picture.frame.minY, words.frame.maxY + 16, accuracy: 0.01)

        // On an empty board the first thing lies in the middle; no words and no picture add nothing.
        var empty = Board(title: "New")
        let first = Outside.add(text: "Seed", to: &empty)
        XCTAssertEqual(empty.item(first[0])!.frame.midX, 0, accuracy: 0.01)
        XCTAssertEqual(empty.item(first[0])!.frame.midY, 0, accuracy: 0.01)
        XCTAssertEqual(Outside.add(text: " \n ", to: &empty), [])
        XCTAssertEqual(Outside.addedLine(to: before), "Added to Summer cabin.")
    }

    /// On a board that is one mind map and nothing else, one line is a new main branch of that map.
    func testOneLineOnABoardThatIsOneMindMapBecomesAMainBranch() {
        var board = Board(title: "Ideas")
        let centre = board.addMap(from: [OutlineNode("Garden", [OutlineNode("Beds"), OutlineNode("Shed")])], title: nil, at: .zero)
        XCTAssertTrue(Outside.isOneMap(board))
        let made = Outside.add(text: "Greenhouse", to: &board)
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(board.item(made[0])?.kind, .idea)
        XCTAssertEqual(board.item(made[0])?.parent, centre)
        XCTAssertEqual(board.children(of: centre).map(\.text), ["Beds", "Shed", "Greenhouse"])
        XCTAssertNotEqual(board.item(made[0])?.frame.origin, board.item(centre)?.frame.origin)   // laid by the map

        // Several lines stay the rule for pasted words: a map of their own beside the first one.
        let list = Outside.add(text: "- One\n- Two", to: &board)
        XCTAssertEqual(board.mapCentres.count, 2)
        XCTAssertFalse(list.isEmpty)
        // A map with a note beside it is not "one map and nothing else": one line is a sticky note.
        var mixed = Board(title: "Mixed")
        mixed.addMap(from: [OutlineNode("Garden", [OutlineNode("Beds")])], title: nil, at: .zero)
        mixed.add(.note, centre: CGPoint(x: 400, y: 0), text: "Loose")
        XCTAssertFalse(Outside.isOneMap(mixed))
        let loose = Outside.add(text: "Greenhouse", to: &mixed)
        XCTAssertEqual(loose.first.flatMap { mixed.item($0) }?.kind, .note)
    }

    /// A timeline, a "Who does what" board and a board from a newer Seedboard refuse with a plain line and
    /// stay untouched; with no board named the thought goes to the board changed last that can take it.
    func testBoardsThatPlaceThemselvesRefuseAndTheThoughtGoesToTheBoardChangedLast() {
        let day = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var timeline = Starter.timeline.board(title: "Trip plan", now: day)
        timeline.changed = day.addingTimeInterval(300)
        var who = Starter.sequence.board(title: "Hand-over", now: day)
        who.changed = day.addingTimeInterval(200)
        var newer = Board(title: "From the future", created: day)
        newer.format = Board.currentFormat + 1
        var cabin = Board(title: "Summer cabin", created: day, changed: day.addingTimeInterval(100))
        let old = Board(title: "Old", created: day, changed: day.addingTimeInterval(50))

        XCTAssertEqual(Outside.refusal(for: timeline), "Nothing was added. “Trip plan” is a timeline and places its things itself. Choose another board.")
        XCTAssertEqual(Outside.refusal(for: who), "Nothing was added. “Hand-over” is a “Who does what” board and places its things itself. Choose another board.")
        XCTAssertEqual(Outside.refusal(for: newer), "Nothing was added. “From the future” was made by a newer Seedboard. Update the app to add to it.")
        XCTAssertNil(Outside.refusal(for: cabin))
        for refusing in [timeline, who, newer] {
            var board = refusing
            XCTAssertEqual(Outside.add(text: "A thought", picture: .init(name: "A.jpg", pixels: CGSize(width: 10, height: 10)), to: &board), [])
            XCTAssertEqual(board, refusing)
        }
        XCTAssertEqual(Outside.boardForThought(in: [timeline, who, old, cabin, newer])?.title, "Summer cabin")
        XCTAssertNil(Outside.boardForThought(in: [timeline, who, newer]))
        XCTAssertNil(Outside.boardForThought(in: []))
        XCTAssertEqual(Outside.add(text: "A thought", to: &cabin).count, 1)
    }

    /// What arrived is remembered on the device, handed out once when the board is opened, and only for
    /// things that are still there.
    func testArrivalsAreChosenOnceAndThenForgotten() throws {
        let one = UUID(), two = UUID(), three = UUID()
        var arrivals = OutsideArrivals()
        arrivals.note([one], on: a)
        arrivals.note([two, one], on: a)          // a second add; nothing twice
        arrivals.note([three], on: b)
        arrivals.note([], on: UUID())
        XCTAssertEqual(arrivals.waiting.count, 2)
        let back = try JSONDecoder().decode(OutsideArrivals.self, from: JSONEncoder().encode(arrivals))
        XCTAssertEqual(back, arrivals)
        XCTAssertEqual(arrivals.take(for: a, present: [one, two, three]), [one, two])
        XCTAssertEqual(arrivals.take(for: a, present: [one, two]), [])            // once only
        XCTAssertEqual(arrivals.keeping([a]).waiting.count, 0)                     // b is gone: forgotten
        XCTAssertEqual(arrivals.take(for: b, present: []), [])                     // the thing was removed meanwhile
        XCTAssertTrue(arrivals.isEmpty)
        // Settings that cannot be read are simply empty, never a crash.
        XCTAssertEqual(try JSONDecoder().decode(OutsideArrivals.self, from: Data(#"{"waiting":7}"#.utf8)), OutsideArrivals())
    }

    /// "Find boards": by name, by the day of the last change, pinned, sent to PARAGON; all or any; ordered; limited.
    func testFindBoardsByNameChangePinAndSent() {
        let day = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var cabin = Board(title: "Summer cabin", created: day, changed: day.addingTimeInterval(3 * 86_400))
        cabin.pinned = true
        var trip = Board(title: "Trip to Málaga", created: day, changed: day.addingTimeInterval(86_400))
        trip.sent = SentInfo(when: day, kind: "note", title: "Trip", path: "Resources/Trip.md")
        let summer = Board(title: "summer reading", created: day, changed: day)
        let all = [cabin, trip, summer]

        XCTAssertEqual(Outside.find(in: all, asks: []).map(\.title), all.map(\.title))
        XCTAssertEqual(Outside.find(in: all, asks: [.nameHolds("SUMMER")]).count, 2)
        XCTAssertEqual(Outside.find(in: all, asks: [.nameBegins("trip")]).map(\.title), ["Trip to Málaga"])
        XCTAssertEqual(Outside.find(in: all, asks: [.nameIs(" trip to malaga ")]).map(\.title), ["Trip to Málaga"])
        XCTAssertEqual(Outside.find(in: all, asks: [.changedAfter(day.addingTimeInterval(2 * 86_400))]).map(\.title), ["Summer cabin"])
        XCTAssertEqual(Outside.find(in: all, asks: [.changedBefore(day.addingTimeInterval(2 * 86_400))]).count, 2)
        XCTAssertEqual(Outside.find(in: all, asks: [.pinned(true)]).map(\.title), ["Summer cabin"])
        XCTAssertEqual(Outside.find(in: all, asks: [.sent(true)]).map(\.title), ["Trip to Málaga"])
        XCTAssertEqual(Outside.find(in: all, asks: [.sent(false), .pinned(false)]).map(\.title), ["summer reading"])
        XCTAssertEqual(Outside.find(in: all, asks: [.sent(true), .pinned(true)]).count, 0)                 // all of them
        XCTAssertEqual(Outside.find(in: all, asks: [.sent(true), .pinned(true)], any: true).count, 2)      // any of them
        XCTAssertEqual(Outside.find(in: all, asks: [], order: .name).map(\.title), ["Summer cabin", "summer reading", "Trip to Málaga"])
        XCTAssertEqual(Outside.find(in: all, asks: [], order: .changed, ascending: false, limit: 2).map(\.title), ["Summer cabin", "Trip to Málaga"])
    }

    /// "New board" offers his own starters: found by name, the exact name first.
    func testStartersAreFoundByName() {
        var shelf = StarterShelf()
        var weekly = Board(title: "Weekly wrap")
        weekly.add(.note, centre: .zero, text: "What went well")
        let own = shelf.saveAs(weekly, name: "Weekly wrap")
        let shown = shelf.shown
        XCTAssertEqual(shown.count, Starter.allCases.count + 1)
        XCTAssertEqual(Outside.starters(named: "", in: shown).count, shown.count)
        XCTAssertEqual(Outside.starters(named: "wrap", in: shown).map(\.id), [own])
        XCTAssertEqual(Outside.starters(named: "MIND MAP", in: shown).first?.builtin, .mindMap)
        XCTAssertEqual(Outside.starters(named: "plan", in: shown).first?.builtin, .steps)
        XCTAssertEqual(Outside.starters(named: "no such starter", in: shown).count, 0)
        // The board such a starter makes is a fresh one with its things on it.
        XCTAssertEqual(shelf.makeBoard(from: own)?.items.first?.text, "What went well")
    }

    /// The device's search is told every word of a board (the first 300 letters were all it knew), up to 20 000 letters.
    func testTheDevicesSearchKnowsEveryWordOfABoard() {
        var board = Board(title: "Summer cabin")
        var last = board.add(.note, centre: .zero, text: "First words")
        for n in 0..<60 { last = board.add(.note, centre: CGPoint(x: Double(n) * 200, y: 300), text: "Filler note number \(n)") }
        let far = board.add(.box, centre: CGPoint(x: 0, y: 900), text: "Zanzibar")
        board.link(from: last, to: far, text: "Afterwards")
        XCTAssertFalse(Outside.searchWords(of: board).contains("Zanzibar"))          // the short description still stops early
        let text = Outside.searchText(of: board)
        XCTAssertTrue(text.hasPrefix("Summer cabin\nFirst words\n"))
        XCTAssertTrue(text.contains("Zanzibar"))
        XCTAssertTrue(text.contains("Afterwards"))                                   // the words on an arrow too
        XCTAssertEqual(Outside.searchText(of: board, limit: 30).count, 30)
        var huge = Board(title: "Huge")
        for _ in 0..<300 { huge.add(.note, centre: .zero, text: String(repeating: "word ", count: 20)) }
        XCTAssertEqual(Outside.searchText(of: huge).count, 20_000)
    }

    /// A Handoff offer travels as plain words and numbers and is read back whole; what cannot be read is left out.
    func testAHandoffOfferTravelsAsPlainValues() {
        let changed = Date(timeIntervalSinceReferenceDate: 800_000_123.456)
        let offer = Handoff.Offer(id: a, changed: changed, view: LeftView(scale: 1.5, x: 40, y: -20))
        let info = Handoff.info(for: offer)
        XCTAssertTrue(info.values.allSatisfy { $0 is String || $0 is Double })
        XCTAssertEqual(Handoff.offer(from: info), offer)
        // Numbers may come back boxed.
        let boxed: [AnyHashable: Any] = ["id": a.uuidString, "changed": NSNumber(value: 5.0), "scale": NSNumber(value: 2), "x": NSNumber(value: 1), "y": NSNumber(value: 3)]
        XCTAssertEqual(Handoff.offer(from: boxed), Handoff.Offer(id: a, changed: Date(timeIntervalSinceReferenceDate: 5), view: LeftView(scale: 2, x: 1, y: 3)))
        XCTAssertEqual(Handoff.offer(from: ["id": a.uuidString]), Handoff.Offer(id: a))
        XCTAssertEqual(Handoff.offer(from: ["id": a.uuidString, "scale": 0.0, "x": 1.0, "y": 1.0])?.view, nil)   // no sound view
        XCTAssertNil(Handoff.offer(from: ["id": "not a board"]))
        XCTAssertNil(Handoff.offer(from: nil))
        XCTAssertEqual(Handoff.activityType, "com.schabbauer.AMSSeedboard.board")
    }

    /// Handoff can be faster than iCloud: an older copy waits for the newest version, at most 20 seconds.
    func testAnOlderCopyWaitsForTheNewestVersionAtMostTwentySeconds() {
        let there = Date(timeIntervalSinceReferenceDate: 800_000_000)
        XCTAssertEqual(Handoff.step(here: there, there: there, waited: 0), .open)
        XCTAssertEqual(Handoff.step(here: there.addingTimeInterval(60), there: there, waited: 0), .open)        // this device is newer
        XCTAssertEqual(Handoff.step(here: there.addingTimeInterval(-0.001), there: there, waited: 0), .open)    // the same moment, as stored
        XCTAssertEqual(Handoff.step(here: there.addingTimeInterval(-5), there: there, waited: 0), .wait)
        XCTAssertEqual(Handoff.step(here: there.addingTimeInterval(-5), there: there, waited: 19.9), .wait)
        XCTAssertEqual(Handoff.step(here: there.addingTimeInterval(-5), there: there, waited: 20), .openWhatIsHere)
        XCTAssertEqual(Handoff.step(here: there, there: nil, waited: 0), .open)                                 // the offer names no time
        XCTAssertEqual(Handoff.longestWait, 20)
        XCTAssertEqual(Handoff.waitingLine, "Waiting for the newest version from iCloud…")
    }
}
