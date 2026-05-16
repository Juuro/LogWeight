import Foundation

public struct WeightEntry: Codable, Equatable, Sendable {
    public let value: Double
    public let date: Date

    public init(value: Double, date: Date) {
        self.value = value
        self.date = date
    }
}

public enum LogWeightWidgetConstants {
    public static let kind = "LogWeightInteractiveWidget"
}

public enum SharedWeightEntryStore {
    public static let appGroupIdentifier = "group.dev.logweight"
    public static let defaultStepInKilograms = 0.1

    private static let entryKey = "widget.lastWeightEntry"
    private static let draftValueKey = "widget.draftWeightValue"
    private static let fallbackWeightInKilograms = 75.0

    public static func loadEntry(userDefaults: UserDefaults? = nil) -> WeightEntry? {
        guard
            let defaults = defaults(userDefaults),
            let data = defaults.data(forKey: entryKey)
        else {
            return nil
        }

        return try? JSONDecoder().decode(WeightEntry.self, from: data)
    }

    public static func loadCurrentValue(userDefaults: UserDefaults? = nil) -> Double {
        guard let defaults = defaults(userDefaults) else {
            return fallbackWeightInKilograms
        }

        if let draft = defaults.object(forKey: draftValueKey) as? NSNumber {
            return clamp(draft.doubleValue)
        }

        if let entry = loadEntry(userDefaults: defaults) {
            return clamp(entry.value)
        }

        return fallbackWeightInKilograms
    }

    @discardableResult
    public static func increment(
        stepInKilograms: Double = defaultStepInKilograms,
        userDefaults: UserDefaults? = nil
    ) -> Double {
        let next = loadCurrentValue(userDefaults: userDefaults) + stepInKilograms
        let clamped = clamp(next)
        defaults(userDefaults)?.set(clamped, forKey: draftValueKey)
        return clamped
    }

    @discardableResult
    public static func decrement(
        stepInKilograms: Double = defaultStepInKilograms,
        userDefaults: UserDefaults? = nil
    ) -> Double {
        let next = loadCurrentValue(userDefaults: userDefaults) - stepInKilograms
        let clamped = clamp(next)
        defaults(userDefaults)?.set(clamped, forKey: draftValueKey)
        return clamped
    }

    public static func save(_ entry: WeightEntry, userDefaults: UserDefaults? = nil) {
        guard
            let defaults = defaults(userDefaults),
            let data = try? JSONEncoder().encode(entry)
        else {
            return
        }

        defaults.set(data, forKey: entryKey)
    }

    public static func clearDraftValue(userDefaults: UserDefaults? = nil) {
        defaults(userDefaults)?.removeObject(forKey: draftValueKey)
    }

    private static func defaults(_ userDefaults: UserDefaults?) -> UserDefaults? {
        userDefaults ?? UserDefaults(suiteName: appGroupIdentifier)
    }

    private static func clamp(_ value: Double) -> Double {
        max(1.0, min(500.0, value))
    }
}
