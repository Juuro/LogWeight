import SwiftUI
import WidgetKit
import LogWeightCore

@main
struct LogWeightWatchApp: App {

    @State private var entryState = EntryState()
    private let healthKitStore: HealthKitStore = Self.makeStore()

    var body: some Scene {
        WindowGroup {
            WatchEntryView(state: entryState, store: healthKitStore)
                .task {
                    SettingsMigrator.migrateIfNeeded()
                    try? await healthKitStore.requestAuthorization()
                    await entryState.loadLastWeight(from: healthKitStore)
                    WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.watchKind)
                }
        }
    }

    private static func makeStore() -> HealthKitStore {
        if CommandLine.arguments.contains("--use-in-memory-store") {
            return InMemoryHealthKitStore()
        }
        return HKHealthStoreAdapter()
    }
}
