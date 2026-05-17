import XCTest
@testable import LogWeightCore

final class WidgetWeightSaveTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WidgetWeightSaveTests.\(UUID().uuidString)"
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

    func testCommitSavesToHealthKitAndClearsDraft() async throws {
        SharedWeightEntryStore.save(WeightEntry(value: 70.0, date: .now), userDefaults: defaults)
        _ = SharedWeightEntryStore.increment(stepInKilograms: 0.2, userDefaults: defaults)

        let store = InMemoryHealthKitStore()
        let savedAt = Date(timeIntervalSince1970: 1_700_000_100)
        try await WidgetWeightSave.commit(to: store, now: savedAt, userDefaults: defaults)

        let samples = try await store.recentWeights(limit: 1)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].valueInKilograms, 70.2, accuracy: 0.0001)
        XCTAssertEqual(samples[0].recordedAt, savedAt)
        XCTAssertEqual(SharedWeightEntryStore.loadCurrentValue(userDefaults: defaults), 70.2, accuracy: 0.0001)
        XCTAssertNil(defaults.object(forKey: "widget.draftWeightValue"))
    }

    func testCommitPropagatesSaveFailure() async {
        let store = InMemoryHealthKitStore(failureMode: .saveFails(reasonCode: 42))
        do {
            try await WidgetWeightSave.commit(to: store, userDefaults: defaults)
            XCTFail("Expected save to throw")
        } catch HealthKitError.saveFailed(let code) {
            XCTAssertEqual(code, 42)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
