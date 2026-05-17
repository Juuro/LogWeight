import XCTest
@testable import LogWeightCore

final class WeightTrendCacheTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suiteName = "WeightTrendCacheTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSaveAndLoadRoundTrip() {
        WeightTrendCache.save(.up, userDefaults: defaults)
        XCTAssertEqual(WeightTrendCache.load(userDefaults: defaults), .up)
    }

    func testLoadWhenMissingReturnsUnknown() {
        XCTAssertEqual(WeightTrendCache.load(userDefaults: defaults), .unknown)
    }

    func testUpdateFromWeightsPersistsDirection() {
        let reference = ScreenshotFixture.referenceDate
        let weights = ScreenshotFixture.linearTrend30Days.samples(now: reference)
        WeightTrendCache.update(from: weights, referenceDate: reference, userDefaults: defaults)
        XCTAssertEqual(WeightTrendCache.load(userDefaults: defaults), .down)
    }
}
