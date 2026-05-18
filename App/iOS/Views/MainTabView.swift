import SwiftUI
import LogWeightCore

struct MainTabView: View {

    enum Tab: Hashable {
        case entry
        case history
    }

    @Bindable var entryState: EntryState
    let store: HealthKitStore
    @State private var selectedTab: Tab = .entry

    var body: some View {
        TabView(selection: $selectedTab) {
            EntryView(state: entryState, store: store)
                .tabItem {
                    Label("Entry", systemImage: "scalemass")
                }
                .accessibilityIdentifier("tab.entry")
                .tag(Tab.entry)

            HistoryView(store: store, showsDoneButton: false)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .accessibilityIdentifier("tab.history")
                .tag(Tab.history)
        }
        .modifier(TabBarOnlyOnSupportedPlatforms())
        .task {
            for await _ in store.observeChanges() {
                guard !Task.isCancelled else { return }
                await entryState.loadLastWeight(from: store)
                await WidgetTimelineRefresh.syncEntryStoreAndReloadWidgets(store: store)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "logweight", url.host == "history" else { return }
            selectedTab = .history
        }
    }
}

/// Keeps Entry/History on a bottom tab bar on iPad (iOS 18+ defaults to sidebar).
/// Matches XCUITest expectations and fits a two-tab utility app.
private struct TabBarOnlyOnSupportedPlatforms: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.tabViewStyle(.tabBarOnly)
        } else {
            content
        }
    }
}

#Preview {
    MainTabView(entryState: EntryState(initialValueInKilograms: 75.0),
                store: InMemoryHealthKitStore(samples: ScreenshotFixture.linearTrend30Days.samples()))
}
