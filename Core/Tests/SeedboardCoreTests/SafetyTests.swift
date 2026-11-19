import XCTest
@testable import SeedboardCore

/// The data-safety rules of 0.2 (S1–S7 of Docs/PANEL-0.2.md).
final class SafetyTests: XCTestCase {
    private let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func board(_ seconds: Double, title: String = "B") -> Board {
        Board(id: id, title: title, created: t0, changed: t0.addingTimeInterval(seconds))
    }

    // MARK: S1

    func testNewsThatArrivesWhileTypingIsHeldAndOfferedAgain() {
        let shown = t0, news = t0.addingTimeInterval(60)
        // Typing: the other device's version is not shown and not thrown away.
        XCTAssertEqual(SafetyRules.news(incoming: news, shown: shown, busy: true), .hold)
        // Typing ended without a change: the held version is taken now.
        XCTAssertEqual(SafetyRules.news(incoming: news, shown: shown, busy: false), .take)
        // Typing ended with a change (a later stamp): mine stays on screen.
        XCTAssertEqual(SafetyRules.news(incoming: news, shown: news.addingTimeInterval(5), busy: false), .ignore)
        // The same version read back from its file (thousandths only) is not news.
        XCTAssertEqual(SafetyRules.news(incoming: shown.addingTimeInterval(0.0004), shown: shown, busy: false), .ignore)
    }

    func testAStoredVersionTheBoardDidNotGrowFromIsKeptBeforeItIsWrittenOver() {
        var lineage = Lineage()
        lineage.add(t0)                                   // the version this device showed
        let mine = board(120, title: "mine")
        let grewFrom = board(0)
        let foreign = board(60, title: "theirs")         // written by another device, never shown here
        XCTAssertEqual(SafetyRules.write(mine: mine, stored: nil, storedIsSame: false, inLineage: false), .write)
        XCTAssertEqual(SafetyRules.write(mine: mine, stored: grewFrom, storedIsSame: false,
                                         inLineage: lineage.holds(grewFrom.changed)), .write)
        XCTAssertEqual(SafetyRules.write(mine: mine, stored: foreign, storedIsSame: false,
                                         inLineage: lineage.holds(foreign.changed)), .keepStoredThenWrite)
        // Once the app has shown their version, it is part of what the board grew from.
        lineage.add(foreign.changed.addingTimeInterval(0.0004))
        XCTAssertTrue(lineage.holds(foreign.changed))
        // The stored one is newer: it stays, mine is set aside.
        XCTAssertEqual(SafetyRules.write(mine: board(30), stored: foreign, storedIsSame: false, inLineage: false), .storedStays)
        XCTAssertEqual(SafetyRules.write(mine: mine, stored: mine, storedIsSame: true, inLineage: true), .nothing)
        // A version from a newer app is never written over.
        var newer = board(10)
        newer.format = Board.currentFormat + 1
        XCTAssertEqual(SafetyRules.write(mine: mine, stored: newer, storedIsSame: false, inLineage: true), .refuse)
        XCTAssertTrue(SafetyRules.wins(newer, over: mine))
        XCTAssertTrue(SafetyRules.wins(mine, over: foreign))
    }

    // MARK: S2

    func testRemovalMarkCarriesItsTimeAndAnOldEmptyMarkCountsFromItsFileDate() {
        let removed = t0.addingTimeInterval(0.25)
        let data = RemovalMark.data(removedAt: removed)
        let read = RemovalMark.removedAt(from: data, fileDate: .distantPast)
        XCTAssertEqual(read!.timeIntervalSince1970, removed.timeIntervalSince1970, accuracy: 0.001)
        let fileDate = t0.addingTimeInterval(-500)
        XCTAssertEqual(RemovalMark.removedAt(from: Data(), fileDate: fileDate), fileDate)
        XCTAssertEqual(RemovalMark.removedAt(from: nil, fileDate: fileDate), fileDate)
        XCTAssertEqual(RemovalMark.removedAt(from: Data("junk".utf8), fileDate: fileDate), fileDate)
        XCTAssertNil(RemovalMark.removedAt(from: Data(), fileDate: nil))
        // A removal is always later than the board's last change, even with a slow clock.
        XCTAssertGreaterThan(RemovalMark.time(now: t0, lastChange: t0.addingTimeInterval(90)), t0.addingTimeInterval(90))
        XCTAssertEqual(RemovalMark.time(now: t0, lastChange: t0.addingTimeInterval(-90)), t0)
    }

