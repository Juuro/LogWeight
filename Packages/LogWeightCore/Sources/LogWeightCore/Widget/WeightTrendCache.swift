import Foundation

/// Cached 28-day weight trend for widget extensions (read synchronously from the App Group).
public enum WeightTrendCache {
    private static let directionKey = "logweight_cached_trend_direction"
    /// Matches the entry widget's HealthKit window.
    public static let entryWidgetLookbackDays = 28
    public static let entryWidgetSampleLimit = 40

    public static func save(
        _ direction: WeightTrendDirection,
        userDefaults: UserDefaults? = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier)
    ) {
        guard let defaults = userDefaults else { return }
        defaults.set(direction.storedValue, forKey: directionKey)
    }

    public static func load(
        userDefaults: UserDefaults? = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier)
    ) -> WeightTrendDirection {
        guard
            let defaults = userDefaults,
            let raw = defaults.string(forKey: directionKey)
        else {
            return .unknown
        }
        return WeightTrendDirection(storedValue: raw)
    }

    public static func update(
        from weights: [Weight],
        referenceDate: Date = .now,
        calendar: Calendar = .current,
        userDefaults: UserDefaults? = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier)
    ) {
        let windowStart = calendar.date(byAdding: .day, value: -entryWidgetLookbackDays, to: referenceDate)
        let direction = WeightTrendEvaluator.direction(
            weights: weights,
            windowStart: windowStart,
            referenceDate: referenceDate
        )
        save(direction, userDefaults: userDefaults)
    }
}

extension WeightTrendDirection {
    var storedValue: String {
        switch self {
        case .up: "up"
        case .down: "down"
        case .flat: "flat"
        case .unknown: "unknown"
        }
    }

    init(storedValue: String) {
        switch storedValue {
        case "up": self = .up
        case "down": self = .down
        case "flat": self = .flat
        default: self = .unknown
        }
    }
}
