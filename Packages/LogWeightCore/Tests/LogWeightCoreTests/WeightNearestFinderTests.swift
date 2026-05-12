import XCTest
@testable import LogWeightCore

final class WeightNearestFinderTests: XCTestCase {
    func testClosestWeightSelectsMiddleCandidate() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let weights = [
            Weight(valueInKilograms: 79.0, recordedAt: base.addingTimeInterval(-3_600)),
            Weight(valueInKilograms: 80.0, recordedAt: base),
            Weight(valueInKilograms: 81.0, recordedAt: base.addingTimeInterval(3_600))
        ]

        let probe = base.addingTimeInterval(600)
        let closest = WeightNearestFinder.closest(to: probe, in: weights)

        XCTAssertEqual(closest?.valueInKilograms, 80.0)
    }

    func testClosestWeightHandlesBoundaryDate() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let first = Weight(valueInKilograms: 78.5, recordedAt: base)
        let second = Weight(valueInKilograms: 79.0, recordedAt: base.addingTimeInterval(7_200))
        let weights = [first, second]

        let closest = WeightNearestFinder.closest(to: base.addingTimeInterval(-120), in: weights)

        XCTAssertEqual(closest, first)
    }

    func testClosestWeightReturnsNilForEmptyInput() {
        let closest = WeightNearestFinder.closest(to: Date(), in: [])
        XCTAssertNil(closest)
    }
}
