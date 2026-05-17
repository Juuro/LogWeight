import Foundation

/// Persists the chart widget's selected time range in the shared app group defaults.
public enum WidgetChartRangeStore {
    private static let rangeKey = "widget.chartTimeRange"

    /// Saves the chart time range for widget-related consumers that read from the shared app group defaults.
    public static func save(_ range: ChartTimeRange, userDefaults: UserDefaults? = nil) {
        defaults(userDefaults)?.set(range.rawValue, forKey: rangeKey)
    }

    /// Loads the previously saved chart time range from the shared app group defaults.
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
