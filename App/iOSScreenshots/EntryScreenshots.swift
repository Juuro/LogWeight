import XCTest

final class EntryScreenshots: ScreenshotTestCase {

    /// Empty entry surface, splash already dismissed, default unit (kg).
    func test_entry_default() throws {
        launchApp()
        waitForElement(app.buttons["entry.stepper.plus"], named: "entry.stepper.plus")
        // Allow the entry view to settle (last-weight prefill, idle animations).
        Thread.sleep(forTimeInterval: 0.3)
        attachScreenshot(named: "entry-default")
    }

    /// Entry surface after 10 taps of `+` — Save button enabled.
    func test_entry_after_plus_ten() throws {
        launchApp()
        let plus = app.buttons["entry.stepper.plus"]
        waitForElement(plus, named: "entry.stepper.plus")
        for _ in 0..<10 {
            plus.tap()
        }
        Thread.sleep(forTimeInterval: 0.2)
        attachScreenshot(named: "entry-after-plus-ten")
    }

    /// Entry surface with the decimal-pad keyboard up.
    func test_entry_keyboard_up() throws {
        launchApp()
        let textField = app.textFields["entry.value.textfield"]
        // An empty store auto-focuses the keyboard on launch (see EntryView's
        // `canEditWithKeyboard`), so the tappable display never appears — only
        // fall back to tapping it if the field isn't already up.
        if !textField.waitForExistence(timeout: 2) {
            let display = app.descendants(matching: .any)["entry.value.display"]
            waitForElement(display, named: "entry.value.display")
            display.tap()
            _ = textField.waitForExistence(timeout: 3)
        }
        Thread.sleep(forTimeInterval: 0.2)
        attachScreenshot(named: "entry-keyboard-up")
    }
}
