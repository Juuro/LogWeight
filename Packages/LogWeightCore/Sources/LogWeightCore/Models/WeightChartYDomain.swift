import Foundation

/// Y-axis scale for weight trend charts — anchors around the data range with padding.
public enum WeightChartYDomain {
    /// Builds a display-unit Y domain from kilogram values (already converted for display).
    public static func domain(forDisplayValues values: [Double]) -> ClosedRange<Double> {
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0.0...1.0
        }

        let span = maximum - minimum
        let minimumVisibleSpan = 1.0
        let padding = max(span * 0.25, 0.4)

        let lowerBound = min(minimum, minimum - padding)
        let adjustedUpper = maximum + padding
        let upperBound = max(adjustedUpper, lowerBound + minimumVisibleSpan)

        return lowerBound...upperBound
    }

    /// Converts weights to display values and returns the Y domain.
    public static func domain(
        for weights: [Weight],
        displayUnit: WeightUnit
    ) -> ClosedRange<Double> {
        let values = weights.map { weight in
            Measurement(value: weight.valueInKilograms, unit: UnitMass.kilograms)
                .converted(to: displayUnit.unitMass)
                .value
        }
        return domain(forDisplayValues: values)
    }
}
