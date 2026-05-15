import XCTest
@testable import LogWeightCore

final class WeightChartLineSeriesTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private var rangeStart: Date { base }

    func testLeadingPrependsSampleBeforeRangeStart() {
        let leading = Weight(valueInKilograms: 70.0, recordedAt: base.addingTimeInterval(-3_600))
        let firstVisible = Weight(valueInKilograms: 71.0, recordedAt: base)
        let lastVisible = Weight(valueInKilograms: 72.0, recordedAt: base.addingTimeInterval(3_600))
        let all = [leading, firstVisible, lastVisible]

        let line = WeightChartLineSeries.lineWeights(
            visible: [firstVisible, lastVisible],
            allWeights: all,
            rangeStart: rangeStart
        )

        XCTAssertEqual(line.count, 3)
        XCTAssertEqual(line[0], leading)
        XCTAssertEqual(line[1], firstVisible)
        XCTAssertEqual(line[2], lastVisible)
    }

    func testNoLeadingWhenAllRange() {
        let only = Weight(valueInKilograms: 75.0, recordedAt: base)

        let line = WeightChartLineSeries.lineWeights(
            visible: [only],
            allWeights: [only],
            rangeStart: nil
        )

        XCTAssertEqual(line, [only])
    }

    func testNoLeadingWhenNoOlderSampleExists() {
        let firstVisible = Weight(valueInKilograms: 71.0, recordedAt: base)
        let lastVisible = Weight(valueInKilograms: 72.0, recordedAt: base.addingTimeInterval(3_600))

        let line = WeightChartLineSeries.lineWeights(
            visible: [firstVisible, lastVisible],
            allWeights: [firstVisible, lastVisible],
            rangeStart: rangeStart
        )

        XCTAssertEqual(line, [firstVisible, lastVisible])
    }

    func testDoesNotExtendPastLatestVisibleSample() {
        let firstVisible = Weight(valueInKilograms: 71.0, recordedAt: base)
        let lastVisible = Weight(valueInKilograms: 72.0, recordedAt: base.addingTimeInterval(3_600))
        let rangeEnd = base.addingTimeInterval(86_400)

        let line = WeightChartLineSeries.lineWeights(
            visible: [firstVisible, lastVisible],
            allWeights: [firstVisible, lastVisible],
            rangeStart: rangeStart
        )

        XCTAssertEqual(line.last, lastVisible)
        XCTAssertFalse(line.contains { $0.recordedAt == rangeEnd && $0 != lastVisible })
    }

    func testEmptyVisibleReturnsEmpty() {
        let line = WeightChartLineSeries.lineWeights(
            visible: [],
            allWeights: [Weight(valueInKilograms: 70.0, recordedAt: base)],
            rangeStart: rangeStart
        )

        XCTAssertTrue(line.isEmpty)
    }

    func testSortsVisibleByRecordedAt() {
        let earlier = Weight(valueInKilograms: 70.0, recordedAt: base)
        let later = Weight(valueInKilograms: 72.0, recordedAt: base.addingTimeInterval(3_600))

        let line = WeightChartLineSeries.lineWeights(
            visible: [later, earlier],
            allWeights: [later, earlier],
            rangeStart: nil
        )

        XCTAssertEqual(line.map(\.recordedAt), [earlier.recordedAt, later.recordedAt])
    }
}
