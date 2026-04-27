import Foundation

/// Test / preview / SwiftUI-canvas-friendly `HealthKitStore` that holds samples
/// in memory and requires zero entitlements.
///
/// Configurable failure modes let tests exercise the denied / save-fails / query-fails
/// branches without touching the real `HKHealthStore`.
public actor InMemoryHealthKitStore: HealthKitStore {

    public enum FailureMode: Sendable, Equatable {
        case happyPath
        case authorizationDenied
        case saveFails(reasonCode: Int)
        case queryFails(reasonCode: Int)
    }

    private var samples: [Weight]
    private var status: HealthKitAuthorizationStatus
    private var failureMode: FailureMode
    private var continuations: [AsyncStream<Void>.Continuation] = []

    public init(
        samples: [Weight] = [],
        authorizationStatus: HealthKitAuthorizationStatus = .sharingAuthorized,
        failureMode: FailureMode = .happyPath
    ) {
        self.samples = samples
        self.status = authorizationStatus
        self.failureMode = failureMode
    }

    public func authorizationStatus() async -> HealthKitAuthorizationStatus {
        status
    }

    public func requestAuthorization() async throws {
        if case .authorizationDenied = failureMode {
            status = .sharingDenied
            throw HealthKitError.authorizationDenied
        }
        status = .sharingAuthorized
    }

    public func save(_ weight: Weight) async throws {
        if case .saveFails(let code) = failureMode {
            throw HealthKitError.saveFailed(reasonCode: code)
        }
        samples.insert(weight, at: 0)
        for continuation in continuations {
            continuation.yield(())
        }
    }

    public func recentWeights(limit: Int) async throws -> [Weight] {
        if case .queryFails(let code) = failureMode {
            throw HealthKitError.queryFailed(reasonCode: code)
        }
        let sorted = samples.sorted { $0.recordedAt > $1.recordedAt }
        return Array(sorted.prefix(max(0, limit)))
    }

    public nonisolated func observeChanges() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        Task {
            await self.register(continuation: continuation)
        }
        continuation.onTermination = { @Sendable [weak self] _ in
            Task {
                await self?.unregister(continuation: continuation)
            }
        }
        return stream
    }

    /// Test affordance: change the failure mode mid-test.
    public func setFailureMode(_ mode: FailureMode) {
        self.failureMode = mode
    }

    /// Test affordance: read the current sample count without going through the
    /// public query API (which can be configured to fail).
    public func sampleCount() -> Int {
        samples.count
    }

    private func register(continuation: AsyncStream<Void>.Continuation) {
        continuations.append(continuation)
    }

    private func unregister(continuation: AsyncStream<Void>.Continuation) {
        continuations.removeAll { existing in
            // Continuation is not Equatable; identify by reference via withUnsafePointer.
            withUnsafePointer(to: existing) { lhs in
                withUnsafePointer(to: continuation) { rhs in
                    lhs == rhs
                }
            }
        }
    }
}
