import XCTest

/// Base class for AI-driven screenshot scenes.
///
/// Each scene is a single test method that:
/// 1. Launches `LogWeight` with `--use-in-memory-store`, `--skip-splash`, and
///    optionally `--seed=<fixture>` so the screen is deterministic.
/// 2. Drives the UI to the target state (taps, swipes, focus).
/// 3. Calls `attachScreenshot(named:)` with a kebab-case scene id.
///
/// The wrapper script `Tools/CaptureScene.sh` runs the test, then extracts the
/// PNG attachment from the resulting `.xcresult` bundle into
/// `Docs/ai-screenshots/<scene>.png`. Scenes are designed to *always pass* —
/// they capture state, they do not assert behavior. Behavior assertions live
/// in `LogWeightUITests`.
class ScreenshotTestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Launches the app with the standard screenshot launch arguments.
    /// Pass `seed` to preload the in-memory store with a `ScreenshotFixture`.
    /// `extraArguments` is appended verbatim (e.g. for Dynamic Type overrides).
    func launchApp(seed: String? = nil, extraArguments: [String] = []) {
        var args = ["--use-in-memory-store", "--skip-splash"]
        if let seed {
            args.append("--seed=\(seed)")
        }
        args.append(contentsOf: extraArguments)
        app.launchArguments = args
        app.launch()
    }

    /// Captures the current screen and attaches it to the test result with
    /// the given name. The wrapper script extracts attachments by name.
    func attachScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for an element to exist and asserts (with a generous timeout) so
    /// scenes fail fast with a clear message when the UI moved.
    @discardableResult
    func waitForElement(_ element: XCUIElement, named: String, timeout: TimeInterval = 5) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element '\(named)' did not appear within \(timeout)s")
        return exists
    }
}
