import XCTest

@MainActor
final class EntryViewSmokeTests: XCTestCase {

    /// Pin UI language so tab labels and copy match English `Localizable.strings`.
    nonisolated static let uiTestLaunchArguments = [
        "--use-in-memory-store",
        "--skip-splash",
        "-AppleLanguages", "(en)",
        "-AppleLocale", "en_US",
    ]

    private var app: XCUIApplication!

    private var historyEmptyState: XCUIElement {
        app.descendants(matching: .any)["history.empty"]
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Inject the in-memory store so this test does NOT require HealthKit
        // entitlements / a real device. See LogWeightApp.makeStore().
        app.launchArguments = Self.uiTestLaunchArguments
        app.launch()
    }

    /// Smoke test: launch → tap +1 a few times → tap Save → assert the
    /// "Saved to Apple Health" status appears.
    func testStepperPrimarySaveFlowReachesSavedState() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        plus.tap()

        let save = app.buttons["entry.save"]
        XCTAssertTrue(save.exists)
        XCTAssertTrue(save.isEnabled)

        save.tap()

        let saved = app.staticTexts["entry.status.saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5.0),
                      "Save status did not appear after tapping Save")
    }

    /// Save stays enabled with the keyboard up and commits the typed first weight in one tap.
    func testSaveWhileKeyboardOpenCommitsFirstWeight() throws {
        let valueField = app.textFields["entry.value.textfield"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.tap()
        valueField.typeText("80")

        let save = app.buttons["entry.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        XCTAssertTrue(save.isEnabled, "Save must stay enabled while the keyboard is open")
        save.tap()

        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2),
                      "Save should apply typed value and persist")
        XCTAssertFalse(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 1),
                       "First-weight prompt should disappear after the first save")
    }

    /// Regression guard: first-time entry keeps the keyboard field available.
    func testFirstEntryShowsKeyboardFieldOnLaunch() throws {
        XCTAssertTrue(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["entry.value.textfield"].waitForExistence(timeout: 2),
                      "First entry should open the keyboard field automatically")
    }

    /// Returning to Entry with an empty Apple Health store should reopen the keyboard field.
    func testFirstEntryReopensKeyboardAfterHistoryTab() throws {
        XCTAssertTrue(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["entry.value.textfield"].waitForExistence(timeout: 2))

        app.openHistoryTab()
        XCTAssertTrue(
            historyEmptyState.waitForExistence(timeout: 10)
                || app.staticTexts["No weights yet."].waitForExistence(timeout: 5)
        )

        app.openEntryTab()
        XCTAssertTrue(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 5))
        // Keyboard focus is scheduled ~400ms after tab return (see EntryView.scheduleFirstWeightKeyboardFocus).
        XCTAssertTrue(
            app.textFields["entry.value.textfield"].waitForExistence(timeout: 8),
            "First entry should reopen the keyboard field when returning from History"
        )
    }

    /// After the first save, keyboard entry stays unavailable and double-tap restores last saved weight.
    func testKeyboardEntryUnavailableAfterFirstSave() throws {
        XCTAssertTrue(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["entry.value.textfield"].waitForExistence(timeout: 2))

        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))

        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        // Tab away and back so Entry leaves keyboard-first editing without changing the saved value.
        app.openHistoryTab()
        app.openEntryTab()

        let valueDisplay = app.descendants(matching: .any)["entry.value.display"]
        XCTAssertTrue(valueDisplay.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["entry.first-weight.prompt"].exists)
        XCTAssertFalse(app.textFields["entry.value.textfield"].exists)
        guard let savedDisplay = Self.parseDisplayValue(valueDisplay.label) else {
            XCTFail("Could not parse display after save: '\(valueDisplay.label)'")
            return
        }

        plus.tap()
        guard let bumpedDisplay = Self.parseDisplayValue(valueDisplay.label) else {
            XCTFail("Could not parse display after bump: '\(valueDisplay.label)'")
            return
        }
        XCTAssertGreaterThan(
            bumpedDisplay,
            savedDisplay + 0.05,
            "Display should increase after tapping +"
        )

        valueDisplay.tap()
        let valueField = app.textFields["entry.value.textfield"]
        XCTAssertFalse(valueField.waitForExistence(timeout: 1),
                       "Keyboard entry must not be available after the first weight is saved")

        valueDisplay.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        XCTAssertFalse(valueField.waitForExistence(timeout: 1),
                       "Double tap must not reopen keyboard editing after the first save")

        guard let restored = Self.parseDisplayValue(valueDisplay.label) else {
            XCTFail("Could not parse display after double tap: '\(valueDisplay.label)'")
            return
        }
        XCTAssertEqual(restored, savedDisplay, accuracy: 0.05,
                       "Double tap should restore the last saved weight on the returning-user branch")
    }

    /// Deleting the last saved weight in History returns Entry to the first-time screen.
    func testDeletingLastWeightReturnsToFirstEntryScreen() throws {
        let valueField = app.textFields["entry.value.textfield"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.tap()
        valueField.typeText("80")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        app.openHistoryTab()
        let savedRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '80'")
        ).firstMatch
        XCTAssertTrue(savedRow.waitForExistence(timeout: 2))
        savedRow.press(forDuration: 1.0)
        app.buttons["Delete"].tap()

        XCTAssertTrue(historyEmptyState.waitForExistence(timeout: 10))

        app.openEntryTab()
        XCTAssertTrue(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["entry.value.textfield"].waitForExistence(timeout: 2))
        XCTAssertFalse(
            app.descendants(matching: .any)["entry.value.display"].waitForExistence(timeout: 1),
            "Stepper display must not appear when Apple Health has no weights"
        )
    }

    /// Phase 4: history now includes a chart on iOS/iPadOS.
    func testHistorySheetShowsTrendChart() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        app.openHistoryTab()

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

    /// Long-press auto-repeat smoke test: holding the +1 stepper for 3 s must
    /// produce many more increments than a single tap and must clearly
    /// exceed the slow-phase-only bound — proof that the gesture is wired to
    /// the engine and that acceleration kicks in. Exact fire count varies
    /// with simulator scheduling, so the delta bound is intentionally loose
    /// (>2.0 in display units ≈ at least 20 increments of 0.1 kg ≈ 0.44 lb).
    func testStepperLongPressAcceleratesIncrement() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        // First entry uses the keyboard field; seed one step so the value is readable.
        plus.tap()
        guard let valueElement = Self.weightValueElement(in: app, timeout: 2) else {
            XCTFail("Weight value UI not found")
            return
        }

        guard let beforeValue = Self.parseWeightValue(from: valueElement) else {
            XCTFail("Could not parse before-value from '\(valueElement.label)' / '\(String(describing: valueElement.value))'")
            return
        }

        plus.press(forDuration: 3.0)

        guard let afterElement = Self.weightValueElement(in: app, timeout: 2) else {
            XCTFail("Weight value UI not found after long press")
            return
        }
        guard let afterValue = Self.parseWeightValue(from: afterElement) else {
            XCTFail("Could not parse after-value from '\(afterElement.label)' / '\(String(describing: afterElement.value))'")
            return
        }

        let delta = afterValue - beforeValue
        XCTAssertGreaterThan(delta, 1.6,
                             "Holding +1 for 3 s should produce far more than 16 steps once acceleration kicks in. before=\(beforeValue), after=\(afterValue), delta=\(delta)")
    }

    /// Returns the visible weight readout (keyboard field on first entry, styled text afterward).
    private static func weightValueElement(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        let display = app.descendants(matching: .any)["entry.value.display"]
        if display.waitForExistence(timeout: timeout) {
            return display
        }
        let field = app.textFields["entry.value.textfield"]
        if field.waitForExistence(timeout: timeout) {
            return field
        }
        return nil
    }

    /// Parses a weight from the stepper display label or the keyboard field value.
    private static func parseWeightValue(from element: XCUIElement) -> Double? {
        if let parsed = parseDisplayValue(element.label) {
            return parsed
        }
        if let value = element.value as? String {
            return parseDisplayValue(value)
        }
        return nil
    }

    /// Extracts the leading numeric value from an accessibility label like
    /// `"Weight 75.0 kg. Tap to edit."`. Tolerant to a comma decimal so the
    /// test does not depend on the simulator's locale.
    private static func parseDisplayValue(_ label: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"\d+(?:[.,]\d+)?"#) else { return nil }
        let nsLabel = label as NSString
        let range = NSRange(location: 0, length: nsLabel.length)
        guard let match = regex.firstMatch(in: label, range: range) else { return nil }
        let numericString = nsLabel
            .substring(with: match.range)
            .replacingOccurrences(of: ",", with: ".")
        return Double(numericString)
    }

    private func openHistoryWithSingleSavedWeight() -> XCUIElement {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        app.openHistoryTab()

        let chart = app.descendants(matching: .any)["history.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 2))
        return chart
    }

    /// Accessibility regression guard: very large Dynamic Type should keep core
    /// controls reachable enough to complete a save.
    func testAccessibilityXXXLStillCanSaveWithStepperFlow() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = Self.uiTestLaunchArguments + [
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

    /// Phase 4 follow-up: with the chart lifted out of the List, the static
    /// "Recent entries" label must exist between the chart and the list rows
    /// (it replaces the old sticky Section header that overlaid content).
    func testHistoryShowsRecentEntriesLabelAboveList() throws {
        let chart = openHistoryWithSingleSavedWeight()
        XCTAssertTrue(chart.exists)

        let label = app.staticTexts["history.recent-entries-label"]
        XCTAssertTrue(label.waitForExistence(timeout: 2),
                      "'Recent entries' label must be present as a static element above the list")
    }

    /// Phase 4 follow-up: scrolling the list must NOT scroll the chart away.
    /// The chart accessibility id must remain hittable after a swipe gesture
    /// over the list area.
    func testHistoryChartStaysPinnedAfterListSwipe() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))

        // Seed a few entries so the list has something to scroll.
        for _ in 0..<3 {
            plus.tap()
            app.buttons["entry.save"].tap()
            XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))
        }

        app.openHistoryTab()

        let chart = app.descendants(matching: .any)["history.chart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 2))

        let list = app.descendants(matching: .any)["history.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 2))
        list.swipeUp()

        // After scrolling the list, the chart MUST still exist (pinned).
        XCTAssertTrue(chart.exists,
                      "Chart should remain in the view hierarchy after scrolling the list")
    }

    /// Splash appears on launch and transitions into the entry screen.
    func testSplashShowsOnLaunchAndTransitionsToEntry() throws {
        app.terminate()

        let splashRun = XCUIApplication()
        splashRun.launchArguments = Self.uiTestLaunchArguments.filter { $0 != "--skip-splash" } + ["--hold-splash"]
        splashRun.launch()

        let splash = splashRun.descendants(matching: .any)["splash.overlay"]
        XCTAssertTrue(splash.waitForExistence(timeout: 1.5), "Splash should appear immediately on launch")

        // Ensure tap-to-continue works and reveals the entry screen.
        splash.tap()
        XCTAssertFalse(splash.waitForExistence(timeout: 1.8), "Splash should dismiss when tapped")
        XCTAssertTrue(splashRun.buttons["entry.stepper.plus"].waitForExistence(timeout: 2),
                      "Entry screen should be available normally")
    }
}
