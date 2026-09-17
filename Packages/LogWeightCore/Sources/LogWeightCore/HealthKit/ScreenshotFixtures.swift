import Foundation

/// Deterministic in-memory weight fixtures for AI-driven screenshot capture.
///
/// Each case produces a reproducible `[Weight]` sample list so that the same
/// `--seed=<rawValue>` launch argument always yields the same *shape* of
/// screen state. Anchor dates default to the current wall-clock time so the
/// samples always fall inside HistoryView's default (recent) chart range,
/// no matter how much later this runs — pass an explicit `now` to pin dates
/// for unit tests that need bit-for-bit reproducibility.
public enum ScreenshotFixture: String, Sendable, CaseIterable {
    case empty
    case singleEntry
    case linearTrend30Days
    case plateauThenDrop90Days

    /// Fixed anchor for unit tests that need bit-for-bit reproducible dates.
    /// 2026-05-01 12:00 UTC.
    public static let referenceDate: Date = Date(timeIntervalSince1970: 1_777_017_600)

    public func samples(now: Date = Date()) -> [Weight] {
        switch self {
        case .empty:
            return []

        case .singleEntry:
            return [Weight(valueInKilograms: 78.4, recordedAt: now)]

        case .linearTrend30Days:
            return Self.linearTrend(
                from: 82.0,
                to: 78.5,
                days: 30,
                endingAt: now
            )

        case .plateauThenDrop90Days:
            return Self.plateauThenDrop(endingAt: now)
        }
    }

    private static func linearTrend(
        from start: Double,
        to end: Double,
        days: Int,
        endingAt now: Date
    ) -> [Weight] {
        guard days > 0 else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        var samples: [Weight] = []
        for offset in 0..<days {
            let progress = Double(offset) / Double(max(days - 1, 1))
            let kilos = start + (end - start) * progress
            let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: now) ?? now
            samples.append(Weight(valueInKilograms: kilos, recordedAt: date))
        }
        return samples
    }

    private static func plateauThenDrop(endingAt now: Date) -> [Weight] {
        let calendar = Calendar(identifier: .gregorian)
        var samples: [Weight] = []
        let totalDays = 90
        for offset in 0..<totalDays {
            let dayFromEnd = totalDays - 1 - offset
            let kilos: Double
            if dayFromEnd >= 60 {
                // First 30 days (oldest): plateau around 84 kg
                kilos = 84.0 + sin(Double(dayFromEnd) * 0.4) * 0.3
            } else if dayFromEnd >= 30 {
                // Middle 30 days: gradual drop 84 → 80
                let progress = 1.0 - Double(dayFromEnd - 30) / 30.0
                kilos = 84.0 - 4.0 * progress
            } else {
                // Last 30 days: continued drop 80 → 76 with noise
                let progress = 1.0 - Double(dayFromEnd) / 30.0
                kilos = 80.0 - 4.0 * progress + sin(Double(dayFromEnd) * 0.7) * 0.25
            }
            let date = calendar.date(byAdding: .day, value: -dayFromEnd, to: now) ?? now
            samples.append(Weight(valueInKilograms: kilos, recordedAt: date))
        }
        return samples
    }
}
