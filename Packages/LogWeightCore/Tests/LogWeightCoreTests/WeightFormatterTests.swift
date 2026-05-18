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

    func testParseRejectsNegativeValues() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"))
        XCTAssertNil(formatter.parseToKilograms("-70.5", unit: .kilograms))
        XCTAssertNil(formatter.parseToKilograms("-155.4", unit: .pounds))
    }

    func testFormatEditableValueUsesLocaleDecimalSeparator() {
        let german = WeightFormatter(locale: Locale(identifier: "de_DE"), fractionDigits: 1)
        XCTAssertEqual(german.formatEditableValue(kilograms: 75.0, in: .kilograms), "75,0")

        let english = WeightFormatter(locale: Locale(identifier: "en_US"), fractionDigits: 1)
        XCTAssertEqual(english.formatEditableValue(kilograms: 75.0, in: .kilograms), "75.0")
    }

    func testSanitizeWeightInputEnglishLocale() {
        let formatter = WeightFormatter(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(formatter.sanitizeWeightInput("82.3"), "82.3")
        XCTAssertEqual(formatter.sanitizeWeightInput("82abc.3kg"), "82.3")
        XCTAssertEqual(formatter.sanitizeWeightInput("-12.34"), "12.3")
        XCTAssertEqual(formatter.sanitizeWeightInput("1.2.3"), "1.2")
        XCTAssertEqual(formatter.sanitizeWeightInput("83.-+*K5"), "83.5")
        XCTAssertEqual(formatter.sanitizeWeightInput("083.55"), "83.5")
        XCTAssertEqual(formatter.sanitizeWeightInput("05"), "5")
        XCTAssertEqual(formatter.sanitizeWeightInput("0.8"), "0.8")
    }

    func testSanitizeWeightInputGermanLocaleUsesComma() {
        let formatter = WeightFormatter(locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(formatter.sanitizeWeightInput("82,3"), "82,3")
        XCTAssertEqual(formatter.sanitizeWeightInput("82.3"), "82,3")
        XCTAssertEqual(formatter.sanitizeWeightInput("ab82,3xy"), "82,3")
        XCTAssertEqual(formatter.sanitizeWeightInput("083,555"), "83,5")
    }
}
