import XCTest

final class TextGrabUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.textgrab.TextGrab")

    override func tearDown() {
        app.terminate()
    }

    func testMenuBarAppLaunches() {
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
    }

    func testMenuBarContainsPrimaryActions() {
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let captureButton = app.buttons["captureTextButton"]
        if !captureButton.waitForExistence(timeout: 3) {
            // The popover can fail to open if the click raced with the
            // previous test's app instance; retry once.
            statusItem.click()
            XCTAssertTrue(captureButton.waitForExistence(timeout: 3))
        }
        XCTAssertTrue(app.buttons["settingsButton"].exists)
    }
}
