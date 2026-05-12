import XCTest

final class HistoryScreenshots: ScreenshotTestCase {

    /// History tab with no entries — empty-state copy.
    func test_history_empty() throws {
        launchApp(seed: "empty")
        openHistoryTab()
        Thread.sleep(forTimeInterval: 0.4)
        attachScreenshot(named: "history-empty")
    }

    /// History tab with a 30-day linear trend — chart visible above list.
    func test_history_with_chart_30d() throws {
        launchApp(seed: "linearTrend30Days")
        openHistoryTab()
        let chart = app.descendants(matching: .any)["history.chart"]
        waitForElement(chart, named: "history.chart")
        Thread.sleep(forTimeInterval: 0.4)
        attachScreenshot(named: "history-with-chart-30d")
    }

    /// History tab with a 90-day plateau-then-drop trend.
    func test_history_90d_plateau() throws {
        launchApp(seed: "plateauThenDrop90Days")
        openHistoryTab()
        let chart = app.descendants(matching: .any)["history.chart"]
        waitForElement(chart, named: "history.chart")
        Thread.sleep(forTimeInterval: 0.4)
        attachScreenshot(named: "history-90d-plateau")
    }

    /// History sheet after scrolling the list — verifies that the topmost
    /// fully-visible row and its matching chart point are highlighted in sync.
    /// The list is scrolled enough that the very-newest row is no longer at the
    /// top, so the highlight should land on a different row + chart point than
    /// the initial-load state.
    func test_history_list_scrolled() throws {
        launchApp(seed: "linearTrend30Days")
        openHistoryTab()
        let chart = app.descendants(matching: .any)["history.chart"]
        waitForElement(chart, named: "history.chart")
        let list = app.descendants(matching: .any)["history.list"]
        waitForElement(list, named: "history.list")
        // Two upward swipes on the list area to push the topmost row down.
        list.swipeUp()
        list.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot(named: "history-list-scrolled")
    }

    /// History sheet after a single small scroll so the new topmost row is
    /// still inside the 1M chart range — verifies the chart point highlight
    /// follows the row highlight (AC4).
    func test_history_list_small_scroll() throws {
        launchApp(seed: "linearTrend30Days")
        openHistoryTab()
        let chart = app.descendants(matching: .any)["history.chart"]
        waitForElement(chart, named: "history.chart")
        let list = app.descendants(matching: .any)["history.list"]
        waitForElement(list, named: "history.list")
        // One small drag — push the topmost row down by ~1-2 rows so the new
        // topmost is still inside the 1M chart range.
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: end)
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot(named: "history-list-small-scroll")
    }

    /// History tab with crosshair active (long-press on chart) showing tooltip.
    func test_history_chart_crosshair() throws {
        launchApp(seed: "linearTrend30Days")
        openHistoryTab()
        let chart = app.descendants(matching: .any)["history.chart"]
        waitForElement(chart, named: "history.chart")
        // Long-press the chart to engage the crosshair gesture.
        chart.press(forDuration: 0.6)
        Thread.sleep(forTimeInterval: 0.4)
        attachScreenshot(named: "history-chart-crosshair")
    }

    private func openHistoryTab() {
        let historyTab = app.tabBars.buttons["History"]
        waitForElement(historyTab, named: "tab.history")
        historyTab.tap()
    }
}
