import XCTest
import CoreGraphics
@testable import SeedboardCore

/// 0.5, pick 24: Share › Seedboard. The waiting list, what a share becomes, which board it goes to, and how
/// the things are laid.
final class Extension05Tests: XCTestCase {
    private let share = UUID()

    /// One arrival is one line whatever its words hold; a line that cannot be read is neither read nor lost.
    func testTheWaitingListIsOneLinePerArrivalAndLosesNothing() {
        let words = Arrival(share: share, board: Arrival.newBoard, kind: .text, words: "Two\nlines \"quoted\"")
        let link = Arrival(share: share, board: UUID().uuidString, kind: .link, words: "Apple", address: "https://apple.com")
        var text = ArrivalList.adding([words], to: "")
        XCTAssertEqual(text.filter(\.isNewline).count, 1)
        text = ArrivalList.adding([link], to: text + "{ a line from a newer Seedboard }\n")
        XCTAssertEqual(ArrivalList.read(text), [words, link])

        // Emptying takes only what was laid; the rest stays exactly as it was written.
        let rest = ArrivalList.text(text, without: [words.id])
        XCTAssertEqual(ArrivalList.read(rest), [link])
        XCTAssertTrue(rest.contains("{ a line from a newer Seedboard }"))
        XCTAssertEqual(ArrivalList.text(ArrivalList.adding([words], to: ""), without: [words.id]), "")
        // A list whose last line has no line break still takes a new line cleanly.
        XCTAssertEqual(ArrivalList.read(ArrivalList.adding([link], to: ArrivalList.line(words)!)), [words, link])
    }

    /// A link is one arrival with the page's title; words are their own arrival unless they only repeat the link.
    func testWhatAShareBecomes() {
        let page = Arrivals.made(share: share, board: "new", text: "", title: "Apple", address: "https://apple.com", pictures: [])
        XCTAssertEqual(page.map(\.kind), [.link])
        XCTAssertEqual(page[0].words, "Apple")
        XCTAssertEqual(page[0].address, "https://apple.com")

        // The address shared as words too (Safari does) is not a second thing; one line of words names the link.
        XCTAssertEqual(Arrivals.made(share: share, board: "new", text: "https://apple.com", title: "", address: "https://apple.com", pictures: []).map(\.kind), [.link])
        let named = Arrivals.made(share: share, board: "new", text: "Read this later", title: "", address: "https://apple.com", pictures: [])
        XCTAssertEqual(named.map(\.kind), [.link])
        XCTAssertEqual(named[0].words, "Read this later")

        // A link with a title AND several lines of words: both come.
        let both = Arrivals.made(share: share, board: "new", text: "Milk\nBread", title: "Shop", address: "https://shop.example", pictures: [])
        XCTAssertEqual(both.map(\.kind), [.link, .text])
        XCTAssertEqual(both[1].words, "Milk\nBread")

        // Pictures keep the identity they were kept under, 10 at most; long words are cut at 20 000 letters.
        let ids = (0..<12).map { _ in UUID() }
        let many = Arrivals.made(share: share, board: "new", text: String(repeating: "a", count: 30_000), title: "", address: nil, pictures: ids)
        XCTAssertEqual(many.filter { $0.kind == .picture }.map(\.id), Array(ids.prefix(10)))
        XCTAssertEqual(many.first { $0.kind == .picture }?.picture, ids[0].uuidString + ".jpg")
        XCTAssertEqual(many.first { $0.kind == .text }?.words.count, 20_000)
        XCTAssertTrue(many.allSatisfy { $0.share == share && $0.board == "new" })
        XCTAssertEqual(Arrivals.made(share: share, board: "new", text: "  \n ", title: "", address: nil, pictures: []), [])
    }

    /// A link becomes a sticky note: the title, then the address on its own line.
    func testALinkBecomesANoteWithTitleAndAddress() {
        let link = Arrival(share: share, board: "new", kind: .link, words: "Apple\n(Sweden)", address: "https://apple.com/se")
        XCTAssertEqual(Arrivals.noteWords(of: link), "Apple (Sweden)\nhttps://apple.com/se")
        let bare = Arrival(share: share, board: "new", kind: .link, words: "", address: "https://apple.com/se")
        XCTAssertEqual(Arrivals.noteWords(of: bare), "https://apple.com/se")

        var board = Board(title: "B")
        XCTAssertEqual(board.land([link]), [link.id])
        XCTAssertEqual(board.item(link.id)?.kind, .note)
        XCTAssertEqual(board.item(link.id)?.text, "Apple (Sweden)\nhttps://apple.com/se")
    }

