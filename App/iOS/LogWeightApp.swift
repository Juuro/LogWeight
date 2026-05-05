import SwiftUI
import LogWeightCore

@main
struct LogWeightApp: App {

    @State private var entryState: EntryState
    @State private var showSplash = true
    @State private var didStartStartupFlow = false
    @State private var startupReady = false
    @State private var minimumSplashTimeElapsed = false
    @State private var skipRequested = false
    @State private var showPreparing = false
    private let holdSplashForUITest: Bool
    private let skipSplashForUITest: Bool
    private let healthKitStore: HealthKitStore

    private static let minimumSplashDuration: Duration = .seconds(1.2)
    private static let preparingHintDelay: Duration = .seconds(1.4)

    init() {
        SettingsMigrator.migrateIfNeeded()
        let store = Self.makeStore()
        self.healthKitStore = store
        self._entryState = State(initialValue: EntryState())
        self.skipSplashForUITest = CommandLine.arguments.contains("--skip-splash")
        self.holdSplashForUITest = CommandLine.arguments.contains("--hold-splash")
        if self.skipSplashForUITest {
            self._showSplash = State(initialValue: false)
            self._minimumSplashTimeElapsed = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                EntryView(state: entryState, store: healthKitStore)
                    .modifier(PrivacyRedactionModifier())

                if showSplash {
                    SplashOverlayView(showPreparing: showPreparing) {
                        skipRequested = true
                        if holdSplashForUITest {
                            dismissSplash()
                            return
                        }
                        dismissSplashIfReady()
                    }
                    .transition(.opacity)
                }
            }
            .task {
                await runStartupFlowIfNeeded()
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

    @MainActor
    private func runStartupFlowIfNeeded() async {
        guard !didStartStartupFlow else { return }
        didStartStartupFlow = true

        let minimumTimer = Task {
            try? await Task.sleep(for: Self.minimumSplashDuration)
            await MainActor.run {
                minimumSplashTimeElapsed = true
                dismissSplashIfReady()
            }
        }

        let preparingTimer = Task {
            try? await Task.sleep(for: Self.preparingHintDelay)
            await MainActor.run {
                guard showSplash && !startupReady else { return }
                showPreparing = true
            }
        }

        // Prompt for HealthKit before first save so "Save" stays one tap
        // after the user has allowed access. Configuring the Health app alone
        // does not grant LogWeight read/write — this call is required.
        try? await healthKitStore.requestAuthorization()
        await entryState.loadLastWeight(from: healthKitStore)

        startupReady = true
        preparingTimer.cancel()
        dismissSplashIfReady()

        _ = await minimumTimer.result
    }

    @MainActor
    private func dismissSplashIfReady() {
        guard showSplash else { return }
        guard !holdSplashForUITest else { return }
        guard startupReady else { return }
        guard minimumSplashTimeElapsed || skipRequested else { return }
        dismissSplash()
    }

    @MainActor
    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.22)) {
            showSplash = false
        }
    }
}
