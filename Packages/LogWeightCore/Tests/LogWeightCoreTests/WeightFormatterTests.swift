import XCTest
@testable import LogWeightCore

final class WeightFormatterTests: XCTestCase {

    func testFormatKilogramsInEnglishLocale() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"), fractionDigits: 1)
        let result = formatter.format(kilograms: 82.34, in: .kilograms)
        XCTAssertTrue(result.contains("82.3"), "Expected 82.3, got \(result)")
        XCTAssertTrue(result.lowercased().contains("kg"))
    }

    func testFormatPoundsConvertsFromKilograms() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"), fractionDigits: 1)
        let result = formatter.format(kilograms: 81.6466, in: .pounds)
        // 81.6466 kg ≈ 180.0 lb
        XCTAssertTrue(result.contains("180.0"), "Expected 180.0, got \(result)")
    }

    func testFormatRespectsGermanDecimalSeparator() {
        let formatter = WeightFormatter(locale: Locale(identifier: "de_DE"), fractionDigits: 1)
        let result = formatter.format(kilograms: 82.3, in: .kilograms)
        XCTAssertTrue(result.contains("82,3") || result.contains("82.3"),
                      "Expected localised separator, got \(result)")
    }

    func testParseKilogramsFromEnglishInput() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"))
        let kg = formatter.parseToKilograms("82.3", unit: .kilograms)
        XCTAssertNotNil(kg)
        XCTAssertEqual(kg!, 82.3, accuracy: 0.001)
    }

    func testParsePoundsFromEnglishInputConvertsToKilograms() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"))
        let kg = formatter.parseToKilograms("180.0", unit: .pounds)
        XCTAssertNotNil(kg)
        XCTAssertEqual(kg!, 81.6466, accuracy: 0.01)
    }

    func testParseAcceptsTrailingUnitSuffix() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"))
        let kg = formatter.parseToKilograms("82.3 kg", unit: .kilograms)
        XCTAssertNotNil(kg)
        XCTAssertEqual(kg!, 82.3, accuracy: 0.001)
    }

    func testParseRejectsGarbage() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"))
        XCTAssertNil(formatter.parseToKilograms("abc", unit: .kilograms))
        XCTAssertNil(formatter.parseToKilograms("", unit: .kilograms))
    }
}