    /// The words the owner reads: on the share page, and in the app when the things have landed.
    func testTheWordsForWhatCame() {
        func one(_ kind: Arrival.Kind) -> Arrival { Arrival(share: share, board: "new", kind: kind) }
        XCTAssertEqual(Arrivals.whatCame([one(.link)]), "A link")
        XCTAssertEqual(Arrivals.whatCame([one(.text)]), "Words")
        XCTAssertEqual(Arrivals.whatCame([one(.picture)]), "1 picture")
        XCTAssertEqual(Arrivals.whatCame([one(.text), one(.picture), one(.picture)]), "Words and 2 pictures")
        XCTAssertEqual(Arrivals.whatCame([one(.link), one(.text), one(.picture)]), "A link, words and 1 picture")
        XCTAssertEqual(Arrivals.whatCame([]), "Nothing to send")
        XCTAssertEqual(Arrivals.cameLine(1), "1 thing came in from Share.")
        XCTAssertEqual(Arrivals.cameLine(2), "2 things came in from Share.")
        XCTAssertEqual(Arrivals.lostLine(1), "1 picture from Share could not be read.")
        XCTAssertEqual(Arrivals.lostLine(3), "3 pictures from Share could not be read.")
    }

    /// A board made for a share is named after its words, else the link, else "Shared pictures".
    func testTheNameOfABoardMadeForAShare() {
        let words = Arrival(share: share, board: "new", kind: .text, words: "Ideas for the garden\nmore")
        let link = Arrival(share: share, board: "new", kind: .link, words: "", address: "https://www.apple.com/se/iphone")
        let picture = Arrival(share: share, board: "new", kind: .picture, picture: "A.jpg")
        XCTAssertEqual(Arrivals.boardName(for: [picture, link, words]), "Ideas for the garden")
        XCTAssertEqual(Arrivals.boardName(for: [picture, link]), "apple.com")
        var titled = link
        titled.words = "iPhone"
        XCTAssertEqual(Arrivals.boardName(for: [titled]), "iPhone")
        XCTAssertEqual(Arrivals.boardName(for: [picture]), "Shared pictures")
    }

    /// The picked board when things can be laid on it; otherwise ONE new board per share, the same one every time.
    func testWhichBoardAnArrivalGoesTo() {
        let cabin = Board(title: "Cabin")
        var plan = Board(title: "Plan")
        plan.kind = Board.sequenceKind
        let gone = UUID()
        let other = UUID()
        let list = [
            Arrival(share: share, board: cabin.id.uuidString, kind: .text, words: "a"),
            Arrival(share: share, board: "new", kind: .text, words: "b"),
            Arrival(share: share, board: gone.uuidString, kind: .text, words: "c"),          // removed meanwhile
            Arrival(share: share, board: plan.id.uuidString, kind: .text, words: "d"),      // places its own things
            Arrival(share: other, board: "new", kind: .text, words: "e"),
            Arrival(share: share, board: cabin.id.uuidString, kind: .text, words: "f"),
        ]
        let groups = Arrivals.groups(list, boards: [cabin, plan])
        XCTAssertEqual(groups.map(\.board), [cabin.id, share, other])
        XCTAssertEqual(groups.map(\.isNew), [false, true, true])
        XCTAssertEqual(groups.map { $0.arrivals.map(\.words) }, [["a", "f"], ["b", "c", "d"], ["e"]])
        // Read a second time, after the new board was made: the same board, no longer new.
        let again = Arrivals.groups(list, boards: [cabin, plan, Board(id: share, title: "b")])
        XCTAssertEqual(again.map(\.board), [cabin.id, share, other])
        XCTAssertEqual(again.map(\.isNew), [false, false, true])
    }

