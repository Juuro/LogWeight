import XCTest
@testable import LogWeightCore

final class TipThankYouPolicyTests: XCTestCase {

    private func freshDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testHiddenWhenNoTipRecorded() {
        let defaults = freshDefaults("TipThankYouPolicyTests.none")
        XCTAssertFalse(TipThankYouPolicy.shouldShowThankYou(now: now, defaults: defaults))
    }

    func testShownRightAfterTip() {
        let defaults = freshDefaults("TipThankYouPolicyTests.fresh")
        TipThankYouPolicy.recordTip(at: now, defaults: defaults)
        XCTAssertTrue(TipThankYouPolicy.shouldShowThankYou(now: now, defaults: defaults))
    }

    func testShownJustInsideWindow() {
        let defaults = freshDefaults("TipThankYouPolicyTests.inside")
        TipThankYouPolicy.recordTip(at: now, defaults: defaults)
        let later = now.addingTimeInterval(TipThankYouPolicy.visibilityWindow - 1)
        XCTAssertTrue(TipThankYouPolicy.shouldShowThankYou(now: later, defaults: defaults))
    }

    func testHiddenAtAndAfterWindow() {
        let defaults = freshDefaults("TipThankYouPolicyTests.outside")
        TipThankYouPolicy.recordTip(at: now, defaults: defaults)
        let later = now.addingTimeInterval(TipThankYouPolicy.visibilityWindow)
        XCTAssertFalse(TipThankYouPolicy.shouldShowThankYou(now: later, defaults: defaults))
    }

    func testHiddenWhenRecordedDateIsInFuture() {
        let defaults = freshDefaults("TipThankYouPolicyTests.future")
        TipThankYouPolicy.recordTip(at: now.addingTimeInterval(3600), defaults: defaults)
        XCTAssertFalse(TipThankYouPolicy.shouldShowThankYou(now: now, defaults: defaults))
    }
}
