import XCTest
@testable import LogWeightCore

final class SharedWeightEntryStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SharedWeightEntryStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults = nil
        if let suiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        suiteName = nil
        super.tearDown()
    }

    func testLoadCurrentValueFallsBackToDefault() {
        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 75.0, accuracy: 0.0001)
    }

    func testSaveAndLoadEntryRoundTrip() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WeightEntry(value: 72.3, date: date)

        SharedWeightEntryStore.save(entry, userDefaults: defaults)

        XCTAssertEqual(SharedWeightEntryStore.loadEntry(userDefaults: defaults), entry)
    }

    func testIncrementAndDecrementAdjustDraftValue() {
        SharedWeightEntryStore.save(WeightEntry(value: 70.0, date: .now), userDefaults: defaults)

        XCTAssertEqual(SharedWeightEntryStore.increment(stepInKilograms: 0.1, userDefaults: defaults), 70.1, accuracy: 0.0001)
        XCTAssertEqual(SharedWeightEntryStore.decrement(stepInKilograms: 0.1, userDefaults: defaults), 70.0, accuracy: 0.0001)
    }

    func testClearDraftFallsBackToLastSavedEntry() {
        SharedWeightEntryStore.save(WeightEntry(value: 69.5, date: .now), userDefaults: defaults)
        _ = SharedWeightEntryStore.increment(stepInKilograms: 0.5, userDefaults: defaults)

        SharedWeightEntryStore.clearDraftValue(userDefaults: defaults)

        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 69.5, accuracy: 0.0001)
    }

    func testClearSavedEntryRemovesCachedEntry() {
        SharedWeightEntryStore.save(WeightEntry(value: 80.0, date: .now), userDefaults: defaults)

        SharedWeightEntryStore.clearSavedEntry(userDefaults: defaults)

        XCTAssertNil(SharedWeightEntryStore.loadEntry(userDefaults: defaults))
        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 75.0, accuracy: 0.0001)
    }

    func testSyncFromLatestWeightReplacesCacheAndClearsDraft() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        SharedWeightEntryStore.save(WeightEntry(value: 70.0, date: date), userDefaults: defaults)
        _ = SharedWeightEntryStore.increment(stepInKilograms: 1.0, userDefaults: defaults)

        let latest = Weight(valueInKilograms: 68.2, recordedAt: date.addingTimeInterval(3600))
        SharedWeightEntryStore.syncFromLatestWeight(latest, userDefaults: defaults)

        XCTAssertEqual(SharedWeightEntryStore.loadEntry(userDefaults: defaults)?.value ?? 0, 68.2, accuracy: 0.0001)
        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 68.2, accuracy: 0.0001)
    }

    func testSyncFromLatestWeightNilClearsCache() {
        SharedWeightEntryStore.save(WeightEntry(value: 70.0, date: .now), userDefaults: defaults)
        _ = SharedWeightEntryStore.increment(stepInKilograms: 0.5, userDefaults: defaults)

        SharedWeightEntryStore.syncFromLatestWeight(nil, userDefaults: defaults)

        XCTAssertNil(SharedWeightEntryStore.loadEntry(userDefaults: defaults))
        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 75.0, accuracy: 0.0001)
    }

    func testExpireStaleDraftClearsAbandonedAdjustment() {
        SharedWeightEntryStore.save(WeightEntry(value: 71.0, date: .now), userDefaults: defaults)
        _ = SharedWeightEntryStore.increment(stepInKilograms: 0.5, userDefaults: defaults)

        let expiredNow = Date().addingTimeInterval(SharedWeightEntryStore.draftTTL + 1)
        SharedWeightEntryStore.expireStaleDraftIfNeeded(now: expiredNow, userDefaults: defaults)

        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 71.0, accuracy: 0.0001)
    }

    func testExpireStaleDraftKeepsRecentAdjustment() {
        SharedWeightEntryStore.save(WeightEntry(value: 71.0, date: .now), userDefaults: defaults)
        _ = SharedWeightEntryStore.increment(stepInKilograms: 0.5, userDefaults: defaults)

        SharedWeightEntryStore.expireStaleDraftIfNeeded(now: .now, userDefaults: defaults)

        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 71.5, accuracy: 0.0001)
    }
}
