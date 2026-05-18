import XCTest

@MainActor
extension XCUIApplication {

    /// Decimal pad has no Done key; resign focus via chrome above the field so the tab bar is hittable.
    private func dismissKeyboardIfPresent() {
        let keyboard = keyboards.element(boundBy: 0)
        guard keyboard.waitForExistence(timeout: 0.5) else { return }
        if staticTexts["entry.first-weight.prompt"].waitForExistence(timeout: 1) {
            staticTexts["entry.first-weight.prompt"].tap()
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        _ = keyboard.waitForNonExistence(timeout: 3)
        guard keyboard.exists else { return }
        tabBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        _ = keyboard.waitForNonExistence(timeout: 2)
    }

    /// Taps a tab-bar control without scroll-to-visible (keyboard can block AX scroll on iPad CI).
    private func tapTabBarButton(_ button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Opens the History tab on iPhone and iPad. UI tests pin English via launch arguments;
    /// the second tab index is a fallback when identifiers are not exposed on tab items.
    func openHistoryTab(file: StaticString = #file, line: UInt = #line) {
        dismissKeyboardIfPresent()

        if tabBars.buttons["tab.history"].waitForExistence(timeout: 1) {
            tapTabBarButton(tabBars.buttons["tab.history"])
            return
        }

        let historyByLabel = tabBars.buttons["History"]
        if historyByLabel.waitForExistence(timeout: 3) {
            tapTabBarButton(historyByLabel.firstMatch)
            return
        }

        let secondTab = tabBars.buttons.element(boundBy: 1)
        if secondTab.waitForExistence(timeout: 3) {
            tapTabBarButton(secondTab)
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

        if tabBars.buttons["tab.entry"].waitForExistence(timeout: 1) {
            tapTabBarButton(tabBars.buttons["tab.entry"])
            return
        }

        let entryByLabel = tabBars.buttons["Entry"]
        if entryByLabel.waitForExistence(timeout: 3) {
            tapTabBarButton(entryByLabel.firstMatch)
            return
        }

        let firstTab = tabBars.buttons.element(boundBy: 0)
        if firstTab.waitForExistence(timeout: 3) {
            tapTabBarButton(firstTab)
            return
        }

        XCTFail(
            "Entry tab not found",
            file: file,
            line: line
        )
    }
}
