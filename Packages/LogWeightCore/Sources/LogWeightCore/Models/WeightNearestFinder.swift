import Foundation

/// Locates the sample nearest in time to a chart hover date.
public enum WeightNearestFinder {
    public static func closest(to date: Date, in weights: [Weight]) -> Weight? {
        weights.min { a, b in
            abs(a.recordedAt.timeIntervalSince(date)) < abs(b.recordedAt.timeIntervalSince(date))
        }
    }
}
