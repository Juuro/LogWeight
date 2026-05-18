import AppIntents
import Foundation
import LogWeightCore
import WidgetKit

struct IncrementWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Increase Weight"
    static let openAppWhenRun = false

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
        WidgetTimelineRefresh.reloadEntryWidget()
        return .result()
    }
}

struct DecrementWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Decrease Weight"
    static let openAppWhenRun = false

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
        WidgetTimelineRefresh.reloadEntryWidget()
        return .result()
    }
}

/// Saves through HealthKit in the host app process. Widget extensions cannot
/// reliably write body-mass samples; `openAppWhenRun` hands off to LogWeight.
struct SaveWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Weight"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let store = HKHealthStoreAdapter()
        try await WidgetWeightSave.commit(to: store)
        WidgetTimelineRefresh.reloadEntryAndChartWidgets()
        await MainActor.run {
            NotificationCenter.default.post(name: .logWeightWidgetDidSave, object: nil)
        }
        return .result()
    }
}
