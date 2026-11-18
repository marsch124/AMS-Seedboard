import XCTest
@testable import SeedboardCore

/// 0.5, the data-safety lane: one small rule test for each of the panel's findings 1 to 11.
final class Safety05Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func scratch() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Safety05-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // 1
    func testAStarterWorkingCopyComesBackAfterTheAppWasStopped() throws {
        let folder = scratch()
        XCTAssertNil(StarterWorking.waiting(in: folder))
        let board = Board(title: "Weekly review", items: [Item(kind: .note, text: "ten new notes")])
        let work = StarterWorking(starter: "00000000-0000-0000-0000-0000000000A1", name: "Weekly review", board: board, when: now)
        XCTAssertTrue(work.write(in: folder))
        // The app was stopped; at the next start the work is there: the same starter, name and board.
        let back = try XCTUnwrap(StarterWorking.waiting(in: folder))
        XCTAssertEqual(back.starter, work.starter)
        XCTAssertEqual(back.name, "Weekly review")
        XCTAssertEqual(back.board, board)
        // The file is never read as a starter itself.
        let file = folder.appendingPathComponent(StarterWorking.fileName(work.starter))
        XCTAssertNil(try? JSONDecoder().decode(StarterEntry.self, from: Data(contentsOf: file)))
        XCTAssertNil(StarterFileName(file.lastPathComponent))
        // Save, Cancel or leaving ends the change: no file stays.
        StarterWorking.clear(in: folder)
        XCTAssertNil(StarterWorking.waiting(in: folder))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
        // A timeline that waited five days sits as far from today as it did.
        let plan = Board.timelineStart(title: "Trip", now: now)
        let late = StarterWorking(starter: "trip", name: "Trip", board: plan, when: now).board(now: now.addingTimeInterval(5 * 86_400))
        let a = plan.items.compactMap(\.start).compactMap { Day(iso: $0) }.min()!
        let b = late.items.compactMap(\.start).compactMap { Day(iso: $0) }.min()!
        XCTAssertEqual(b - a, 5)
    }

    // 2
    func testAMoveOrRenameNeverWinsOverANewerStarterBoard() throws {
        // Both devices hold "Weekly review" as it was at 9:00.
        var shelf = StarterShelf()
        let id = shelf.saveAs(Board(title: "W", changed: now, items: [Item(kind: .note, text: "old")]), name: "Weekly review", now: now)
        var pad = shelf, mac = shelf
        // iPad, 10:00: the content is changed.
        let new = Board(title: "W", changed: now, items: [Item(kind: .note, text: "old"), Item(kind: .note, text: "new")])
        pad.change(id, board: new, now: now.addingTimeInterval(3600))
        // Mac, 10:05, has not read that yet: one place up, and a new name.
        mac.move(id, to: 0, now: now.addingTimeInterval(3900))
        mac.rename(id, name: "Week", hint: "Mine", now: now.addingTimeInterval(3901))
        let padEntry = try XCTUnwrap(pad.entries[id]), macEntry = try XCTUnwrap(mac.entries[id])
        for joined in [StarterEntry.newer(padEntry, macEntry), StarterEntry.newer(macEntry, padEntry)] {
            // The Mac's name and place, the iPad's board.
            XCTAssertEqual(joined.name, "Week")
            XCTAssertEqual(joined.order, macEntry.order)
            XCTAssertEqual(joined.board?.items.count, 2)
        }
        XCTAssertEqual(StarterShelf(entries: [macEntry, padEntry]).starter(id)?.board?.items.count, 2)
        // A built-in that was only moved here never wins over its board changed elsewhere.
        var a = StarterShelf(), b = StarterShelf()
        a.change("flow", board: new, now: now)
        b.move("flow", to: 0, now: now.addingTimeInterval(60))
        XCTAssertEqual(StarterEntry.newer(a.entries["flow"]!, b.entries["flow"]!).board?.items.count, 2)
        // A file of 0.4 has no stamp for the content: it reads as before (the later copy wins whole).
        let old = StarterEntry(id: "x", name: "Old", board: Board(title: "1", changed: now), changed: now)
        let late = StarterEntry(id: "x", name: "Late", board: Board(title: "2", changed: now), changed: now.addingTimeInterval(5))
        XCTAssertEqual(StarterEntry.newer(old, late), late)
        // The replaced version is kept aside when its board differs, under a name that says when.
        XCTAssertTrue(StarterKept.keepAside(stored: padEntry, new: macEntry))
        XCTAssertFalse(StarterKept.keepAside(stored: padEntry, new: StarterEntry.newer(padEntry, macEntry)))
        XCTAssertFalse(StarterKept.keepAside(stored: nil, new: macEntry))
        let name = StarterKept.name(id: id, at: now, tag: "ABC123", timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(StarterKept.kept(name, timeZone: TimeZone(identifier: "UTC")!), now)
        XCTAssertNil(StarterKept.kept("\(id).seedstarter"))
        // … and goes after 30 days, like a set-aside board.
        let safety = scratch()
        try Data("x".utf8).write(to: safety.appendingPathComponent(name))
        XCTAssertEqual(KeptFiles.tidy(safety: safety, now: now.addingTimeInterval(29 * 86_400), timeZone: TimeZone(identifier: "UTC")!), 0)
        XCTAssertEqual(KeptFiles.tidy(safety: safety, now: now.addingTimeInterval(31 * 86_400), timeZone: TimeZone(identifier: "UTC")!), 1)
    }

    // 3
    func testAStarterThatHasNotArrivedIsNeverWrittenOverAndOfTwoCopiesTheNewerWins() {
        let mine = StarterEntry(id: "a", name: "Mine, older", board: Board(title: "1", changed: now), changed: now)
        // iCloud has not brought "a" yet: the device's older copy is shown, and iCloud's file is left alone.
        let waiting = StarterLevelling.plan(device: ["a": mine], cloudMain: [:], held: ["a"])
        XCTAssertEqual(waiting.best["a"], mine)
        XCTAssertTrue(waiting.toCloud.isEmpty)
        XCTAssertTrue(waiting.toDevice.isEmpty)
        // Not held, and not in iCloud at all: it goes up.
        XCTAssertEqual(StarterLevelling.plan(device: ["a": mine], cloudMain: [:]).toCloud, ["a"])
        // iCloud off: nothing is written there.
        XCTAssertTrue(StarterLevelling.plan(device: ["a": mine], cloudMain: [:], cloudOn: false).toCloud.isEmpty)
        // Of two copies in iCloud ("a.seedstarter" and "a 2.seedstarter") the NEWER wins, whichever the folder lists last.
        let main = StarterEntry(id: "a", name: "Main, newest", board: Board(title: "3", changed: now), changed: now.addingTimeInterval(20))
        let copy = StarterEntry(id: "a", name: "Copy, older", board: Board(title: "2", changed: now), changed: now.addingTimeInterval(10))
        let plan = StarterLevelling.plan(device: ["a": mine], cloudMain: ["a": main], cloudOthers: [copy])
        XCTAssertEqual(plan.best["a"], main)
        XCTAssertEqual(plan.toDevice, ["a"])
        XCTAssertTrue(plan.toCloud.isEmpty)
        // The copy is the newer one: its content goes into the starter's own file.
        let newerCopy = StarterEntry(id: "a", name: "Copy, newest", board: Board(title: "4", changed: now), changed: now.addingTimeInterval(30))
        let other = StarterLevelling.plan(device: ["a": mine], cloudMain: ["a": main], cloudOthers: [newerCopy])
        XCTAssertEqual(other.best["a"], newerCopy)
        XCTAssertEqual(other.toCloud, ["a"])
        // The names of the files.
        XCTAssertEqual(StarterFileName("mindMap.seedstarter")?.id, "mindMap")
        XCTAssertNil(StarterFileName("mindMap.seedstarter")?.copy)
        XCTAssertEqual(StarterFileName("mindMap 2.seedstarter")?.id, "mindMap")
        XCTAssertEqual(StarterFileName("mindMap 2.seedstarter")?.copy, 2)
        let stub = StarterFileName(".mindMap.seedstarter.icloud")
        XCTAssertEqual(stub?.id, "mindMap")
        XCTAssertEqual(stub?.waiting, true)
        XCTAssertEqual(stub?.name, "mindMap.seedstarter")
        XCTAssertNil(StarterFileName(".DS_Store"))
        XCTAssertNil(StarterFileName("mindMap.working"))
    }

    // 4
    func testAClosedSessionNeverSavesOverTheOpenOne() {
        // A small desk that works as the app does: the board is opened into a session, and a session's change is
        // kept only when the rule lets it.
        final class Session { var board: Board; init(_ board: Board) { self.board = board } }
        var stored = Board(title: "X", items: [Item(kind: .note, text: "start")])
        var shown: Session?
        func open() -> Session { let s = Session(stored); shown = s; return s }
        func change(_ session: Session, _ words: String) {
            session.board.items.append(Item(kind: .note, text: words))
            session.board.touch()
            if SafetyRules.maySave(asking: session, shown: shown) { stored = session.board }
        }
        let old = open()          // twelve photos are still loading for this one
        let new = open()          // the same board, opened again
        change(new, "abc")
        change(old, "a photo that arrived late")
        XCTAssertEqual(stored.items.map(\.text), ["start", "abc"])
        XCTAssertFalse(SafetyRules.maySave(asking: old, shown: new))
        XCTAssertTrue(SafetyRules.maySave(asking: new, shown: new))
        // No board on screen at all (back to the list): nothing saves.
        XCTAssertFalse(SafetyRules.maySave(asking: old, shown: nil))
    }

    // 5
    func testAPictureThatIsNotInICloudsFolderIsNeverCountedAsSent() {
        // The write to iCloud failed: the file is not in its folder. It is missing, never "sent".
        XCTAssertEqual(PictureKeeping.upload(cloudOn: true, inFolder: false, known: nil, uploaded: nil), .missing)
        XCTAssertEqual(PictureKeeping.upload(cloudOn: true, inFolder: false, known: false, uploaded: true), .missing)
        // In the folder: sent only when iCloud says it has taken it.
        XCTAssertEqual(PictureKeeping.upload(cloudOn: true, inFolder: true, known: true, uploaded: false), .waiting)
        XCTAssertEqual(PictureKeeping.upload(cloudOn: true, inFolder: true, known: true, uploaded: nil), .waiting)
        XCTAssertEqual(PictureKeeping.upload(cloudOn: true, inFolder: true, known: nil, uploaded: nil), .waiting)
        XCTAssertEqual(PictureKeeping.upload(cloudOn: true, inFolder: true, known: true, uploaded: true), .sent)
        // Only iCloud's place holder is there: iCloud has it.
        XCTAssertEqual(PictureKeeping.upload(cloudOn: true, inFolder: false, stub: true, known: nil, uploaded: nil), .sent)
        // iCloud is off: nothing waits for ever.
        XCTAssertEqual(PictureKeeping.upload(cloudOn: false, inFolder: false, known: nil, uploaded: nil), .sent)
        // The watch: every look in the first minute, then every tenth (30 seconds).
        XCTAssertTrue((1...20).allSatisfy { PictureKeeping.watchLooks(at: $0) })
        XCTAssertEqual((21...60).filter { PictureKeeping.watchLooks(at: $0) }, [30, 40, 50, 60])
    }

    // 6
    func testTheExportSaysWhichPicturesAreMissingAndPacksTheStarters() throws {
        var photo = Item(kind: .picture); photo.picture = "A.jpg"
        var other = Item(kind: .picture); other.picture = "B.jpg"
        let board = Board(title: "Cabin", items: [photo])
        let own = StarterEntry(id: "own", name: "Weekly: review", order: 8, board: Board(title: "W", items: [other]), changed: now)
        let changed = StarterEntry(id: "flow", name: "Flow", order: 3, builtin: "flow", board: Board(title: "F"), changed: now)
        let moved = StarterEntry(id: "steps", name: "Steps", order: 0, builtin: "steps", changed: now)
        var gone = StarterEntry(id: "gone", name: "Gone", order: 9, board: Board(title: "G"), changed: now)
        gone.removed = true
        let starters = [own, changed, moved, gone]
        // Own and changed starters are packed, in the shelf's order, under their own names; untouched and removed ones are not.
        XCTAssertEqual(ExportRules.starterBoards(starters).map(\.title), ["Flow", "Weekly: review"])
        let files = ExportRules.starterFiles(starters) { Data($0.title.utf8) }
        XCTAssertEqual(files.map(\.name), ["Starters/Flow.seedboard", "Starters/\(ParagonExport.noteTitle(for: "Weekly: review")).seedboard"])
        // The pictures: what the boards show and what the starters show.
        XCTAssertEqual(ExportRules.pictureNames(boards: [board], starters: starters), ["A.jpg", "B.jpg"])
        // The line under the button.
        XCTAssertEqual(ExportRules.summary(boards: 14, pictures: 31, missing: 3),
                       "Exported 14 boards and 31 pictures. 3 pictures are not on this device yet and are not in the file.")
        XCTAssertEqual(ExportRules.summary(boards: 1, starters: 2, pictures: 1, missing: 1),
                       "Exported 1 board, 2 starters and 1 picture. 1 picture is not on this device yet and is not in the file.")
        XCTAssertEqual(ExportRules.summary(boards: 3, pictures: 0, missing: 0), "Exported 3 boards.")
        // The zip is made with the Starters folder in it.
        let place = scratch()
        let zip = try BoardArchive.make(name: "Seedboard boards", files: [("Cabin.seedboard", Data("b".utf8))] + files, in: place)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip.path))
    }

    // 7
    func testAStepBackNeverForgetsWhatWasSent() {
        var box = Item(kind: .box, text: "Call the plumber"); box.todo = true
        let other = Item(kind: .box, text: "")
        let before = Board(title: "B", items: [box, other])            // the state Undo goes back to
        var present = before
        present.items[1].text = "typed after the tick"
        // Sent: the box is in the Inbox, the board is a note in PARAGON.
        present.sentTodos = [box.id]
        present.noteSent(box.id, words: "Call the plumber", place: SentTask.inbox)
        present.sent = SentInfo(when: now, kind: "note", title: "B", path: "Resources/B.md")
        // Undo takes the typing back, and nothing else.
        let back = before.keepingSentMarks(of: present)
        XCTAssertEqual(back.items[1].text, "")
        XCTAssertEqual(back.sentTodos, [box.id])
        XCTAssertEqual(back.sentTask(box.id)?.words, "Call the plumber")
        XCTAssertEqual(back.sent, present.sent)
        XCTAssertTrue(ParagonExport.inboxTasks(board: back).isEmpty, "nothing is left to send twice")
        // A thing that is not on the earlier state brings no mark along.
        var late = present
        let extra = Item(kind: .box, text: "later"); late.items.append(extra); late.sentTodos.append(extra.id)
        XCTAssertEqual(before.keepingSentMarks(of: late).sentTodos, [box.id])
        // Taking the tick off forgets it was sent — and Redo of that step still does.
        var unticked = present
        unticked.items[0].todo = false
        unticked.sentTodos = []
        XCTAssertEqual(unticked.keepingSentMarks(of: present).sentTodos, [])
        // Undo of taking the tick off: the earlier state had the mark itself.
        XCTAssertEqual(present.keepingSentMarks(of: unticked).sentTodos, [box.id])
    }

    // 8
    func testTheMemoryHoldsABoardOfFortyPhotos() {
        // A phone photo is stored 2048 × 1536; the board keeps a copy 1024 long.
        let kept = PictureKeeping.memorySize(width: 2048, height: 1536)
        XCTAssertEqual(kept.width, 1024)
        XCTAssertEqual(kept.height, 768)
        let cost = PictureKeeping.memoryCost(width: kept.width, height: kept.height)
        XCTAssertLessThanOrEqual(40 * cost, PictureKeeping.memoryRoom)
        // Kept in full, only thirteen fitted.
        XCTAssertLessThan(PictureKeeping.memoryRoom / PictureKeeping.memoryCost(width: 2048, height: 1536), 14)
        // A small picture is never made larger; an upright one keeps its shape.
        XCTAssertEqual(PictureKeeping.memorySize(width: 300, height: 200).width, 300)
        XCTAssertEqual(PictureKeeping.memorySize(width: 1536, height: 2048).height, 1024)
        // The file is read in full only when the picture is shown clearly larger than its copy.
        XCTAssertFalse(PictureKeeping.wantsSharp(shown: 640, kept: 1024))
        XCTAssertFalse(PictureKeeping.wantsSharp(shown: 1100, kept: 1024))
        XCTAssertTrue(PictureKeeping.wantsSharp(shown: 2000, kept: 1024))
        XCTAssertFalse(PictureKeeping.wantsSharp(shown: 2000, kept: 300), "a small file has no more to give")
    }

    // 9
    func testLeavingNeverWaitsLongerThanTwoSecondsForStarters() {
        let lines = StoreLines(label: "test.starters.\(UUID().uuidString)")
        // The iCloud line is busy for as long as it likes.
        let cloudBusy = DispatchSemaphore(value: 0)
        lines.inCloud { cloudBusy.wait() }
        // Nothing was written: leaving does not wait at all.
        var start = Date()
        XCTAssertTrue(lines.flush())
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
        // A starter was saved: the device write is done while iCloud is still busy.
        var written = false
        lines.onDevice { written = true }
        start = Date()
        XCTAssertTrue(lines.flush())
        XCTAssertTrue(written)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        // Even a device line that hangs does not hold the app longer than the limit.
        let deviceBusy = DispatchSemaphore(value: 0)
        lines.onDevice { deviceBusy.wait() }
        start = Date()
        XCTAssertFalse(lines.flush(limit: 0.2))
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        deviceBusy.signal()
        cloudBusy.signal()
        XCTAssertTrue(lines.flush(), "what did not finish in time is waited for at the next leave")
    }

    // 10
    func testAPictureThatComesBackKeepsItsBytesAndIsNeverWrittenTwice() throws {
        let device = scratch(), cloud = scratch()
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4])
        // A new name: written byte for byte.
        XCTAssertEqual(PictureFiles.adopt(bytes, named: "A.jpg", device: device, cloud: cloud, isPicture: { _ in true }), .written)
        XCTAssertEqual(try Data(contentsOf: device.appendingPathComponent("A.jpg")), bytes)
        // Again, with other bytes: the file stays exactly as it is.
        XCTAssertEqual(PictureFiles.adopt(Data([9, 9]), named: "A.jpg", device: device, cloud: cloud, isPicture: { _ in true }), .here)
        XCTAssertEqual(try Data(contentsOf: device.appendingPathComponent("A.jpg")), bytes)
        // Only iCloud has it (as a file, or as a place holder): nothing is written anywhere.
        try Data([7]).write(to: cloud.appendingPathComponent("B.jpg"))
        try Data().write(to: cloud.appendingPathComponent(".C.jpg.icloud"))
        XCTAssertEqual(PictureFiles.adopt(bytes, named: "B.jpg", device: device, cloud: cloud, isPicture: { _ in true }), .here)
        XCTAssertEqual(PictureFiles.adopt(bytes, named: "C.jpg", device: device, cloud: cloud, isPicture: { _ in true }), .here)
        XCTAssertFalse(FileManager.default.fileExists(atPath: device.appendingPathComponent("B.jpg").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: device.appendingPathComponent("C.jpg").path))
        XCTAssertEqual(try Data(contentsOf: cloud.appendingPathComponent("B.jpg")), Data([7]))
        // Not a picture, or not a plain picture name: refused.
        XCTAssertEqual(PictureFiles.adopt(bytes, named: "D.jpg", device: device, cloud: nil, isPicture: { _ in false }), .refused)
        XCTAssertEqual(PictureFiles.adopt(bytes, named: "../E.jpg", device: device, cloud: nil, isPicture: { _ in true }), .refused)
        XCTAssertEqual(PictureFiles.adopt(bytes, named: "F.png", device: device, cloud: nil, isPicture: { _ in true }), .refused)
    }

    // 11
    func testAPictureGoesOnlyWhenItWasUnnamedTwiceAWeekApart() {
        let old = now.addingTimeInterval(-40 * 86_400)
        let files: [(name: String, date: Date?)] = [("A.jpg", old), ("B.jpg", old), ("C.jpg", now.addingTimeInterval(-86_400))]
        // The first pass that finds A unnamed only remembers it.
        let first = PictureKeeping.tidy(files: files, named: ["B.jpg"], seen: [:], now: now)
        XCTAssertEqual(first.go, [])
        XCTAssertEqual(first.seen, ["A.jpg": now])
        // Six days later: still not.
        let second = PictureKeeping.tidy(files: files, named: ["B.jpg"], seen: first.seen, now: now.addingTimeInterval(6 * 86_400))
        XCTAssertEqual(second.go, [])
        XCTAssertEqual(second.seen, ["A.jpg": now])
        // A week after the first time: it goes.
        let third = PictureKeeping.tidy(files: files, named: ["B.jpg"], seen: second.seen, now: now.addingTimeInterval(7 * 86_400))
        XCTAssertEqual(third.go, ["A.jpg"])
        // A board that arrived meanwhile names it: forgotten, and the week starts again if it is ever unnamed.
        let named = PictureKeeping.tidy(files: files, named: ["A.jpg", "B.jpg"], seen: first.seen, now: now.addingTimeInterval(8 * 86_400))
        XCTAssertEqual(named.go, [])
        XCTAssertEqual(named.seen, [:])
        // Something could not be read: nothing goes, and what was remembered stays.
        let blind = PictureKeeping.tidy(files: files, named: ["B.jpg"], seen: first.seen, now: now.addingTimeInterval(9 * 86_400), complete: false)
        XCTAssertEqual(blind.go, [])
        XCTAssertEqual(blind.seen, first.seen)
        // Only iCloud's place holder says "still in iCloud"; the Finder's own hidden file says nothing.
        XCTAssertTrue(PictureKeeping.stillInCloud(".A.jpg.icloud"))
        XCTAssertFalse(PictureKeeping.stillInCloud(".DS_Store"))
        XCTAssertFalse(PictureKeeping.stillInCloud("A.jpg"))
    }
}
