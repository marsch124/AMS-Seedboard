import XCTest

/// 0.5, the `iphone` lane: the plate "Add a picture" behind the Picture tile (hold the tile on iPhone and iPad).
/// `-plate picture` opens it at once, as holding the tile does. Every control is found by its identifier;
/// every wait is for an element. (Written, not run.)
final class IphoneUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testThePicturePlateOffersPhotosTheCameraAndAScanAndCancelClosesIt() throws {
        #if os(macOS)
        throw XCTSkip("The Mac has no plate behind the Picture tile: its pictures from the iPhone come through the menus.")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-sampleData", "-board", "balcony", "-plate", "picture"]
        app.launch()

        // The plate with its three ways, in this order.
        XCTAssertTrue(element(app, "plate.picture").waitForExistence(timeout: 15), "the plate did not appear")
        for way in ["photos", "camera", "scan"] {
            XCTAssertTrue(element(app, "plate.picture." + way).waitForExistence(timeout: 5), "plate.picture.\(way) is missing")
        }
        let photos = element(app, "plate.picture.photos").frame, camera = element(app, "plate.picture.camera").frame
        let scan = element(app, "plate.picture.scan").frame
        XCTAssertLessThan(photos.midX, camera.midX, "Photos comes first")
        XCTAssertLessThan(camera.midX, scan.midX, "Scan a page comes last")

        // Cancel closes it, and the board with its Picture tile is there again.
        let cancel = element(app, "plate.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Cancel is missing")
        cancel.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element(app, "plate.picture"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "the plate did not close")
        XCTAssertTrue(element(app, "tool.picture").waitForExistence(timeout: 10), "tool.picture did not appear")
        #endif
    }
}
