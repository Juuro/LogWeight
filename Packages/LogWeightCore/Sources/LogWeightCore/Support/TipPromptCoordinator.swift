import Foundation

/// Decides when to show the one-time "support LogWeight" tip prompt.
///
/// Shown at most once, after the user has logged `promptThreshold` successful
/// weight entries. Pure `UserDefaults` logic with no StoreKit/UIKit
/// dependency, so it is exercised without any purchase infrastructure — the
/// App layer only calls `recordSuccessfulEntry(defaults:)` once per
/// successful `EntryState.commit(store:)` and presents the prompt when it
/// returns `true`.
public enum TipPromptCoordinator {
    public static let promptThreshold = 10

    /// Increments the successful-entry count and reports whether the prompt
    /// should be shown now. Returns `true` at most once per install.
    @discardableResult
    public static func recordSuccessfulEntry(defaults: UserDefaults = .standard) -> Bool {
        let count = defaults.integer(forKey: SettingsKey.successfulEntryCount) + 1
        defaults.set(count, forKey: SettingsKey.successfulEntryCount)
        guard count >= promptThreshold, !defaults.bool(forKey: SettingsKey.tipPromptShown) else {
            return false
        }
        return true
    }

    /// Marks the prompt as shown so it never appears again, regardless of
    /// whether the user opened the tip jar or dismissed it.
    public static func markPresented(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: SettingsKey.tipPromptShown)
    }
}
