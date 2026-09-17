import XCTest

final class HistoryScreenshots: WatchScreenshotTestCase {

    /// History sheet opened from the toolbar clock button, with a seeded 30-day trend.
    func test_history_default() throws {
        launchApp(seed: "linearTrend30Days")
        let historyButton = app.buttons["watch.history.button"]
        waitForElement(historyButton, named: "watch.history.button")
        historyButton.tap()
        let chart = app.descendants(matching: .any)["history.chart"]
        waitForElement(chart, named: "history.chart")
        Thread.sleep(forTimeInterval: 0.4)
        attachScreenshot(named: "watch-history-default")
    }
}
