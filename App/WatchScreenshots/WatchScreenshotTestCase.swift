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
    /// simulator's region (set via `xcodebuild test -testRegion`): only
    /// `.us` is imperial (lb) — `.uk` (e.g. en-GB) still displays kg for
    /// body weight despite Foundation reporting it as a distinct,
    /// non-`.metric` measurement system.
    func launchApp(seed: String? = nil) {
        let unit = Locale.current.measurementSystem == .us ? "lb" : "kg"
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
