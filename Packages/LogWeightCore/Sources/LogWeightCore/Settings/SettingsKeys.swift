import Foundation

/// Canonical `UserDefaults` / `@AppStorage` keys used across LogWeight.
///
/// All keys are namespaced under `logweight_*` so they can be batch-cleared
/// during account-deletion / privacy-reset flows in future phases without
/// touching unrelated UserDefaults entries.
///
/// The schema version is bumped whenever the *meaning* of a key changes. Adding
/// new keys is non-breaking and does NOT bump the version.
public enum SettingsKey {
    public static let unitPreference = "logweight_unit_preference"
    public static let defaultEntryMode = "logweight_default_entry_mode"
    public static let hapticsEnabled = "logweight_haptics_enabled"
    public static let schemaVersion = "logweight_settings_schema_version"
}

/// The schema version this build understands. Bump whenever a key's meaning
/// changes; never decrease.
public let CURRENT_SETTINGS_SCHEMA_VERSION: Int = 1

public enum DefaultEntryMode: String, CaseIterable, Codable, Sendable {
    /// Pre-fill the entry with the most-recent saved weight (recommended).
    case lastSaved = "last_saved"
    /// Pre-fill with a fixed value the user configures.
    case fixedValue = "fixed_value"
}
