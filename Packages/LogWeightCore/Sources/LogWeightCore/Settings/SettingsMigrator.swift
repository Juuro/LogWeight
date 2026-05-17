import Foundation

/// Settings schema migrator. Idempotent — safe to call on every cold start.
///
/// Phase 1 has only schema v1, so the migrator simply stamps the version on
/// first launch. The structure is in place so future phases can chain migrators
/// without changing the call site in `LogWeightApp`.
public enum SettingsMigrator {

    public static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        let stored = defaults.object(forKey: SettingsKey.schemaVersion) as? Int ?? 0
        guard stored < CURRENT_SETTINGS_SCHEMA_VERSION else {
            mirrorWidgetPreferences(standardDefaults: defaults)
            return
        }

        // Future migrators chain here, e.g.:
        // if stored < 2 { migrateToV2(defaults) }

        defaults.set(CURRENT_SETTINGS_SCHEMA_VERSION, forKey: SettingsKey.schemaVersion)
        mirrorWidgetPreferences(standardDefaults: defaults)
    }

    private static func mirrorWidgetPreferences(standardDefaults: UserDefaults) {
        WeightDisplayPreferences.mirrorUnitPreferenceToAppGroup(standardDefaults: standardDefaults)
        TrendArrowPreferences.mirrorToAppGroup(standardDefaults: standardDefaults)
    }
}
