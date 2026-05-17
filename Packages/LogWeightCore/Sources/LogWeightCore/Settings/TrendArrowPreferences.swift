import Foundation

/// Whether trend arrows appear in widgets, complications, and the History chart header.
public enum TrendArrowPreferences {
    /// Reads app-group defaults first (widgets), then standard defaults (app / watch). Defaults to enabled.
    public static func isEnabled(
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier),
        standardDefaults: UserDefaults = .standard
    ) -> Bool {
        for defaults in [sharedDefaults, standardDefaults].compactMap({ $0 }) {
            if let enabled = bool(from: defaults) {
                return enabled
            }
        }
        return true
    }

    /// Copies the app preference into the App Group so widget extensions can read it.
    public static func mirrorToAppGroup(
        standardDefaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier)
    ) {
        guard let shared = sharedDefaults else { return }
        let enabled = standardDefaults.object(forKey: SettingsKey.trendArrowEnabled) as? Bool ?? true
        shared.set(enabled, forKey: SettingsKey.trendArrowEnabled)
    }

    private static func bool(from defaults: UserDefaults) -> Bool? {
        guard defaults.object(forKey: SettingsKey.trendArrowEnabled) != nil else {
            return nil
        }
        return defaults.bool(forKey: SettingsKey.trendArrowEnabled)
    }
}
