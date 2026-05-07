import XCTest

final class SettingsScreenshots: ScreenshotTestCase {

    /// Settings sheet, default state (kg unit).
    func test_settings_default() throws {
        launchApp()
        let settings = app.buttons["entry.settings"]
        waitForElement(settings, named: "entry.settings")
        settings.tap()
        waitForElement(app.segmentedControls["settings.unit"], named: "settings.unit")
        Thread.sleep(forTimeInterval: 0.3)
        attachScreenshot(named: "settings-default")
    }

    /// Settings sheet after switching unit to lbs via the segmented control.
    func test_settings_lbs_unit() throws {
        launchApp()
        let settings = app.buttons["entry.settings"]
        waitForElement(settings, named: "entry.settings")
        settings.tap()
        let unitControl = app.segmentedControls["settings.unit"]
        waitForElement(unitControl, named: "settings.unit")
        // The segmented control exposes its segments as buttons; pick the
        // second one (lbs) without depending on its localised label.
        let lbsSegment = unitControl.buttons.element(boundBy: 1)
        if lbsSegment.exists {
            lbsSegment.tap()
        }
        Thread.sleep(forTimeInterval: 0.3)
        attachScreenshot(named: "settings-lbs-unit")
    }
}
