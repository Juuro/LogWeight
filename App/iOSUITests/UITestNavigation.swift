import XCTest

@MainActor
extension XCUIApplication {

    /// Decimal pad has no Done key; tap above the keyboard so tab-bar buttons are hittable.
    private func dismissKeyboardIfPresent() {
        guard keyboards.element(boundBy: 0).waitForExistence(timeout: 0.5) else { return }
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
    }

    /// Opens the History tab on iPhone and iPad. UI tests pin English via launch arguments;
    /// the second tab index is a fallback when identifiers are not exposed on tab items.
    func openHistoryTab(file: StaticString = #file, line: UInt = #line) {
        dismissKeyboardIfPresent()

        if tabBars.buttons["tab.history"].waitForExistence(timeout: 3) {
            tabBars.buttons["tab.history"].tap()
            return
        }

        let historyByLabel = tabBars.buttons["History"]
        if historyByLabel.waitForExistence(timeout: 3) {
            historyByLabel.firstMatch.tap()
            return
        }

        let secondTab = tabBars.buttons.element(boundBy: 1)
        if secondTab.waitForExistence(timeout: 3) {
            secondTab.tap()
            return
        }

        XCTFail(
            "History tab not found",
            file: file,
            line: line
        )
    }

    /// Returns to the Entry tab after visiting History.
    func openEntryTab(file: StaticString = #file, line: UInt = #line) {
        dismissKeyboardIfPresent()

        if tabBars.buttons["tab.entry"].waitForExistence(timeout: 3) {
            tabBars.buttons["tab.entry"].tap()
            return
        }

        let entryByLabel = tabBars.buttons["Entry"]
        if entryByLabel.waitForExistence(timeout: 3) {
            entryByLabel.firstMatch.tap()
            return
        }

        let firstTab = tabBars.buttons.element(boundBy: 0)
        if firstTab.waitForExistence(timeout: 3) {
            firstTab.tap()
            return
        }

        XCTFail(
            "Entry tab not found",
            file: file,
            line: line
        )
    }
}
