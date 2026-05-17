import Foundation

/// Shared time-window options for weight trend charts (History and widgets).
public enum ChartTimeRange: String, CaseIterable, Codable, Sendable {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case all

    public var label: String {
        switch self {
        case .oneWeek: "1W"
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .all: "All"
        }
    }

    /// Start of the visible window, or `nil` for all history.
    public func cutoffDate(referenceDate: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .oneWeek:
            calendar.date(byAdding: .day, value: -7, to: referenceDate)
        case .oneMonth:
            calendar.date(byAdding: .month, value: -1, to: referenceDate)
        case .threeMonths:
            calendar.date(byAdding: .month, value: -3, to: referenceDate)
        case .sixMonths:
            calendar.date(byAdding: .month, value: -6, to: referenceDate)
        case .oneYear:
            calendar.date(byAdding: .year, value: -1, to: referenceDate)
        case .all:
            nil
        }
    }

    /// Weights whose `recordedAt` falls on or after the range cutoff.
    public func filterWeights(_ weights: [Weight], referenceDate: Date = .now) -> [Weight] {
        let sorted = weights.sorted { $0.recordedAt < $1.recordedAt }
        guard let cutoff = cutoffDate(referenceDate: referenceDate) else {
            return sorted
        }
        return sorted.filter { $0.recordedAt >= cutoff }
    }

    /// X-axis domain for a chart using this range.
    public func xDomain(
        weights: [Weight],
        referenceDate: Date = .now
    ) -> ClosedRange<Date> {
        let end = referenceDate
        if let start = cutoffDate(referenceDate: end) {
            return start...end
        }
        let filtered = filterWeights(weights, referenceDate: end)
        guard let first = filtered.first else {
            return end.addingTimeInterval(-86_400)...end
        }
        return first.recordedAt...end
    }
}
