import XCTest

extension XCUIApplication {

    /// Opens the History tab on iPhone and iPad. UI tests pin English via launch arguments;
    /// the second tab index is a fallback when identifiers are not exposed on tab items.
    func openHistoryTab(file: StaticString = #file, line: UInt = #line) {
        let candidates: [XCUIElement] = [
            tabBars.buttons["tab.history"],
            buttons["tab.history"],
            tabBars.buttons["History"],
            buttons["History"],
            tabBars.buttons.element(boundBy: 1),
        ]

        for candidate in candidates {
            if candidate.waitForExistence(timeout: 1) {
                candidate.tap()
                return
            }
        }

        XCTFail(
            "History tab not found",
            file: file,
            line: line
        )
    }
}
