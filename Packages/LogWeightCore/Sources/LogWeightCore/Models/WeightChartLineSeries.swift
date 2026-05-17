import Foundation

/// Builds the weight samples used for a history chart line, including an optional
/// off-window leading anchor so the line enters from the left without implying
/// the first visible point is the user's earliest entry.
public enum WeightChartLineSeries {
    /// Returns weights for `LineMark` rendering: sorted visible samples plus an optional
    /// leading boundary at `rangeStart` (last sample before the range, clamped to the
    /// chart's left edge so the line does not draw past the Y-axis).
    public static func lineWeights(
        visible: [Weight],
        allWeights: [Weight],
        rangeStart: Date?
    ) -> [Weight] {
        let sortedVisible = visible.sorted { $0.recordedAt < $1.recordedAt }
        guard !sortedVisible.isEmpty else { return [] }

        var result: [Weight] = []

        if let rangeStart {
            let sortedAll = allWeights.sorted { $0.recordedAt < $1.recordedAt }
            if let leading = sortedAll.last(where: { $0.recordedAt < rangeStart }),
               let boundary = leadingBoundary(
                   leading: leading,
                   firstVisible: sortedVisible[0],
                   rangeStart: rangeStart
               ) {
                result.append(boundary)
            }
        }

        result.append(contentsOf: sortedVisible)
        return result
    }

    /// Point on the segment from `leading` to `firstVisible` at `rangeStart`, for chart clipping.
    private static func leadingBoundary(
        leading: Weight,
        firstVisible: Weight,
        rangeStart: Date
    ) -> Weight? {
        let firstTime = firstVisible.recordedAt.timeIntervalSinceReferenceDate
        let rangeTime = rangeStart.timeIntervalSinceReferenceDate
        guard firstTime > rangeTime else { return nil }

        let leadingTime = leading.recordedAt.timeIntervalSinceReferenceDate
        let span = firstTime - leadingTime
        guard span > 0 else { return nil }

        let t = (rangeTime - leadingTime) / span
        let value = leading.valueInKilograms
            + t * (firstVisible.valueInKilograms - leading.valueInKilograms)
        return Weight(valueInKilograms: value, recordedAt: rangeStart)
    }
}
