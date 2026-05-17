import XCTest
@testable import LogWeightCore

final class ChartTimeRangeTests: XCTestCase {
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testOneWeekCutoffIsSevenDaysBeforeReference() {
        let cutoff = ChartTimeRange.oneWeek.cutoffDate(referenceDate: reference, calendar: calendar)
        let expected = calendar.date(byAdding: .day, value: -7, to: reference)
        XCTAssertEqual(cutoff, expected)
    }

    func testAllRangeHasNoCutoff() {
        XCTAssertNil(ChartTimeRange.all.cutoffDate(referenceDate: reference, calendar: calendar))
    }

    func testFilterWeightsExcludesSamplesBeforeCutoff() {
        let old = Weight(valueInKilograms: 70, recordedAt: reference.addingTimeInterval(-864_000))
        let recent = Weight(valueInKilograms: 75, recordedAt: reference.addingTimeInterval(-3600))
        let filtered = ChartTimeRange.oneWeek.filterWeights([old, recent], referenceDate: reference)
        XCTAssertEqual(filtered, [recent])
    }

    func testXDomainForBoundedRangeUsesCutoffToReference() {
        let start = calendar.date(byAdding: .day, value: -7, to: reference)!
        let domain = ChartTimeRange.oneWeek.xDomain(weights: [], referenceDate: reference)
        XCTAssertEqual(domain.lowerBound, start)
        XCTAssertEqual(domain.upperBound, reference)
    }
}
