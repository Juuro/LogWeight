import Foundation

/// Decides whether the tip jar keeps showing its "thank you" note after a
/// purchase.
///
/// Tips are consumables, so StoreKit keeps no entitlement to query. Instead the
/// date of the last successful tip is stored in `UserDefaults`, and the note
/// stays visible for `visibilityWindow` afterwards. Pure `UserDefaults` logic
/// with no StoreKit dependency.
public enum TipThankYouPolicy {
    public static let visibilityWindow: TimeInterval = 7 * 24 * 60 * 60

    public static func recordTip(at date: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(date, forKey: SettingsKey.lastTipPurchaseDate)
    }

    /// `true` if the last recorded tip happened within `visibilityWindow` of `now`.
    /// A stored date in the future (clock change) counts as not recent.
    public static func shouldShowThankYou(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        guard let last = defaults.object(forKey: SettingsKey.lastTipPurchaseDate) as? Date else {
            return false
        }
        let elapsed = now.timeIntervalSince(last)
        return elapsed >= 0 && elapsed < visibilityWindow
    }
}
