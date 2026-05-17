import AppIntents
import Foundation
import LogWeightCore
import WidgetKit

struct IncrementWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Weight"
    static var openAppWhenRun = false

    @Parameter(title: "Step (kg)")
    var stepInKilograms: Double

    init() {
        self.stepInKilograms = SharedWeightEntryStore.defaultStepInKilograms
    }

    init(stepInKilograms: Double) {
        self.stepInKilograms = stepInKilograms
    }

    func perform() async throws -> some IntentResult {
        _ = SharedWeightEntryStore.increment(stepInKilograms: stepInKilograms)
        WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.kind)
        return .result()
    }
}

struct DecrementWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Weight"
    static var openAppWhenRun = false

    @Parameter(title: "Step (kg)")
    var stepInKilograms: Double

    init() {
        self.stepInKilograms = SharedWeightEntryStore.defaultStepInKilograms
    }

    init(stepInKilograms: Double) {
        self.stepInKilograms = stepInKilograms
    }

    func perform() async throws -> some IntentResult {
        _ = SharedWeightEntryStore.decrement(stepInKilograms: stepInKilograms)
        WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.kind)
        return .result()
    }
}

/// Saves through HealthKit in the host app process. Widget extensions cannot
/// reliably write body-mass samples; `openAppWhenRun` hands off to LogWeight.
struct SaveWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Weight"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let store = HKHealthStoreAdapter()
        try await WidgetWeightSave.commit(to: store)
        WidgetCenter.shared.reloadAllTimelines()
        await MainActor.run {
            NotificationCenter.default.post(name: .logWeightWidgetDidSave, object: nil)
        }
        return .result()
    }
}
