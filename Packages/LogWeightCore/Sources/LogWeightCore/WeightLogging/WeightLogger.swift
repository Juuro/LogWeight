import Foundation

/// Why a value needs explicit confirmation before it is saved.
public enum WeightLogConfirmationReason: Sendable, Equatable {
    case outOfRange
    case largeJump
}

/// Result of checking a logging request. Checking never writes.
public enum WeightLogEvaluation: Sendable, Equatable {
    case ready(Weight)
    case needsConfirmation(Weight, WeightLogConfirmationReason)
    case duplicate(Weight)
    case accessNotGranted
    case invalid
}

/// Final result of a logging request. Carries no health values beyond the
/// `Weight` the caller already supplied; `.failed` carries only a numeric code.
public enum WeightLogOutcome: Sendable, Equatable {
    case saved(Weight)
    case alreadyLogged(Weight)
    case declined
    case accessNotGranted
    case invalid
    case failed(reasonCode: Int)
}

/// Decision logic for logging a weight outside the stepper UI.
///
/// Callers `evaluate` first, optionally ask the user to confirm, then `save`.
/// Writes go through `HealthKitStore` only; nothing is cached or persisted here.
public struct WeightLogger: Sendable {
    private let store: any HealthKitStore
    private let policy: WeightLogPolicy
    private let now: @Sendable () -> Date

    public init(
        store: any HealthKitStore,
        policy: WeightLogPolicy = .default,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.store = store
        self.policy = policy
        self.now = now
    }

    /// Checks a request without writing.
    public func evaluate(kilograms: Double) async -> WeightLogEvaluation {
        guard await store.authorizationStatus() == .sharingAuthorized else {
            return .accessNotGranted
        }
        guard kilograms.isFinite, kilograms > 0 else {
            return .invalid
        }
        let timestamp = now()
        let weight = Weight(valueInKilograms: kilograms, recordedAt: timestamp)

        // A failed read counts as "no previous sample" (the range check still applies).
        let newest = (try? await store.recentWeights(limit: 1))?.first

        if let newest, isDuplicate(kilograms, of: newest, at: timestamp) {
            return .duplicate(newest)
        }
        if !policy.plausibleRangeKilograms.contains(kilograms) {
            return .needsConfirmation(weight, .outOfRange)
        }
        if let newest,
           abs(kilograms - newest.valueInKilograms) > policy.largeJumpKilograms {
            return .needsConfirmation(weight, .largeJump)
        }
        return .ready(weight)
    }

    /// Same value (within tolerance) as the newest entry, recorded moments ago.
    /// Covers a repeat run and an entry just made through Apple Health's own Siri logging.
    private func isDuplicate(_ kilograms: Double, of newest: Weight, at timestamp: Date) -> Bool {
        let age = timestamp.timeIntervalSince(newest.recordedAt)
        return age >= 0
            && age <= policy.duplicateWindow
            && abs(kilograms - newest.valueInKilograms) <= policy.duplicateToleranceKilograms
    }

    /// Writes the weight once. Never retries and never logs the value.
    public func save(_ weight: Weight) async -> WeightLogOutcome {
        do {
            try await store.save(weight)
            return .saved(weight)
        } catch let error as HealthKitError {
            return failure(for: error)
        } catch {
            SecurityLog.error("weight_log_save_failed", code: -1)
            return .failed(reasonCode: -1)
        }
    }

    private func failure(for error: HealthKitError) -> WeightLogOutcome {
        switch error {
        case .authorizationDenied:
            return .accessNotGranted
        case .saveFailed(let code):
            SecurityLog.error("weight_log_save_failed", code: code)
            return .failed(reasonCode: code)
        default:
            SecurityLog.error("weight_log_save_failed", code: -1)
            return .failed(reasonCode: -1)
        }
    }
}
