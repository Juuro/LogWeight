import XCTest

/// App Store scenes for iPhone Duo (outer and inner display, portrait and landscape).
/// The same scenes run on whichever display is active; `Tools/CaptureDuoStoreScreenshots.sh`
/// files them per display. Landscape frames are captured in the display's native
/// portrait buffer and rotated upright by that script.
@MainActor
final class DuoScreenshots: ScreenshotTestCase {

    func test_duo_entry_portrait() throws {
        captureEntry(landscape: false)
    }

    func test_duo_entry_landscape() throws {
        captureEntry(landscape: true)
    }

    func test_duo_history_portrait() throws {
        captureHistory(landscape: false)
    }

    func test_duo_history_landscape() throws {
        captureHistory(landscape: true)
    }

    func test_duo_settings_portrait() throws {
        launchApp(seed: "linearTrend30Days")
        ensurePortrait()
        let settings = app.buttons["entry.settings"]
        waitForElement(settings, named: "entry.settings")
        settings.tap()
        waitForElement(app.segmentedControls["settings.unit"], named: "settings.unit")
        Thread.sleep(forTimeInterval: 0.5)
        attachScreenshot(named: "duo-settings-portrait")
    }

    /// Entry screen with an existing weight (stepper mode, no keyboard).
    private func captureEntry(landscape: Bool) {
        launchApp(seed: "linearTrend30Days")
        if landscape { rotateToLandscape() } else { ensurePortrait() }
        let display = app.descendants(matching: .any)["entry.value.display"]
        waitForElement(display, named: "entry.value.display")
        Thread.sleep(forTimeInterval: 0.8)
        attachScreenshot(named: landscape ? "duo-entry-landscape" : "duo-entry-portrait")
    }

    /// History with a 90-day trend so the chart has a clear shape.
    private func captureHistory(landscape: Bool) {
        launchApp(seed: "plateauThenDrop90Days")
        if !landscape { ensurePortrait() }
        app.openHistoryTab()
        if landscape { rotateToLandscape() }
        let chart = app.descendants(matching: .any)["history.chart"]
        waitForElement(chart, named: "history.chart")
        Thread.sleep(forTimeInterval: 0.8)
        attachScreenshot(named: landscape ? "duo-history-landscape" : "duo-history-portrait")
    }
}
