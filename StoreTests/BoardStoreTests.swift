import XCTest
import SeedboardCore

/// 0.11: the file store on a throwaway folder. A second folder stands in for iCloud's Documents folder, so no
/// iCloud and no running app are needed. One small test for each thing the store promises.
final class BoardStoreTests: XCTestCase {
    private var root: URL!
    private var disk: BoardDisk!
    private var device: URL { root.appendingPathComponent("device/Boards") }
    private var removedDevice: URL { root.appendingPathComponent("device/Removed") }
    private var safety: URL { root.appendingPathComponent("device/SafetyCopies") }
    private var cloud: URL { root.appendingPathComponent("cloud/Documents/Boards") }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        disk = BoardDisk(support: root.appendingPathComponent("device"),
                         cloudDocuments: root.appendingPathComponent("cloud/Documents"))
    }

    override func tearDown() { try? FileManager.default.removeItem(at: root) }

    private func day(_ n: Double) -> Date { Date(timeIntervalSince1970: 1_700_000_000 + n * 3600) }

    private func board(_ id: UUID, _ title: String, at hours: Double) -> Board {
        Board(id: id, title: title, created: day(0), changed: day(hours))
    }

    private func put(_ board: Board, in folder: URL, as name: String? = nil) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try disk.encode(board)!.write(to: folder.appendingPathComponent(name ?? "\(board.id.uuidString).seedboard"))
    }

    private func names(_ folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    func testSaveThenReadBack() {
        let one = board(UUID(), "Alex's trip", at: 1)
        disk.save(one, grewFrom: nil)
        disk.flush(cloudToo: true)
        XCTAssertTrue(names(device).contains("\(one.id.uuidString).seedboard"))
        XCTAssertTrue(names(cloud).contains("\(one.id.uuidString).seedboard"))
        let found = disk.loadAll()
        XCTAssertEqual(found.boards.map(\.title), ["Alex's trip"])
    }

    func testNewerVersionWinsAndTheOlderIsKept() throws {
        let id = UUID()
        try put(board(id, "Old", at: 1), in: device)
        try put(board(id, "New", at: 5), in: cloud)
        let found = disk.loadAll()
        XCTAssertEqual(found.boards.first?.title, "New")
        // The device now holds the newer one; the older one is set aside, not lost.
        let onDevice = try Data(contentsOf: device.appendingPathComponent("\(id.uuidString).seedboard"))
        XCTAssertEqual(disk.decode(onDevice)?.title, "New")
        XCTAssertEqual(names(safety).filter { $0.hasSuffix(".seedboard") }.count, 1)
    }

    func testICloudsNumberedCopyIsJoinedAndCleared() throws {
        let id = UUID()
        try put(board(id, "Mine", at: 1), in: cloud)
        try put(board(id, "Other device", at: 9), in: cloud, as: "\(id.uuidString) 2.seedboard")
        let found = disk.loadAll()
        XCTAssertEqual(found.boards.first?.title, "Other device")
        XCTAssertFalse(names(cloud).contains("\(id.uuidString) 2.seedboard"))
        XCTAssertEqual(names(safety).filter { $0.hasSuffix(".seedboard") }.count, 1)
    }

    func testRemovalMarkHidesTheBoardAndALaterChangeBringsItBack() throws {
        let one = board(UUID(), "Gone soon", at: 1)
        disk.save(one, grewFrom: nil)
        disk.flush(cloudToo: true)
        disk.remove(id: one.id)
        disk.flush(cloudToo: true)
        var found = disk.loadAll()
        XCTAssertTrue(found.boards.isEmpty)
        XCTAssertNotNil(found.gone[one.id])
        XCTAssertFalse(names(removedDevice).isEmpty)
        // A change made after the removal wins over the mark.
        var later = one
        later.changed = Date().addingTimeInterval(3600)
        try put(later, in: device)
        found = disk.loadAll()
        XCTAssertEqual(found.boards.map(\.id), [one.id])
    }

    func testAnUnreadableCloudFileIsLeftAlone() throws {
        let id = UUID()
        try put(board(id, "Safe", at: 3), in: device)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let junk = Data("not a board".utf8)
        let file = cloud.appendingPathComponent("\(id.uuidString).seedboard")
        try junk.write(to: file)
        let found = disk.loadAll()
        XCTAssertEqual(found.boards.first?.title, "Safe")
        XCTAssertEqual(try Data(contentsOf: file), junk)
    }
}
