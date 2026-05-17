import Foundation
import LogWeightCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Keeps widgets aligned with HealthKit and in-app mutations.
enum WidgetTimelineRefresh {
#if canImport(WidgetKit)
    static func reloadEntryWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.kind)
    }

#if os(iOS)
    static func reloadChartWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.chartKind)
    }

    static func reloadEntryAndChartWidgets() {
        reloadEntryWidget()
        reloadChartWidget()
    }
#endif

    static func syncEntryStoreAndReloadWidgets(store: HealthKitStore) async {
#if os(iOS)
        let latest = try? await store.recentWeights(limit: 1).first
        SharedWeightEntryStore.syncFromLatestWeight(latest)
        reloadEntryAndChartWidgets()
#endif
    }
#endif
}
