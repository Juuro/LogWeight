import XCTest
@testable import LogWeightCore

final class InMemoryHealthKitStoreTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testSaveRoundTrip() async throws {
        let store = InMemoryHealthKitStore()
        let weight = Weight(valueInKilograms: 80.0, recordedAt: referenceDate)
        try await store.save(weight)
        let result = try await store.recentWeights(limit: 10)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, weight)
    }

    func testRecentWeightsSortsNewestFirst() async throws {
        let store = InMemoryHealthKitStore()
        let earlier = Weight(valueInKilograms: 78.0, recordedAt: referenceDate)
        let later = Weight(valueInKilograms: 79.0, recordedAt: referenceDate.addingTimeInterval(60))
        try await store.save(earlier)
        try await store.save(later)
        let result = try await store.recentWeights(limit: 10)
        XCTAssertEqual(result.first?.valueInKilograms, 79.0)
    }

    func testRecentWeightsRespectsLimit() async throws {
        let store = InMemoryHealthKitStore()
        for i in 0..<5 {
            try await store.save(Weight(
                valueInKilograms: 75.0 + Double(i),
                recordedAt: referenceDate.addingTimeInterval(Double(i * 60))
            ))
        }
        let result = try await store.recentWeights(limit: 2)
        XCTAssertEqual(result.count, 2)
    }

    func testAuthorizationDeniedFailureMode() async {
        let store = InMemoryHealthKitStore(
            authorizationStatus: .notDetermined,
            failureMode: .authorizationDenied
        )
        do {
            try await store.requestAuthorization()
            XCTFail("Expected authorization to throw")
        } catch HealthKitError.authorizationDenied {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let status = await store.authorizationStatus()
        XCTAssertEqual(status, .sharingDenied)
    }

    func testSaveFailsFailureMode() async {
        let store = InMemoryHealthKitStore(failureMode: .saveFails(reasonCode: 7))
        do {
            try await store.save(Weight(valueInKilograms: 80.0, recordedAt: referenceDate))
            XCTFail("Expected save to throw")
        } catch HealthKitError.saveFailed(let code) {
            XCTAssertEqual(code, 7)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testQueryFailsFailureMode() async {
        let store = InMemoryHealthKitStore(failureMode: .queryFails(reasonCode: 11))
        do {
            _ = try await store.recentWeights(limit: 10)
            XCTFail("Expected query to throw")
        } catch HealthKitError.queryFailed(let code) {
            XCTAssertEqual(code, 11)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testObserveChangesEmitsOnSave() async throws {
        let store = InMemoryHealthKitStore()
        let stream = store.observeChanges()

        let expectation = self.expectation(description: "observeChanges yields")

        let consumer = Task {
            for await _ in stream {
                expectation.fulfill()
                break
            }
        }

        // Tiny delay so the consumer has time to register before the save fires.
        try await Task.sleep(nanoseconds: 50_000_000)
        try await store.save(Weight(valueInKilograms: 80.0, recordedAt: referenceDate))

        await fulfillment(of: [expectation], timeout: 2.0)
        consumer.cancel()
    }

    func testObserveChangesStopsWhenConsumerCancels() async throws {
        // DA4 fix: cancelling the consumer must stop the underlying observer.
        // We assert on absence: after cancellation, no further yields land.
        let store = InMemoryHealthKitStore()
        let stream = store.observeChanges()

        var receivedAfterCancel = 0
        let consumer = Task {
            for await _ in stream {
                receivedAfterCancel += 1
            }
        }
        consumer.cancel()
        try await Task.sleep(nanoseconds: 50_000_000)

        try await store.save(Weight(valueInKilograms: 80.0, recordedAt: referenceDate))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(receivedAfterCancel, 0)
    }

    func testDeleteRemovesEntry() async throws {
        let store = InMemoryHealthKitStore()
        let weight = Weight(valueInKilograms: 80.0, recordedAt: referenceDate)
        try await store.save(weight)

        try await store.delete(weight)
        let result = try await store.recentWeights(limit: 10)
        XCTAssertTrue(result.isEmpty)
    }

    func testDeleteThrowsForMissingEntry() async {
        let store = InMemoryHealthKitStore()
        do {
            try await store.delete(Weight(valueInKilograms: 80.0, recordedAt: referenceDate))
            XCTFail("Expected delete to throw")
        } catch HealthKitError.deleteFailed {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
