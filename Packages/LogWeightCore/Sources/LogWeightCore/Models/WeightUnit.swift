import Foundation
import HealthKit

/// User-facing weight unit. Phase 1 supports kilograms and pounds only.
/// Stones are intentionally omitted in Phase 1 — adding `case stones` later
/// is a non-breaking change because callers iterate `WeightUnit.allCases`.
public enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kilograms = "kg"
    case pounds = "lb"

    /// HKUnit equivalent for HealthKit serialisation. Internal values are always
    /// stored canonically in kilograms; this is only used at the read/write boundary.
    public var hkUnit: HKUnit {
        switch self {
        case .kilograms:
            return HKUnit.gramUnit(with: .kilo)
        case .pounds:
            return HKUnit.pound()
        }
    }

    /// Foundation `UnitMass` equivalent for `Measurement`-based formatting.
    public var unitMass: UnitMass {
        switch self {
        case .kilograms:
            return .kilograms
        case .pounds:
            return .pounds
        }
    }

    /// Localisable display name (short form). Long names are produced by
    /// `WeightFormatter` so that pluralisation and locale rules apply.
    public var shortDisplayName: String {
        rawValue
    }
}
