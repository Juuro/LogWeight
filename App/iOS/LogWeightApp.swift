import SwiftUI
import LogWeightCore

@main
struct LogWeightApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @State private var entryState: EntryState
    private let healthKitStore: HealthKitStore

    init() {
        SettingsMigrator.migrateIfNeeded()
        let store = Self.makeStore()
        self.healthKitStore = store
        self._entryState = State(initialValue: EntryState())
    }

    var body: some Scene {
        WindowGroup {
            EntryView(state: entryState, store: healthKitStore)
                .modifier(PrivacyRedactionModifier())
                .task {
                    await entryState.loadLastWeight(from: healthKitStore)
                }
        }
    }

    /// Picks the production `HKHealthStoreAdapter` unless the launch arguments
    /// request the in-memory store (used by `EntryViewSmokeTests`).
    private static func makeStore() -> HealthKitStore {
        if CommandLine.arguments.contains("--use-in-memory-store") {
            return InMemoryHealthKitStore()
        }
        return HKHealthStoreAdapter()
    }
}
