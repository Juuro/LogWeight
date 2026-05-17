import Foundation

/// Persists the chart widget's selected time range in the app group.
/// Used when `WidgetConfigurationIntent` parameters decode to defaults across processes.
public enum WidgetChartRangeStore {
    private static let rangeKey = "widget.chartTimeRange"

    public static func save(_ range: ChartTimeRange, userDefaults: UserDefaults? = nil) {
        defaults(userDefaults)?.set(range.rawValue, forKey: rangeKey)
    }

    public static func load(userDefaults: UserDefaults? = nil) -> ChartTimeRange? {
        guard let raw = defaults(userDefaults)?.string(forKey: rangeKey) else {
            return nil
        }
        return ChartTimeRange(rawValue: raw)
    }

    private static func defaults(_ userDefaults: UserDefaults?) -> UserDefaults? {
        userDefaults ?? UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier)
    }
}
