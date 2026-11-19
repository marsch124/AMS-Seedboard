import XCTest
@testable import SeedboardCore

final class Paragon11Tests: XCTestCase {
    func testSendCauses() {
        func err(_ domain: String, _ code: Int) -> Error { NSError(domain: domain, code: code) }
        XCTAssertEqual(SendCause.classify(err(NSPOSIXErrorDomain, 28)), .diskFull)
        XCTAssertEqual(SendCause.classify(err(NSCocoaErrorDomain, 640)), .diskFull)
        XCTAssertEqual(SendCause.classify(err(NSPOSIXErrorDomain, 13)), .locked)
        XCTAssertEqual(SendCause.classify(err(NSPOSIXErrorDomain, 16)), .inUse)
        XCTAssertEqual(SendCause.classify(err(NSCocoaErrorDomain, 4)), .folderMissing)
        XCTAssertEqual(SendCause.classify(err(NSCocoaErrorDomain, 4353)), .iCloudUnavailable)
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 512, userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: 28)])
        XCTAssertEqual(SendCause.classify(wrapped), .diskFull)
        XCTAssertTrue(SendCause.words(for: err(NSPOSIXErrorDomain, 28), what: "the Inbox").hasPrefix("The Inbox could not be saved: the disk is full."))
    }

    func testWaitingForParagon() {
        var board = Board(title: "Alex")
        let a = board.addCentre(at: .zero)
        let sentAt = Date(timeIntervalSince1970: 1_000_000)
        board.noteSent(a, words: "Order timber", place: SentTask.inbox)
        board.changed = sentAt
        XCTAssertEqual(InboxWait.state(of: a, in: board, seen: [:], now: sentAt.addingTimeInterval(3600)), .waiting)
        XCTAssertEqual(InboxWait.state(of: a, in: board, seen: [:], now: sentAt.addingTimeInterval(90_000)), .late)
        XCTAssertEqual(InboxWait.state(of: a, in: board, seen: [a: .inParagon], now: sentAt.addingTimeInterval(90_000)), .filed)
        XCTAssertEqual(InboxWait.line(for: board, seen: [:], now: sentAt.addingTimeInterval(60)), "1 waiting for PARAGON")
        XCTAssertEqual(InboxWait.line(for: board, seen: [:], now: sentAt.addingTimeInterval(90_000)), "1 not filed yet — open PARAGON")
        XCTAssertEqual(InboxWait.line(for: board, seen: [a: .done]), "1 in PARAGON")
    }

    func testChosenOnlyAndEmail() {
        var board = Board(title: "Summer cabin")
        let root = board.addCentre(at: .zero)
        let one = board.addChild(of: root, text: "Roof") ?? UUID()
        let two = board.addChild(of: root, text: "Walls") ?? UUID()
        _ = board.addChild(of: one, text: "Tiles")
        let part = board.chosenOnly([one, two])
        XCTAssertEqual(part?.items.count, 3)
        XCTAssertNil(part?.sent)
        let tops = part?.items.filter { $0.parent == nil }.count
        XCTAssertEqual(tops, 2)
        XCTAssertNil(board.chosenOnly([]))
        XCTAssertEqual(Board.chosenWords(3), "The 3 chosen things")
        let mail = board.emailText
        XCTAssertTrue(mail.hasPrefix("Here is my board “Summer cabin”:\n\n"))
        XCTAssertTrue(mail.hasSuffix("\n\nMade with Seedboard"))
        XCTAssertTrue(mail.contains(board.outlineText))
    }
}