    /// Arrivals lie in a free column to the right, one under the other; nothing is covered, moved or laid twice.
    func testArrivalsLandBesideEverythingAndOnlyOnce() {
        var board = Board(title: "B", items: [Item(kind: .note, x: 0, y: 0), Item(kind: .box, x: 300, y: 200)])
        let old = board.items
        let words = Arrival(share: share, board: "x", kind: .text, words: "One thought")
        let list = Arrival(share: share, board: "x", kind: .text, words: "Trip\n\tFlights\n\tHotel")
        let picture = Arrival(share: share, board: "x", kind: .picture, picture: "P.jpg")
        let unread = Arrival(share: share, board: "x", kind: .picture, picture: "Q.jpg")
        let empty = Arrival(share: share, board: "x", kind: .text, words: "  ")

        let laid = board.land([words, list, picture, unread, empty], pixels: [picture.id: CGSize(width: 800, height: 600)])
        XCTAssertEqual(laid, [words.id, list.id, picture.id])
        XCTAssertEqual(Array(board.items.prefix(2)), old)                                    // nothing was moved
        let box = old.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let new = board.items.dropFirst(2)
        XCTAssertTrue(new.allSatisfy { $0.frame.minX >= box.maxX + 40 - 0.001 })           // a free column to the right
        XCTAssertEqual(board.item(words.id)?.kind, .note)
        XCTAssertEqual(board.item(words.id)?.frame.origin, CGPoint(x: box.maxX + 40, y: box.minY))

        // A list is a mind map: its middle carries the arrival's identity and its ideas hang on it.
        XCTAssertEqual(board.item(list.id)?.kind, .idea)
        XCTAssertEqual(board.item(list.id)?.text, "Trip")
        XCTAssertEqual(Set(board.children(of: list.id).map(\.text)), ["Flights", "Hotel"])
        let map = board.items.filter { $0.id == list.id || $0.parent == list.id }.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        XCTAssertEqual(map.minY, board.item(words.id)!.frame.maxY + 16, accuracy: 0.001)   // under the first, 16 apart
        XCTAssertEqual(map.minX, box.maxX + 40, accuracy: 0.001)

        // The picture is a picture thing that names its file, under the map.
        XCTAssertEqual(board.item(picture.id)?.picture, "P.jpg")
        XCTAssertEqual(board.item(picture.id)!.frame.minY, map.maxY + 16, accuracy: 0.001)
        XCTAssertNil(board.item(unread.id))                                                  // no picture, no thing

        // The same lines read again lay nothing.
        let count = board.items.count
        XCTAssertEqual(board.land([words, list, picture], pixels: [picture.id: CGSize(width: 800, height: 600)]), [])
        XCTAssertEqual(board.items.count, count)

        // Nothing is laid on a board that places its own things.
        var plan = Board(title: "Plan")
        plan.kind = Board.sequenceKind
        XCTAssertEqual(plan.land([words]), [])
        XCTAssertTrue(plan.items.isEmpty)
    }

    /// The share page is told the pinned boards first, then the newest, 30 at most, and only boards that take things.
    func testTheBoardsTheSharePageOffers() {
        let day = Date(timeIntervalSince1970: 1_000_000)
        var boards = (0..<35).map { Board(title: "B\($0)", created: day, changed: day.addingTimeInterval(Double($0))) }
        boards[3].pinned = true
        boards[20].pinned = true
        boards[34].kind = Board.sequenceKind
        boards[33].format = Board.currentFormat + 1
        let list = ShareBoards.list(of: boards)
        XCTAssertEqual(list.count, 30)
        XCTAssertEqual(list.prefix(4).map(\.name), ["B20", "B3", "B32", "B31"])
        XCTAssertFalse(list.contains { $0.name == "B34" || $0.name == "B33" })
        XCTAssertEqual(list[0].colour, boards[20].colour)
        // Written and read back; one broken entry does not lose the others.
        XCTAssertEqual(ShareBoards.read(ShareBoards.data(of: list)), list)
        let half = Data(#"[{"id":"\#(list[0].id.uuidString)","name":"A","colour":"pink","pinned":true},{"name":"no id"}]"#.utf8)
        XCTAssertEqual(ShareBoards.read(half), [ShareBoard(id: list[0].id, name: "A", colour: "pink", pinned: true)])
    }
}
