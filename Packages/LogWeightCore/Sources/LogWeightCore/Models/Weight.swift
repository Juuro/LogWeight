import Foundation

/// A single body-weight observation. Stored canonically in kilograms; conversion
/// is handled at the display boundary by `WeightFormatter`.
///
/// `Weight` is a value type with no identity — equality and hashing are defined
/// by `valueInKilograms` (rounded to 3 decimal places to absorb floating-point
/// noise from unit conversions) and `recordedAt`.
public struct Weight: Equatable, Hashable, Sendable, Codable {
    public let valueInKilograms: Double
    public let recordedAt: Date

    public init(valueInKilograms: Double, recordedAt: Date) {
        self.valueInKilograms = valueInKilograms
        self.recordedAt = recordedAt
    }

    /// Convenience initialiser that converts from a user-facing unit into the
    /// canonical kilogram representation.
    public init(value: Double, unit: WeightUnit, recordedAt: Date) {
        let measurement = Measurement(value: value, unit: unit.unitMass)
        self.valueInKilograms = measurement.converted(to: .kilograms).value
        self.recordedAt = recordedAt
    }

    public func value(in unit: WeightUnit) -> Double {
        let measurement = Measurement(value: valueInKilograms, unit: UnitMass.kilograms)
        return measurement.converted(to: unit.unitMass).value
    }

    /// Equality rounds to 3 decimal places so a kg→lb→kg round-trip remains equal.
    public static func == (lhs: Weight, rhs: Weight) -> Bool {
        let lhsRounded = (lhs.valueInKilograms * 1000).rounded() / 1000
        let rhsRounded = (rhs.valueInKilograms * 1000).rounded() / 1000
        return lhsRounded == rhsRounded && lhs.recordedAt == rhs.recordedAt
    }

    public func hash(into hasher: inout Hasher) {
        let rounded = (valueInKilograms * 1000).rounded() / 1000
        hasher.combine(rounded)
        hasher.combine(recordedAt)
    }
}
