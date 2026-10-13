import Foundation
import XCTest
@testable import LogWeightCore

final class WeightLoggerTests: XCTestCase {

    private let clock = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeLogger(
        samples: [Weight] = [],
        status: HealthKitAuthorizationStatus = .sharingAuthorized,
        failureMode: InMemoryHealthKitStore.FailureMode = .happyPath
    ) -> (WeightLogger, InMemoryHealthKitStore) {
        let store = InMemoryHealthKitStore(
            samples: samples,
            authorizationStatus: status,
            failureMode: failureMode
        )
        let fixed = clock
        return (WeightLogger(store: store, now: { fixed }), store)
    }

    // MARK: - Foundation

    func testEvaluateReturnsAccessNotGrantedWhenNotAuthorized() async {
        for status in [HealthKitAuthorizationStatus.notDetermined, .sharingDenied] {
            let (logger, store) = makeLogger(status: status)
            let result = await logger.evaluate(kilograms: 82.4)
            XCTAssertEqual(result, .accessNotGranted)
            let stored = try? await store.recentWeights(limit: 10)
            XCTAssertEqual(stored?.count, 0)
        }
    }

    func testEvaluateReturnsInvalidForNonPositiveOrNonFiniteValues() async {
        let (logger, _) = makeLogger()
        for value in [Double.nan, .infinity, 0, -5] {
            let result = await logger.evaluate(kilograms: value)
            XCTAssertEqual(result, .invalid, "value \(value)")
        }
    }

    func testEvaluateReturnsReadyWithInjectedClock() async {
        let (logger, _) = makeLogger()
        let result = await logger.evaluate(kilograms: 82.4)
        XCTAssertEqual(result, .ready(Weight(valueInKilograms: 82.4, recordedAt: clock)))
    }

    func testSaveWritesExactlyOneSample() async throws {
        let (logger, store) = makeLogger()
        let weight = Weight(valueInKilograms: 82.4, recordedAt: clock)
        let outcome = await logger.save(weight)
        XCTAssertEqual(outcome, .saved(weight))
        let stored = try await store.recentWeights(limit: 10)
        XCTAssertEqual(stored, [weight])
    }

    func testSaveFailureMapsReasonCodeAndStoresNothing() async throws {
        let (logger, store) = makeLogger(failureMode: .saveFails(reasonCode: 7))
        let weight = Weight(valueInKilograms: 82.4, recordedAt: clock)
        let outcome = await logger.save(weight)
        XCTAssertEqual(outcome, .failed(reasonCode: 7))
        let stored = try await store.recentWeights(limit: 10)
        XCTAssertTrue(stored.isEmpty)
    }

    // MARK: - First entry, range, jump

    private func previous(_ kilograms: Double, secondsAgo: TimeInterval = 3600) -> Weight {
        Weight(valueInKilograms: kilograms, recordedAt: clock.addingTimeInterval(-secondsAgo))
    }

    func testFirstEntryOnEmptyStoreIsReady() async {
        let (logger, _) = makeLogger()
        let result = await logger.evaluate(kilograms: 80)
        XCTAssertEqual(result, .ready(Weight(valueInKilograms: 80, recordedAt: clock)))
    }

    func testRangeBoundariesAreReadyAndJustOutsideNeedsConfirmation() async {
        let (logger, _) = makeLogger()
        for value in [20.0, 500.0] {
            let result = await logger.evaluate(kilograms: value)
            XCTAssertEqual(result, .ready(Weight(valueInKilograms: value, recordedAt: clock)), "value \(value)")
        }
        for value in [19.9, 500.1] {
            let result = await logger.evaluate(kilograms: value)
            XCTAssertEqual(
                result,
                .needsConfirmation(Weight(valueInKilograms: value, recordedAt: clock), .outOfRange),
                "value \(value)"
            )
        }
    }

    func testJumpExactlyAtThresholdIsReadyAndAboveNeedsConfirmation() async {
        let (logger, _) = makeLogger(samples: [previous(80)])
        let atThreshold = await logger.evaluate(kilograms: 90)
        XCTAssertEqual(atThreshold, .ready(Weight(valueInKilograms: 90, recordedAt: clock)))
        let above = await logger.evaluate(kilograms: 90.1)
        XCTAssertEqual(
            above,
            .needsConfirmation(Weight(valueInKilograms: 90.1, recordedAt: clock), .largeJump)
        )
        let downward = await logger.evaluate(kilograms: 69.9)
        XCTAssertEqual(
            downward,
            .needsConfirmation(Weight(valueInKilograms: 69.9, recordedAt: clock), .largeJump)
        )
    }

