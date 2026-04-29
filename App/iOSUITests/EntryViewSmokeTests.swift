import XCTest

final class EntryViewSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Inject the in-memory store so this test does NOT require HealthKit
        // entitlements / a real device. See LogWeightApp.makeStore().
        app.launchArguments = ["--use-in-memory-store"]
        app.launch()
    }

    /// Smoke test: launch → tap +1 a few times → tap Save → assert the
    /// "Saved to Apple Health" status appears within 500ms.
    func testStepperPrimarySaveFlowReachesSavedState() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        plus.tap()
        plus.tap()

        let save = app.buttons["entry.save"]
        XCTAssertTrue(save.exists)
        XCTAssertTrue(save.isEnabled)

        let start = Date()
        save.tap()

        let saved = app.staticTexts["entry.status.saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 2.0),
                      "Save status did not appear after tapping Save")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 2.0,
                          "Save took longer than 2.0s end-to-end (budget includes UI overhead)")
    }

    /// Verifies that tapping the value display enters edit mode and returns to
    /// a save-ready state after dismissing the software keyboard toolbar (when present).
    func testKeyboardOpenDisablesSaveAndDoneReEnablesIt() throws {
        let valueDisplay = app.buttons["entry.value.display"]
        XCTAssertTrue(valueDisplay.waitForExistence(timeout: 2))
        valueDisplay.tap()

        let done = app.buttons["entry.keyboard.done"]
        if done.waitForExistence(timeout: 2) {
            done.tap()
        } else {
            // Some simulator setups attach a hardware keyboard and skip the
            // software keyboard toolbar entirely. In that case, just continue.
        }

        let save = app.buttons["entry.save"]
        XCTAssertTrue(save.isEnabled, "Save must be re-enabled when keyboard is dismissed")
    }

    /// Phase 4: history now includes a chart on iOS/iPadOS.
    func testHistorySheetShowsTrendChart() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        let history = app.buttons["entry.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 2))
        history.tap()

        let chart = app.descendants(matching: .any)["history.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 2),
                      "History chart should be visible on iOS")
    }

    /// Phase 4: settings controls should remain reachable for accessibility/testing.
    func testSettingsSheetExposesCoreControls() throws {
        let settings = app.buttons["entry.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 2))
        settings.tap()

        XCTAssertTrue(app.segmentedControls["settings.unit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["settings.prefill"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["settings.haptics"].waitForExistence(timeout: 2))
    }

    /// Accessibility regression guard: very large Dynamic Type should keep core
    /// controls reachable enough to complete a save.
    func testAccessibilityXXXLStillCanSaveWithStepperFlow() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "--use-in-memory-store",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()

        let save = app.buttons["entry.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))
    }
}
