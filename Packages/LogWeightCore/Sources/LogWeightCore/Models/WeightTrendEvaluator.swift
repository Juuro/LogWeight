import Foundation

/// Direction of recent body-weight change for compact UI (widgets, complications).
public enum WeightTrendDirection: Sendable, Equatable {
    case up
    case down
    case flat
    case unknown
}

/// Tunables for `WeightTrendEvaluator.direction`.
public struct WeightTrendConfiguration: Sendable, Equatable {
    public var minimumSampleCount: Int
    public var minimumSpanDays: Double
    /// Slopes with magnitude below this (kg/day) are treated as flat.
    public var flatSlopeThresholdKgPerDay: Double

    public init(
        minimumSampleCount: Int = 3,
        minimumSpanDays: Double = 7,
        flatSlopeThresholdKgPerDay: Double = 0.02
    ) {
        self.minimumSampleCount = minimumSampleCount
        self.minimumSpanDays = minimumSpanDays
        self.flatSlopeThresholdKgPerDay = flatSlopeThresholdKgPerDay
    }

    /// Relaxed gates for short chart windows (e.g. 1W widget) so a visible trend can be shown.
    public static func forChartRange(_ range: ChartTimeRange) -> WeightTrendConfiguration {
        switch range {
        case .oneWeek:
            WeightTrendConfiguration(
                minimumSampleCount: 2,
                minimumSpanDays: 1,
                flatSlopeThresholdKgPerDay: 0.015
            )
        case .oneMonth:
            WeightTrendConfiguration(
                minimumSampleCount: 3,
                minimumSpanDays: 4,
                flatSlopeThresholdKgPerDay: 0.02
            )
        case .threeMonths, .sixMonths:
            WeightTrendConfiguration(
                minimumSampleCount: 3,
                minimumSpanDays: 7,
                flatSlopeThresholdKgPerDay: 0.02
            )
        case .oneYear, .all:
            WeightTrendConfiguration()
        }
    }
}

/// Estimates whether weight is trending up, down, or flat using OLS slope over a time window.
public enum WeightTrendEvaluator {
    private static let secondsPerDay: Double = 86_400

    public static func direction(
        weights: [Weight],
        windowStart: Date?,
        referenceDate: Date = .now,
        configuration: WeightTrendConfiguration = WeightTrendConfiguration()
    ) -> WeightTrendDirection {
        let inWindow = weights.filter { weight in
            weight.recordedAt <= referenceDate
                && (windowStart.map { weight.recordedAt >= $0 } ?? true)
        }
        let sorted = inWindow.sorted { $0.recordedAt < $1.recordedAt }

        guard sorted.count >= configuration.minimumSampleCount else {
            return .unknown
        }

        guard let first = sorted.first, let last = sorted.last else {
            return .unknown
        }

        let spanDays = last.recordedAt.timeIntervalSince(first.recordedAt) / Self.secondsPerDay
        guard spanDays >= configuration.minimumSpanDays else {
            return .unknown
        }

        guard let slopeKgPerDay = linearSlopeKgPerDay(samples: sorted, origin: first.recordedAt) else {
            return .unknown
        }

        let threshold = configuration.flatSlopeThresholdKgPerDay
        if slopeKgPerDay > threshold {
            return .up
        }
        if slopeKgPerDay < -threshold {
            return .down
        }
        return .flat
    }

    /// Ordinary least-squares slope (kg/day) with x = days since `origin`.
    private static func linearSlopeKgPerDay(samples: [Weight], origin: Date) -> Double? {
        guard samples.count >= 2 else { return nil }

        var sumX = 0.0
        var sumY = 0.0
        var sumXX = 0.0
        var sumXY = 0.0
        let n = Double(samples.count)

        for sample in samples {
            let x = sample.recordedAt.timeIntervalSince(origin) / secondsPerDay
            let y = sample.valueInKilograms
            sumX += x
            sumY += y
            sumXX += x * x
            sumXY += x * y
        }

        let denominator = n * sumXX - sumX * sumX
        guard denominator > 0 else { return nil }

        return (n * sumXY - sumX * sumY) / denominator
    }
}
