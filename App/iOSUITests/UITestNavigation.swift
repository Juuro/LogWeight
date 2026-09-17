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
        let tabBar = tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 1) {
            tabBar.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
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

    /// Opens the History tab on iPhone and iPad, in whatever locale the
    /// simulator is running (see Tools/CaptureStoreScreenshots.sh's
    /// `-testLanguage`/`-testRegion`) — falls back through stable identifier,
    /// localized label (English and German), and tab index, in that order.
    /// iPadOS 18's regular-width tab bar floats as a top capsule outside the
    /// `tabBars` accessibility container, so the last fallbacks search `app.buttons` directly.
    func openHistoryTab(file: StaticString = #file, line: UInt = #line) {
        dismissKeyboardIfPresent()

        if tabBars.buttons["tab.history"].waitForExistence(timeout: 1) {
            tapTabBarButton(tabBars.buttons["tab.history"])
            return
        }

        for label in ["History", "Verlauf"] {
            let byLabel = tabBars.buttons[label]
            if byLabel.waitForExistence(timeout: 2) {
                tapTabBarButton(byLabel.firstMatch)
                return
            }
        }

        let secondTab = tabBars.buttons.element(boundBy: 1)
        if secondTab.waitForExistence(timeout: 3) {
            tapTabBarButton(secondTab)
            return
        }

        let historyButton = buttons["tab.history"]
        if historyButton.waitForExistence(timeout: 3) {
            tapTabBarButton(historyButton)
            return
        }

        for label in ["History", "Verlauf"] {
            let byLabel = buttons[label]
            if byLabel.waitForExistence(timeout: 2) {
                tapTabBarButton(byLabel.firstMatch)
                return
            }
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
