import Foundation

/// Persists the widget's current value through `HealthKitStore` and mirrors it to
/// the App Group cache used for fast widget rendering.
public enum WidgetWeightSave {
    public static func commit(
        to store: HealthKitStore,
        now: Date = .now,
        userDefaults: UserDefaults? = nil
    ) async throws {
        let value = SharedWeightEntryStore.loadCurrentValue(userDefaults: userDefaults)
        let weight = Weight(valueInKilograms: value, recordedAt: now)
        if await store.authorizationStatus() != .sharingAuthorized {
            try await store.requestAuthorization()
        }
        try await store.save(weight)
        SharedWeightEntryStore.save(WeightEntry(value: value, date: now), userDefaults: userDefaults)
        SharedWeightEntryStore.clearDraftValue(userDefaults: userDefaults)
    }
}
