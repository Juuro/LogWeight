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
        XCTAssertEqual(state.initialWeightLoadOutcome, .pending)
        XCTAssertFalse(state.hasResolvedInitialWeight)
        XCTAssertFalse(state.hasConfirmedEmptyWeightStore)
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
        XCTAssertEqual(state.initialWeightLoadOutcome, .hasPriorWeight)
        XCTAssertTrue(state.hasResolvedInitialWeight)
        XCTAssertFalse(state.hasConfirmedEmptyWeightStore)
    }

    @MainActor
    func testLoadLastWeightConfirmsEmptyStore() async {
        let store = InMemoryHealthKitStore()
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        XCTAssertEqual(state.displayValueInKilograms, 0, accuracy: 0.001)
        XCTAssertTrue(state.isAwaitingFirstWeight)
        XCTAssertEqual(state.initialWeightLoadOutcome, .emptyStore)
        XCTAssertTrue(state.hasResolvedInitialWeight)
        XCTAssertTrue(state.hasConfirmedEmptyWeightStore)
        XCTAssertNil(state.lastSavedWeight)
    }

    @MainActor
    func testCommitNoOpsWhileAwaitingFirstWeightWithoutValue() async {
        let store = InMemoryHealthKitStore()
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        await state.commit(store: store, now: referenceDate)
        XCTAssertEqual(state.saveStatus, .idle)
        XCTAssertNil(state.lastSavedWeight)
    }

    @MainActor
    func testLoadLastWeightReturnsToFirstEntryAfterAllSamplesRemoved() async throws {
        let store = InMemoryHealthKitStore()
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        state.setValue(80.0, unit: .kilograms)
        await state.commit(store: store, now: referenceDate)
        XCTAssertEqual(state.initialWeightLoadOutcome, .hasPriorWeight)
        XCTAssertNotNil(state.lastSavedWeight)

        let recent = try await store.recentWeights(limit: 1)
        let saved = try XCTUnwrap(recent.first)
        try await store.delete(saved)
        await state.loadLastWeight(from: store)

        XCTAssertTrue(state.hasConfirmedEmptyWeightStore)
        XCTAssertTrue(state.isAwaitingFirstWeight)
        XCTAssertEqual(state.displayValueInKilograms, 0, accuracy: 0.001)
        XCTAssertNil(state.lastSavedWeight)
        XCTAssertEqual(state.saveStatus, .idle)
    }

    @MainActor
    func testStepperActivatesBaseValueFromAwaitingFirstWeight() async {
        let store = InMemoryHealthKitStore()
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        state.increment()
        XCTAssertEqual(state.displayValueInKilograms, 75.1, accuracy: 0.001)
        XCTAssertFalse(state.isAwaitingFirstWeight)
    }

    @MainActor
    func testLoadLastWeightMarksLoadFailedOnQueryError() async {
        let store = InMemoryHealthKitStore(failureMode: .queryFails(reasonCode: 11))
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        XCTAssertEqual(state.displayValueInKilograms, 75.0, accuracy: 0.001)
        XCTAssertEqual(state.initialWeightLoadOutcome, .loadFailed)
        XCTAssertTrue(state.hasResolvedInitialWeight)
        XCTAssertFalse(state.hasConfirmedEmptyWeightStore)
        XCTAssertNil(state.lastSavedWeight)
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

    @MainActor
    func testCommitClearsConfirmedEmptyStoreAfterFirstSave() async {
        let store = InMemoryHealthKitStore()
        let state = EntryState(initialValueInKilograms: 75.0)
        await state.loadLastWeight(from: store)
        XCTAssertTrue(state.hasConfirmedEmptyWeightStore)
        state.setValue(80.0, unit: .kilograms)

        await state.commit(store: store, now: referenceDate)
        XCTAssertEqual(state.initialWeightLoadOutcome, .hasPriorWeight)
        XCTAssertFalse(state.hasConfirmedEmptyWeightStore)
    }
}
