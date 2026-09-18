import XCTest

/// Automated accessibility regression guard for the manual matrix in
/// `docs/AccessibilityAudit.md`. `performAccessibilityAudit()` (Xcode 15+)
/// checks contrast, hit-target size, Dynamic Type truncation, missing
/// traits/labels, and element detection — the same categories the manual
/// checklist covers by hand.
@MainActor
final class AccessibilityAuditTests: XCTestCase {

    /// Dynamic Type auditing requires simulator support that isn't available
    /// on every runtime; the manual matrix in `docs/AccessibilityAudit.md`
    /// covers Dynamic Type by hand, so the automated audit excludes it here.
    private static let auditTypes: XCUIAccessibilityAuditType = .all.subtracting(.dynamicType)

    private var app: XCUIApplication!

    /// Prints full issue detail, then fails only on issues outside
    /// `acceptedDescriptions` — see "Known limitations" in
    /// `docs/AccessibilityAudit.md` for why each accepted one is tolerated
    /// rather than patched.
    private static func auditHandler(
        accepting acceptedDescriptions: Set<String> = []
    ) -> (XCUIAccessibilityAuditIssue) -> Bool {
        { issue in
            print("Accessibility audit issue: \(issue.compactDescription)")
            print("  detail: \(issue.detailedDescription)")
            if let element = issue.element {
                print("  element: \(element)")
            }
            return acceptedDescriptions.contains(issue.compactDescription)
        }
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = EntryViewSmokeTests.uiTestLaunchArguments
        app.launch()
    }

    func testEntryScreenFirstTimeAudit() throws {
        XCTAssertTrue(app.staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: Self.auditTypes, Self.auditHandler())
    }

    /// "Saved to Apple Health" uses `.secondary` at `.callout` size — accepted,
    /// see docs/AccessibilityAudit.md Known limitations.
    func testEntryScreenAfterSaveAudit() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        try app.performAccessibilityAudit(
            for: Self.auditTypes,
            Self.auditHandler(accepting: ["Contrast nearly passed"])
        )
    }

    /// Row timestamp uses `.secondary` at `.callout` size ("Contrast nearly
    /// passed"); the chart's drawn axis/point content isn't exposed as
    /// accessible text ("Potentially inaccessible text", the same gap
    /// `docs/AccessibilityAudit.md` already tracks under "no custom VoiceOver
    /// summaries"). Both accepted, see Known limitations there.
    func testHistoryScreenWithChartAudit() throws {
        let plus = app.buttons["entry.stepper.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["entry.status.saved"].waitForExistence(timeout: 2))

        app.openHistoryTab()
        XCTAssertTrue(app.descendants(matching: .any)["history.chart"].waitForExistence(timeout: 2))

        try app.performAccessibilityAudit(
            for: Self.auditTypes,
            Self.auditHandler(accepting: ["Contrast nearly passed", "Potentially inaccessible text"])
        )
    }

    /// Toolbar "Done" is unstyled system chrome — iOS 26 renders it as a
    /// translucent Liquid Glass capsule, which the audit flags (classification
    /// flips between "failed" and "nearly passed" run to run, same underlying
    /// cause). "Pre-fill with" row's trailing value text ("Last saved" /
    /// "Fixed value") is SwiftUI's own default Form Picker layout, which can
    /// clip at the largest Dynamic Type sizes. Both accepted, see
    /// docs/AccessibilityAudit.md Known limitations.
    func testSettingsScreenAudit() throws {
        let settings = app.buttons["entry.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 2))
        settings.tap()
        XCTAssertTrue(app.segmentedControls["settings.unit"].waitForExistence(timeout: 2))

        try app.performAccessibilityAudit(
            for: Self.auditTypes,
            Self.auditHandler(accepting: ["Contrast failed", "Contrast nearly passed", "Text clipped"])
        )
    }
}
