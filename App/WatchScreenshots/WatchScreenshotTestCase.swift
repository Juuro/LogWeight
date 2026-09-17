import XCTest

/// Base class for watch App Store screenshot scenes. Mirrors
/// `ScreenshotTestCase` (App/iOSScreenshots) but for the watchOS app, which
/// has no splash screen and launches straight into `WatchEntryView`.
class WatchScreenshotTestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Launches the watch app with an in-memory store, optionally preloaded
    /// with a `ScreenshotFixture` via `seed`. Display unit follows the
    /// simulator's region (set via `xcodebuild test -testRegion`): DE
    /// captures in kg, everything else in lb.
    func launchApp(seed: String? = nil) {
        let unit = Locale.current.region?.identifier == "DE" ? "kg" : "lb"
        var args = ["--use-in-memory-store", "-logweight_unit_preference", unit]
        if let seed {
            args.append("--seed=\(seed)")
        }
        app.launchArguments = args
        app.launch()
    }

    func attachScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    func waitForElement(_ element: XCUIElement, named: String, timeout: TimeInterval = 5) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element '\(named)' did not appear within \(timeout)s")
        return exists
    }
}
