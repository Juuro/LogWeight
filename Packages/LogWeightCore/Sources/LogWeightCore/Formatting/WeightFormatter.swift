import Foundation

/// Locale-aware formatting and parsing for body-weight values.
///
/// Uses `MeasurementFormatter` so decimal separators, unit symbols and
/// pluralisation match the user's locale. The internal canonical unit is always
/// kilograms; conversion happens at this boundary only.
public struct WeightFormatter {

    private let locale: Locale
    private let fractionDigits: Int

    public init(locale: Locale = .current, fractionDigits: Int = 1) {
        self.locale = locale
        self.fractionDigits = fractionDigits
    }

    /// Formats a value already expressed in kilograms into a string in the given
    /// `unit`. Example: `format(82.34, in: .pounds)` → `"181.5 lb"` for en_US.
    public func format(kilograms: Double, in unit: WeightUnit) -> String {
        let measurement = Measurement(value: kilograms, unit: UnitMass.kilograms)
            .converted(to: unit.unitMass)

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = fractionDigits
        numberFormatter.maximumFractionDigits = fractionDigits

        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.numberFormatter = numberFormatter
        formatter.unitOptions = .providedUnit
        return formatter.string(from: measurement)
    }

    /// Locale-aware numeric string for weight text fields (no unit suffix).
    public func formatEditableValue(kilograms: Double, in unit: WeightUnit) -> String {
        let value = Measurement(value: kilograms, unit: UnitMass.kilograms)
            .converted(to: unit.unitMass)
            .value
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = fractionDigits
        numberFormatter.maximumFractionDigits = fractionDigits
        return numberFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    /// Keeps only ASCII decimal digits and at most one decimal separator (locale separator,
    /// `.`, or `,`). Rejects minus signs and other symbols so pasted text cannot enter
    /// invalid weights silently.
    public func sanitizeWeightInput(_ string: String) -> String {
        if string.contains("-") {
            return ""
        }

        let preferredSeparator = locale.decimalSeparator ?? "."
        var sanitized = ""
        var hasSeparator = false

        for character in string {
            if Self.isASCIIWeightDigit(character) {
                sanitized.append(character)
                continue
            }
            let symbol = String(character)
            guard symbol == preferredSeparator || symbol == "." || symbol == "," else {
                continue
            }
            guard !hasSeparator else { continue }
            hasSeparator = true
            sanitized.append(preferredSeparator)
        }

        return sanitized
    }

    private static func isASCIIWeightDigit(_ character: Character) -> Bool {
        ("0"..."9").contains(character)
    }

    /// Parses a user-typed string in the given unit into a kilogram value.
    /// Returns `nil` if the input cannot be interpreted under the active locale,
    /// or if the parsed value converts to a negative kilogram amount.
    public func parseToKilograms(_ string: String, unit: WeightUnit) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal

        // Trim whitespace and any unit suffix the user might have typed.
        let cleaned = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: unit.shortDisplayName, with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let number = formatter.number(from: cleaned) else {
            return nil
        }
        let measurement = Measurement(value: number.doubleValue, unit: unit.unitMass)
        let kilograms = measurement.converted(to: .kilograms).value
        guard kilograms >= 0 else {
            return nil
        }
        return kilograms
    }
}
