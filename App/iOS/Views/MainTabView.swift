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
                .tag(Tab.entry)

            HistoryView(store: store, showsDoneButton: false)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(Tab.history)
        }
    }
}

#Preview {
    MainTabView(entryState: EntryState(initialValueInKilograms: 75.0),
                store: InMemoryHealthKitStore(samples: ScreenshotFixture.linearTrend30Days.samples()))
}
