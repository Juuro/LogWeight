import XCTest
@testable import LogWeightCore

final class WeightChartYDomainTests: XCTestCase {
    func testEmptyValuesReturnsPlaceholderDomain() {
        XCTAssertEqual(WeightChartYDomain.domain(forDisplayValues: []), 0.0...1.0)
    }

    func testSingleValueAddsPadding() {
        let domain = WeightChartYDomain.domain(forDisplayValues: [75.0])
        XCTAssertLessThan(domain.lowerBound, 75.0)
        XCTAssertGreaterThan(domain.upperBound, 75.0)
        XCTAssertGreaterThanOrEqual(domain.upperBound - domain.lowerBound, 1.0)
    }

    func testSpanUsesMinimumVisibleSpan() {
        let domain = WeightChartYDomain.domain(forDisplayValues: [75.0, 75.1])
        XCTAssertGreaterThanOrEqual(domain.upperBound - domain.lowerBound, 1.0)
    }

    func testDomainForWeightsConvertsToDisplayUnit() {
        let weights = [
            Weight(valueInKilograms: 80, recordedAt: .now),
            Weight(valueInKilograms: 82, recordedAt: .now.addingTimeInterval(3600)),
        ]
        let kgDomain = WeightChartYDomain.domain(for: weights, displayUnit: .kilograms)
        let lbDomain = WeightChartYDomain.domain(for: weights, displayUnit: .pounds)
        XCTAssertGreaterThan(lbDomain.upperBound, kgDomain.upperBound)
    }
}