    func testOutOfRangeTakesPrecedenceOverLargeJump() async {
        let (logger, _) = makeLogger(samples: [previous(80)])
        let result = await logger.evaluate(kilograms: 5)
        XCTAssertEqual(
            result,
            .needsConfirmation(Weight(valueInKilograms: 5, recordedAt: clock), .outOfRange)
        )
    }

    func testQueryFailureIsTreatedAsNoPreviousSample() async {
        let (logger, _) = makeLogger(failureMode: .queryFails(reasonCode: 3))
        let inRange = await logger.evaluate(kilograms: 80)
        XCTAssertEqual(inRange, .ready(Weight(valueInKilograms: 80, recordedAt: clock)))
        let outOfRange = await logger.evaluate(kilograms: 5)
        XCTAssertEqual(
            outOfRange,
            .needsConfirmation(Weight(valueInKilograms: 5, recordedAt: clock), .outOfRange)
        )
    }

    func testEvaluateNeverChangesTheStore() async throws {
        let (logger, store) = makeLogger(samples: [previous(80)])
        _ = await logger.evaluate(kilograms: 95)
        _ = await logger.evaluate(kilograms: 5)
        _ = await logger.evaluate(kilograms: 80)
        let stored = try await store.recentWeights(limit: 10)
        XCTAssertEqual(stored.count, 1)
    }

    // MARK: - Duplicates

    func testIdenticalValueInsideWindowIsDuplicate() async {
        let recent = previous(82.4, secondsAgo: 30)
        let (logger, _) = makeLogger(samples: [recent])
        let result = await logger.evaluate(kilograms: 82.4)
        XCTAssertEqual(result, .duplicate(recent))
    }

    func testDuplicateWindowBoundary() async {
        let atWindow = previous(82.4, secondsAgo: 60)
        let (inside, _) = makeLogger(samples: [atWindow])
        let insideResult = await inside.evaluate(kilograms: 82.4)
        XCTAssertEqual(insideResult, .duplicate(atWindow))

        let (outside, _) = makeLogger(samples: [previous(82.4, secondsAgo: 61)])
        let outsideResult = await outside.evaluate(kilograms: 82.4)
        XCTAssertEqual(outsideResult, .ready(Weight(valueInKilograms: 82.4, recordedAt: clock)))
    }

    func testDifferentValueInsideWindowIsNotDuplicate() async {
        let (logger, _) = makeLogger(samples: [previous(82.4, secondsAgo: 10)])
        let result = await logger.evaluate(kilograms: 82.5)
        XCTAssertEqual(result, .ready(Weight(valueInKilograms: 82.5, recordedAt: clock)))
    }

    func testPoundRoundTripStillCountsAsDuplicate() async {
        let recent = previous(82.4, secondsAgo: 5)
        let (logger, _) = makeLogger(samples: [recent])
        let pounds = Weight(valueInKilograms: 82.4, recordedAt: clock).value(in: .pounds)
        let backToKilograms = Weight(value: (pounds * 10).rounded() / 10, unit: .pounds, recordedAt: clock)
            .valueInKilograms
        let result = await logger.evaluate(kilograms: backToKilograms)
        XCTAssertEqual(result, .duplicate(recent))
    }

    func testDuplicateTakesPrecedenceOverConfirmation() async {
        let recent = previous(5, secondsAgo: 5)
        let (logger, _) = makeLogger(samples: [recent])
        let result = await logger.evaluate(kilograms: 5)
        XCTAssertEqual(result, .duplicate(recent))
    }

    func testSampleFromTheFutureIsNotADuplicate() async {
        let future = Weight(valueInKilograms: 82.4, recordedAt: clock.addingTimeInterval(30))
        let (logger, _) = makeLogger(samples: [future])
        let result = await logger.evaluate(kilograms: 82.4)
        XCTAssertEqual(result, .ready(Weight(valueInKilograms: 82.4, recordedAt: clock)))
    }
}
