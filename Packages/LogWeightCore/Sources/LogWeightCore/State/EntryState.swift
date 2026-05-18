import Foundation
import Observation

/// Result of the entry surface's first HealthKit weight history read.
public enum InitialWeightLoadOutcome: Equatable, Sendable {
    case pending
    case emptyStore
    case hasPriorWeight
    case loadFailed
}

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
    /// Outcome of the first `loadLastWeight(from:)` attempt.
    public private(set) var initialWeightLoadOutcome: InitialWeightLoadOutcome = .pending
    /// `true` when HealthKit has no samples yet and the entry surface should not show a default weight.
    public private(set) var isAwaitingFirstWeight: Bool = false

    /// `true` after the first `loadLastWeight(from:)` attempt finishes (success or failure).
    public var hasResolvedInitialWeight: Bool {
        initialWeightLoadOutcome != .pending
    }

    /// `true` only when HealthKit read succeeded and returned no body-mass samples.
    public var hasConfirmedEmptyWeightStore: Bool {
        initialWeightLoadOutcome == .emptyStore
    }

    private let stepIncrementInKilograms: Double
    private static let stepperBaseKilograms: Double = 75.0

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
    /// On read failure the entry surface is never blocked; keyboard-first entry is not offered.
    public func loadLastWeight(from store: HealthKitStore) async {
        do {
            if let recent = try await store.recentWeights(limit: 1).first {
                lastSavedWeight = recent
                displayValueInKilograms = recent.valueInKilograms
                initialWeightLoadOutcome = .hasPriorWeight
                isAwaitingFirstWeight = false
            } else {
                prepareForFirstWeightEntry()
                initialWeightLoadOutcome = .emptyStore
            }
        } catch {
            initialWeightLoadOutcome = .loadFailed
            isAwaitingFirstWeight = false
        }
    }

    /// Resets the entry surface for keyboard-first first weight entry.
    public func prepareForFirstWeightEntry() {
        isAwaitingFirstWeight = true
        displayValueInKilograms = 0
        lastSavedWeight = nil
        saveStatus = .idle
    }

    public func increment() {
        activateStepperBaseIfNeeded()
        let next = displayValueInKilograms + stepIncrementInKilograms
        displayValueInKilograms = clamp(next)
    }

    public func decrement() {
        activateStepperBaseIfNeeded()
        let next = displayValueInKilograms - stepIncrementInKilograms
        displayValueInKilograms = clamp(next)
    }

    public func setValue(_ value: Double, unit: WeightUnit) {
        let measurement = Measurement(value: value, unit: unit.unitMass)
        displayValueInKilograms = clamp(measurement.converted(to: .kilograms).value)
        isAwaitingFirstWeight = false
    }

    private func activateStepperBaseIfNeeded() {
        guard isAwaitingFirstWeight, displayValueInKilograms == 0 else { return }
        displayValueInKilograms = Self.stepperBaseKilograms
        isAwaitingFirstWeight = false
    }

    /// Persists the current value via `store`. The function returns when the save
    /// has either succeeded or failed; UI observes `saveStatus` to react.
    ///
    /// Always calls `requestAuthorization()` before `save`. Opening the Health
    /// app or adding manual samples does **not** grant LogWeight access — the user
    /// must allow this app in the system HealthKit sheet (or in Settings → Health).
    public func commit(store: HealthKitStore, now: Date = .now) async {
        guard displayValueInKilograms > 0 else {
            return
        }
        saveStatus = .saving
        let weight = Weight(valueInKilograms: displayValueInKilograms, recordedAt: now)
        do {
            try await store.requestAuthorization()
            try await store.save(weight)
            saveStatus = .savedAt(now)
            lastSavedWeight = weight
            if initialWeightLoadOutcome == .emptyStore {
                initialWeightLoadOutcome = .hasPriorWeight
                isAwaitingFirstWeight = false
            }
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

    /// Sets the displayed weight to `lastSavedWeight` (from `loadLastWeight` or the last successful `commit`).
    /// Silently no-ops when nothing has been loaded or saved yet in this session.
    public func restoreDisplayToLastLoggedWeight() {
        guard let weight = lastSavedWeight else { return }
        setValue(weight.valueInKilograms, unit: .kilograms)
    }

    private func clamp(_ value: Double) -> Double {
        // Body weight bounds: 1 kg .. 500 kg. Defensive only — UI prevents this anyway.
        max(1.0, min(500.0, value))
    }
}
