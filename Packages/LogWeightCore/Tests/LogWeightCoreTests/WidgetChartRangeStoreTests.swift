import XCTest
@testable import LogWeightCore

final class WidgetChartRangeStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        // Unique suite per test method so `swift test --parallel` does not share state.
        suiteName = "WidgetChartRangeStoreTests.\(name)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSaveAndLoadRoundTrip() {
        WidgetChartRangeStore.save(.threeMonths, userDefaults: defaults)
        XCTAssertEqual(WidgetChartRangeStore.load(userDefaults: defaults), .threeMonths)
    }

    func testLoadReturnsNilWhenUnset() {
        XCTAssertNil(WidgetChartRangeStore.load(userDefaults: defaults))
    }
}
