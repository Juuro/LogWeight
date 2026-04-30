import Foundation
import HealthKit

/// Production `HealthKitStore` backed by a real `HKHealthStore`.
///
/// Lives only on platforms that ship HealthKit (iOS, iPadOS, watchOS, macOS).
/// tvOS does not ship HealthKit; LogWeight does not target tvOS.
public final class HKHealthStoreAdapter: HealthKitStore {

    private let healthStore: HKHealthStore
    private let bodyMassType: HKQuantityType

    public init() {
        self.healthStore = HKHealthStore()
        // Force-unwrap is safe: bodyMass is a system-defined identifier that
        // is guaranteed to resolve on every platform that ships HealthKit.
        // We assert at init so a future SDK regression is caught immediately.
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            preconditionFailure("HKQuantityTypeIdentifier.bodyMass is not available; the SDK is broken.")
        }
        self.bodyMassType = type
    }

    public func authorizationStatus() async -> HealthKitAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .sharingDenied
        }
        switch healthStore.authorizationStatus(for: bodyMassType) {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .sharingDenied
        case .sharingAuthorized:
            return .sharingAuthorized
        @unknown default:
            return .notDetermined
        }
    }

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        let toShare: Set<HKSampleType> = [bodyMassType]
        let toRead: Set<HKObjectType> = [bodyMassType]
        try await healthStore.requestAuthorization(toShare: toShare, read: toRead)
    }

    public func save(_ weight: Weight) async throws {
        try await saveWithTimestampRetry(weight)
    }

    /// Writes a body-mass sample and retries with tiny timestamp nudges when
    /// HealthKit rejects with invalid-argument collisions (code 3).
    private func saveWithTimestampRetry(_ weight: Weight) async throws {
        do {
            try await saveOnce(weight)
            return
        } catch HealthKitError.saveFailed(let code) where code == HKError.Code.errorInvalidArgument.rawValue {
            // Retry with slight second offsets to avoid same-instant collisions.
            for secondOffset in 1...5 {
                let shifted = Weight(
                    valueInKilograms: weight.valueInKilograms,
                    recordedAt: weight.recordedAt.addingTimeInterval(TimeInterval(secondOffset))
                )
                do {
                    try await saveOnce(shifted)
                    return
                } catch HealthKitError.saveFailed(let retryCode) where retryCode == HKError.Code.errorInvalidArgument.rawValue {
                    continue
                }
            }
            throw HealthKitError.saveFailed(reasonCode: HKError.Code.errorInvalidArgument.rawValue)
        }
    }

    /// Single-attempt sample write mapped into `HealthKitError`.
    private func saveOnce(_ weight: Weight) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight.valueInKilograms)
        let sample = HKQuantitySample(
            type: bodyMassType,
            quantity: quantity,
            start: weight.recordedAt,
            end: weight.recordedAt
        )
        do {
            try await healthStore.save(sample)
        } catch let error as HKError {
            throw HealthKitError.saveFailed(reasonCode: error.code.rawValue)
        } catch {
            throw HealthKitError.saveFailed(reasonCode: -1)
        }
    }

    public func recentWeights(limit: Int) async throws -> [Weight] {
        guard HKHealthStore.isHealthDataAvailable() else {
            return []
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Weight], Error>) in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error as? HKError {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: error.code.rawValue))
                    return
                }
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: (error as NSError).code))
                    return
                }
                let weights: [Weight] = (samples ?? []).compactMap { sample in
                    guard let q = sample as? HKQuantitySample else { return nil }
                    let kg = q.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    return Weight(valueInKilograms: kg, recordedAt: q.endDate)
                }
                continuation.resume(returning: weights)
            }
            healthStore.execute(query)
        }
    }

    public func delete(_ weight: Weight) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }

        guard let matchingSample = try await fetchMatchingQuantitySample(for: weight) else {
            throw HealthKitError.deleteFailed(reasonCode: -1)
        }

        try await hkDelete(sample: matchingSample, mapFailure: HealthKitError.deleteFailed(reasonCode:))
    }

    public func replace(old: Weight, new: Weight) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        // No-op edits (same value and timestamp) should succeed silently.
        guard old != new else {
            return
        }
        guard let oldSample = try await fetchMatchingQuantitySample(for: old) else {
            throw HealthKitError.replaceFailed(reasonCode: -1)
        }
        do {
            try await hkDelete(sample: oldSample, mapFailure: HealthKitError.replaceFailed(reasonCode:))
        } catch HealthKitError.replaceFailed(let deleteCode) where deleteCode == HKError.Code.errorInvalidArgument.rawValue {
            // Some samples can be non-replaceable in-place on device (e.g. source/ownership constraints).
            // Fall back to writing the edited value so the user's change is not lost.
            do {
                try await save(new)
                return
            } catch HealthKitError.saveFailed(let code) {
                throw HealthKitError.replaceFailed(reasonCode: code)
            } catch HealthKitError.healthDataUnavailable {
                throw HealthKitError.healthDataUnavailable
            } catch {
                throw HealthKitError.replaceFailed(reasonCode: -1)
            }
        }
        do {
            try await save(new)
        } catch HealthKitError.saveFailed(let code) {
            // Best-effort rollback so replace remains lossless when possible.
            try? await save(old)
            throw HealthKitError.replaceFailed(reasonCode: code)
        } catch HealthKitError.healthDataUnavailable {
            // Best-effort rollback for completeness.
            try? await save(old)
            throw HealthKitError.healthDataUnavailable
        } catch {
            try? await save(old)
            throw HealthKitError.replaceFailed(reasonCode: -1)
        }
    }

    /// Resolves a persisted `HKQuantitySample` matching a `Weight` from `recentWeights`.
    private func fetchMatchingQuantitySample(for weight: Weight) async throws -> HKQuantitySample? {
        let start = weight.recordedAt.addingTimeInterval(-1)
        let end = weight.recordedAt.addingTimeInterval(1)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantitySample?, Error>) in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: datePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error as? HKError {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: error.code.rawValue))
                    return
                }
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(reasonCode: (error as NSError).code))
                    return
                }

                let target = weight.valueInKilograms
                let sample = (samples ?? [])
                    .compactMap { $0 as? HKQuantitySample }
                    .filter { quantitySample in
                        let value = quantitySample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                        return abs(value - target) < 0.0005
                    }
                    .min(by: { lhs, rhs in
                        abs(lhs.endDate.timeIntervalSince(weight.recordedAt))
                        < abs(rhs.endDate.timeIntervalSince(weight.recordedAt))
                    })
                continuation.resume(returning: sample)
            }
            healthStore.execute(query)
        }
    }

    private func hkDelete(sample matchingSample: HKQuantitySample, mapFailure: (Int) -> HealthKitError) async throws {
        do {
            try await healthStore.delete(matchingSample)
        } catch let error as HKError {
            throw mapFailure(error.code.rawValue)
        } catch {
            throw mapFailure((error as NSError).code)
        }
    }

    public func observeChanges() -> AsyncStream<Void> {
        // Implementation contract: see HealthKitStore protocol comments.
        // We hold the query in a Task-scoped reference so onTermination can stop it.
        let healthStore = self.healthStore
        let bodyMassType = self.bodyMassType
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)

        // The query itself must be alive for the lifetime of the stream.
        // We keep it in a class-bound holder so onTermination can release it.
        let holder = QueryHolder()
        let query = HKObserverQuery(sampleType: bodyMassType, predicate: nil) { _, completion, _ in
            continuation.yield(())
            completion()
        }
        holder.query = query
        healthStore.execute(query)

        continuation.onTermination = { @Sendable _ in
            if let q = holder.query {
                healthStore.stop(q)
                holder.query = nil
            }
        }
        return stream
    }

    /// Holds a strong reference to the active observer query so we can stop it
    /// on stream termination. Class-bound so the closure capture is reference-typed
    /// and reassignment works across the actor boundary.
    private final class QueryHolder: @unchecked Sendable {
        var query: HKObserverQuery?
    }
}
