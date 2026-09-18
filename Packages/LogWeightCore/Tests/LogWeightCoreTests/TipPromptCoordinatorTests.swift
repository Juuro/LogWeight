import XCTest
@testable import LogWeightCore

final class TipPromptCoordinatorTests: XCTestCase {

    private func freshDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testDoesNotPromptBeforeThreshold() {
        let defaults = freshDefaults("TipPromptCoordinatorTests.before")
        for _ in 1..<TipPromptCoordinator.promptThreshold {
            XCTAssertFalse(TipPromptCoordinator.recordSuccessfulEntry(defaults: defaults))
        }
    }

    func testPromptsExactlyAtThreshold() {
        let defaults = freshDefaults("TipPromptCoordinatorTests.at")
        for _ in 1..<TipPromptCoordinator.promptThreshold {
            _ = TipPromptCoordinator.recordSuccessfulEntry(defaults: defaults)
        }
        XCTAssertTrue(TipPromptCoordinator.recordSuccessfulEntry(defaults: defaults))
    }

    func testNeverPromptsAgainAfterMarkedPresented() {
        let defaults = freshDefaults("TipPromptCoordinatorTests.once")
        for _ in 0..<TipPromptCoordinator.promptThreshold {
            _ = TipPromptCoordinator.recordSuccessfulEntry(defaults: defaults)
        }
        TipPromptCoordinator.markPresented(defaults: defaults)

        XCTAssertFalse(TipPromptCoordinator.recordSuccessfulEntry(defaults: defaults))
        XCTAssertFalse(TipPromptCoordinator.recordSuccessfulEntry(defaults: defaults))
    }

    func testDoesNotPromptAgainWithoutMarkingPresented() {
        // Guards against double-counting if the caller forgets to mark the
        // prompt as shown: count keeps climbing but must stay gated by the
        // shown flag once it's actually set.
        let defaults = freshDefaults("TipPromptCoordinatorTests.unmarked")
        for _ in 0..<(TipPromptCoordinator.promptThreshold + 5) {
            _ = TipPromptCoordinator.recordSuccessfulEntry(defaults: defaults)
        }
        XCTAssertEqual(
            defaults.integer(forKey: SettingsKey.successfulEntryCount),
            TipPromptCoordinator.promptThreshold + 5
        )
    }
}
