import Foundation
import LogWeightCore
#if os(iOS)
import WidgetKit
#endif

/// Keeps Home Screen widgets aligned with HealthKit after app-side mutations.
enum WidgetTimelineRefresh {
    static func syncEntryStoreAndReloadAll(store: HealthKitStore) async {
#if os(iOS)
        let latest = try? await store.recentWeights(limit: 1).first
        SharedWeightEntryStore.syncFromLatestWeight(latest)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}
