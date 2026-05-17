import Foundation

/// Resolves the user's preferred weight display unit for surfaces that cannot use `@AppStorage`.
public enum WeightDisplayPreferences {
    /// Reads app-group defaults first (iOS widgets), then standard defaults (app / watch), then locale.
    public static func preferredUnit(
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier),
        standardDefaults: UserDefaults = .standard
    ) -> WeightUnit {
        for defaults in [sharedDefaults, standardDefaults].compactMap({ $0 }) {
            if let unit = unit(from: defaults) {
                return unit
            }
        }
        return localeDefaultUnit
    }

    /// Copies the app preference into the App Group so widget extensions can read it.
    public static func mirrorUnitPreferenceToAppGroup(
        standardDefaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier)
    ) {
        guard let shared = sharedDefaults,
              let raw = standardDefaults.string(forKey: SettingsKey.unitPreference)
        else {
            return
        }
        shared.set(raw, forKey: SettingsKey.unitPreference)
    }

    private static func unit(from defaults: UserDefaults) -> WeightUnit? {
        guard let raw = defaults.string(forKey: SettingsKey.unitPreference) else {
            return nil
        }
        return WeightUnit(rawValue: raw)
    }

    private static var localeDefaultUnit: WeightUnit {
        Locale.current.measurementSystem == .metric ? .kilograms : .pounds
    }
}
