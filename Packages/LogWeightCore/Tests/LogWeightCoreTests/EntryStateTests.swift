import XCTest
@testable import LogWeightCore

final class EntryStateTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor
    func testInitialState() {
        let state = EntryState(initialValueInKilograms: 75.0)
        XCTAssertEqual(state.displayValueInKilograms, 75.0, accuracy: 0.001)
        XCTAssertEqual(state.saveStatus, .idle)
        XCTAssertNil(state.lastSavedWeight)
    }

    @MainActor
    func testIncrementAndDecrementUseConfiguredStep() {
        let state = EntryState(initialValueInKilograms: 75.0, stepIncrementInKilograms: 0.1)
        state.increment()
        XCTAssertEqual(state.displayValueInKilograms, 75.1, accuracy: 0.001)
        state.decrement()
        state.decrement()
        XCTAssertEqual(state.displayValueInKilograms, 74.9, accuracy: 0.001)
    }

    @MainActor
    func testIncrementClampsAtUpperBound() {
        let state = EntryState(initialValueInKilograms: 499.95, stepIncrementInKilograms: 0.1)
        state.increment()
        XCTAssertEqual(state.displayValueInKilograms, 500.0, accuracy: 0.001)
        state.increment()
        XCTAssertEqual(state.displayValueInKilograms, 500.0, accuracy: 0.001)
    }

    @MainActor
    func testDecrementClampsAtLowerBound() {
        let state = EntryState(initialValueInKilograms: 1.0, stepIncrementInKilograms: 0.1)
        state.decrement()
        XCTAssertEqual(state.displayValueInKilograms, 1.0, accuracy: 0.001)
    }

    @MainActor
    func testCommitHappyPathTransitionsToSaved() async {
        let state = EntryState(initialValueInKilograms: 80.0)
        let store = InMemoryHealthKitStore()
        await state.commit(store: store, now: referenceDate)
        if case .savedAt(let date) = state.saveStatus {
            XCTAssertEqual(date, referenceDate)
        } else {
            XCTFail("Expected savedAt status, got \(state.saveStatus)")
        }
        XCTAssertEqual(state.lastSavedWeight?.valueInKilograms, 80.0)
    }

    @MainActor
    func testCommitFailedSavePropagatesReasonCode() async {
        let state = EntryState(initialValueInKilograms: 80.0)
        let store = InMemoryHealthKitStore(failureMode: .saveFails(reasonCode: 42))
        await state.commit(store: store, now: referenceDate)
        XCTAssertEqual(state.saveStatus, .failed(reasonCode: 42))
        XCTAssertNil(state.lastSavedWeight)
    }

    @MainActor
    func testCommitFailsWhenRequestAuthorizationDenied() async {
        let state = EntryState(initialValueInKilograms: 80.0)
        let store = InMemoryHealthKitStore(
            authorizationStatus: .notDetermined,
            failureMode: .authorizationDenied
        )
        await state.commit(store: store, now: referenceDate)
        XCTAssertEqual(state.saveStatus, .failed(reasonCode: -3))
        XCTAssertNil(state.lastSavedWeight)
    }

    @MainActor
    func testLoadLastWeightPreFillsValue() async {
        let store = InMemoryHealthKitStore(samples: [
            Weight(valueInKilograms: 78.5, recordedAt: referenceDate)
        ])
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        XCTAssertEqual(state.displayValueInKilograms, 78.5, accuracy: 0.001)
        XCTAssertEqual(state.lastSavedWeight?.valueInKilograms, 78.5)
    }

    @MainActor
    func testLoadLastWeightSilentlyNoOpsOnEmptyStore() async {
        let store = InMemoryHealthKitStore()
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        XCTAssertEqual(state.displayValueInKilograms, 75.0, accuracy: 0.001)
    }

    @MainActor
    func testResetReturnsToIdle() async {
        let state = EntryState(initialValueInKilograms: 80.0)
        let store = InMemoryHealthKitStore()
        await state.commit(store: store, now: referenceDate)
        state.reset()
        XCTAssertEqual(state.saveStatus, .idle)
    }

    @MainActor
    func testRestoreDisplayNoOpsWhenNoLastSaved() {
        let state = EntryState(initialValueInKilograms: 80.0)
        state.increment()
        state.restoreDisplayToLastLoggedWeight()
        XCTAssertEqual(state.displayValueInKilograms, 80.1, accuracy: 0.001)
    }

    @MainActor
    func testRestoreDisplayAfterLoadLastWeight() async {
        let store = InMemoryHealthKitStore(samples: [
            Weight(valueInKilograms: 78.5, recordedAt: referenceDate)
        ])
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        state.increment()
        state.restoreDisplayToLastLoggedWeight()
        XCTAssertEqual(state.displayValueInKilograms, 78.5, accuracy: 0.001)
    }

    @MainActor
    func testRestoreDisplayAfterCommit() async {
        let state = EntryState(initialValueInKilograms: 80.0)
        let store = InMemoryHealthKitStore()
        await state.commit(store: store, now: referenceDate)
        state.increment()
        state.increment()
        state.restoreDisplayToLastLoggedWeight()
        XCTAssertEqual(state.displayValueInKilograms, 80.0, accuracy: 0.001)
    }
}
