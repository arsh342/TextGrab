import XCTest

final class TextGrabUITests: XCTestCase {
    func testMenuBarAppLaunches() {
        let app = XCUIApplication(bundleIdentifier: "com.textgrab.TextGrab")
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
    }

    func testMenuBarContainsPrimaryActions() {
        let app = XCUIApplication(bundleIdentifier: "com.textgrab.TextGrab")
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        XCTAssertTrue(app.buttons["Capture Text"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Settings..."].exists)
    }
}
