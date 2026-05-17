import XCTest
@testable import LogWeightCore

final class WeightDisplayPreferencesTests: XCTestCase {
    func testPreferredUnitReadsSharedDefaultsFirst() {
        let shared = UserDefaults(suiteName: "WeightDisplayPreferencesTests.shared")!
        let standard = UserDefaults(suiteName: "WeightDisplayPreferencesTests.standard")!
        shared.removePersistentDomain(forName: "WeightDisplayPreferencesTests.shared")
        standard.removePersistentDomain(forName: "WeightDisplayPreferencesTests.standard")

        shared.set(WeightUnit.pounds.rawValue, forKey: SettingsKey.unitPreference)
        standard.set(WeightUnit.kilograms.rawValue, forKey: SettingsKey.unitPreference)

        XCTAssertEqual(
            WeightDisplayPreferences.preferredUnit(sharedDefaults: shared, standardDefaults: standard),
            .pounds
        )
    }

    func testPreferredUnitFallsBackToStandardDefaults() {
        let standard = UserDefaults(suiteName: "WeightDisplayPreferencesTests.standardOnly")!
        standard.removePersistentDomain(forName: "WeightDisplayPreferencesTests.standardOnly")
        standard.set(WeightUnit.pounds.rawValue, forKey: SettingsKey.unitPreference)

        XCTAssertEqual(
            WeightDisplayPreferences.preferredUnit(sharedDefaults: nil, standardDefaults: standard),
            .pounds
        )
    }

    func testMirrorUnitPreferenceToAppGroup() {
        let shared = UserDefaults(suiteName: "WeightDisplayPreferencesTests.mirror")!
        let standard = UserDefaults(suiteName: "WeightDisplayPreferencesTests.mirrorStandard")!
        shared.removePersistentDomain(forName: "WeightDisplayPreferencesTests.mirror")
        standard.removePersistentDomain(forName: "WeightDisplayPreferencesTests.mirrorStandard")

        standard.set(WeightUnit.pounds.rawValue, forKey: SettingsKey.unitPreference)
        WeightDisplayPreferences.mirrorUnitPreferenceToAppGroup(
            standardDefaults: standard,
            sharedDefaults: shared
        )

        XCTAssertEqual(shared.string(forKey: SettingsKey.unitPreference), WeightUnit.pounds.rawValue)
    }
}
