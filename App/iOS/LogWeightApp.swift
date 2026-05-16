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
                MainTabView(entryState: entryState, store: healthKitStore)
                    .modifier(PrivacyRedactionModifier())
                    .onReceive(NotificationCenter.default.publisher(for: .logWeightWidgetDidSave)) { _ in
                        Task { @MainActor in
                            await entryState.loadLastWeight(from: healthKitStore)
                        }
                    }

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
    ///
    /// When `--use-in-memory-store` is paired with `--seed=<rawValue>` (e.g.
    /// `--seed=linearTrend30Days`), the in-memory store is preloaded with the
    /// matching `ScreenshotFixture` so AI-driven screenshot tests can capture
    /// deterministic states.
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
