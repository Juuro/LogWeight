import XCTest

/// Automated accessibility regression guard for the manual matrix in
/// `docs/AccessibilityAudit.md`. `performAccessibilityAudit()` (Xcode 15+)
/// checks contrast, hit-target size, Dynamic Type truncation, missing
/// traits/labels, and element detection — the same categories the manual
/// checklist covers by hand.
@MainActor
final class AccessibilityAuditTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = EntryViewSmokeTests.uiTestLaunchArguments
        app.launch()
    }

    func testEntryScreenFirstTimeAudit() throws {
        XCTAssertTrue(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit()
    }

    func testEntryScreenAfterSaveAudit() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        try app.performAccessibilityAudit()
    }

    func testHistoryScreenWithChartAudit() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        app.openHistoryTab()
        XCTAssertTrue(app.descendants(matching: .any)["history.chart"].waitForExistence(timeout: 2))

        try app.performAccessibilityAudit()
    }

    func testSettingsScreenAudit() throws {
        let settings = app.buttons["entry.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 2))
        settings.tap()
        XCTAssertTrue(app.segmentedControls["settings.unit"].waitForExistence(timeout: 2))

        try app.performAccessibilityAudit()
    }
}
