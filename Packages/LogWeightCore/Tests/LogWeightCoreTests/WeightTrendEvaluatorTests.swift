import XCTest
@testable import LogWeightCore

final class WeightTrendEvaluatorTests: XCTestCase {
    private let reference = ScreenshotFixture.referenceDate

    func testLinearTrend30DaysIsDown() {
        let samples = ScreenshotFixture.linearTrend30Days.samples(now: reference)
        let windowStart = Calendar.current.date(byAdding: .day, value: -28, to: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: samples,
            windowStart: windowStart,
            referenceDate: reference
        )

        XCTAssertEqual(direction, .down)
    }

    func testTooFewSamplesReturnsUnknown() {
        let samples = [
            Weight(valueInKilograms: 75.0, recordedAt: reference.addingTimeInterval(-3 * 86_400)),
            Weight(valueInKilograms: 74.5, recordedAt: reference)
        ]
        let windowStart = Calendar.current.date(byAdding: .day, value: -28, to: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: samples,
            windowStart: windowStart,
            referenceDate: reference
        )

        XCTAssertEqual(direction, .unknown)
    }

    func testSpanTooShortReturnsUnknown() {
        let samples = (0..<4).map { index in
            Weight(
                valueInKilograms: 75.0 + Double(index) * 0.5,
                recordedAt: reference.addingTimeInterval(Double(index) * 86_400)
            )
        }
        let windowStart = Calendar.current.date(byAdding: .day, value: -28, to: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: samples,
            windowStart: windowStart,
            referenceDate: reference
        )

        XCTAssertEqual(direction, .unknown)
    }

    func testFlatPlateauReturnsFlat() {
        let calendar = Calendar(identifier: .gregorian)
        let samples = (0..<10).map { offset in
            let date = calendar.date(byAdding: .day, value: -(9 - offset) * 3, to: reference) ?? reference
            return Weight(valueInKilograms: 75.0, recordedAt: date)
        }
        let windowStart = calendar.date(byAdding: .day, value: -28, to: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: samples,
            windowStart: windowStart,
            referenceDate: reference
        )

        XCTAssertEqual(direction, .flat)
    }

    func testClearUpwardTrend() {
        let calendar = Calendar(identifier: .gregorian)
        let samples = (0..<8).map { offset in
            let date = calendar.date(byAdding: .day, value: -(7 - offset) * 4, to: reference) ?? reference
            return Weight(valueInKilograms: 70.0 + Double(offset) * 0.4, recordedAt: date)
        }
        let windowStart = calendar.date(byAdding: .day, value: -28, to: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: samples,
            windowStart: windowStart,
            referenceDate: reference
        )

        XCTAssertEqual(direction, .up)
    }

    func testSamplesOutsideWindowAreIgnored() {
        let calendar = Calendar(identifier: .gregorian)
        let old = Weight(
            valueInKilograms: 90.0,
            recordedAt: calendar.date(byAdding: .day, value: -60, to: reference) ?? reference
        )
        let recent = (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -(4 - offset) * 5, to: reference) ?? reference
            return Weight(valueInKilograms: 75.0 + Double(offset) * 0.5, recordedAt: date)
        }
        let windowStart = calendar.date(byAdding: .day, value: -28, to: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: [old] + recent,
            windowStart: windowStart,
            referenceDate: reference
        )

        XCTAssertEqual(direction, .up)
    }

    func testOneWeekChartConfigurationAllowsShortSpan() {
        let calendar = Calendar(identifier: .gregorian)
        let samples = [
            Weight(
                valueInKilograms: 72.0,
                recordedAt: calendar.date(byAdding: .day, value: -2, to: reference) ?? reference
            ),
            Weight(valueInKilograms: 67.9, recordedAt: reference)
        ]
        let windowStart = ChartTimeRange.oneWeek.cutoffDate(referenceDate: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: samples,
            windowStart: windowStart,
            referenceDate: reference,
            configuration: .forChartRange(.oneWeek)
        )

        XCTAssertEqual(direction, .down)
    }

    func testFutureSamplesExcluded() {
        let future = Weight(
            valueInKilograms: 100.0,
            recordedAt: reference.addingTimeInterval(86_400)
        )
        let samples = ScreenshotFixture.linearTrend30Days.samples(now: reference) + [future]
        let windowStart = Calendar.current.date(byAdding: .day, value: -28, to: reference)

        let direction = WeightTrendEvaluator.direction(
            weights: samples,
            windowStart: windowStart,
            referenceDate: reference
        )

        XCTAssertEqual(direction, .down)
    }
}
