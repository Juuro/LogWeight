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

    /// Verifies that tapping the value display opens the keyboard and DISABLES
    /// the Save button — DA1 fix. Tapping Done re-enables it.
    func testKeyboardOpenDisablesSaveAndDoneReEnablesIt() throws {
        let valueDisplay = app.buttons["entry.value.display"]
        XCTAssertTrue(valueDisplay.waitForExistence(timeout: 2))
        valueDisplay.tap()

        let save = app.buttons["entry.save"]
        XCTAssertFalse(save.isEnabled, "Save must be disabled while keyboard is up")

        let done = app.buttons["entry.keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        done.tap()

        XCTAssertTrue(save.isEnabled, "Save must be re-enabled when keyboard is dismissed")
    }
}
