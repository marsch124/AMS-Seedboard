import XCTest
import CoreGraphics
@testable import SeedboardCore

final class Finding09Tests: XCTestCase {
    private func board(_ title: String, ago: Double? = nil) -> Board {
        var b = Board(title: title)
        if let ago { b.putAway = Date(timeIntervalSince1970: 1_000_000 - ago) }
        return b
    }

    /// Put away: out of the list, newest first on the page, still found by a search, unpinned, never deleted.
    func testPutAwayRules() {
        var pinned = board("Pinned one")
        pinned.pinned = true
        let a = board("Old", ago: 500), b = board("Older", ago: 900), c = board("Cabin")
        let all = [pinned, a, b, c]
        XCTAssertEqual(PutAway.listed(all).map(\.title), ["Pinned one", "Cabin"])
        XCTAssertEqual(PutAway.away(all).map(\.title), ["Old", "Older"])
        XCTAssertEqual(PutAway.shown("", in: all).map(\.title), ["Pinned one", "Cabin"])
        XCTAssertEqual(PutAway.shown("old", in: all).map(\.title), ["Old", "Older"])
        XCTAssertEqual(PutAway.rowWords(all), "Put away (2)")
        XCTAssertNil(PutAway.rowWords([c]))
        PutAway.putAway(&pinned, now: Date(timeIntervalSince1970: 5))
        XCTAssertFalse(pinned.pinned)
        XCTAssertTrue(pinned.isPutAway)
        PutAway.bringBack(&pinned)
        XCTAssertFalse(pinned.isPutAway)
        // It is stored and read back.
        var kept = c
        PutAway.putAway(&kept, now: Date(timeIntervalSince1970: 7))
        let back = try? JSONDecoder().decode(Board.self, from: JSONEncoder().encode(kept))
        XCTAssertEqual(back?.putAway, kept.putAway)
    }

    /// The line under a board: parts of 0 are left out, singular and plural, done and late.
    func testListLine() {
        var b = Board(title: "Plans")
        XCTAssertEqual(b.listLine(), "Empty")
        let one = b.add(.idea, centre: .zero, text: "First")
        XCTAssertEqual(b.listLine(), "1 idea")
        let two = b.add(.note, centre: CGPoint(x: 200, y: 0), text: "Second")
        b.add(.note, centre: CGPoint(x: 400, y: 0), text: "")
        XCTAssertEqual(b.listLine(), "2 ideas")
        for i in b.items.indices where [one, two].contains(b.items[i].id) { b.items[i].todo = true }
        XCTAssertEqual(b.listLine(doneThings: [one]), "2 ideas · 1 done")
        XCTAssertEqual(b.listLine(doneThings: [UUID()]), "2 ideas")

        var t = Board.timeline(title: "Plan")
        let today = Day(year: 2026, month: 12, day: 10)
        let late = t.addBar("Late", start: Day(year: 2026, month: 12, day: 1), days: 3)
        let ok = t.addBar("Done", start: Day(year: 2026, month: 12, day: 1), days: 3)
        t.addMilestone("Later", on: Day(year: 2026, month: 12, day: 20))
        t.setDone([ok], true, on: today)
        XCTAssertEqual(t.listLine(today: today), "2 bars · 1 milestone · 1 done · 1 late")
        _ = late
    }

    /// Words read inside a picture are found; the answer says it was the picture.
    func testPictureWordsAreFound() {
        var b = Board(title: "Trip")
        b.add(.note, centre: .zero, text: "Tickets")
        var pic = Item(kind: .picture)
        pic.picture = "x.jpg"
        b.items.append(pic)
        XCTAssertEqual(b.picturesToRead.count, 1)
        XCTAssertEqual(BoardSearch.way("platform", board: b), .none)
        b.items[1].pictureWords = "Platform 9 Departures"
        XCTAssertEqual(b.picturesToRead.count, 0)
        XCTAssertEqual(BoardSearch.way("PLATFORM", board: b), .picture)
        XCTAssertEqual(BoardSearch.way("tickets", board: b), .words)
        XCTAssertEqual(BoardSearch.way("tickets platform", board: b), .picture)
        XCTAssertEqual(BoardSearch.way("", board: b), .words)
        XCTAssertFalse(b.holds("platform"))          // the older rule is unchanged
        b.items[1].pictureWords = ""
        XCTAssertEqual(b.picturesToRead.count, 0)    // "" = read, nothing found
    }

    /// What the device's search is told.
    func testSpotlightWords() {
        var b = Board(title: "Cabin")
        b.add(.idea, centre: .zero, text: "Timber")
        var pic = Item(kind: .picture)
        pic.pictureWords = "Hardware store"
        b.items.append(pic)
        PutAway.putAway(&b)
        let told = Outside.spotlight(of: b)
        XCTAssertEqual(told.title, "Cabin")
        XCTAssertEqual(told.line, "Timber")
        XCTAssertEqual(told.kind, "Board")
        XCTAssertTrue(told.text.contains("Hardware store"))
        XCTAssertEqual(SpotlightWords.domain, "boards")
        var t = Board.timeline(title: "Plan")
        XCTAssertEqual(Outside.spotlight(of: t).kind, "Timeline")
        XCTAssertEqual(Outside.spotlight(of: Board(title: "Empty")).line, "Empty")
    }

    /// The names of the undo steps, from the board before and after.
    func testStepWords() {
        let before = Board(title: "B")
        var b = before
        let note = b.add(.note, centre: .zero, text: "Hi")
        XCTAssertEqual(StepWords.describe(before: before, after: b), "Added a sticky note")
        var c = b
        c.add(.idea, centre: CGPoint(x: 5, y: 5), text: "x")
        c.add(.box, centre: CGPoint(x: 99, y: 5), text: "y")
        XCTAssertEqual(StepWords.describe(before: b, after: c), "Added 2 things")
        XCTAssertEqual(StepWords.describe(before: c, after: b), "Removed 2 things")
        var d = b
        d.items[0].text = "Hello"
        XCTAssertEqual(StepWords.describe(before: b, after: d), "Changed words")
        var e = b
        e.items[0].colour = "pink"
        XCTAssertEqual(StepWords.describe(before: b, after: e), "Coloured 1 thing")
        var f = b
        f.items[0].x += 40
        XCTAssertEqual(StepWords.describe(before: b, after: f), "Moved 1 thing")
        XCTAssertEqual(StepWords.describe(before: b, after: b), "Changed the board")
        _ = note
        let time = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 21, minute: 40))!
        XCTAssertEqual(StepWords.line("Moved 3 things", at: time), "Moved 3 things · 21:40")
        // The list: newest first, each says how many Undos go back to before it.
        var g = d
        g.items[0].colour = "pink"
        let steps = StepWords.list(before: [before, b, d], now: g, times: [time, time, time])
        XCTAssertEqual(steps.map(\.words), ["Coloured 1 thing", "Changed words", "Added a sticky note"])
        XCTAssertEqual(steps.map(\.undos), [1, 2, 3])
    }
}

extension Finding09Tests {
    func testSetPictureWords() {
        var b = Board(title: "T")
        var pic = Item(kind: .picture)
        pic.picture = "p.jpg"
        b.items.append(pic)
        let note = b.add(.note, centre: .zero, text: "n")
        b.setPictureWords(pic.id, "Hello")
        b.setPictureWords(note, "Nope")
        XCTAssertEqual(b.items[0].pictureWords, "Hello")
        XCTAssertNil(b.items[1].pictureWords)
    }
}
