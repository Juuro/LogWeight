import Foundation
import Observation

/// Observable state for the entry surface.
///
/// One instance per screen lifetime. `commit(store:)` is the only path that
/// touches HealthKit; everything else is pure state mutation that can be
/// exercised in tests without HealthKit entitlements.
@Observable
@MainActor
public final class EntryState {

    public enum SaveStatus: Equatable, Sendable {
        case idle
        case saving
        case savedAt(Date)
        case failed(reasonCode: Int)
    }

    public var displayValueInKilograms: Double
    public var displayUnit: WeightUnit
    public private(set) var saveStatus: SaveStatus
    public private(set) var lastSavedWeight: Weight?

    private let stepIncrementInKilograms: Double

    public init(
        initialValueInKilograms: Double = 75.0,
        displayUnit: WeightUnit = .kilograms,
        stepIncrementInKilograms: Double = 0.1
    ) {
        self.displayValueInKilograms = initialValueInKilograms
        self.displayUnit = displayUnit
        self.saveStatus = .idle
        self.lastSavedWeight = nil
        self.stepIncrementInKilograms = stepIncrementInKilograms
    }

    /// Pre-fills the value with the most-recent saved weight, if available.
    /// Silently no-ops on read failure — the entry surface is never blocked.
    public func loadLastWeight(from store: HealthKitStore) async {
        guard let recent = try? await store.recentWeights(limit: 1).first else {
            return
        }
        self.lastSavedWeight = recent
        self.displayValueInKilograms = recent.valueInKilograms
    }

    public func increment() {
        let next = displayValueInKilograms + stepIncrementInKilograms
        displayValueInKilograms = clamp(next)
    }

    public func decrement() {
        let next = displayValueInKilograms - stepIncrementInKilograms
        displayValueInKilograms = clamp(next)
    }

    public func setValue(_ value: Double, unit: WeightUnit) {
        let measurement = Measurement(value: value, unit: unit.unitMass)
        displayValueInKilograms = clamp(measurement.converted(to: .kilograms).value)
    }

    /// Persists the current value via `store`. The function returns when the save
    /// has either succeeded or failed; UI observes `saveStatus` to react.
    public func commit(store: HealthKitStore, now: Date = .now) async {
        saveStatus = .saving
        let weight = Weight(valueInKilograms: displayValueInKilograms, recordedAt: now)
        do {
            try await store.save(weight)
            saveStatus = .savedAt(now)
            lastSavedWeight = weight
        } catch HealthKitError.saveFailed(let code) {
            saveStatus = .failed(reasonCode: code)
        } catch HealthKitError.healthDataUnavailable {
            saveStatus = .failed(reasonCode: -2)
        } catch HealthKitError.authorizationDenied {
            saveStatus = .failed(reasonCode: -3)
        } catch {
            saveStatus = .failed(reasonCode: (error as NSError).code)
        }
    }

    public func reset() {
        saveStatus = .idle
    }

    private func clamp(_ value: Double) -> Double {
        // Body weight bounds: 1 kg .. 500 kg. Defensive only — UI prevents this anyway.
        max(1.0, min(500.0, value))
    }
}
