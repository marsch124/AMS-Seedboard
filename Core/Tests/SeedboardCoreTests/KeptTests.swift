import XCTest
@testable import SeedboardCore

/// 0.2 picks 4 and 5: bringing back removed boards and earlier versions, and the export of all boards.
/// The file work runs against a throwaway folder only.
final class KeptTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let a = UUID(uuidString: "AAAAAAAA-1111-1111-1111-111111111111")!
    private let b = UUID(uuidString: "BBBBBBBB-2222-2222-2222-222222222222")!
    /// 18 Nov 2026 10:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_794_996_000)

    private func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    private func board(_ id: UUID, _ title: String, changed: Date) -> Board {
        Board(id: id, title: title, created: changed, changed: changed)
    }

    // MARK: Rules

    func testDaysLeftCountsDownFromThirty() {
        XCTAssertEqual(KeptRules.daysLeft(since: now, now: now), 30)
        XCTAssertEqual(KeptRules.daysLeft(since: ago(12), now: now), 18)
        XCTAssertEqual(KeptRules.daysLeft(since: ago(12.5), now: now), 18)   // a started day counts as a day left
        XCTAssertEqual(KeptRules.daysLeft(since: ago(29.2), now: now), 1)
        XCTAssertEqual(KeptRules.daysLeft(since: ago(30), now: now), 0)
        XCTAssertEqual(KeptRules.daysLeft(since: ago(45), now: now), 0)
        XCTAssertEqual(KeptRules.removedLine(removed: ago(12), now: now, timeZone: utc), "removed 6 Nov · 18 days left")
        XCTAssertEqual(KeptRules.removedLine(removed: ago(29.2), now: now, timeZone: utc), "removed 20 Oct · 1 day left")
        XCTAssertEqual(KeptRules.removedLine(removed: ago(30), now: now, timeZone: utc), "removed 19 Oct · last day")
    }

    func testTheNewestCopyOfARemovedBoardIsTheOneShown() {
        let old = RemovedCopy(board: board(a, "Plan", changed: ago(9)), removed: ago(3))     // the device's copy
        let new = RemovedCopy(board: board(a, "Plan v2", changed: ago(5)), removed: ago(4))  // iCloud's, changed later
        let twin = RemovedCopy(board: board(a, "Plan v2", changed: ago(5)), removed: ago(2)) // the same version, moved later
        let other = RemovedCopy(board: board(b, "Party", changed: ago(20)), removed: ago(10))
        // The version changed last wins, whatever the day it was moved; of twins, the one removed last.
        XCTAssertEqual(KeptRules.newest([old, new, other]), [new, other])
        XCTAssertEqual(KeptRules.newest([new, old, twin, other]), [twin, other])
        // A board that is in the list again (it was brought back) is not among the removed.
        XCTAssertEqual(KeptRules.removedRows([old, new, other], present: [a]), [other])
    }

    func testAnEarlierVersionOpensAsANewBoardWithTheVersionInItsName() {
        let when = Date(timeIntervalSince1970: 1_794_996_000)   // 18 Nov 2026 10:00 UTC
        XCTAssertEqual(KeptRules.copyTitle("Summer cabin", version: when, now: now, timeZone: utc),
                       "Summer cabin (version from 18 Nov 10:00)")
        XCTAssertEqual(KeptRules.copyTitle("Summer cabin", version: when, now: now,
                                           taken: ["summer cabin (VERSION from 18 Nov 10:00)"], timeZone: utc),
                       "Summer cabin (version from 18 Nov 10:00) 2")
        // Last year's version says its year.
        XCTAssertEqual(KeptRules.copyTitle("Plan", version: ago(400), now: now, timeZone: utc), "Plan (version from 14 Oct 2025 10:00)")

        var version = board(a, "Summer cabin", changed: when)
        version.pinned = true
        version.sent = SentInfo(when: when, kind: "note", title: "Summer cabin", path: "Resources/Summer cabin.md")
        let copy = KeptRules.asCopy(version, now: now, timeZone: utc)
        XCTAssertNotEqual(copy.id, a, "a copy never takes the place of the board it is a version of")
        XCTAssertEqual(copy.title, "Summer cabin (version from 18 Nov 10:00)")
        XCTAssertEqual(copy.changed, now)
        XCTAssertFalse(copy.pinned)
        XCTAssertNil(copy.sent)
    }

    func testTheTidyDecision() {
        // Removed boards and set-aside versions go after 30 days; daily copies never by this rule.
        XCTAssertFalse(KeptRules.letGo(.setAside, kept: ago(29.9), now: now))
        XCTAssertTrue(KeptRules.letGo(.setAside, kept: ago(30.1), now: now))
        XCTAssertFalse(KeptRules.letGo(.removed, kept: ago(30), now: now))
        XCTAssertTrue(KeptRules.letGo(.removed, kept: ago(31), now: now))
        XCTAssertFalse(KeptRules.letGo(.daily, kept: ago(400), now: now))
    }

    func testKeptFileNamesAreRead() {
        let removed = KeptFileName("\(a.uuidString)-20261118-091500.seedboard", timeZone: utc)
        XCTAssertEqual(removed?.kind, .removed)
        XCTAssertEqual(removed?.id, a)
        XCTAssertEqual(removed?.kept, Date(timeIntervalSince1970: 1_794_993_300))
        XCTAssertEqual(KeptFileName("\(a.uuidString)-20261118-091500-AB12CD.seedboard", timeZone: utc)?.kind, .setAside(nil))
        XCTAssertEqual(KeptFileName("\(a.uuidString)-20261118-091500-AB12CD-away.seedboard", timeZone: utc)?.kind, .setAside(.away))
        XCTAssertEqual(KeptFileName("\(a.uuidString)-20261118-091500-AB12CD-here.seedboard", timeZone: utc)?.kind, .setAside(.here))
        XCTAssertEqual(KeptFileName("\(a.uuidString)-20261118-091500-AB12CD.unreadable", timeZone: utc)?.isBoard, false)
        XCTAssertEqual(KeptFileName(".\(a.uuidString)-20261118-091500.seedboard.icloud", timeZone: utc)?.waiting, true)
        // A board's own file, a mark and anything else are not kept copies.
        XCTAssertNil(KeptFileName("\(a.uuidString).seedboard", timeZone: utc))
        XCTAssertNil(KeptFileName("\(a.uuidString).gone", timeZone: utc))
        XCTAssertNil(KeptFileName("notes-20261118-091500.seedboard", timeZone: utc))
        XCTAssertEqual(KeptFileName.ending(for: .away), "-away")
        XCTAssertEqual(KeptFileName.ending(for: nil), "")
    }

    func testEarlierVersionsAreListedOncePerVersionAndNeverTheBoardAsItStands() {
        let current = board(a, "Summer cabin", changed: ago(0.1))
        func version(_ path: String, _ changed: Date, _ source: EarlierVersion.Source, kept: Date) -> EarlierVersion {
            EarlierVersion(path: path, board: board(a, "Summer cabin", changed: changed), kept: kept, source: source)
        }
        let same = version("2026-11-18/x", ago(0.1), .daily, kept: now)                  // the board as it stands
        let daily1 = version("2026-11-17/x", ago(3), .daily, kept: ago(1))
        let daily2 = version("2026-11-16/x", ago(3), .daily, kept: ago(2))               // the same version again
        let away = version("clash", ago(3), .setAside(.away), kept: ago(2.5))            // … and set aside: says most
        let older = version("2026-11-12/x", ago(8), .daily, kept: ago(6))
        let goneForGood = EarlierVersion(path: "g", board: board(b, "Gone", changed: ago(9)), kept: ago(8), source: .daily)

        let groups = KeptRules.groups(versions: [same, daily1, daily2, away, older, goneForGood], boards: [current],
                                      removed: [], marked: [b])
        XCTAssertEqual(groups.map(\.title), ["Summer cabin"], "a board removed for good is not listed")
        XCTAssertEqual(groups.first?.versions.map(\.path), ["clash", "2026-11-12/x"])
        XCTAssertEqual(groups.first?.countLine, "2 earlier versions")

        // The same copies of a board that is among the removed, and of one that is nowhere else.
        let removed = RemovedCopy(board: board(b, "Gone", changed: ago(5)), removed: ago(4))
        XCTAssertEqual(KeptRules.groups(versions: [goneForGood], boards: [], removed: [removed], marked: [b]).map(\.state), [.removed])
        XCTAssertEqual(KeptRules.groups(versions: [goneForGood], boards: [], removed: [], marked: []).map(\.state), [.lost])

        // Of this device's own set-aside versions only the newest 10 are listed; the rest is counted.
        let own = (1...13).map { version("own\($0)", ago(Double($0) * 0.01 + 0.2), .setAside(.here), kept: now) }
        let many = KeptRules.groups(versions: own + [away], boards: [current], removed: [], marked: [])
        XCTAssertEqual(many.first?.versions.count, 11)
        XCTAssertEqual(many.first?.hidden, 3)
        XCTAssertEqual(many.first?.versions.last?.path, "clash", "another device's version is always listed")

        XCTAssertEqual(KeptRules.sourceLine(away, now: now, timeZone: utc), "from another device, 15 Nov 10:00")
        XCTAssertEqual(KeptRules.sourceLine(older, now: now, timeZone: utc), "daily copy, 10 Nov 10:00")
        XCTAssertEqual(KeptRules.clashLine("Summer cabin"),
                       "Another device changed “Summer cabin”. The other version is kept under Earlier versions.")
    }

    // MARK: The folders (a throwaway folder stands in for the device and for iCloud)

    private func coder() -> (encode: (Board) -> Data, decode: @Sendable (Data) -> Board?) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return ({ try! encoder.encode($0) }, { data in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try? decoder.decode(Board.self, from: data)
        })
    }

    private func throwaway() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SeedboardKeptTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    func testTheFoldersAreListedTidiedAndOneBoardRemovedForGood() throws {
        let fm = FileManager.default
        let root = try throwaway()
        let (encode, decode) = coder()
        func folder(_ name: String) throws -> URL {
            let url = root.appendingPathComponent(name, isDirectory: true)
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        let device = try folder("Removed"), cloud = try folder("CloudRemoved")
        let safety = try folder("SafetyCopies"), boards = try folder("Boards")
        let stamp = KeptRules.stamp(utc)
        func removedName(_ id: UUID, _ date: Date) -> String { "\(id.uuidString)-\(stamp.string(from: date)).seedboard" }

        // Removed: board A on the device and (changed later) in "iCloud"; board B on the device; one broken file.
        try encode(board(a, "Plan", changed: ago(9))).write(to: device.appendingPathComponent(removedName(a, ago(3))))
        try encode(board(a, "Plan v2", changed: ago(5))).write(to: cloud.appendingPathComponent(removedName(a, ago(4))))
        try encode(board(b, "Party", changed: ago(20))).write(to: device.appendingPathComponent(removedName(b, ago(10))))
        try Data("not a board".utf8).write(to: device.appendingPathComponent(removedName(UUID(), ago(1))))
        try Data().write(to: boards.appendingPathComponent("\(b.uuidString).gone"))

        // Earlier versions: a daily copy, a fresh set-aside one, one of 31 days ago, old unreadable bytes, a broken copy.
        let day = try folder("SafetyCopies/2026-11-17")
        try encode(board(a, "Plan", changed: ago(2))).write(to: day.appendingPathComponent("\(a.uuidString).seedboard"))
        try Data("broken".utf8).write(to: day.appendingPathComponent("\(b.uuidString).seedboard"))
        let fresh = "\(a.uuidString)-\(stamp.string(from: ago(1)))-AB12CD-away.seedboard"
        let stale = "\(a.uuidString)-\(stamp.string(from: ago(31)))-EF34AB.seedboard"
        let junk = "\(a.uuidString)-\(stamp.string(from: ago(40)))-CD56EF.unreadable"
        try encode(board(a, "Plan", changed: ago(1))).write(to: safety.appendingPathComponent(fresh))
        try encode(board(a, "Plan", changed: ago(31))).write(to: safety.appendingPathComponent(stale))
        try Data("junk".utf8).write(to: safety.appendingPathComponent(junk))

        let places = KeptPlaces(removed: [device, cloud], safety: safety, boards: [boards], decode: decode)
        var listing = KeptFiles.list(places, timeZone: utc)
        XCTAssertEqual(listing.removed.count, 3, "only copies that can be read are listed")
        XCTAssertEqual(KeptRules.newest(listing.removed).map(\.board.title), ["Plan v2", "Party"])
        XCTAssertEqual(listing.marked, [b])
        XCTAssertEqual(Set(listing.versions.map(\.path)), ["2026-11-17/\(a.uuidString).seedboard", fresh, stale])
        XCTAssertEqual(listing.versions.first { $0.path == fresh }?.source, .setAside(.away))
        let again = try XCTUnwrap(listing.versions.first { $0.path == fresh })
        XCTAssertEqual(KeptFiles.read(again, in: places)?.changed, ago(1))

        // Tidy: the set-aside copies older than 30 days go; the daily copy and the fresh one stay.
        XCTAssertEqual(KeptFiles.tidy(safety: safety, now: now, timeZone: utc), 2)
        listing = KeptFiles.list(places, timeZone: utc)
        XCTAssertEqual(Set(listing.versions.map(\.path)), ["2026-11-17/\(a.uuidString).seedboard", fresh])
        XCTAssertTrue(fm.fileExists(atPath: day.appendingPathComponent("\(b.uuidString).seedboard").path))

        // Remove for good: both copies of A go, B stays, nothing else is touched.
        XCTAssertEqual(KeptFiles.removeForGood(a, in: places.removed, timeZone: utc), 2)
        listing = KeptFiles.list(places, timeZone: utc)
        XCTAssertEqual(listing.removed.map(\.board.title), ["Party"])
        XCTAssertEqual(listing.versions.count, 2)
    }

    // MARK: Export all boards

    func testTheExportNamesItsFilesAndWritesAnOutline() {
        var cabin = Board(id: a, title: "Summer cabin", created: ago(3), changed: ago(1))
        let centre = cabin.addCentre(at: .zero, text: "Summer cabin")
        let budget = cabin.addChild(of: centre, text: "Budget")!
        if let i = cabin.index(of: budget) { cabin.items[i].todo = true }
        let twin = Board(id: b, title: "summer cabin", created: ago(2), changed: ago(2))
        let odd = Board(title: "What/if: plan?", created: ago(2), changed: ago(2))

        XCTAssertEqual(ExportRules.archiveName(now, timeZone: utc), "Seedboard boards 2026-11-18")
        let names = ExportRules.fileNames([cabin, twin, odd])
        XCTAssertEqual(names[a], "Summer cabin")
        XCTAssertEqual(names[b], "summer cabin (2)", "two files never differ by capitals only")
        XCTAssertEqual(names[odd.id], "What if plan")

        let text = ExportRules.outline(of: cabin, now: now, timeZone: utc)
        XCTAssertTrue(text.hasPrefix("# Summer cabin\n\n2 ideas · last changed 17 Nov 10:00 · exported from Seedboard on 18 Nov\n"), text)
        XCTAssertTrue(text.contains("- Summer cabin\n  - Budget"), text)
        XCTAssertTrue(text.hasSuffix("To do:\n- [ ] Budget\n"), text)

        let files = ExportRules.files([cabin, twin], bytes: { $0.id == self.b ? nil : Data("x".utf8) }, now: now, timeZone: utc)
        XCTAssertEqual(files.map(\.name), ["Summer cabin.seedboard", "Summer cabin.md"], "a board without bytes is left out")

        XCTAssertEqual(ExportRules.lastExportLine(nil, now: now, timeZone: utc), "No export yet.")
        XCTAssertEqual(ExportRules.lastExportLine(ago(6), now: now, timeZone: utc), "Last export: 12 Nov")
    }

    func testTheExportIsOneZipFile() throws {
        let root = try throwaway()
        let files = [(name: "Summer cabin.seedboard", data: Data("{}".utf8)), (name: "Summer cabin.md", data: Data("# Summer cabin\n".utf8))]
        let zip = try BoardArchive.make(name: "Seedboard boards 2026-11-18", files: files, in: root)
        XCTAssertEqual(zip.lastPathComponent, "Seedboard boards 2026-11-18.zip")
        let bytes = try Data(contentsOf: zip)
        XCTAssertEqual(Array(bytes.prefix(2)), [0x50, 0x4B], "a zip file starts with PK")
        // The names of both files are in it, and the folder it was made from is cleared away.
        XCTAssertNotNil(bytes.range(of: Data("Seedboard boards 2026-11-18/Summer cabin.seedboard".utf8)))
        XCTAssertNotNil(bytes.range(of: Data("Seedboard boards 2026-11-18/Summer cabin.md".utf8)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Seedboard boards 2026-11-18").path))
    }

    func testABoardComesInAsANewBoard() throws {
        var old = board(a, "Summer cabin", changed: ago(5))
        old.pinned = true
        let new = ExportRules.imported(old, taken: ["summer cabin", "Summer cabin (imported)"], now: now)
        XCTAssertNotEqual(new.id, a, "a board that comes in never replaces one")
        XCTAssertEqual(new.title, "Summer cabin (imported 2)")
        XCTAssertEqual(new.changed, now)
        XCTAssertFalse(new.pinned)
        XCTAssertEqual(ExportRules.imported(old, taken: [], now: now).title, "Summer cabin")

        let bytes = try JSONEncoder().encode(old)
        XCTAssertTrue(ExportRules.looksLikeBoard(bytes))
        XCTAssertFalse(ExportRules.looksLikeBoard(Data(#"{"id":"\#(a.uuidString)","name":"something else"}"#.utf8)))
        XCTAssertFalse(ExportRules.looksLikeBoard(Data("# Summer cabin".utf8)))
    }
}