    func testAChangeMadeAfterTheRemovalBringsTheBoardBack() {
        let removed = t0
        XCTAssertEqual(SafetyRules.removal(removedAt: removed, lastChange: t0.addingTimeInterval(-60)), .staysRemoved)
        XCTAssertEqual(SafetyRules.removal(removedAt: removed, lastChange: t0), .staysRemoved)
        XCTAssertEqual(SafetyRules.removal(removedAt: removed, lastChange: nil), .staysRemoved)
        XCTAssertEqual(SafetyRules.removal(removedAt: removed, lastChange: t0.addingTimeInterval(60)), .comesBack)
        // The removal's own time never brings the board straight back.
        let last = t0.addingTimeInterval(7)
        XCTAssertEqual(SafetyRules.removal(removedAt: RemovalMark.time(now: t0, lastChange: last), lastChange: last), .staysRemoved)
    }

    // MARK: S3

    func testFileNamesOfBoardsCopiesAndMarksAreAllRead() {
        let u = id.uuidString
        XCTAssertEqual(BoardFileName("\(u).seedboard"), BoardFileName("\(u).seedboard"))
        let own = BoardFileName("\(u).seedboard")
        XCTAssertEqual(own?.id, id)
        XCTAssertEqual(own?.kind, .board)
        XCTAssertNil(own?.copy)
        XCTAssertEqual(own?.waiting, false)
        // iCloud's own copies: never skipped.
        XCTAssertEqual(BoardFileName("\(u) 2.seedboard")?.copy, 2)
        XCTAssertEqual(BoardFileName("\(u) 2.seedboard")?.id, id)
        XCTAssertEqual(BoardFileName("\(u) 14.seedboard")?.copy, 14)
        // Not arrived yet.
        let waiting = BoardFileName(".\(u) 3.seedboard.icloud")
        XCTAssertEqual(waiting?.copy, 3)
        XCTAssertEqual(waiting?.waiting, true)
        XCTAssertEqual(waiting?.name, "\(u) 3.seedboard")
        XCTAssertEqual(BoardFileName("\(u).gone")?.kind, .removalMark)
        XCTAssertEqual(BoardFileName(".\(u).gone.icloud")?.waiting, true)
        XCTAssertNil(BoardFileName("notes.txt"))
        XCTAssertNil(BoardFileName("Summer cabin.seedboard"))
        XCTAssertNil(BoardFileName("\(u) x.seedboard"))
        XCTAssertNil(BoardFileName(".DS_Store"))
    }

    // MARK: S4

