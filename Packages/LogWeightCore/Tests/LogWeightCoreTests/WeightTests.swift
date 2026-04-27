import XCTest
@testable import LogWeightCore

final class WeightTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testEqualityIgnoresFloatingPointNoiseWithinThreeDecimals() {
        let a = Weight(valueInKilograms: 82.3456, recordedAt: referenceDate)
        let b = Weight(valueInKilograms: 82.3461, recordedAt: referenceDate)
        XCTAssertEqual(a, b)
    }

    func testEqualityRejectsDifferingDates() {
        let a = Weight(valueInKilograms: 80.0, recordedAt: referenceDate)
        let b = Weight(valueInKilograms: 80.0, recordedAt: referenceDate.addingTimeInterval(1))
        XCTAssertNotEqual(a, b)
    }

    func testKilogramsToPoundsRoundTripPreservesValue() {
        let original = Weight(valueInKilograms: 82.0, recordedAt: referenceDate)
        let lb = original.value(in: .pounds)
        let roundTrip = Weight(value: lb, unit: .pounds, recordedAt: referenceDate)
        XCTAssertEqual(original, roundTrip)
    }

    func testCanonicalStorageIsKilograms() {
        let lbWeight = Weight(value: 180.0, unit: .pounds, recordedAt: referenceDate)
        // 180 lb ≈ 81.6466 kg
        XCTAssertEqual(lbWeight.valueInKilograms, 81.6466, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let original = Weight(valueInKilograms: 75.5, recordedAt: referenceDate)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Weight.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testEdgeCases() {
        let small = Weight(valueInKilograms: 0.1, recordedAt: referenceDate)
        let large = Weight(valueInKilograms: 499.9, recordedAt: referenceDate)
        XCTAssertNotEqual(small, large)
        XCTAssertEqual(small.value(in: .pounds), 0.220, accuracy: 0.01)
    }
}
