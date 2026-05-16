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
}
