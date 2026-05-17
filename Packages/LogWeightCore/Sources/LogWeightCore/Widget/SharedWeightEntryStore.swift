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
    public static let chartKind = "LogWeightChartWidget"
}

public enum SharedWeightEntryStore {
    public static let appGroupIdentifier = "group.de.juuronina.logweight"
    public static let defaultStepInKilograms = 0.1
    /// Unsaved widget +/- adjustments expire after this interval.
    public static let draftTTL: TimeInterval = 600

    private static let entryKey = "widget.lastWeightEntry"
    private static let draftValueKey = "widget.draftWeightValue"
    private static let draftUpdatedAtKey = "widget.draftUpdatedAt"
    private static let fallbackWeightInKilograms = 75.0
    private static let minimumWeightInKilograms = 1.0
    private static let maximumWeightInKilograms = 500.0

    public static func loadEntry(userDefaults: UserDefaults? = nil) -> WeightEntry? {
        guard
            let defaults = defaults(userDefaults),
            let data = defaults.data(forKey: entryKey)
        else {
            return nil
        }

        do {
            return try JSONDecoder().decode(WeightEntry.self, from: data)
        } catch {
            assertionFailure("SharedWeightEntryStore decode failed")
            return nil
        }
    }

    public static func loadCurrentValue(userDefaults: UserDefaults? = nil) -> Double {
        guard let defaults = defaults(userDefaults) else {
            return fallbackWeightInKilograms
        }

        expireStaleDraftIfNeeded(userDefaults: defaults)

        if defaults.object(forKey: draftValueKey) != nil {
            return clamp(defaults.double(forKey: draftValueKey))
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
        persistDraft(clamped, userDefaults: userDefaults)
        return clamped
    }

    @discardableResult
    public static func decrement(
        stepInKilograms: Double = defaultStepInKilograms,
        userDefaults: UserDefaults? = nil
    ) -> Double {
        let next = loadCurrentValue(userDefaults: userDefaults) - stepInKilograms
        let clamped = clamp(next)
        persistDraft(clamped, userDefaults: userDefaults)
        return clamped
    }

    public static func save(_ entry: WeightEntry, userDefaults: UserDefaults? = nil) {
        guard let defaults = defaults(userDefaults) else {
            return
        }
        do {
            let data = try JSONEncoder().encode(entry)
            defaults.set(data, forKey: entryKey)
        } catch {
            assertionFailure("SharedWeightEntryStore encode failed")
        }
    }

    public static func clearDraftValue(userDefaults: UserDefaults? = nil) {
        guard let defaults = defaults(userDefaults) else {
            return
        }
        defaults.removeObject(forKey: draftValueKey)
        defaults.removeObject(forKey: draftUpdatedAtKey)
    }

    public static func clearSavedEntry(userDefaults: UserDefaults? = nil) {
        defaults(userDefaults)?.removeObject(forKey: entryKey)
    }

    /// Replaces the App Group cache with the latest HealthKit weight, or clears it when none exists.
    /// Always discards any unsaved widget draft.
    public static func syncFromLatestWeight(_ weight: Weight?, userDefaults: UserDefaults? = nil) {
        clearDraftValue(userDefaults: userDefaults)
        if let weight {
            save(
                WeightEntry(value: weight.valueInKilograms, date: weight.recordedAt),
                userDefaults: userDefaults
            )
        } else {
            clearSavedEntry(userDefaults: userDefaults)
        }
    }

    /// Clears an expired widget draft so the timeline can fall back to the last saved entry.
    public static func expireStaleDraftIfNeeded(
        now: Date = .now,
        userDefaults: UserDefaults? = nil
    ) {
        guard let defaults = defaults(userDefaults),
              defaults.object(forKey: draftValueKey) != nil
        else {
            return
        }

        guard let updatedAt = defaults.object(forKey: draftUpdatedAtKey) as? Date else {
            clearDraftValue(userDefaults: defaults)
            return
        }

        if now.timeIntervalSince(updatedAt) > draftTTL {
            clearDraftValue(userDefaults: defaults)
        }
    }

    private static func persistDraft(_ value: Double, userDefaults: UserDefaults?) {
        guard let defaults = defaults(userDefaults) else {
            return
        }
        defaults.set(clamp(value), forKey: draftValueKey)
        defaults.set(Date(), forKey: draftUpdatedAtKey)
    }

    private static func defaults(_ userDefaults: UserDefaults?) -> UserDefaults? {
        userDefaults ?? UserDefaults(suiteName: appGroupIdentifier)
    }

    private static func clamp(_ value: Double) -> Double {
        max(minimumWeightInKilograms, min(maximumWeightInKilograms, value))
    }
}
