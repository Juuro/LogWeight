import Foundation

/// Builds the weight samples used for a history chart line, including an optional
/// off-window leading anchor so the line enters from the left without implying
/// the first visible point is the user's earliest entry.
public enum WeightChartLineSeries {
    /// Returns weights for `LineMark` rendering: sorted visible samples plus an optional
    /// leading anchor (last sample before `rangeStart`).
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
            if let leading = sortedAll.last(where: { $0.recordedAt < rangeStart }) {
                result.append(leading)
            }
        }

        result.append(contentsOf: sortedVisible)
        return result
    }
}
