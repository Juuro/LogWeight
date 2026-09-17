import XCTest

final class EntryScreenshots: WatchScreenshotTestCase {

    /// Entry surface, prefilled from a seeded trend so the display isn't 0.0.
    func test_entry_default() throws {
        launchApp(seed: "linearTrend30Days")
        let display = app.descendants(matching: .any)["watch.entry.value"]
        waitForElement(display, named: "watch.entry.value")
        Thread.sleep(forTimeInterval: 0.3)
        attachScreenshot(named: "watch-entry-default")
    }
}
