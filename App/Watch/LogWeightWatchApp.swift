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
        guard CommandLine.arguments.contains("--use-in-memory-store") else {
            return HKHealthStoreAdapter()
        }
        let fixtureSamples = parseSeedFixture(from: CommandLine.arguments)?.samples() ?? []
        return InMemoryHealthKitStore(samples: fixtureSamples)
    }

    private static func parseSeedFixture(from arguments: [String]) -> ScreenshotFixture? {
        let prefix = "--seed="
        guard let raw = arguments.first(where: { $0.hasPrefix(prefix) })?.dropFirst(prefix.count) else {
            return nil
        }
        return ScreenshotFixture(rawValue: String(raw))
    }
}
