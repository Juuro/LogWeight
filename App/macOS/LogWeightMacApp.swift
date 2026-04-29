import SwiftUI
import LogWeightCore

@main
struct LogWeightMacApp: App {

    @State private var entryState: EntryState
    private let healthKitStore: HealthKitStore

    init() {
        SettingsMigrator.migrateIfNeeded()
        let store = Self.makeStore()
        self.healthKitStore = store
        self._entryState = State(initialValue: EntryState())
    }

    var body: some Scene {
        MenuBarExtra("LogWeight", systemImage: "scalemass") {
            MacMenuBarEntryView(state: entryState, store: healthKitStore)
                .task {
                    try? await healthKitStore.requestAuthorization()
                    await entryState.loadLastWeight(from: healthKitStore)
                }
        }
        .menuBarExtraStyle(.window)

        WindowGroup("History", id: "history") {
            HistoryView(store: healthKitStore)
                .frame(minWidth: 360, minHeight: 420)
        }

        Settings {
            SettingsView()
                .frame(minWidth: 420, minHeight: 380)
        }
    }

    private static func makeStore() -> HealthKitStore {
        if CommandLine.arguments.contains("--use-in-memory-store") {
            return InMemoryHealthKitStore()
        }
        return HKHealthStoreAdapter()
    }
}
