import XCTest
import StoreKitTest

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
    private var storeKitSession: SKTestSession?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        storeKitSession = nil
    }

    /// Starts a local StoreKit testing session from `Resources/LogWeight.storekit`
    /// so IAP-driven scenes (the tip jar) load real `Product`s without a
    /// network call. Scheme-level StoreKit configuration only applies to the
    /// Run action, not Test, so scenes needing IAP call this explicitly
    /// before `launchApp()`.
    ///
    /// Reads the file straight from the checked-out source tree via
    /// `#filePath` rather than as a bundled resource: XcodeGen 2.46 silently
    /// drops `.storekit` files from a target's `resources:` list (confirmed
    /// against an identically-placed `.txt`, which copies fine), so bundling
    /// isn't an option here.
    @discardableResult
    func startStoreKitTestSession() throws -> SKTestSession {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/LogWeight.storekit")
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        storeKitSession = session
        return session
    }

    /// Launches the app with the standard screenshot launch arguments.
    /// Pass `seed` to preload the in-memory store with a `ScreenshotFixture`.
    /// `extraArguments` is appended verbatim (e.g. for Dynamic Type overrides).
    ///
    /// Language/region are intentionally *not* pinned here — env vars set by
    /// the calling shell don't cross into the simulator-hosted test process,
    /// so locale is driven by `xcodebuild test -testLanguage -testRegion`
    /// instead (see Tools/CaptureScene.sh and Tools/CaptureStoreScreenshots.sh).
    /// Display unit follows that region: only `.us` is imperial (lb) — `.uk`
    /// (e.g. en-GB) still displays kg for body weight despite Foundation
    /// reporting it as a distinct, non-`.metric` measurement system — passed
    /// via the `-logweight_unit_preference` NSUserDefaults argument (crosses
    /// into the app process the same way `-AppleLanguages` did).
    func launchApp(seed: String? = nil, extraArguments: [String] = []) {
        let unit = Locale.current.measurementSystem == .us ? "lb" : "kg"
        var args = [
            "--use-in-memory-store",
            "--skip-splash",
            "-logweight_unit_preference", unit,
        ]
        if let seed {
            args.append("--seed=\(seed)")
        }
        args.append(contentsOf: extraArguments)
        app.launchArguments = args
        app.launch()
    }

    /// Forces portrait and waits until the app window is taller than wide. A previous
    /// landscape scene can leave the simulator rotated, so portrait scenes verify instead of
    /// assuming (otherwise a sideways frame with portrait pixel dimensions slips through).
    func ensurePortrait() {
        for _ in 0..<6 {
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 1.0)
            let frame = app.windows.firstMatch.frame
            if frame.height > frame.width { return }
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 0.5)
        }
        let frame = app.windows.firstMatch.frame
        XCTFail("Device did not return to portrait (orientation=\(XCUIDevice.shared.orientation.rawValue), window=\(frame))")
    }

    /// Rotates the device to landscape and waits until the app window is wider than tall.
    /// The simulator sometimes ignores the first request, so retry (with a portrait nudge)
    /// and fail loudly instead of silently capturing a portrait frame.
    func rotateToLandscape() {
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        for _ in 0..<6 {
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 1.0)
            let frame = app.windows.firstMatch.frame
            if frame.width > frame.height { return }
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 0.5)
        }
        let frame = app.windows.firstMatch.frame
        XCTFail("Device did not rotate to landscape (orientation=\(XCUIDevice.shared.orientation.rawValue), window=\(frame), app=\(app.frame))")
    }

    /// The screen to capture. `XCUIScreen.main` is the iPhone Duo's outer display; with
    /// `SCREENSHOT_DISPLAY=inner` (set by `Tools/CaptureDuoStoreScreenshots.sh --pose inner`,
    /// forwarded via `TEST_RUNNER_SCREENSHOT_DISPLAY`) capture its second, inner screen.
    private func captureScreen() -> XCUIScreen {
        guard ProcessInfo.processInfo.environment["SCREENSHOT_DISPLAY"] == "inner" else {
            return XCUIScreen.main
        }
        return XCUIScreen.screens.first { $0 != XCUIScreen.main } ?? XCUIScreen.main
    }

    /// Captures the current screen and attaches it to the test result with
    /// the given name. The wrapper script extracts attachments by name.
    func attachScreenshot(named name: String) {
        let screenshot = captureScreen().screenshot()
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
