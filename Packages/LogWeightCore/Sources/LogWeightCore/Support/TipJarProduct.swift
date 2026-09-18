import Foundation

/// Consumable tip-jar product identifiers.
///
/// Kept in Core (Foundation-only, no StoreKit import) so both the App-layer
/// StoreKit wrapper and `TipPromptCoordinator`'s tests share one source of
/// truth for the identifiers registered in App Store Connect and the local
/// `.storekit` configuration file.
public enum TipJarProduct: String, CaseIterable, Sendable {
    case small = "dev.logweight.tip.small"
    case medium = "dev.logweight.tip.medium"
    case large = "dev.logweight.tip.large"

    public var sfSymbol: String {
        switch self {
        case .small: return "cup.and.saucer"
        case .medium: return "heart"
        case .large: return "star"
        }
    }
}
