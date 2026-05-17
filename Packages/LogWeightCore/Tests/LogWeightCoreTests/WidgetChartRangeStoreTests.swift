import XCTest
@testable import LogWeightCore

final class WidgetChartRangeStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "WidgetChartRangeStoreTests")!
        defaults.removePersistentDomain(forName: "WidgetChartRangeStoreTests")
    }

    func testSaveAndLoadRoundTrip() {
        WidgetChartRangeStore.save(.threeMonths, userDefaults: defaults)
        XCTAssertEqual(WidgetChartRangeStore.load(userDefaults: defaults), .threeMonths)
    }

    func testLoadReturnsNilWhenUnset() {
        XCTAssertNil(WidgetChartRangeStore.load(userDefaults: defaults))
    }
}
