import XCTest
@testable import LogWeightCore

final class TrendArrowPreferencesTests: XCTestCase {
    func testIsEnabledDefaultsToTrueWhenUnset() {
        let shared = UserDefaults(suiteName: "TrendArrowPreferencesTests.unset.shared")!
        let standard = UserDefaults(suiteName: "TrendArrowPreferencesTests.unset.standard")!
        shared.removePersistentDomain(forName: "TrendArrowPreferencesTests.unset.shared")
        standard.removePersistentDomain(forName: "TrendArrowPreferencesTests.unset.standard")

        XCTAssertTrue(TrendArrowPreferences.isEnabled(sharedDefaults: shared, standardDefaults: standard))
    }

    func testIsEnabledReadsSharedDefaultsFirst() {
        let shared = UserDefaults(suiteName: "TrendArrowPreferencesTests.shared")!
        let standard = UserDefaults(suiteName: "TrendArrowPreferencesTests.standard")!
        shared.removePersistentDomain(forName: "TrendArrowPreferencesTests.shared")
        standard.removePersistentDomain(forName: "TrendArrowPreferencesTests.standard")

        shared.set(false, forKey: SettingsKey.trendArrowEnabled)
        standard.set(true, forKey: SettingsKey.trendArrowEnabled)

        XCTAssertFalse(TrendArrowPreferences.isEnabled(sharedDefaults: shared, standardDefaults: standard))
    }

    func testMirrorToAppGroup() {
        let shared = UserDefaults(suiteName: "TrendArrowPreferencesTests.mirror")!
        let standard = UserDefaults(suiteName: "TrendArrowPreferencesTests.mirrorStandard")!
        shared.removePersistentDomain(forName: "TrendArrowPreferencesTests.mirror")
        standard.removePersistentDomain(forName: "TrendArrowPreferencesTests.mirrorStandard")

        standard.set(false, forKey: SettingsKey.trendArrowEnabled)
        TrendArrowPreferences.mirrorToAppGroup(standardDefaults: standard, sharedDefaults: shared)

        XCTAssertFalse(shared.bool(forKey: SettingsKey.trendArrowEnabled))
    }
}