    func testAKindThisVersionDoesNotKnowMakesTheBoardReadOnlyAndIsWrittenBack() throws {
        let a = "22222222-2222-2222-2222-222222222222", b = "33333333-3333-3333-3333-333333333333"
        let json = #"{"id":"\#(id.uuidString)","format":1,"items":[{"id":"\#(a)","kind":"hexagon","text":"x"},{"id":"\#(b)","kind":"box"}],"links":[{"from":"\#(a)","to":"\#(b)","style":"zigzag"}]}"#
        let board = try JSONDecoder().decode(Board.self, from: Data(json.utf8))
        XCTAssertFalse(board.canBeChanged)
        XCTAssertTrue(board.holdsUnknownKinds)
        XCTAssertEqual(board.items[0].kind, .box)          // drawn as a box
        XCTAssertEqual(board.items[0].unknownKind, "hexagon")
        XCTAssertEqual(board.links[0].unknownStyle, "zigzag")
        let again = try JSONSerialization.jsonObject(with: JSONEncoder().encode(board)) as! [String: Any]
        XCTAssertEqual((again["items"] as! [[String: Any]])[0]["kind"] as? String, "hexagon")
        XCTAssertEqual((again["items"] as! [[String: Any]])[1]["kind"] as? String, "box")
        XCTAssertEqual((again["links"] as! [[String: Any]])[0]["style"] as? String, "zigzag")
        // Only an arrow of an unknown kind is enough.
        let arrowOnly = try JSONDecoder().decode(Board.self, from: Data(#"{"id":"\#(id.uuidString)","links":[{"from":"\#(a)","to":"\#(b)","style":"zigzag"}]}"#.utf8))
        XCTAssertFalse(arrowOnly.canBeChanged)
        XCTAssertTrue(try JSONDecoder().decode(Board.self, from: Data(#"{"id":"\#(id.uuidString)","items":[{"kind":"note"}]}"#.utf8)).canBeChanged)
    }

    func testFieldsThisVersionDoesNotKnowAreCarriedThroughALoadAndASave() throws {
        let a = "22222222-2222-2222-2222-222222222222", b = "33333333-3333-3333-3333-333333333333"
        let json = """
        {"id":"\(id.uuidString)","title":"T","lanes":{"count":3,"names":["a","b"],"on":true,"gap":1.5,"none":null},
         "items":[{"id":"\(a)","kind":"box","text":"x","note":"a long note","pressure":[0.25,1]}],
         "links":[{"id":"\(b)","from":"\(a)","to":"\(a)","dashed":true,"ends":"both"}]}
        """
        var board = try JSONDecoder().decode(Board.self, from: Data(json.utf8))
        XCTAssertTrue(board.canBeChanged)
        XCTAssertEqual(board.items[0].extra["note"], .string("a long note"))
        // A change made by this version leaves them alone.
        board.title = "Changed"
        board.items[0].text = "y"
        board.touch()
        let out = try JSONSerialization.jsonObject(with: JSONEncoder().encode(board)) as! [String: Any]
        let lanes = out["lanes"] as! [String: Any]
        XCTAssertEqual(lanes["count"] as? Int, 3)
        XCTAssertEqual(lanes["names"] as? [String], ["a", "b"])
        XCTAssertEqual(lanes["on"] as? Bool, true)
        XCTAssertEqual(lanes["gap"] as? Double, 1.5)
        XCTAssertTrue(lanes["none"] is NSNull)
        let item = (out["items"] as! [[String: Any]])[0]
        XCTAssertEqual(item["note"] as? String, "a long note")
        XCTAssertEqual(item["pressure"] as? [Double], [0.25, 1])
        XCTAssertEqual(item["text"] as? String, "y")
        let link = (out["links"] as! [[String: Any]])[0]
        XCTAssertEqual(link["dashed"] as? Bool, true)
        XCTAssertEqual(link["ends"] as? String, "both")
        XCTAssertEqual(out["title"] as? String, "Changed")
        // And a second round trip gives the same board.
        XCTAssertEqual(try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board)), board)
    }

    // MARK: S6

    /// A copy of PARAGON's reader (`CaptureItem` and `CaptureTarget` in AMS-PARA, Core/Sources/ParagonCore/Vault/Capture.swift,
    /// read on 18 Nov 2026, build 339). If PARAGON changes its line, change this copy with it.
    private enum ParagonCaptureTarget: Codable, Equatable {
        case inbox
        case today
        case note(path: String)
    }

    private struct ParagonCaptureItem: Codable, Equatable {
        var id: UUID
        var text: String
        var url: URL?
        var target: ParagonCaptureTarget
        var asTask: Bool
        var createdAt: Date
        var files: [String]?
    }

    func testTheInboxWaitingLineIsReadByParagonsOwnReader() throws {
        var board = Board(title: "Trip")
        let first = board.add(.box, centre: .zero, text: "Buy\ntickets")
        let second = board.add(.note, centre: .zero, text: "Pack")
        board.items[board.index(of: first)!].todo = true
        board.items[board.index(of: second)!].todo = true
        let lines = ParagonExport.taskLines(ParagonExport.inboxTasks(board: board), now: t0)
            + [ParagonExport.noteLine(title: "Trip", now: t0)]
        let data = try ParagonExport.waitingData(lines)
        // PARAGON reads the file line by line, dates as ISO 8601, and skips a line it cannot read.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let read = try data.split(separator: 0x0A).map { try decoder.decode(ParagonCaptureItem.self, from: $0) }
        XCTAssertEqual(read.count, 3)
        XCTAssertEqual(read.map(\.text), ["Buy tickets", "Pack", "[[Trip]] — a board from Seedboard"])
        XCTAssertEqual(read.map(\.asTask), [true, true, false])
        XCTAssertEqual(read.map(\.target), [.inbox, .inbox, .inbox])
        XCTAssertEqual(read.map(\.createdAt), [t0, t0.addingTimeInterval(1), t0])
        XCTAssertEqual(Set(read.map(\.id)).count, 3)
        XCTAssertNil(read[0].url)
        XCTAssertNil(read[0].files)
        XCTAssertEqual(data.last, 0x0A)
    }

    func testOnlyAFolderParagonUsesCountsAsItsNotes() {
        XCTAssertTrue(ParagonExport.looksLikeParagonFolder(["Inbox.md", "Projects"]))
        XCTAssertTrue(ParagonExport.looksLikeParagonFolder([".Inbox.md.icloud"]))
        XCTAssertTrue(ParagonExport.looksLikeParagonFolder([".ams-para/config.json", "Projects"]))
        // A bare Projects folder can be a folder PARAGON never used.
        XCTAssertFalse(ParagonExport.looksLikeParagonFolder(["Projects"]))
        XCTAssertFalse(ParagonExport.looksLikeParagonFolder([]))
    }

    // MARK: S7

    func testALinkThatArrivesBeforeTheBoardsAreLoadedIsHeld() {
        let url = URL(string: ParagonExport.boardLink(id))!
        XCTAssertEqual(BoardLink.id(from: url), id)
        XCTAssertNil(BoardLink.id(from: URL(string: "seedboard://note/\(id.uuidString)")!))
        XCTAssertNil(BoardLink.id(from: URL(string: "amspara://board/\(id.uuidString)")!))
        XCTAssertNil(BoardLink.id(from: URL(string: "seedboard://board/nonsense")!))
        XCTAssertEqual(BoardLink.answer(loaded: false, onDevice: false, removedAt: nil), .hold)
        XCTAssertEqual(BoardLink.answer(loaded: false, onDevice: true, removedAt: nil), .hold)
        XCTAssertEqual(BoardLink.answer(loaded: true, onDevice: true, removedAt: nil), .open)
        XCTAssertEqual(BoardLink.answer(loaded: true, onDevice: false, removedAt: t0), .removed(t0))
        XCTAssertEqual(BoardLink.answer(loaded: true, onDevice: false, removedAt: nil), .missing)
        XCTAssertEqual(BoardLink.removedLine(Date(timeIntervalSince1970: 1_795_000_000), timeZone: TimeZone(identifier: "UTC")!),
                       "This board was removed on 18 Nov 2026.")
    }
}

/// Fails when a stored field is added (or renamed, or dropped) without raising `Board.currentFormat`.
/// An older app carries a field it does not know, but it cannot USE it, so a new field always means a new
/// format number: add the new list below under the new number, and leave the old lists as they are.
/// Since format 5 the test also proves that every field is really WRITTEN (a field with a name and a reading
/// line but no writing line was silently not saved), and it watches strokes, lanes, starters and sent tasks too.
final class StoredFieldsTests: XCTestCase {
    private struct Fields: Equatable {
        var board: [String], item: [String], link: [String], sent: [String]
        var stroke: [String] = [], lanes: [String] = [], starter: [String] = [], sentTask: [String] = []
    }

    private let golden: [Int: Fields] = [
        1: Fields(board: ["changed", "colour", "created", "format", "id", "items", "links", "pinned", "sent", "sentTodos", "title"],
                  item: ["bothSides", "colour", "folded", "h", "id", "kind", "order", "parent", "text", "todo", "w", "x", "y"],
                  link: ["colour", "from", "head", "id", "style", "text", "to"],
                  sent: ["kind", "path", "title", "when"]),
        // 0.2: a main branch remembers its side. (The lead adds the other 0.2 fields here when the builders' work is joined.)
        2: Fields(board: ["changed", "colour", "created", "format", "id", "items", "kind", "links", "pinned", "sent", "sentTodos", "title"],
                  item: ["answer", "bothSides", "colour", "end", "folded", "from", "h", "id", "kind", "lanes", "order", "parent", "row", "side", "start", "strokes", "text", "to", "todo", "w", "x", "y"],
                  link: ["colour", "dashed", "from", "fromSide", "head", "id", "style", "tail", "text", "to", "toSide"],
                  sent: ["kind", "path", "title", "when"]),
        // 0.3: a picture on a board names its file.
        3: Fields(board: ["changed", "colour", "created", "format", "id", "items", "kind", "links", "pinned", "sent", "sentTodos", "title"],
                  item: ["answer", "bothSides", "colour", "end", "folded", "from", "h", "id", "kind", "lanes", "order", "parent", "picture", "row", "side", "start", "strokes", "text", "to", "todo", "w", "x", "y"],
                  link: ["colour", "dashed", "from", "fromSide", "head", "id", "style", "tail", "text", "to", "toSide"],
                  sent: ["kind", "path", "title", "when"]),
        // 0.4: a picture can show only a part of itself.
        4: Fields(board: ["changed", "colour", "created", "format", "id", "items", "kind", "links", "pinned", "sent", "sentTodos", "title"],
                  item: ["answer", "bothSides", "colour", "crop", "end", "folded", "from", "h", "id", "kind", "lanes", "order", "parent", "picture", "row", "side", "start", "strokes", "text", "to", "todo", "w", "x", "y"],
                  link: ["colour", "dashed", "from", "fromSide", "head", "id", "style", "tail", "text", "to", "toSide"],
                  sent: ["kind", "path", "title", "when"]),
        // 0.5: a door to another board, the day a bar was done, every thing that became a PARAGON task.
        // From here on every list must match exactly, and strokes, lanes, starters and sent tasks are watched too.
        5: Fields(board: ["changed", "colour", "created", "format", "id", "items", "kind", "links", "pinned", "sent", "sentTasks", "sentTodos", "title"],
                  item: ["answer", "bothSides", "colour", "crop", "doneDay", "door", "end", "folded", "from", "h", "id", "kind", "lanes", "order", "parent", "picture", "row", "side", "start", "strokes", "text", "to", "todo", "w", "x", "y"],
                  link: ["colour", "dashed", "from", "fromSide", "head", "id", "style", "tail", "text", "to", "toSide"],
                  sent: ["kind", "path", "title", "when"],
                  stroke: ["colour", "points", "pressure", "width"],
                  lanes: ["cuts", "names", "way"],
                  starter: ["board", "boardChanged", "builtin", "changed", "hint", "id", "name", "order", "removed", "removedWhen"],
                  sentTask: ["id", "place", "words"]),
        // 0.9: vote dots, pinned in place, a web page's title, words inside a picture; legend, background,
        // numbered steps, put away; the highlighter pen.
        6: Fields(board: ["backdrop", "changed", "colour", "created", "format", "id", "items", "kind", "legend", "links", "numberSteps", "pinned", "putAway", "sent", "sentTasks", "sentTodos", "title"],
                  item: ["answer", "bothSides", "colour", "crop", "doneDay", "door", "end", "folded", "from", "h", "id", "kind", "lanes", "linkTitle", "locked", "order", "parent", "picture", "pictureWords", "row", "side", "start", "strokes", "text", "to", "todo", "votes", "w", "x", "y"],
                  link: ["colour", "dashed", "from", "fromSide", "head", "id", "style", "tail", "text", "to", "toSide"],
                  sent: ["kind", "path", "title", "when"],
                  stroke: ["colour", "pen", "points", "pressure", "width"],
                  lanes: ["cuts", "names", "way"],
                  starter: ["board", "boardChanged", "builtin", "changed", "hint", "id", "name", "order", "removed", "removedWhen"],
                  sentTask: ["id", "place", "words"]),
        // 0.11: a board's own due day.
        7: Fields(board: ["backdrop", "changed", "colour", "created", "due", "format", "id", "items", "kind", "legend", "links", "numberSteps", "pinned", "putAway", "sent", "sentTasks", "sentTodos", "title"],
                  item: ["answer", "bothSides", "colour", "crop", "doneDay", "door", "end", "folded", "from", "h", "id", "kind", "lanes", "linkTitle", "locked", "order", "parent", "picture", "pictureWords", "row", "side", "start", "strokes", "text", "to", "todo", "votes", "w", "x", "y"],
                  link: ["colour", "dashed", "from", "fromSide", "head", "id", "style", "tail", "text", "to", "toSide"],
                  sent: ["kind", "path", "title", "when"],
                  stroke: ["colour", "pen", "points", "pressure", "width"],
                  lanes: ["cuts", "names", "way"],
                  starter: ["board", "boardChanged", "builtin", "changed", "hint", "id", "name", "order", "removed", "removedWhen"],
                  sentTask: ["id", "place", "words"]),
    ]

    func testAStoredFieldIsNeverAddedWithoutANewFormatNumber() throws {
        let want = try XCTUnwrap(golden[Board.currentFormat],
                                 "Board.currentFormat was raised: add the list of stored fields for the new format here.")
        let message = "A stored field changed: raise Board.currentFormat and add the new list under the new number."
        let declared = Fields(board: Board.CodingKeys.allCases.map(\.rawValue).sorted(),
                              item: Item.CodingKeys.allCases.map(\.rawValue).sorted(),
                              link: Link.CodingKeys.allCases.map(\.rawValue).sorted(),
                              sent: SentInfo.CodingKeys.allCases.map(\.rawValue).sorted(),
                              stroke: Stroke.CodingKeys.allCases.map(\.rawValue).sorted(),
                              lanes: Lanes.CodingKeys.allCases.map(\.rawValue).sorted(),
                              starter: StarterEntry.CodingKeys.allCases.map(\.rawValue).sorted(),
                              sentTask: SentTask.CodingKeys.allCases.map(\.rawValue).sorted())
        XCTAssertEqual(declared, want, message)
    }

    /// A field with a name and a reading line but no writing line is silently not saved. So: fill EVERY field of an
    /// item, an arrow, a board, a stroke, lanes, a starter and a sent task, write them, and require the names in
    /// the file to be exactly the listed ones.
    func testEveryStoredFieldIsReallyWritten() throws {
        let want = try XCTUnwrap(golden[Board.currentFormat])
        let message = "A stored field is declared but not written (or written but not declared): add its encode line."
        let a = Item(kind: .idea, text: "a")
        var b = Item(kind: .idea, text: "b", parent: a.id)
        b.side = .left
        b.start = "2026-12-01"; b.end = "2026-12-05"; b.row = 2
        var lanes = Lanes(way: .columns, count: 3)
        lanes.names = ["one", "two", "three"]
        b.lanes = lanes
        b.from = a.id; b.to = a.id; b.answer = true
        var stroke = Stroke(colour: "blue", width: .thick, points: [0, 0, 4, 4], pressure: [0.5, 0.6])
        stroke.pen = "highlighter"
        b.strokes = [stroke]
        b.picture = "3F2A.jpg"
        b.crop = [0.1, 0.1, 0.5, 0.5]
        b.door = a.id
        b.doneDay = "2026-12-04"
        b.votes = 2; b.locked = true; b.linkTitle = "Page"; b.pictureWords = "words"
        var arrow = Link(from: a.id, to: b.id, text: "go")
        arrow.fromSide = .left; arrow.toSide = .right; arrow.tail = true; arrow.dashed = true
        var board = Board(title: "Full", items: [a, b], links: [arrow])
        board.kind = Board.timelineKind
        board.sent = SentInfo(when: Date(), kind: "note", title: "Full", path: "Resources/Full.md")
        board.sentTodos = [a.id]
        board.legend = ["yellow": "Open"]; board.backdrop = "dots"; board.numberSteps = true; board.putAway = Date(); board.due = "2027-01-12"
        board.noteSent(b.id, words: "b", place: SentTask.note)
        let starter = StarterEntry(id: "own-1", name: "Mine", hint: "h", order: 1, removed: true, removedWhen: Date(),
                                   builtin: "blank", board: board, changed: Date(), boardChanged: Date())

        let file = try JSONSerialization.jsonObject(with: JSONEncoder().encode(board)) as! [String: Any]
        let item = (file["items"] as! [[String: Any]])[1]
        let starterFile = try JSONSerialization.jsonObject(with: JSONEncoder().encode(starter)) as! [String: Any]
        let written = Fields(board: file.keys.sorted(),
                             item: item.keys.sorted(),
                             link: (file["links"] as! [[String: Any]])[0].keys.sorted(),
                             sent: (file["sent"] as! [String: Any]).keys.sorted(),
                             stroke: (item["strokes"] as! [[String: Any]])[0].keys.sorted(),
                             lanes: (item["lanes"] as! [String: Any]).keys.sorted(),
                             starter: starterFile.keys.sorted(),
                             sentTask: (file["sentTasks"] as! [[String: Any]])[0].keys.sorted())
        XCTAssertEqual(written, want, message)

        // And everything comes back as it was written.
        let back = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board))
        XCTAssertEqual(back, board)
        XCTAssertEqual(try JSONDecoder().decode(StarterEntry.self, from: JSONEncoder().encode(starter)).board, board)
    }

    func testAnArrivalNeverCoversWhatIsOnTheBoard() {
        var board = Board(title: "B", items: [Item(kind: .note, x: 0, y: 0), Item(kind: .box, x: 300, y: 200)])
        let size = CGSize(width: 150, height: 110)
        let first = board.arrivalSpot(size: size)
        let box = board.items.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        XCTAssertEqual(first, CGPoint(x: box.maxX + 40, y: box.minY))
        let firstFrame = CGRect(origin: first, size: size)
        XCTAssertFalse(board.items.contains { $0.frame.intersects(firstFrame) })
        // A second arrival in the same go lies under the first, 16 points apart.
        let second = board.arrivalSpot(size: size, taken: [firstFrame])
        XCTAssertEqual(second, CGPoint(x: first.x, y: firstFrame.maxY + 16))
        // An empty board: the middle, then under it.
        board.items = []
        let middle = board.arrivalSpot(size: size)
        XCTAssertEqual(middle, CGPoint(x: -75, y: -55))
        XCTAssertEqual(board.arrivalSpot(size: size, taken: [CGRect(origin: middle, size: size)]), CGPoint(x: -75, y: 55 + 16))
    }

    func testTheBoardKnowsWhatBecameATask() {
        var a = Item(kind: .box, text: "a"); a.todo = true
        let b = Item(kind: .box, text: "b")
        var board = Board(title: "B", items: [a, b])
        XCTAssertEqual(board.todoState(of: a.id), .waiting)
        XCTAssertNil(board.todoState(of: b.id))
        board.noteSent(a.id, words: "a", place: SentTask.inbox)
        board.noteSent(a.id, words: "a again", place: SentTask.note)
        XCTAssertEqual(board.sentTasks.count, 1)
        XCTAssertEqual(board.sentTask(a.id)?.words, "a again")
        XCTAssertEqual(board.todoState(of: a.id), .inParagon)
        // A board of 0.4 only has the list of sent boxes: still "in PARAGON".
        board.sentTasks = []; board.sentTodos = [a.id]
        XCTAssertEqual(board.todoState(of: a.id), .inParagon)
        board.items.removeAll { $0.id == a.id }
        board.noteSent(a.id, words: "a", place: SentTask.inbox)
        board.dropSentTasksOfMissingThings()
        XCTAssertTrue(board.sentTasks.isEmpty)
    }
}
