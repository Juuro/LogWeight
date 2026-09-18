import XCTest

final class HistoryScreenshots: WatchScreenshotTestCase {

    /// History sheet opened from the toolbar clock button, with a seeded
    /// 30-day trend. HistoryView compiles its chart out on watchOS
    /// (`#if !os(watchOS)` in App/Shared/Views/HistoryView.swift) — the watch
    /// sheet is list-only, so this only waits for the recent-entries list.
    func test_history_default() throws {
        launchApp(seed: "linearTrend30Days")
        let historyButton = app.buttons["watch.history.button"].firstMatch
        waitForElement(historyButton, named: "watch.history.button")
        historyButton.tap()
        let list = app.descendants(matching: .any)["history.list"]
        waitForElement(list, named: "history.list")
        Thread.sleep(forTimeInterval: 0.4)
        attachScreenshot(named: "watch-history-default")
    }
}
