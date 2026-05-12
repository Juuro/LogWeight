import Foundation

/// Authorisation state of LogWeight's HealthKit access.
///
/// Mirrors a subset of `HKAuthorizationStatus` but is decoupled from the HealthKit
/// types so the protocol stays testable without `import HealthKit`.
public enum HealthKitAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case sharingDenied
    case sharingAuthorized
}

/// Errors surfaced by any `HealthKitStore` implementation.
///
/// Do NOT include weight values, sample identifiers, or user identifiers in
/// `localizedDescription`. The caller is responsible for never logging the value.
public enum HealthKitError: Error, Sendable, Equatable {
    case healthDataUnavailable
    case authorizationDenied
    case saveFailed(reasonCode: Int)
    case queryFailed(reasonCode: Int)
    case deleteFailed(reasonCode: Int)
    /// The sample was created by a different source and cannot be deleted by this app.
    case deleteNotPermitted
    /// Failed to replace an existing entry (e.g. could not locate old sample or write failed mid-replace).
    case replaceFailed(reasonCode: Int)
}

/// Abstraction over HealthKit body-mass read/write.
///
/// The protocol is intentionally minimal so the production adapter
/// (`HKHealthStoreAdapter`) and the test/preview double (`InMemoryHealthKitStore`)
/// remain trivially swappable. `LogWeightCore` never imports `HealthKit` outside
/// of the production adapter — this protocol surfaces only Foundation types.
///
/// ## Threading
/// All async functions are safe to call from any context. Implementations MUST
/// hop to the appropriate executor internally.
///
/// ## Implementation contract for `observeChanges()`
/// Implementations MUST:
/// 1. Build the stream via `AsyncStream.makeStream(of: Void.self)`.
/// 2. Hold the resulting continuation weakly (or via a dedicated actor) so that
///    cancellation of the consuming `Task` does not leak.
/// 3. Set `continuation.onTermination` to invalidate any underlying observer
///    (e.g. stop an `HKObserverQuery`) so observers do not outlive their consumer.
/// 4. Phase 1 uses foreground delivery only. Optional
///    `enableBackgroundDelivery` for observer-driven refreshes is a later
///    optimisation (battery review on watchOS before enabling).
public protocol HealthKitStore: Sendable {
    /// Current authorisation state for body-mass write. Read access is implicitly
    /// ungrantable per Apple's HealthKit privacy model — `recentWeights` will
    /// simply return an empty array if the user has not authorised reads.
    func authorizationStatus() async -> HealthKitAuthorizationStatus

    /// Requests authorisation for body-mass read+write. May present the system
    /// HealthKit sheet on first call. Throws `HealthKitError.healthDataUnavailable`
    /// on platforms / devices without HealthKit.
    func requestAuthorization() async throws

    /// Persists a weight sample. Returns `Void` — record identity is intentionally
    /// not surfaced through this boundary because nothing in the app currently
    /// needs it, and exposing it would couple callers to HealthKit semantics.
    func save(_ weight: Weight) async throws

    /// Reads the `limit` most-recent body-mass samples, newest first.
    func recentWeights(limit: Int) async throws -> [Weight]

    /// Deletes a previously read weight sample.
    ///
    /// Callers should pass an item returned by `recentWeights(limit:)`.
    func delete(_ weight: Weight) async throws

    /// Replaces an existing sample with updated weight and timestamp.
    ///
    /// Implementations MUST resolve `old` to the same persisted record callers see from
    /// `recentWeights(limit:)`, typically by matching date and value near that row.
    func replace(old: Weight, new: Weight) async throws

    /// Yields a `Void` element each time the body-mass record set changes. See
    /// the protocol-level "Implementation contract" comment above for required
    /// invariants. Cancellation of the consuming `Task` MUST stop the underlying
    /// observer.
    func observeChanges() -> AsyncStream<Void>
}
