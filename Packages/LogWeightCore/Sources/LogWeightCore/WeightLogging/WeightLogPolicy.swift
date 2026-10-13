import Foundation

/// Tunable limits for logging a weight without the stepper UI (Siri, Shortcuts,
/// Action Button). Values are in kilograms, the app's canonical unit.
public struct WeightLogPolicy: Sendable, Equatable {
    /// Values outside this range need explicit confirmation before saving.
    public var plausibleRangeKilograms: ClosedRange<Double>
    /// A difference from the newest entry above this needs explicit confirmation.
    public var largeJumpKilograms: Double
    /// An identical value logged this recently counts as a duplicate.
    public var duplicateWindow: TimeInterval
    /// "Identical" means within this tolerance (absorbs kg/lb rounding).
    public var duplicateToleranceKilograms: Double

    public init(
        plausibleRangeKilograms: ClosedRange<Double> = 20...500,
        largeJumpKilograms: Double = 10,
        duplicateWindow: TimeInterval = 60,
        duplicateToleranceKilograms: Double = 0.05
    ) {
        self.plausibleRangeKilograms = plausibleRangeKilograms
        self.largeJumpKilograms = largeJumpKilograms
        self.duplicateWindow = duplicateWindow
        self.duplicateToleranceKilograms = duplicateToleranceKilograms
    }

    public static let `default` = WeightLogPolicy()
}
